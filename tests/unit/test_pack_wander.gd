extends TestCase
## PackWander(무리 함께 배회: 기준점이 움직이고, 무리원은 기준점 둘레 안에서 배회) 단위 테스트.

const RADIUS: float = 64.0
const INTERVAL: float = 3.0
const SPEED: float = 9.0
const START: Vector2 = Vector2(100, 50)

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 7


func test_outside_radius_returns() -> void:
	var wander: PackWander = PackWander.new(START, RADIUS, INTERVAL, 0.0, SPEED, rng)
	assert_false(wander.is_outside(START + Vector2(RADIUS - 1.0, 0)), "기준점에서 반지름 안이면 자기 배회")
	assert_true(wander.is_outside(START + Vector2(RADIUS + 1.0, 0)), "반지름 밖이면 기준점 쪽으로 돌아온다")


func test_anchor_moves_at_speed() -> void:
	var wander: PackWander = PackWander.new(START, RADIUS, INTERVAL, 0.0, SPEED, rng)
	wander.update(1.0, START)
	assert_almost_eq(wander.anchor.distance_to(START), SPEED, 0.01, "멈출 확률이 0이면 1초에 speed만큼 움직인다")


func test_anchor_rests_when_rest_chance_is_one() -> void:
	var wander: PackWander = PackWander.new(START, RADIUS, INTERVAL, 1.0, SPEED, rng)
	wander.update(1.0, START)
	assert_eq(wander.anchor, START, "멈출 확률이 1이면 움직이지 않는다")


func test_direction_kept_until_interval() -> void:
	var wander: PackWander = PackWander.new(START, RADIUS, INTERVAL, 0.0, SPEED, rng)
	wander.update(0.5, START)
	var first: Vector2 = wander.anchor - START
	var before: Vector2 = wander.anchor
	wander.update(0.5, START)
	var second: Vector2 = wander.anchor - before
	assert_almost_eq(first.angle_to(second), 0.0, 0.001, "방향은 interval초 동안 그대로다")


func test_anchor_pulled_back_toward_members() -> void:
	var wander: PackWander = PackWander.new(START, RADIUS, INTERVAL, 0.0, 1000.0, rng)
	wander.update(1.0, START)
	assert_almost_eq(wander.anchor.distance_to(START), RADIUS, 0.01, "무리원이 따라오지 못하면 기준점이 가운데에서 반지름보다 멀어지지 않는다")


func test_same_seed_same_path() -> void:
	var other_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	other_rng.seed = 7
	var a: PackWander = PackWander.new(START, RADIUS, 0.5, 0.3, SPEED, rng)
	var b: PackWander = PackWander.new(START, RADIUS, 0.5, 0.3, SPEED, other_rng)
	for i: int in 20:
		a.update(0.25, START)
		b.update(0.25, START)
	assert_eq(a.anchor, b.anchor, "같은 시드면 같은 길로 움직인다")


func test_reset_moves_anchor() -> void:
	var wander: PackWander = PackWander.new(START, RADIUS, INTERVAL, 0.0, SPEED, rng)
	wander.update(1.0, START)
	var spot: Vector2 = Vector2(-300, 20)
	wander.reset(spot)
	assert_eq(wander.anchor, spot, "포기한 자리(무리 가운데)에 기준점을 다시 둔다")
