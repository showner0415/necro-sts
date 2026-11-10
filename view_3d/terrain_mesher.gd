class_name TerrainMesher
extends RefCounted
## 칸 정보(TerrainCells)에서 3D 지형 메시를 만든다. chunk_cells칸 구역마다 메시 하나라서 화면 밖 구역은 그리지 않는다.
## - 정점은 모두 월드 위치라 메시 노드를 옮기지 않는다
## - 사각형은 칸 모서리에서만 만나므로 구역 경계에도 틈이 생기지 않는다
## - 벽 앞면은 벽이 아닌 쪽으로만 만든다. 옆 구역의 칸도 같은 격자로 본다

## 마지막 build에서 만든 사각형 수
var quad_count: int = 0


## 비어 있지 않은 구역마다 메시 하나
func build(cells: TerrainCells, chunk_cells: int, wall_height_px: float) -> Array[ArrayMesh]:
	quad_count = 0
	var meshes: Array[ArrayMesh] = []
	for chunk_y: int in range(0, cells.size.y, chunk_cells):
		for chunk_x: int in range(0, cells.size.x, chunk_cells):
			var quads: _Quads = _Quads.new()
			for y: int in range(chunk_y, mini(chunk_y + chunk_cells, cells.size.y)):
				for x: int in range(chunk_x, mini(chunk_x + chunk_cells, cells.size.x)):
					_add_cell(quads, cells, x, y, wall_height_px)
			if quads.count > 0:
				quad_count += quads.count
				meshes.append(quads.build())
	return meshes


func _add_cell(quads: _Quads, cells: TerrainCells, x: int, y: int, wall_height_px: float) -> void:
	var color: Color = cells.top_colors[cells.index_of(x, y)]
	if color.a == 0.0:
		return
	var unit: float = float(cells.tile_size) / ViewSpace.TILE
	var corner: Vector3 = ViewSpace.to_3d(cells.origin, 0.0) + Vector3(x, 0, y) * unit
	var right: Vector3 = Vector3.RIGHT * unit
	var back: Vector3 = Vector3.BACK * unit
	if not cells.is_wall(x, y):
		quads.add(corner, right, back, Vector3.UP, color)
		return
	var up: Vector3 = Vector3.UP * (wall_height_px / ViewSpace.TILE)
	var face: Color = cells.face_color
	quads.add(corner + up, right, back, Vector3.UP, color)
	if not cells.is_wall(x, y + 1):
		quads.add(corner + back, up, right, Vector3.BACK, face)
	if not cells.is_wall(x, y - 1):
		quads.add(corner, right, up, Vector3.FORWARD, face)
	if not cells.is_wall(x + 1, y):
		quads.add(corner + right, back, up, Vector3.RIGHT, face)
	if not cells.is_wall(x - 1, y):
		quads.add(corner, up, back, Vector3.LEFT, face)


## 사각형을 모아 메시를 만든다.
class _Quads:
	var count: int = 0
	var _vertices: PackedVector3Array = PackedVector3Array()
	var _normals: PackedVector3Array = PackedVector3Array()
	var _colors: PackedColorArray = PackedColorArray()

	## corner에서 u, v로 펼친 사각형. 앞면에서 볼 때 u → v가 시계 방향이어야 한다 (u × v = -normal).
	func add(corner: Vector3, u: Vector3, v: Vector3, normal: Vector3, color: Color) -> void:
		count += 1
		for point: Vector3 in [corner, corner + u, corner + u + v, corner, corner + u + v, corner + v]:
			_vertices.append(point)
			_normals.append(normal)
			_colors.append(color)

	func build() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vertices
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_COLOR] = _colors
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
