class_name TerrainMesher
extends RefCounted
## 칸 정보(TerrainCells)에서 3D 지형 메시를 만든다. chunk_cells칸 구역마다 메시 하나라서 화면 밖 구역은 그리지 않는다.
## - 정점은 모두 월드 위치라 메시 노드를 옮기지 않는다
## - 앞면이 붙은 칸의 사각형은 칸 모서리에서만 만나므로 구역 경계에도 틈이 생기지 않는다
## - 사방이 벽인 칸의 윗면은 한 줄로 합친다 (2배 맵은 칸의 대부분이 이런 칸이다). 합친 윗면 아래에는 같은 색의 낮은 윗면이 있다
## - 벽 앞면은 벽이 아닌 쪽으로만 만든다. 옆 구역의 칸도 같은 격자로 본다
## - 2배 맵은 칸이 11만 개라, 칸마다 부르는 함수를 줄이려고 벽 격자를 멤버에 담아 직접 읽는다

const VERTICES_PER_QUAD: int = 4
const QUAD_INDICES: PackedInt32Array = [0, 1, 2, 0, 2, 3]

## 마지막 build에서 만든 사각형 수
var quad_count: int = 0

var _walls: PackedByteArray
var _colors: PackedColorArray
## 칸마다 1 = 사방이 벽
var _interior: PackedByteArray
var _width: int = 0
var _height: int = 0
var _face_color: Color
var _origin: Vector3
var _unit: float = 1.0
var _wall_units: float = 1.0


## 비어 있지 않은 구역마다 메시 하나. cap_height_px가 0보다 크면 앞벽을 잘라낸 자리에 보일 낮은 윗면을 벽 칸 아래에 깐다.
func build(cells: TerrainCells, chunk_cells: int, wall_height_px: float, cap_height_px: float = 0.0) -> Array[ArrayMesh]:
	quad_count = 0
	_read(cells, wall_height_px)
	var meshes: Array[ArrayMesh] = []
	var cap_y: float = _origin.y + cap_height_px / ViewSpace.TILE
	var top_y: float = _origin.y + _wall_units
	for chunk_y: int in range(0, _height, chunk_cells):
		for chunk_x: int in range(0, _width, chunk_cells):
			var quads: _Quads = _Quads.new()
			var end_x: int = mini(chunk_x + chunk_cells, _width)
			for y: int in range(chunk_y, mini(chunk_y + chunk_cells, _height)):
				for x: int in range(chunk_x, end_x):
					_add_cell(quads, x, y)
				_add_runs(quads, _interior, chunk_x, end_x, y, top_y)
				if cap_height_px > 0.0:
					_add_runs(quads, _walls, chunk_x, end_x, y, cap_y)
			if quads.count > 0:
				quad_count += quads.count
				meshes.append(quads.build())
	return meshes


func _read(cells: TerrainCells, wall_height_px: float) -> void:
	_walls = cells.walls
	_colors = cells.top_colors
	_width = cells.size.x
	_height = cells.size.y
	_face_color = cells.face_color
	_origin = ViewSpace.to_3d(cells.origin, 0.0)
	_unit = float(cells.tile_size) / ViewSpace.TILE
	_wall_units = wall_height_px / ViewSpace.TILE
	_interior = PackedByteArray()
	_interior.resize(_width * _height)
	_interior.fill(0)
	for y: int in range(1, _height - 1):
		for x: int in range(1, _width - 1):
			var index: int = y * _width + x
			if _walls[index] == 1 and _walls[index - 1] == 1 and _walls[index + 1] == 1 and _walls[index - _width] == 1 and _walls[index + _width] == 1:
				_interior[index] = 1


func _is_wall(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < _width and y < _height and _walls[y * _width + x] == 1


func _add_cell(quads: _Quads, x: int, y: int) -> void:
	var index: int = y * _width + x
	if _interior[index] == 1:
		return
	var color: Color = _colors[index]
	if color.a == 0.0:
		return
	var corner: Vector3 = _origin + Vector3(x, 0, y) * _unit
	var right: Vector3 = Vector3.RIGHT * _unit
	var back: Vector3 = Vector3.BACK * _unit
	if _walls[index] != 1:
		quads.add(corner, right, back, Vector3.UP, color)
		return
	var up: Vector3 = Vector3.UP * _wall_units
	quads.add(corner + up, right, back, Vector3.UP, color)
	if not _is_wall(x, y + 1):
		quads.add(corner + back, up, right, Vector3.BACK, _face_color)
	if not _is_wall(x, y - 1):
		quads.add(corner, right, up, Vector3.FORWARD, _face_color)
	if not _is_wall(x + 1, y):
		quads.add(corner + right, back, up, Vector3.RIGHT, _face_color)
	if not _is_wall(x - 1, y):
		quads.add(corner, up, back, Vector3.LEFT, _face_color)


## 한 줄에서 mask가 1이고 같은 색으로 이어진 칸을 높이 y의 사각형 하나로 합친다.
## 사방이 벽인 칸의 윗면(mask = _interior)과, 앞벽을 잘라낸 자리에 보일 낮은 윗면(mask = _walls)에 쓴다.
func _add_runs(quads: _Quads, mask: PackedByteArray, from_x: int, to_x: int, y: int, height: float) -> void:
	var x: int = from_x
	while x < to_x:
		var index: int = y * _width + x
		var color: Color = _colors[index]
		if mask[index] != 1 or color.a == 0.0:
			x += 1
			continue
		var run_start: int = x
		while x < to_x and mask[y * _width + x] == 1 and _colors[y * _width + x] == color:
			x += 1
		var corner: Vector3 = Vector3(_origin.x + run_start * _unit, height, _origin.z + y * _unit)
		quads.add(corner, Vector3.RIGHT * (x - run_start) * _unit, Vector3.BACK * _unit, Vector3.UP, color)


## 사각형을 모아 메시를 만든다.
class _Quads:
	var count: int = 0
	var _vertices: PackedVector3Array = PackedVector3Array()
	var _normals: PackedVector3Array = PackedVector3Array()
	var _colors: PackedColorArray = PackedColorArray()
	var _indices: PackedInt32Array = PackedInt32Array()

	## corner에서 u, v로 펼친 사각형. 앞면에서 볼 때 u → v가 시계 방향이어야 한다 (u × v = -normal).
	func add(corner: Vector3, u: Vector3, v: Vector3, normal: Vector3, color: Color) -> void:
		count += 1
		var base: int = _vertices.size()
		_vertices.append(corner)
		_vertices.append(corner + u)
		_vertices.append(corner + u + v)
		_vertices.append(corner + v)
		for i: int in VERTICES_PER_QUAD:
			_normals.append(normal)
			_colors.append(color)
		for offset: int in QUAD_INDICES:
			_indices.append(base + offset)

	func build() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vertices
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_COLOR] = _colors
		arrays[Mesh.ARRAY_INDEX] = _indices
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
