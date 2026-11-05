extends TestCase
## DiveBehavior(행동 조각 "치고 빠지기", 박쥐) 단위 테스트.
## 조각은 body.velocity만 정하므로, 트리에 넣지 않은 노드로 확인하고 이동은 여기서 직접 한다.

const DT: float = 1.0 / 60.0
const SPEED: float = 70.0
const DAMAGE: float = 1.0
## 원래 몸 색 (팔레트 2e222f)
const BASE_COLOR: Color = Color(0.18039216, 0.13333334, 0.18431373, 1)
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
	assert_almost_eq(body.position.distance_to(target.position), dive.orbit_radius, dive.retreat_speed * DT + 0.01, "도는 반경까지 물러난다")
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
	var on_circle: Vector2 = Vector2(dive.orbit_radius, 0)
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
