extends TestCase
## DiveBehavior(행동 조각 "치고 빠지기", 박쥐) 단위 테스트.
## 조각은 body.velocity만 정하므로, 트리에 넣지 않은 노드로 확인하고 이동은 여기서 직접 한다.

const DT: float = 1.0 / 60.0
const SPEED: float = 70.0
const DAMAGE: float = 1.0
## 원래 몸 색 (팔레트 181425)
const BASE_COLOR: Color = Color(0.09411765, 0.078431375, 0.14509805, 1)
const MAX_FRAMES: int = 600


class FakeBody:
	extends CharacterBody2D
	var hostiles: Array[Node2D] = []

	func get_hostiles() -> Array[Node2D]:
		return hostiles


class FakeHostile:
	extends Node2D
	var damage: Array[float] = []

	func take_damage(amount: float, _source: Node2D = null) -> void:
		damage.append(amount)


var body: FakeBody
var target: FakeHostile
var stats: CombatStats
var dive: DiveBehavior


func before_each() -> void:
	body = FakeBody.new()
	target = FakeHostile.new()
	body.hostiles = [target]
	stats = CombatStats.create(SPEED, 0.0, DAMAGE, 0.0)
	dive = DiveBehavior.new()


func after_each() -> void:
	body.free()
	target.free()


func _step(with_target: bool = true) -> void:
	dive.update(DT)
	dive.act(body, stats, target if with_target else null, DT)
	body.position += body.velocity * DT


func _run_until(state: DiveBehavior.State) -> int:
	for frame: int in MAX_FRAMES:
		if dive.get_state() == state:
			return frame
		_step()
	return -1


func test_far_target_is_approached() -> void:
	target.position = Vector2(dive.dive_range + 50.0, 0)
	_step()
	assert_eq(dive.get_state(), DiveBehavior.State.APPROACH)
	assert_almost_eq(body.velocity.x, SPEED, 0.001, "이동 속도로 다가간다")
	assert_false(dive.is_busy())


func test_windup_stops_and_blinks() -> void:
	target.position = Vector2(dive.dive_range - 10.0, 0)
	_step()
	assert_eq(dive.get_state(), DiveBehavior.State.WINDUP)
	assert_eq(body.velocity, Vector2.ZERO, "예고 중에는 멈춘다")
	assert_true(dive.is_telegraphing())
	var colors: Dictionary[Color, bool] = {}
	while dive.get_state() == DiveBehavior.State.WINDUP:
		colors[dive.get_body_color(BASE_COLOR)] = true
		_step()
	assert_true(colors.has(dive.blink_color) and colors.has(BASE_COLOR), "예고 중 깜빡인다")


func test_dive_direction_is_fixed_at_start() -> void:
	target.position = Vector2(dive.dive_range - 10.0, 0)
	_run_until(DiveBehavior.State.DIVE)
	var direction: Vector2 = dive.get_attack_direction()
	assert_almost_eq(direction.angle(), 0.0, 0.001, "돌진을 시작할 때 대상 쪽")
	assert_true(dive.is_attack_locked())
	# 대상이 옆으로 비켜도 방향은 그대로다.
	target.position = Vector2(0, 80)
	_step()
	assert_eq(dive.get_attack_direction(), direction)
	assert_almost_eq(body.velocity.length(), dive.dive_speed, 0.001, "돌진 속도")


func test_bites_once_then_retreats_to_orbit_radius() -> void:
	target.position = Vector2(dive.dive_range - 10.0, 0)
	_run_until(DiveBehavior.State.DIVE)
	_run_until(DiveBehavior.State.RETREAT)
	assert_eq(target.damage, [DAMAGE] as Array[float], "한 번 문다")
	var retreat_frames: int = _run_until(DiveBehavior.State.ORBIT)
	assert_true(retreat_frames > 0, "물러난 뒤 돌기 시작한다")
	assert_almost_eq(body.position.distance_to(target.position), dive.get_orbit_radius(), dive.retreat_speed * DT + 0.01, "도는 반경까지 물러난다")
	assert_true(body.position.x < target.position.x, "대상의 반대쪽(돌진해 온 쪽)으로 물러난다")
	assert_eq(target.damage.size(), 1, "물러나는 동안 다시 물지 않는다")


func test_miss_retreats_after_max_distance() -> void:
	target.position = Vector2(dive.dive_range - 10.0, 0)
	_run_until(DiveBehavior.State.DIVE)
	var start: Vector2 = body.position
	# 돌진 길에서 대상을 치운다.
	target.position = Vector2(0, 500)
	_run_until(DiveBehavior.State.RETREAT)
	assert_true(target.damage.is_empty(), "빗나갔다")
	assert_almost_eq(body.position.distance_to(start), dive.dive_distance, dive.dive_speed * DT + 0.01, "최대 거리까지 날고 물러나기 시작")


