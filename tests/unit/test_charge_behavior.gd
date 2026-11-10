extends TestCase
## ChargeBehavior(행동 조각 "돌진하기") 단위 테스트.
## 조각은 body.velocity만 정하므로, 트리에 넣지 않은 노드로 확인하고 이동은 여기서 직접 한다.

const DT: float = 1.0 / 60.0
const SPEED: float = 35.0
const DAMAGE: float = 3.0
const BODY_MASK: int = 23
const BODY_LAYER: int = 4
const WORLD_MASK: int = 1
## 원래 몸 색 (팔레트 181425)
const BASE_COLOR: Color = Color(0.09411765, 0.078431375, 0.14509805, 1)


## get_hostiles()가 있는 가짜 몸
class FakeBody:
	extends CharacterBody2D
	var hostiles: Array[Node2D] = []

	func get_hostiles() -> Array[Node2D]:
		return hostiles


## 피해와 밀쳐내기를 기록하는 가짜 상대
class FakeHostile:
	extends Node2D
	var damage: Array[float] = []
	var pushes: Array[Vector2] = []

	func take_damage(amount: float, _source: Node2D = null) -> void:
		damage.append(amount)

	func knock_back(offset: Vector2, _duration: float) -> void:
		pushes.append(offset)


var body: FakeBody
var target: FakeHostile
var stats: CombatStats
var charge: ChargeBehavior


func before_each() -> void:
	body = FakeBody.new()
	body.collision_mask = BODY_MASK
	body.collision_layer = BODY_LAYER
	target = FakeHostile.new()
	body.hostiles = [target]
	stats = CombatStats.create(SPEED, 0.0, DAMAGE, 0.0)
	charge = ChargeBehavior.new()
	charge.world_collision_mask = WORLD_MASK


func after_each() -> void:
	body.free()
	target.free()


## 한 프레임: 조각을 부르고, 정한 속도로 몸을 옮긴다 (move_and_slide 대신).
func _step(with_target: bool = true) -> void:
	charge.update(DT)
	charge.act(body, stats, target if with_target else null, DT)
	body.position += body.velocity * DT


## 예고가 끝날 때까지 진행한다 (돌진 시작 직전까지).
func _run_windup() -> void:
	target.position = Vector2(charge.charge_range - 10.0, 0)
	_step()
	var frames: int = 0
	while charge.get_state() == ChargeBehavior.State.WINDUP and frames < 600:
		_step()
		frames += 1


func test_warning_segment_only_during_windup() -> void:
	assert_eq(charge.get_warning_segment(Vector2.ZERO).size(), 0, "예고 전에는 선이 없음")
	charge._state = ChargeBehavior.State.WINDUP
	charge._direction = Vector2.RIGHT
	var segment: PackedVector2Array = charge.get_warning_segment(Vector2(10, 20))
	assert_eq(segment[0], Vector2(10, 20), "몸에서 시작")
	assert_eq(segment[1], Vector2(10, 20) + Vector2.RIGHT * charge.get_charge_length(Vector2(10, 20)), "돌진 길이만큼")


func test_far_target_is_approached_without_attacking() -> void:
	target.position = Vector2(charge.charge_range + 50.0, 0)
	_step()
	assert_eq(charge.get_state(), ChargeBehavior.State.APPROACH)
	assert_almost_eq(body.velocity.x, SPEED, 0.001, "이동 속도로 다가간다")
	assert_false(charge.is_busy())
	assert_true(target.damage.is_empty(), "다가가는 동안은 공격하지 않는다")


func test_in_range_starts_windup_and_stops() -> void:
	target.position = Vector2(charge.charge_range - 10.0, 0)
	_step()
	assert_eq(charge.get_state(), ChargeBehavior.State.WINDUP)
	assert_true(charge.is_busy(), "예고 중에는 대상이 없어도 이어 간다")
	assert_eq(body.velocity, Vector2.ZERO, "예고 중에는 멈춘다")


