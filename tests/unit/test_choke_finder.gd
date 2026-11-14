extends TestCase
## ChokeFinder(좁은 길목 찾기) 단위 테스트. 작은 손그림 배치로 본다 (# 벽, 나머지 바닥, 칸 32px).

const CELL: float = 32.0
const WALLS: String = "#"

## 두 굴(5칸 폭)을 2칸 폭 통로 하나로만 잇는다
const STRAIGHT: Array[String] = [
	"####################",
	"#.....########.....#",
	"#..................#",
	"#..................#",
	"#.....########.....#",
	"#.....########.....#",
	"####################",
]
## 긴 길목(22칸) 아래에 벽 한 줄을 두고 3칸 폭 통로로도 잇는다 (가까운 우회: 내려갔다 오는 길이 길목 길이에 비해 짧다)
const NEAR_DETOUR: Array[String] = [
	"##################################",
	"#.....######################.....#",
	"#................................#",
	"#................................#",
	"#.....######################.....#",
	"#................................#",
	"#................................#",
	"#................................#",
	"##################################",
]
## 3칸 폭 통로가 길목에서 멀리 아래에 있다 (먼 우회)
const FAR_DETOUR: Array[String] = [
	"####################",
	"#.....########.....#",
	"#..................#",
	"#..................#",
	"#.....########.....#",
	"#.....########.....#",
	"#.....########.....#",
	"#.....########.....#",
	"#.....########.....#",
	"#.....########.....#",
	"#..................#",
	"#..................#",
	"#..................#",
	"####################",
]
## 꺾인 길목: 왼쪽 위 굴에서 오른쪽으로 가다 아래로 꺾여 아래 굴에 닿는다
const BENT: Array[String] = [
	"##############",
	"#.....########",
	"#...........##",
	"#...........##",
	"#.....####..##",
	"#.....####..##",
	"##########..##",
	"#######......#",
	"#######......#",
	"#######......#",
	"#######......#",
	"##############",
]
## 막다른 2칸 폭 틈 (입구가 하나라 길목이 아니다)
const DEAD_END: Array[String] = [
	"#############",
	"#.....#######",
	"#...........#",
	"#...........#",
	"#.....#######",
	"#.....#######",
	"#############",
]

var finder: ChokeFinder


func before_each() -> void:
	finder = ChokeFinder.new()


func _find(rows: Array[String]) -> Array[ChokeData]:
	return finder.find(PackedStringArray(rows), CELL, WALLS)


func test_straight_corridor_is_one_choke_without_detour() -> void:
	var chokes: Array[ChokeData] = _find(STRAIGHT)
	assert_eq(chokes.size(), 1, "길목 하나")
	var choke: ChokeData = chokes[0]
	assert_eq(choke.cells.size(), 16, "통로 8칸 × 2줄")
	assert_eq(choke.entrances.size(), 2, "입구 둘")
	assert_eq(choke.detour_ratio(0, 1), -1.0, "돌아갈 길이 없다")


func test_wait_spots_are_outside_entrance() -> void:
	var choke: ChokeData = _find(STRAIGHT)[0]
	for i: int in choke.entrances.size():
		var spots: PackedVector2Array = choke.wait_spots[i]
		assert_eq(spots.size(), 3, "입구마다 3자리 (%d)" % i)
		for spot: Vector2 in spots:
			var cell: Vector2i = Vector2i((spot / CELL).floor())
			assert_true(finder.is_floor(cell), "자리는 바닥 (%s)" % spot)
			assert_false(choke.cells.has(Vector2(cell)), "자리는 길목 밖 (%s)" % spot)
			assert_almost_eq(absf(spot.x - choke.entrances[i].x), 2.0 * CELL, 0.01, "입구에서 2칸 바깥 (%s)" % spot)


func test_near_detour_is_within_limit_and_far_is_not() -> void:
	var near: ChokeData = _find(NEAR_DETOUR)[0]
	var far: ChokeData = _find(FAR_DETOUR)[0]
	var near_ratio: float = near.detour_ratio(0, 1)
	var far_ratio: float = far.detour_ratio(0, 1)
	assert_true(near_ratio > 1.0 and near_ratio <= 1.5, "가까운 우회는 1.5배 이하 (%.2f)" % near_ratio)
	assert_true(far_ratio > 1.5, "먼 우회는 1.5배 넘음 (%.2f)" % far_ratio)


func test_bent_corridor_is_one_choke() -> void:
	var chokes: Array[ChokeData] = _find(BENT)
	assert_eq(chokes.size(), 1, "꺾인 길목도 하나")
	assert_eq(chokes[0].entrances.size(), 2, "입구 둘")
	var entrances: PackedVector2Array = chokes[0].entrances
	assert_true(absf(entrances[0].y - entrances[1].y) > 2.0 * CELL, "입구 하나는 위 굴, 하나는 아래 굴 (%s)" % entrances)


func test_dead_end_is_not_a_choke() -> void:
	assert_eq(_find(DEAD_END).size(), 0, "입구가 하나인 막다른 틈은 길목이 아니다")


func test_pair_index_order() -> void:
	assert_eq(ChokeData.pair_index(0, 1, 3), 0)
	assert_eq(ChokeData.pair_index(0, 2, 3), 1)
	assert_eq(ChokeData.pair_index(1, 2, 3), 2)


func test_from_settings_reads_choke_values() -> void:
	var settings: CaveOutlineSettings = CaveOutlineSettings.new()
	settings.choke_wait_count = 5
	settings.choke_wait_distance = 3.0
	var made: ChokeFinder = ChokeFinder.from_settings(settings)
	assert_eq(made.wait_count, 5)
	assert_eq(made.wait_distance, 3.0)
	var choke: ChokeData = made.find(PackedStringArray(STRAIGHT), CELL, WALLS)[0]
	assert_true(choke.wait_spots[0].size() >= 3, "더 많은 자리를 찾는다 (굴이 좁으면 겹쳐 줄 수 있다)")