func test_orbit_then_dives_again_after_orbit_time() -> void:
	target.position = Vector2(dive.dive_range - 10.0, 0)
	_run_until(DiveBehavior.State.ORBIT)
	var frames: int = _run_until(DiveBehavior.State.WINDUP)
	assert_almost_eq(frames * DT, dive.orbit_time, DT * 1.5, "정해진 시간 돌고 다시 예고")


func test_orbit_velocity_is_tangent_and_keeps_away_from_others() -> void:
	dive.act(body, stats, target, DT)
	var center: Vector2 = Vector2.ZERO
	var on_circle: Vector2 = Vector2(dive.get_orbit_radius(), 0)
	var velocity: Vector2 = dive.get_orbit_velocity(on_circle, center, [center] as Array[Vector2])
	assert_almost_eq(velocity.normalized().dot(Vector2.RIGHT), 0.0, 0.01, "반경 위에서는 접선 방향으로 돈다")
	assert_almost_eq(velocity.length(), dive.orbit_speed, 0.01, "도는 속도")
	# 반경 위에 다른 상대(언데드)가 가까이 있으면 그 반대쪽으로 비킨다.
	var other: Vector2 = on_circle + Vector2(-10, 0)
	var dodging: Vector2 = dive.get_orbit_velocity(on_circle, center, [center, other] as Array[Vector2])
	assert_true(dodging.normalized().dot(other.direction_to(on_circle)) > 0.3, "가까운 상대에게서 바깥으로 비킨다 (%s)" % dodging)


func test_orbit_direction_is_random_per_bat() -> void:
	var signs: Dictionary[float, bool] = {}
	for i: int in 40:
		var one: DiveBehavior = DiveBehavior.new()
		one.act(body, stats, target, DT)
		signs[one.get_orbit_sign()] = true
	assert_true(signs.has(1.0) and signs.has(-1.0), "시계·반시계가 둘 다 나온다")


# --- 무리 동시 돌진 ---

## 같은 규칙을 공유하는 다른 박쥐 하나를 만들고, 규칙과 두 박쥐를 한 프레임씩 진행한다.
func _pack_step(pack: PackAttack, other: DiveBehavior, other_body: FakeBody) -> void:
	pack.update(DT, 2, dive.can_join_pack_attack() and other.can_join_pack_attack())
	_step()
	other.update(DT)
	other.act(other_body, stats, target, DT)
	other_body.position += other_body.velocity * DT


func test_pack_dive_together_with_locked_direction() -> void:
	# 방향을 미리 고정하는 설정에서 확인한다 (기본값 0은 아래 test_pack_dive_aims_at_launch_without_lock).
	dive.pack_lock_time = 0.2
	var pack: PackAttack = dive.make_pack_attack()
	dive.join_pack(pack)
	var other: DiveBehavior = DiveBehavior.new()
	other.join_pack(pack)
	var other_body: FakeBody = FakeBody.new()
	other_body.hostiles = [target]
	# 둘 다 돌고 있는 중 (첫 다가가기에서 바로 예고하지 않도록 멀리 둔다)
	target.position = Vector2(dive.dive_range + 200.0, 0)
	other_body.position = Vector2(dive.dive_range + 200.0, 30)
	var frames: int = 0
	while not pack.is_winding_up() and frames < MAX_FRAMES:
		_pack_step(pack, other, other_body)
		frames += 1
	assert_true(pack.is_winding_up(), "6초 뒤 무리 예고 시작")
	_pack_step(pack, other, other_body)
	assert_eq(dive.get_state(), DiveBehavior.State.PACK_WINDUP, "다가가던 박쥐도 무리 예고에 들어간다")
	assert_eq(other.get_state(), DiveBehavior.State.PACK_WINDUP)
	assert_true(dive.is_telegraphing() and dive.is_group_attack(), "봇이 보는 예고: 무리 공격")
	assert_eq(body.velocity, Vector2.ZERO, "제자리에 멈춘다")
	assert_false(dive.is_attack_locked(), "아직 방향이 정해지지 않음")
	# 방향 고정 전까지 진행한 뒤, 고정 직후 대상이 옮겨 가도 그 방향 그대로 돌진한다.
	while not pack.is_direction_locked() and frames < MAX_FRAMES * 2:
		_pack_step(pack, other, other_body)
		frames += 1
	_pack_step(pack, other, other_body)
	assert_true(dive.is_attack_locked(), "끝나기 조금 전에 방향 고정")
	var locked: Vector2 = dive.get_attack_direction()
	target.position += Vector2(0, 80)
	while dive.get_state() == DiveBehavior.State.PACK_WINDUP and frames < MAX_FRAMES * 2:
		_pack_step(pack, other, other_body)
		frames += 1
	assert_eq(dive.get_state(), DiveBehavior.State.DIVE, "예고가 끝나면 돌진")
	assert_eq(other.get_state(), DiveBehavior.State.DIVE, "같은 프레임에 같이 돌진")
	assert_eq(dive.get_attack_direction(), locked, "고정한 방향으로 돌진 (그 뒤 움직인 대상을 따라가지 않음)")
	assert_true(dive.is_group_attack())
	other_body.free()