func test_direction_follows_target_then_locks() -> void:
	target.position = Vector2(charge.charge_range - 10.0, 0)
	_step()
	# 고정 전: 대상이 아래로 옮기면 방향도 따라간다.
	target.position = Vector2(0, 50)
	_step()
	assert_almost_eq(charge.get_direction().angle(), PI / 2.0, 0.001, "고정 전에는 대상을 따라 돈다")
	while not charge.is_direction_locked():
		_step()
	var locked: Vector2 = charge.get_direction()
	target.position = Vector2(-50, 0)
	_step()
	assert_eq(charge.get_direction(), locked, "고정된 뒤에는 대상이 움직여도 방향이 그대로")


func test_blinks_during_windup() -> void:
	target.position = Vector2(charge.charge_range - 10.0, 0)
	var colors: Dictionary[Color, bool] = {}
	_step()
	while charge.get_state() == ChargeBehavior.State.WINDUP:
		colors[charge.get_body_color(BASE_COLOR)] = true
		_step()
	assert_true(colors.has(charge.blink_color) and colors.has(BASE_COLOR), "예고 중 원래 색과 깜빡임 색이 번갈아 나온다")
	assert_eq(charge.get_body_color(BASE_COLOR), BASE_COLOR, "예고가 아니면 원래 색")


func test_charge_ignores_bodies_and_runs_distance_then_recovers() -> void:
	_run_windup()
	assert_eq(charge.get_state(), ChargeBehavior.State.CHARGE)
	var start: Vector2 = body.position
	_step()
	assert_eq(body.collision_mask, WORLD_MASK, "돌진 중에는 벽과만 부딪힌다")
	assert_eq(body.collision_layer, 0, "돌진 중에는 다른 몸도 이 몸에 밀리지 않는다")
	assert_almost_eq(body.velocity.length(), charge.charge_speed, 0.001, "돌진 속도")
	while charge.get_state() == ChargeBehavior.State.CHARGE:
		_step(false)
	assert_almost_eq(body.position.distance_to(start), charge.charge_distance, charge.charge_speed * DT + 0.01, "정해진 거리를 달린다 (한 프레임 오차)")
	assert_eq(charge.get_state(), ChargeBehavior.State.RECOVER)
	assert_eq(body.collision_mask, BODY_MASK, "끝나면 충돌층을 되돌린다")
	assert_eq(body.collision_layer, BODY_LAYER)
	var recover_frames: int = 0
	while charge.get_state() == ChargeBehavior.State.RECOVER:
		assert_eq(body.velocity, Vector2.ZERO, "멈칫하는 동안 멈춘다")
		_step(false)
		recover_frames += 1
	assert_almost_eq(recover_frames * DT, charge.recover_time, DT * 1.5, "멈칫 시간")
	assert_false(charge.is_busy())


func test_hits_each_hostile_once_per_charge() -> void:
	var other: FakeHostile = FakeHostile.new()
	body.hostiles.append(other)
	_run_windup()
	# 돌진 길 위에 대상과 다른 상대가 있다. 지나가며 둘 다 한 번씩 맞는다.
	other.position = body.position + charge.get_direction() * 40.0
	while charge.get_state() == ChargeBehavior.State.CHARGE:
		_step()
	assert_eq(target.damage, [DAMAGE] as Array[float], "대상은 한 번만 맞는다")
	assert_eq(other.damage, [DAMAGE] as Array[float], "지나가며 다른 상대도 한 번 맞는다")
	assert_eq(target.pushes.size(), 1, "맞으면 밀려난다")
	assert_almost_eq(target.pushes[0].length(), charge.knockback_distance, 0.001, "밀쳐내는 거리")
	other.free()


