extends TestCase
## 칸 정보에서 3D 지형 메시 만들기 (TerrainMesher)

const CHUNK: int = 16
const WALL_HEIGHT: float = 32.0
## 팔레트 색: 3a4466, 5a6988, 8b9bb4
const FLOOR_COLOR: Color = Color(0.22745098, 0.26666668, 0.4, 1)
const WALL_COLOR: Color = Color(0.3529412, 0.4117647, 0.53333336, 1)
const FACE_COLOR: Color = Color(0.54509807, 0.60784316, 0.7058824, 1)
## 메시에 저장되며 생기는 오차 (색은 8비트, 크기는 AABB 여유)
const COLOR_TOLERANCE: float = 0.01
const SIZE_TOLERANCE: float = 0.001

var mesher: TerrainMesher


func before_each() -> void:
	mesher = TerrainMesher.new()


## 글자 줄로 칸을 만든다: # 벽, . 바닥, 빈칸 그리지 않음
func _cells(rows: Array[String]) -> TerrainCells:
	var cells: TerrainCells = TerrainCells.new()
	cells.size = Vector2i(rows[0].length(), rows.size())
	cells.face_color = FACE_COLOR
	cells.walls.resize(cells.size.x * cells.size.y)
	cells.top_colors.resize(cells.size.x * cells.size.y)
	for y: int in cells.size.y:
		for x: int in cells.size.x:
			var c: String = rows[y][x]
			cells.walls[cells.index_of(x, y)] = 1 if c == "#" else 0
			cells.top_colors[cells.index_of(x, y)] = WALL_COLOR if c == "#" else (FLOOR_COLOR if c == "." else Color.TRANSPARENT)
	return cells


func test_caps_merge_runs_of_same_colored_walls() -> void:
	mesher.build(_cells(["###", ".#."]), CHUNK, WALL_HEIGHT, 6.0)
	var without_caps: int = TerrainMesher.new().build(_cells(["###", ".#."]), CHUNK, WALL_HEIGHT).size()
	assert_eq(without_caps, 1, "구역 하나")
	var plain: TerrainMesher = TerrainMesher.new()
	plain.build(_cells(["###", ".#."]), CHUNK, WALL_HEIGHT)
	assert_eq(mesher.quad_count, plain.quad_count + 2, "윗줄 3칸은 하나로 합쳐 낮은 윗면 2개")


func test_caps_stop_at_chunk_edge() -> void:
	var plain: TerrainMesher = TerrainMesher.new()
	plain.build(_cells(["####"]), 2, WALL_HEIGHT)
	mesher.build(_cells(["####"]), 2, WALL_HEIGHT, 6.0)
	assert_eq(mesher.quad_count, plain.quad_count + 2, "구역마다 따로")


func test_floor_is_one_quad_per_cell() -> void:
	mesher.build(_cells(["...", "..."]), CHUNK, WALL_HEIGHT)
	assert_eq(mesher.quad_count, 6, "바닥 6칸")


func test_wall_has_top_and_faces_toward_non_walls() -> void:
	mesher.build(_cells(["#."]), CHUNK, WALL_HEIGHT)
	assert_eq(mesher.quad_count, 6, "바닥 1 + 벽 윗면 1 + 앞면 4")


func test_no_face_between_two_walls() -> void:
	mesher.build(_cells(["##", "##"]), CHUNK, WALL_HEIGHT)
	assert_eq(mesher.quad_count, 12, "윗면 4 + 바깥 앞면 8")


func test_no_face_between_walls_in_different_chunks() -> void:
	var meshes: Array[ArrayMesh] = mesher.build(_cells(["##"]), 1, WALL_HEIGHT)
	assert_eq(meshes.size(), 2, "구역 둘")
	assert_eq(mesher.quad_count, 8, "윗면 2 + 앞면 6 (구역 경계에는 앞면 없음)")


func test_chunks_split_the_map() -> void:
	assert_eq(mesher.build(_cells(["....."]), 2, WALL_HEIGHT).size(), 3, "5칸을 2칸씩 나누면 구역 셋")