func test_pack_waits_for_member_in_own_attack() -> void:
	var pack: PackAttack = dive.make_pack_attack()
	dive.join_pack(pack)
	target.position = Vector2(dive.dive_range - 10.0, 0)
	_run_until(DiveBehavior.State.DIVE)
	assert_false(dive.can_join_pack_attack(), "돌진 중에는 무리 공격에 들어가지 못한다")
	_run_until(DiveBehavior.State.ORBIT)
	assert_true(dive.can_join_pack_attack(), "돌기로 돌아오면 들어갈 수 있다")


func test_no_pack_means_no_pack_windup() -> void:
	target.position = Vector2(dive.dive_range - 10.0, 0)
	for i: int in roundi((dive.pack_interval + 2.0) / DT):
		_step()
		assert_ne(dive.get_state(), DiveBehavior.State.PACK_WINDUP, "무리가 없으면(언데드 등) 동시 돌진을 하지 않는다")
		if dive.get_state() == DiveBehavior.State.PACK_WINDUP:
			return


func test_pack_dive_aims_at_launch_without_lock() -> void:
	dive.pack_lock_time = 0.0
	var pack: PackAttack = dive.make_pack_attack()
	dive.join_pack(pack)
	target.position = Vector2(dive.dive_range + 200.0, 0)
	var frames: int = 0
	while not pack.is_winding_up() and frames < MAX_FRAMES:
		pack.update(DT, 2, dive.can_join_pack_attack())
		_step()
		frames += 1
	_step()
	assert_eq(dive.get_state(), DiveBehavior.State.PACK_WINDUP)
	# 예고 내내 방향이 정해지지 않고, 마지막 순간 대상이 옮겨 간 쪽으로 날아간다 (걷기로는 피하지 못한다).
	while pack.is_winding_up() and frames < MAX_FRAMES * 2:
		assert_false(dive.is_attack_locked(), "고정 시간 0이면 예고 중에는 방향이 정해지지 않는다")
		pack.update(DT, 2, true)
		target.position += Vector2(0, 2)
		_step()
		frames += 1
	assert_eq(dive.get_state(), DiveBehavior.State.DIVE)
	var expected: Vector2 = (target.position - body.position).normalized()
	assert_almost_eq(dive.get_attack_direction().angle_to(expected), 0.0, 0.05, "날아가는 순간 대상이 있던 쪽")


# --- 흩어져 돌기 ---

func test_orbit_radius_is_random_per_bat_within_range() -> void:
	dive.orbit_radius_min = 50.0
	dive.orbit_radius_max = 75.0
	var radii: Dictionary = {}
	for i: int in 20:
		var one: DiveBehavior = dive.make_instance()
		var radius: float = one.get_orbit_radius()
		assert_true(radius >= 50.0 and radius <= 75.0, "반경 %.1f가 50~75 안" % radius)
		assert_eq(one.get_orbit_radius(), radius, "한 번 정하면 그대로")
		radii[snappedf(radius, 1.0)] = true
	assert_true(radii.size() > 5, "박쥐마다 다르다 (%d가지)" % radii.size())


func test_wobble_stays_within_limits() -> void:
	dive.orbit_speed_wobble = 0.15
	dive.orbit_angle_wobble_deg = 10.0
	target.position = Vector2(dive.dive_range + 100.0, 0)
	_step()
	var base: Vector2 = Vector2(80.0, 0)
	var min_speed: float = INF
	var max_speed: float = 0.0
	var max_angle: float = 0.0
	for i: int in 600:
		var wobbled: Vector2 = dive.apply_wobble(base, i * DT)
		min_speed = minf(min_speed, wobbled.length())
		max_speed = maxf(max_speed, wobbled.length())
		max_angle = maxf(max_angle, absf(rad_to_deg(base.angle_to(wobbled))))
	assert_true(min_speed >= 80.0 * 0.85 - 0.01 and max_speed <= 80.0 * 1.15 + 0.01, "속도 %.1f~%.1f가 ±15%% 안" % [min_speed, max_speed])
	assert_true(max_speed - min_speed > 80.0 * 0.1, "실제로 흔들린다")
	assert_true(max_angle <= 10.01 and max_angle > 3.0, "방향이 ±10도 안에서 흔들린다 (최대 %.1f도)" % max_angle)


