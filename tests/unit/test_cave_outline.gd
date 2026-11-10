extends TestCase
## 동굴 벽 윤곽 규칙 (CaveOutline)

const WALLS: String = "####################"
const OPEN: String = "#..................#"


func _settings() -> CaveOutlineSettings:
	return CaveOutlineSettings.new()


## 가운데에 넓은 방이 있는 맵
func _room_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray([WALLS, WALLS])
	for i: int in 12:
		rows.append(OPEN)
	rows.append(WALLS)
	rows.append(WALLS)
	return rows


## 두 방을 2칸 길목으로 이은 맵
func _choke_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray([WALLS])
	for y: int in 8:
		rows.append("#........##........#")
	for y: int in 2:
		rows.append("#..................#")
	for y: int in 8:
		rows.append("#........##........#")
	rows.append(WALLS)
	return rows


func test_room_center_is_floor_and_map_edge_is_rock() -> void:
	var outline: CaveOutline = CaveOutline.new(_room_rows(), _settings())
	outline.build()
	assert_false(outline.is_rock(Vector2i(10, 8) * 8), "방 가운데는 바닥")
	assert_true(outline.is_rock(Vector2i.ZERO), "맵 모서리는 바위")


func test_same_input_gives_same_result() -> void:
	var first: CaveOutlineData = CaveOutline.new(_room_rows(), _settings()).build()
	var second: CaveOutlineData = CaveOutline.new(_room_rows(), _settings()).build()
	assert_eq(first.values, second.values, "같은 값")


func test_different_noise_seed_changes_shape() -> void:
	var other: CaveOutlineSettings = _settings()
	other.noise_seed = 77
	assert_ne(CaveOutline.new(_room_rows(), _settings()).build().values, CaveOutline.new(_room_rows(), other).build().values, "씨앗이 다르면 모양이 다름")


func test_contour_is_closed_and_simplified() -> void:
	var data: CaveOutlineData = CaveOutline.new(_room_rows(), _settings()).build()
	assert_eq(data.loops.size(), 1, "방 하나에 윤곽선 하나")
	assert_true(data.loops[0].size() >= 8, "윤곽선 점이 충분함")


func test_cell_states_mark_contour_cells() -> void:
	var data: CaveOutlineData = CaveOutline.new(_room_rows(), _settings()).build()
	assert_eq(data.cell_states[8 * 20 + 10], 0, "방 가운데 칸은 바닥뿐")
	assert_eq(data.cell_states[0], 2, "맵 모서리 칸은 바위뿐")
	assert_true(data.cell_states.has(1), "윤곽이 지나는 칸이 있음")


func test_two_cell_choke_keeps_a_passage() -> void:
	var outline: CaveOutline = CaveOutline.new(_choke_rows(), _settings())
	outline.build()
	assert_true(outline.is_narrow_cell(9, 9), "2칸 길목은 좁은 칸")
	var widths: Array[Dictionary] = outline.choke_widths()
	assert_eq(widths.size(), 1, "길목 하나")
	assert_true(widths[0].width >= 40.0, "길목이 막히지 않음: %s" % widths[0].width)


func test_protection_limits_cover_depth_in_choke() -> void:
	var outline: CaveOutline = CaveOutline.new(_choke_rows(), _settings())
	outline.build()
	assert_true(outline.deepest_cover_px(true) <= _settings().protect_guard_px + 4.0, "보호 구역에서 PNG 바닥을 덮는 깊이: %s" % outline.deepest_cover_px(true))


func test_wide_floor_is_not_narrow() -> void:
	var outline: CaveOutline = CaveOutline.new(_room_rows(), _settings())
	assert_false(outline.is_narrow_cell(10, 8), "넓은 방 가운데")
	assert_false(outline.is_narrow_cell(0, 0), "벽 칸은 좁은 바닥이 아님")


func test_small_rock_speck_is_removed() -> void:
	var settings: CaveOutlineSettings = _settings()
	settings.large_noise_strength = 0.0
	settings.small_noise_strength = 0.0
	var rows: PackedStringArray = _room_rows()
	rows[8] = "#........#.........#"
	var outline: CaveOutline = CaveOutline.new(rows, settings)
	outline.build()
	assert_false(outline.is_rock(Vector2i(9, 8) * 8 + Vector2i(4, 4)), "한 칸 바위는 흐려져 없어짐")


func test_encode_round_trip() -> void:
	assert_almost_eq(CaveOutlineData.decode(CaveOutlineData.encode(0.5)), 0.5, 0.002, "문턱 값")
	assert_eq(CaveOutlineData.encode(1.0), 255, "범위를 넘으면 잘림")
