extends TestCase
## 동굴 지형 메시 (CaveTerrainMesher)

const WALLS: String = "####################"
const OPEN: String = "#..................#"
const CHUNK_CELLS: int = 8
const WALL_HEIGHT: float = 128.0
const CAP_HEIGHT: float = 6.08

var _walls: PlaceholderWalls


func before_each() -> void:
	var rows: PackedStringArray = PackedStringArray([WALLS, WALLS])
	for i: int in 12:
		rows.append(OPEN)
	rows.append(WALLS)
	rows.append(WALLS)
	_walls = PlaceholderWalls.new()
	_walls.layout = rows
	_walls.wall_chars = "#"


func after_each() -> void:
	_walls.free()


func _build() -> Array[ArrayMesh]:
	var data: CaveOutlineData = CaveOutline.new(_walls.layout, CaveOutlineSettings.new()).build()
	return CaveTerrainMesher.new().build(data, TerrainCells.from_walls(_walls), _walls, CHUNK_CELLS, WALL_HEIGHT, CAP_HEIGHT)


func test_builds_chunks_with_triangles() -> void:
	var meshes: Array[ArrayMesh] = _build()
	assert_true(meshes.size() > 1, "구역이 여러 개")
	assert_true(CaveTerrainMesher.last_triangles > 0, "삼각형이 있음")
	assert_eq(CaveTerrainMesher.stats.failed_polygons, 0, "나누지 못한 다각형 없음")


func test_lean_stays_within_maximum() -> void:
	_build()
	assert_true(CaveTerrainMesher.last_max_lean <= CaveOutlineSettings.new().max_lean_px + 0.001, "벽이 들어가는 거리: %s" % CaveTerrainMesher.last_max_lean)


func test_rock_side_is_left_of_travel_on_screen() -> void:
	assert_almost_eq(CaveTerrainMesher._rock_side(Vector2.ZERO, Vector2.RIGHT).distance_to(Vector2(0, -1)), 0.0, 0.001, "동쪽으로 가면 바위는 화면 위쪽")


func test_all_triangles_face_their_normals() -> void:
	for mesh: ArrayMesh in _build():
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for corner: int in range(0, indices.size(), 3):
			var a: Vector3 = vertices[indices[corner]]
			var cross: Vector3 = (vertices[indices[corner + 1]] - a).cross(vertices[indices[corner + 2]] - a)
			# 시계 방향이 앞면이라 외적은 법선의 반대쪽이다.
			if cross.length() > 0.00001 and cross.dot(normals[indices[corner]]) > 0.0:
				assert_true(false, "법선과 반대로 도는 삼각형 %s" % a)
				return
	assert_true(true, "모든 삼각형이 법선 쪽을 봄")
