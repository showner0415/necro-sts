extends TestCase
## PackData(무리 종류: 종마다 최소~최대)와 PackPlacer(무리원을 자리 둘레에 흩어 놓기) 단위 테스트.

const RAT_PATH: String = "res://data/monsters/rat.tres"
const BOAR_PATH: String = "res://data/monsters/boar.tres"
const RADIUS: float = 48.0
const SPACING: float = 16.0
const TRIES: int = 30


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_roll_counts_stay_in_range_and_keep_order() -> void:
	var mixed: PackData = load("res://data/packs/mixed_boar_rats.tres")
	for seed_value: int in 20:
		var datas: Array[MonsterData] = mixed.roll(_rng(seed_value))
		assert_true(datas.size() >= 3 and datas.size() <= 4, "멧돼지 1 + 쥐 2~3 (%d)" % datas.size())
		assert_eq(datas[0], load(BOAR_PATH), "목록 순서대로: 멧돼지 먼저")
		for i: int in range(1, datas.size()):
			assert_eq(datas[i], load(RAT_PATH), "나머지는 쥐")


func test_roll_uses_both_ends_of_range() -> void:
	var big: PackData = load("res://data/packs/rat_big.tres")
	var seen: Dictionary = {}
	for seed_value: int in 60:
		seen[big.roll(_rng(seed_value)).size()] = true
	assert_eq(seen.keys().size(), 3, "쥐 큰 무리는 6, 7, 8마리가 모두 나온다 (%s)" % [seen.keys()])


func test_same_seed_same_pack() -> void:
	var gang: PackData = load("res://data/packs/rat_gang.tres")
	assert_eq(gang.roll(_rng(5)).size(), gang.roll(_rng(5)).size(), "같은 시드면 같은 수")


func test_placer_keeps_radius_spacing_and_floor() -> void:
	var center: Vector2 = Vector2(100, 100)
	# 자리 오른쪽 반은 벽이다.
	var left_only: Callable = func(point: Vector2) -> bool: return point.x <= center.x
	var points: PackedVector2Array = PackPlacer.place(center, 4, RADIUS, SPACING, _rng(3), left_only, TRIES)
	assert_eq(points.size(), 4)
	for i: int in points.size():
		assert_true(points[i].distance_to(center) <= RADIUS + 0.01, "반지름 안 (%s)" % points[i])
		assert_true(points[i].x <= center.x, "벽 쪽(오른쪽)에는 두지 않는다 (%s)" % points[i])
		for k: int in range(i + 1, points.size()):
			assert_true(points[i].distance_to(points[k]) >= SPACING, "서로 간격 (%d, %d)" % [i, k])


func test_placer_falls_back_to_center() -> void:
	var nowhere: Callable = func(_point: Vector2) -> bool: return false
	var points: PackedVector2Array = PackPlacer.place(Vector2(5, 5), 2, RADIUS, SPACING, _rng(1), nowhere, TRIES)
	assert_eq(points, PackedVector2Array([Vector2(5, 5), Vector2(5, 5)]), "놓을 곳이 없으면 자리 한가운데")
