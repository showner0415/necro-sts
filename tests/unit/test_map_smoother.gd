extends TestCase
## MapSmoother(벽 가장자리 다듬기) 단위 테스트. 작은 맵을 글자 줄로 만들어 다듬는다.

const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
const ROOM: String = "265c42"
const PASSAGE: String = "3a4466"


## "#" 벽, "1" 굴, "." 통로, "s" 도착 지점, "c" 상자
func _layout(lines: Array[String]) -> MapLayout:
	var colors: Dictionary = {"#": "181425", ".": PASSAGE, "1": ROOM, "s": "63c74d", "c": "feae34"}
	var image: Image = Image.create(lines[0].length(), lines.size(), false, Image.FORMAT_RGBA8)
	for y: int in lines.size():
		for x: int in lines[y].length():
			image.set_pixel(x, y, Color(colors[lines[y][x]]))
	return MapLayout.from_image(image)


## 넓은 굴 둘을 넓은 통로(3~6줄, 4칸)와 좁은 통로(9~10줄, 2칸)로 잇는다. 두 통로 사이(7~8줄)는 벽
func _two_rooms() -> MapLayout:
	return _layout([
		"##########################",
		"#11111111##########11111c#",
		"#11111111##########111111#",
		"#11111111..........111111#",
		"#111s1111..........111111#",
		"#11111111..........111111#",
		"#11111111..........111111#",
		"#11111111##########111111#",
		"#11111111##########111111#",
		"#11111111..........111111#",
		"#11111111..........111111#",
		"#11111111##########111111#",
		"##########################",
	])


func test_same_seed_same_result() -> void:
	var layout: MapLayout = _two_rooms()
	assert_eq(MapSmoother.smooth(layout, 1), MapSmoother.smooth(layout, 1), "같은 씨앗이면 같은 결과")
	assert_ne(MapSmoother.smooth(layout, 1), layout.rows, "가장자리가 실제로 바뀐다")


func test_keeps_width_reachability_and_connections() -> void:
	var layout: MapLayout = _two_rooms()
	var spawn: Vector2i = layout.cells_of("spawn")[0]
	for seed_value: int in SEEDS:
		var rows: PackedStringArray = MapSmoother.smooth(layout, seed_value)
		assert_eq(MapSmoother.narrow_cells(rows), [] as Array[Vector2i], "씨앗 %d: 바닥은 모두 2칸 이상" % seed_value)
		assert_true(MapSmoother.reachable(rows, spawn).has(layout.cells_of("chest")[0]), "씨앗 %d: 상자에 걸어서 닿는다" % seed_value)
		var after: MapLayout = MapLayout.from_rows(rows, layout.objects)
		assert_eq(after.rooms.size(), layout.rooms.size(), "씨앗 %d: 굴 수 그대로" % seed_value)
		for i: int in layout.rooms.size():
			assert_eq(after.rooms[i].entrances, layout.rooms[i].entrances, "씨앗 %d: 굴 %d 입구 수 그대로" % [seed_value, i])


func test_narrow_passage_and_its_walls_untouched() -> void:
	var layout: MapLayout = _two_rooms()
	for seed_value: int in SEEDS:
		var rows: PackedStringArray = MapSmoother.smooth(layout, seed_value)
		# 좁은 통로(9~10줄)와 그 위아래 벽(8, 11줄)의 통로 구간(9~18열)은 그대로다.
		for y: int in [8, 9, 10, 11]:
			assert_eq(rows[y].substr(9, 10), layout.rows[y].substr(9, 10), "씨앗 %d: 좁은 길목 %d줄" % [seed_value, y])


func test_wide_passage_stays_three_wide_and_wall_between_stays() -> void:
	var layout: MapLayout = _two_rooms()
	for seed_value: int in SEEDS:
		var rows: PackedStringArray = MapSmoother.smooth(layout, seed_value)
		for x: int in range(10, 18):
			var open: int = 0
			for y: int in range(2, 8):
				if not MapLayout.WALL_CHARS.contains(rows[y][x]):
					open += 1
			assert_true(open >= 3, "씨앗 %d: 넓은 통로 %d열이 3칸 이상 (%d칸)" % [seed_value, x, open])
			assert_true(MapLayout.WALL_CHARS.contains(rows[8][x]), "씨앗 %d: 두 통로 사이 벽 %d열이 남는다" % [seed_value, x])


func test_room_core_and_objects_untouched() -> void:
	var layout: MapLayout = _two_rooms()
	for seed_value: int in SEEDS:
		var rows: PackedStringArray = MapSmoother.smooth(layout, seed_value)
		for o: Dictionary in layout.objects:
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var c: Vector2i = o.cell + Vector2i(dx, dy)
					assert_eq(rows[c.y][c.x], layout.rows[c.y][c.x], "씨앗 %d: 물건 둘레 %s 그대로" % [seed_value, c])
		for room: Dictionary in layout.rooms:
			var center: Vector2i = Vector2i(room.center.round())
			assert_eq(rows[center.y][center.x], layout.rows[center.y][center.x], "씨앗 %d: 굴 가운데 그대로" % seed_value)