## 무리 구역을 쓰는 박쥐를 대상(원점) 주위 angle_deg 자리, 도는 반경 위에 두고 한 번 돈다.
func _orbit_in_sector(pack: PackAttack, index: int, count: int, angle_deg: float, sign: float) -> void:
	dive.join_pack(pack)
	dive.set_pack_slot(index, count, [] as Array[Vector2])
	target.position = Vector2.ZERO
	body.position = Vector2.RIGHT.rotated(deg_to_rad(angle_deg)) * dive.get_orbit_radius()
	# 돌기 상태로 만든다: 다가가기에서 예고 → 돌진 → 물러나기 → 돌기
	_run_until(DiveBehavior.State.ORBIT)
	body.position = Vector2.RIGHT.rotated(deg_to_rad(angle_deg)) * dive.get_orbit_radius()
	dive._orbit_sign = sign
	_step()


func test_turns_back_at_sector_edge() -> void:
	var pack: PackAttack = PackAttack.new(100.0, 0.4, 0.0, 2, 0.0)
	pack.set_formation_angle(0.0)
	# 3마리 중 0번 자리: 가운데 0도, 오가는 폭 ±48도 (60도 × 0.8). 각도가 커지는 쪽 끝을 넘은 곳.
	_orbit_in_sector(pack, 0, 3, 55.0, -1.0)
	assert_eq(dive.get_orbit_sign(), 1.0, "구역 끝을 넘으면 가운데 쪽(각도가 줄어드는 쪽)으로 돈다")
	var moved: float = rad_to_deg(body.position.angle())
	assert_true(moved < 55.0, "실제로 각도가 줄어든다 (%.2f도)" % moved)


func test_keeps_direction_inside_sector() -> void:
	var pack: PackAttack = PackAttack.new(100.0, 0.4, 0.0, 2, 0.0)
	pack.set_formation_angle(0.0)
	_orbit_in_sector(pack, 0, 3, 10.0, -1.0)
	assert_eq(dive.get_orbit_sign(), -1.0, "구역 안에서는 자기 방향 그대로")
	assert_true(dive.can_join_pack_attack(), "구역 안에서 돌면 동시 돌진에 들어갈 수 있다")


func test_out_of_sector_cannot_join_pack_attack() -> void:
	var pack: PackAttack = PackAttack.new(100.0, 0.4, 0.0, 2, 0.0)
	pack.set_formation_angle(0.0)
	_orbit_in_sector(pack, 0, 3, 150.0, 1.0)
	assert_false(dive.can_join_pack_attack(), "구역 밖이면 자리로 돌아갈 때까지 기다린다")


func test_pushes_away_from_close_pack_mate() -> void:
	dive.pack_spacing = 32.0
	dive._orbit_sign = 1.0
	var center: Vector2 = Vector2.ZERO
	var on_circle: Vector2 = Vector2(dive.get_orbit_radius(), 0)
	var free: Vector2 = dive.get_orbit_velocity(on_circle, center, [] as Array[Vector2])
	var mate: Vector2 = on_circle + free.normalized() * 10.0
	var pushed: Vector2 = dive.get_orbit_velocity(on_circle, center, [] as Array[Vector2], [mate] as Array[Vector2])
	assert_true(pushed.dot(free) < free.dot(free) * 0.5, "앞에 동료가 32보다 가까우면 그쪽으로 덜 간다 (%s → %s)" % [free, pushed])
	var far_mate: Vector2 = on_circle + free.normalized() * 40.0
	assert_eq(dive.get_orbit_velocity(on_circle, center, [] as Array[Vector2], [far_mate] as Array[Vector2]), free, "32보다 멀면 영향 없음")


func test_assemble_flies_straight_to_own_spot() -> void:
	var pack: PackAttack = PackAttack.new(100.0, 0.4, 0.0, 2, 0.0)
	pack.set_formation_angle(0.0)
	dive.join_pack(pack)
	dive.set_pack_slot(1, 3, [] as Array[Vector2])
	var center: Vector2 = Vector2.ZERO
	var spot: Vector2 = Vector2.RIGHT.rotated(TAU / 3.0) * dive.get_orbit_radius()
	var from: Vector2 = Vector2.RIGHT * dive.get_orbit_radius()
	var velocity: Vector2 = dive.get_assemble_velocity(from, center, [] as Array[Vector2])
	assert_almost_eq(velocity.length(), dive.retreat_speed, 0.01, "멀면 물러나는 속도로 (도는 속도보다 빠르게)")
	assert_almost_eq(velocity.angle_to(spot - from), 0.0, 0.01, "자기 자리(120도, 자기 반경)로 곧장")
	var near: Vector2 = dive.get_assemble_velocity(spot + Vector2(3, 0), center, [] as Array[Vector2])
	assert_true(near.length() < dive.retreat_speed * 0.5, "자리 근처에서는 느려진다 (%.1f)" % near.length())