func test_unpainted_cells_make_no_quads_or_chunks() -> void:
	assert_eq(mesher.build(_cells(["  "]), 1, WALL_HEIGHT).size(), 0, "그리지 않는 칸만 있으면 구역 없음")
	assert_eq(mesher.quad_count, 0, "사각형 없음")


func test_vertices_are_world_positions() -> void:
	var cells: TerrainCells = _cells(["."])
	cells.origin = Vector2(32, 64)
	var box: AABB = mesher.build(cells, CHUNK, WALL_HEIGHT)[0].get_aabb()
	assert_eq(box.position, Vector3(1, 0, 2), "2D (32, 64) = 3D (1, 0, 2)")
	assert_almost_eq(box.size.x, 1.0, SIZE_TOLERANCE, "한 칸 = 1단위 (가로)")
	assert_almost_eq(box.size.y, 0.0, SIZE_TOLERANCE, "바닥은 높이 없음")
	assert_almost_eq(box.size.z, 1.0, SIZE_TOLERANCE, "한 칸 = 1단위 (세로)")


func test_wall_height_in_units() -> void:
	var box: AABB = mesher.build(_cells(["#"]), CHUNK, 48.0)[0].get_aabb()
	assert_almost_eq(box.size.y, 1.5, 0.001, "48픽셀 = 1.5단위")


func test_triangles_face_their_normals() -> void:
	var arrays: Array = mesher.build(_cells(["#."]), CHUNK, WALL_HEIGHT)[0].surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var wrong: int = 0
	for i: int in range(0, vertices.size(), 3):
		# Godot의 앞면은 시계 방향이다: (b - a) × (c - a)가 법선의 반대쪽이어야 한다.
		if (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).dot(normals[i]) >= 0.0:
			wrong += 1
	assert_eq(wrong, 0, "모든 삼각형이 법선 쪽에서 앞면")


func test_colors_come_from_cells() -> void:
	var arrays: Array = mesher.build(_cells(["#"]), CHUNK, WALL_HEIGHT)[0].surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i: int in colors.size():
		var expected: Color = WALL_COLOR if normals[i].y > 0.5 else FACE_COLOR
		assert_almost_eq(colors[i].r, expected.r, COLOR_TOLERANCE, "윗면은 윗면 색, 옆면은 앞면 색")


func test_ground_cells_match_2d_checker() -> void:
	var ground: PlaceholderGround = PlaceholderGround.new()
	ground.size_in_tiles = Vector2i(4, 2)
	ground.color_a = FLOOR_COLOR
	ground.color_b = WALL_COLOR
	var cells: TerrainCells = TerrainCells.from_ground(ground)
	assert_eq(cells.origin, Vector2(-64, -32), "원점이 가운데")
	assert_eq(cells.top_colors[0], FLOOR_COLOR, "첫 칸은 색 A")
	assert_eq(cells.top_colors[1], WALL_COLOR, "옆 칸은 색 B")
	ground.free()


func test_walls_read_2d_colors_and_leave_unpainted_floors() -> void:
	var walls: PlaceholderWalls = PlaceholderWalls.new()
	walls.layout = PackedStringArray(["#xa."])
	walls.top_color = WALL_COLOR
	walls.face_color = FACE_COLOR
	walls.wall_chars = "#x"
	walls.wall_colors = {"x": FLOOR_COLOR}
	walls.floor_colors = {"a": PackedColorArray([FACE_COLOR, FLOOR_COLOR])}
	var cells: TerrainCells = TerrainCells.from_walls(walls)
	assert_eq(cells.top_colors[0], WALL_COLOR, "기본 벽 색")
	assert_eq(cells.top_colors[1], FLOOR_COLOR, "글자별 벽 색")
	assert_eq(cells.top_colors[2], FACE_COLOR, "체크무늬는 (열 + 줄)로 번갈아: 2번 칸은 첫 색")
	assert_eq(cells.top_colors[3].a, 0.0, "색이 없는 바닥은 칠하지 않음")
	assert_eq(cells.is_wall(1, 0), true, "x도 벽")
	walls.free()