func test_hostile_behind_or_beside_is_not_hit_when_front_only() -> void:
	charge.front_only_hit = true
	var behind: FakeHostile = FakeHostile.new()
	var beside: FakeHostile = FakeHostile.new()
	body.hostiles.append_array([behind, beside])
	_run_windup()
	# 돌진을 시작할 때 멧돼지에 붙어 있던 상대: 뒤쪽과 옆(돌진 방향과 90도). 맞는 거리 안이지만 앞쪽이 아니다.
	behind.position = body.position - charge.get_direction() * (charge.hit_radius - 2.0)
	beside.position = body.position + charge.get_direction().orthogonal() * (charge.hit_radius - 2.0)
	_step()
	assert_eq(behind.damage.size(), 0, "뒤쪽 상대는 맞지 않는다")
	assert_eq(beside.damage.size(), 0, "옆 상대는 맞지 않는다")
	behind.free()
	beside.free()


func test_hostile_behind_is_hit_by_default() -> void:
	assert_false(charge.front_only_hit, "기본은 앞쪽만 맞히는 규칙을 쓰지 않는다 (사용자 결정)")
	var behind: FakeHostile = FakeHostile.new()
	body.hostiles.append(behind)
	_run_windup()
	behind.position = body.position - charge.get_direction() * (charge.hit_radius - 2.0)
	_step()
	assert_eq(behind.damage.size(), 1, "맞는 거리 안이면 뒤쪽 상대도 맞는다")
	behind.free()


func test_next_charge_can_hit_again() -> void:
	_run_windup()
	while charge.get_state() == ChargeBehavior.State.CHARGE:
		_step()
	while charge.get_state() == ChargeBehavior.State.RECOVER:
		_step()
	# 대상을 다시 돌진 거리 안, 몸 앞에 둔다.
	target.position = body.position + Vector2(charge.charge_range - 10.0, 0)
	_step()
	while charge.get_state() == ChargeBehavior.State.WINDUP:
		_step()
	while charge.get_state() == ChargeBehavior.State.CHARGE:
		_step()
	assert_eq(target.damage.size(), 2, "다음 돌진에서는 다시 맞는다")


func test_continues_without_target_while_busy() -> void:
	target.position = Vector2(charge.charge_range - 10.0, 0)
	_step()
	var frames: int = 0
	while charge.get_state() != ChargeBehavior.State.APPROACH and frames < 600:
		_step(false)
		frames += 1
	assert_true(frames > 0 and frames < 600, "대상이 사라져도 예고 → 돌진 → 멈칫을 끝까지 한다 (%d프레임)" % frames)


func test_keeps_windup_target_even_if_target_changes() -> void:
	var other: FakeHostile = FakeHostile.new()
	target.position = Vector2(charge.charge_range - 10.0, 0)
	other.position = Vector2(0, 50)
	_step()
	assert_eq(charge.get_state(), ChargeBehavior.State.WINDUP)
	# 쓰는 쪽이 노리는 대상을 다른 상대로 바꿔 넘겨도, 예고를 시작할 때의 대상을 겨눈다.
	charge.update(DT)
	charge.act(body, stats, other, DT)
	assert_almost_eq(charge.get_direction().angle(), 0.0, 0.001, "예고 중에는 처음 대상(오른쪽) 그대로")
	other.free()


func test_charge_ends_past_target_by_overshoot() -> void:
	# 가까운 대상: 대상까지 + 더 달리는 거리만큼만 달린다 (최대 거리보다 짧다).
	target.position = Vector2(60, 0)
	_step()
	while charge.get_state() == ChargeBehavior.State.WINDUP:
		_step()
	var start: Vector2 = body.position
	var expected: float = start.distance_to(target.position) + charge.overshoot_distance
	assert_true(expected < charge.charge_distance, "이 경우는 최대 거리보다 짧다 (%.0f < %.0f)" % [expected, charge.charge_distance])
	while charge.get_state() == ChargeBehavior.State.CHARGE:
		_step(false)
	assert_almost_eq(body.position.distance_to(start), expected, charge.charge_speed * DT + 0.01, "대상을 지나 overshoot만큼 달리고 끝난다")


func test_charge_length_is_capped() -> void:
	target.position = Vector2(charge.charge_range - 10.0, 0)
	_step()
	assert_eq(charge.get_charge_length(Vector2(-1000, 0)), charge.charge_distance, "멀면 최대 거리까지만")
