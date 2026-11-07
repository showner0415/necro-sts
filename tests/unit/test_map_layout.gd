extends TestCase
## MapLayout(맵 배치 PNG 읽기) 단위 테스트. 작은 그림을 코드로 그려서 읽는다.

const WALL: String = "181425"
const PASSAGE: String = "3a4466"
const ROOM: String = "265c42"


## 글자 줄로 그림을 만든다: "#" 벽, "." 통로, "1" 1등급 굴, "r" 쥐, "c" 상자, "s" 도착 지점, "?" 모르는 색, " " 투명
func _image(lines: Array[String]) -> Image:
	var colors: Dictionary = {"#": WALL, ".": PASSAGE, "1": ROOM, "r": "c0cbdc", "c": "feae34", "s": "63c74d", "?": "ff0044"}
	var image: Image = Image.create(lines[0].length(), lines.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y: int in lines.size():
		for x: int in lines[y].length():
			var c: String = lines[y][x]
			if colors.has(c):
				image.set_pixel(x, y, Color(colors[c]))
	return image


## 굴 넷이 통로로 네모(고리)를 이루고, 막다른 굴 하나가 오른쪽 아래 굴의 통로로만 이어진 맵
func _ring_map() -> MapLayout:
	return MapLayout.from_image(_image([
		"###########",
		"#11....11##",
		"#1s#####r1#",
		"#.#######.#",
		"#.#######.#",
		"#11.....11#",
		"#11######.#",
		"####1c....#",
		"###########",
	]))


func test_reads_tiles_and_objects() -> void:
	var layout: MapLayout = _ring_map()
	assert_eq(layout.errors, PackedStringArray(), "문제없음")
	assert_eq(layout.size, Vector2i(11, 9))
	assert_eq(layout.get_char(Vector2i(0, 0)), "#", "벽")
	assert_eq(layout.get_char(Vector2i(3, 1)), ".", "통로")
	assert_eq(layout.cells_of("rat"), [Vector2i(8, 2)] as Array[Vector2i])
	assert_eq(layout.cells_of("spawn"), [Vector2i(2, 2)] as Array[Vector2i])
	assert_eq(layout.get_char(Vector2i(8, 2)), "1", "물건 칸의 바닥은 이웃 바닥 종류")
	assert_true(layout.is_wall(Vector2i(-1, 0)), "맵 밖은 벽")


func test_rooms_entrances_and_cycle() -> void:
	var layout: MapLayout = _ring_map()
	assert_eq(layout.rooms.size(), 5, "굴 다섯")
	var top_left: int = layout.room_at(Vector2i(1, 1))
	var top_right: int = layout.room_at(Vector2i(8, 1))
	var bottom_left: int = layout.room_at(Vector2i(1, 5))
	var bottom_right: int = layout.room_at(Vector2i(8, 5))
	var dead_end: int = layout.room_at(Vector2i(4, 7))
	assert_eq(layout.rooms[top_left].entrances, 2, "왼쪽 위 굴: 오른쪽·아래 통로")
	assert_eq(layout.rooms[dead_end].entrances, 1, "막다른 굴은 입구 하나")
	assert_eq(layout.rooms[dead_end].neighbors.size(), 1)
	assert_true(layout.has_cycle([top_left, top_right, bottom_right, bottom_left] as Array[int]), "네 굴이 고리")
	assert_eq(layout.rooms[dead_end].neighbors, [bottom_right] as Array[int], "막다른 굴은 오른쪽 아래 굴에만 이어진다")
	assert_false(layout.has_cycle([top_left, dead_end] as Array[int]), "둘만으로는 고리가 아니다")


func test_transparent_is_wall_and_unknown_color_is_error() -> void:
	var layout: MapLayout = MapLayout.from_image(_image([
		"s. ",
		"..?",
	]))
	assert_true(layout.is_wall(Vector2i(2, 0)), "투명은 벽")
	assert_eq(layout.errors.size(), 1, "모르는 색 하나")
	assert_true(layout.errors[0].contains("ff0044"), "색과 위치를 알려준다: %s" % layout.errors[0])


func test_spawn_must_be_single() -> void:
	var layout: MapLayout = MapLayout.from_image(_image(["...", "..."]))
	assert_eq(layout.errors.size(), 1, "도착 지점이 없으면 문제")
