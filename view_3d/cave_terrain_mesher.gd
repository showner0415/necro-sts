class_name CaveTerrainMesher
extends RefCounted
## 동굴 벽 윤곽선(CaveOutlineData.loops)으로 3D 지형 메시를 만든다. 도구(tools/map_png/make_cave_outline.gd)에서 미리 구워 두고, 게임은 불러오기만 한다.
## - 바닥: 평평하다. 칸 하나에 사각형 하나. 바위뿐인 칸에는 없다
## - 벽 윗면·낮은 윗면(앞벽을 잘라낸 자리): 윤곽선이 지나는 칸은 칸을 윤곽선으로 잘라 삼각형으로 나누고, 바위뿐인 칸은 줄로 합친다
## - 벽 면: 윤곽선 조각마다 세운다. 맨 아래는 윤곽선에 붙이고, 위로 갈수록 바위 쪽으로만 들어간다 (최대 max_lean_px). 윗면은 맨 위 줄과 같은 점을 쓴다
## - 정점은 윤곽선의 점과 월드 위치만으로 정해지므로 구역 경계와 윗면 가장자리에 틈이 생기지 않는다
## - 법선은 벽 면의 수평 방향, 윗면은 위쪽이다

## 윤곽선이 지나는 칸을 찾을 때 선을 따라 보는 간격 (픽셀)
const RASTER_STEP: float = 1.0
## 이보다 가까운 두 점은 같은 점으로 본다 (픽셀)
const REPEAT_DISTANCE: float = 0.01

## 마지막으로 만든 메시의 삼각형 수, 벽이 윤곽선에서 들어간 가장 큰 거리 (픽셀), 구간별 시간·삼각형 수 (확인용)
static var last_triangles: int = 0
static var last_max_lean: float = 0.0
static var stats: Dictionary = {}

var _data: CaveOutlineData
var _settings: CaveOutlineSettings
var _cells: TerrainCells
var _source: PlaceholderWalls
var _threshold: float
var _origin: Vector2
var _row_noise: FastNoiseLite
var _heights: PackedFloat32Array
var _top_y: float
var _cap_y: float
var _floor_chars: Dictionary = {}
var _top_loops: Array[PackedVector2Array] = []
## 윤곽선 점마다 바위 쪽 방향
var _inward: Array[PackedVector2Array] = []
## 윤곽선마다 바닥을 둘러싸는지 (아니면 바닥 속의 바위)
var _is_floor_loop: Array[bool] = []
var _loop_bounds: Array[Rect2] = []
var _top_bounds: Array[Rect2] = []
## 칸마다 1 = 윤곽선이 지남 (윗면 / 낮은 윗면)
var _top_mixed: PackedByteArray
var _base_mixed: PackedByteArray
## 구역마다 벽 면 조각 [윤곽선 번호, 점 번호]
var _chunk_faces: Dictionary = {}


func build(data: CaveOutlineData, cells: TerrainCells, source: PlaceholderWalls, chunk_cells: int, wall_height_px: float, cap_height_px: float) -> Array[ArrayMesh]:
	_data = data
	_settings = data.settings
	_cells = cells
	_source = source
	_threshold = _settings.threshold
	_origin = cells.origin
	_row_noise = CaveOutline.make_noise(_settings.noise_seed + 3, _settings.lean_noise_px)
	_top_y = wall_height_px
	_cap_y = cap_height_px
	_heights = PackedFloat32Array([0.0, _settings.foot_height_px])
	_heights.append_array(_settings.face_rows_px)
	_heights.append(wall_height_px)
	for c: String in source.floor_colors.keys():
		_floor_chars[c.unicode_at(0)] = source.floor_colors[c]
	last_triangles = 0
	last_max_lean = 0.0
	stats = {"mesh_usec": 0, "floor_usec": 0, "floor_tris": 0, "top_usec": 0, "top_tris": 0, "cap_usec": 0, "cap_tris": 0, "face_usec": 0, "face_tris": 0, "faces": 0, "failed_polygons": 0}
	_prepare_loops(chunk_cells)
	var meshes: Array[ArrayMesh] = []
	for chunk_y: int in range(0, cells.size.y, chunk_cells):
		for chunk_x: int in range(0, cells.size.x, chunk_cells):
			var triangles: _Triangles = _Triangles.new()
			_add_chunk(triangles, chunk_x, chunk_y, chunk_cells)
			if triangles.count > 0:
				last_triangles += triangles.count
				var started: int = Time.get_ticks_usec()
				meshes.append(triangles.build())
				stats["mesh_usec"] += Time.get_ticks_usec() - started
	return meshes


func _prepare_loops(chunk_cells: int) -> void:
	_top_mixed.resize(_cells.size.x * _cells.size.y)
	_top_mixed.fill(0)
	_base_mixed.resize(_cells.size.x * _cells.size.y)
	_base_mixed.fill(0)
	for loop_index: int in _data.loops.size():
		var loop: PackedVector2Array = _data.loops[loop_index]
		var inward: PackedVector2Array = PackedVector2Array()
		var top: PackedVector2Array = PackedVector2Array()
		var noise: FastNoiseLite = CaveOutline.make_noise(_settings.noise_seed + 2, _settings.lean_noise_px)
		for point: int in loop.size():
			var direction: Vector2 = _rock_side(loop[point - 1], loop[point]) + _rock_side(loop[point], loop[(point + 1) % loop.size()])
			direction = direction.normalized() if direction != Vector2.ZERO else _rock_side(loop[point - 1], loop[point])
			inward.append(direction)
			var lean: float = (0.5 + 0.5 * noise.get_noise_2dv(loop[point])) * _settings.max_lean_px
			last_max_lean = maxf(last_max_lean, lean)
			top.append(loop[point] + direction * lean)
		_inward.append(inward)
		_top_loops.append(top)
		_is_floor_loop.append(_signed_area(loop) > 0.0)
		_loop_bounds.append(_bounds(loop))
		_top_bounds.append(_bounds(top))
		_mark_cells(loop, _base_mixed)
		_mark_cells(top, _top_mixed)
		for point: int in loop.size():
			var middle: Vector2 = (loop[point] + loop[(point + 1) % loop.size()]) * 0.5
			var chunk: Vector2i = Vector2i((middle / (float(_data.cell_px) * chunk_cells)).floor())
			if not _chunk_faces.has(chunk):
				_chunk_faces[chunk] = []
			_chunk_faces[chunk].append(Vector2i(loop_index, point))


## 윤곽선은 바위를 왼쪽(화면 기준)에 두고 돈다 (CaveOutline._segment_edges).
static func _rock_side(from: Vector2, to: Vector2) -> Vector2:
	var along: Vector2 = to - from
	return Vector2(along.y, -along.x).normalized() if along != Vector2.ZERO else Vector2.ZERO


## 양수면 화면에서 시계 방향으로 돈다 (바닥을 둘러싼 윤곽선)
static func _signed_area(loop: PackedVector2Array) -> float:
	var area: float = 0.0
	for index: int in loop.size():
		var next: Vector2 = loop[(index + 1) % loop.size()]
		area += loop[index].x * next.y - next.x * loop[index].y
	return area


static func _bounds(polygon: PackedVector2Array) -> Rect2:
	var rect: Rect2 = Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		rect = rect.expand(point)
	return rect


func _mark_cells(loop: PackedVector2Array, marks: PackedByteArray) -> void:
	for index: int in loop.size():
		var from: Vector2 = loop[index]
		var to: Vector2 = loop[(index + 1) % loop.size()]
		var steps: int = maxi(ceili(from.distance_to(to) / RASTER_STEP), 1)
		for step: int in steps + 1:
			var cell: Vector2i = Vector2i((from.lerp(to, float(step) / steps) / _data.cell_px).floor())
			if cell.x >= 0 and cell.y >= 0 and cell.x < _cells.size.x and cell.y < _cells.size.y:
				marks[cell.y * _cells.size.x + cell.x] = 1


func _add_chunk(triangles: _Triangles, chunk_x: int, chunk_y: int, chunk_cells: int) -> void:
	var end_x: int = mini(chunk_x + chunk_cells, _cells.size.x)
	var end_y: int = mini(chunk_y + chunk_cells, _cells.size.y)
	var rect: PackedVector2Array = _rect_polygon(Rect2(Vector2(chunk_x, chunk_y) * _data.cell_px, Vector2(end_x - chunk_x, end_y - chunk_y) * _data.cell_px))
	var started: int = Time.get_ticks_usec()
	for y: int in range(chunk_y, end_y):
		for x: int in range(chunk_x, end_x):
			if _base_mixed[y * _cells.size.x + x] == 1 or not _center_is_rock(x, y):
				var color: Color = _floor_color(x, y)
				if color.a > 0.0:
					_add_rect(triangles, Vector2(x, y) * _data.cell_px, Vector2.ONE * _data.cell_px, 0.0, color)
					stats["floor_tris"] += 2
	stats["floor_usec"] += Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var before: int = triangles.count
	_add_surface(triangles, chunk_x, end_x, chunk_y, end_y, _top_y, _top_mixed, _chunk_parts(rect, _top_loops, _top_bounds))
	stats["top_tris"] += triangles.count - before
	stats["top_usec"] += Time.get_ticks_usec() - started
	if _cap_y > 0.0:
		started = Time.get_ticks_usec()
		before = triangles.count
		_add_surface(triangles, chunk_x, end_x, chunk_y, end_y, _cap_y, _base_mixed, _chunk_parts(rect, _data.loops, _loop_bounds))
		stats["cap_tris"] += triangles.count - before
		stats["cap_usec"] += Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	before = triangles.count
	for face: Vector2i in _chunk_faces.get(Vector2i(chunk_x, chunk_y) / chunk_cells, []):
		_add_face(triangles, face.x, face.y)
		stats["faces"] += 1
	stats["face_tris"] += triangles.count - before
	stats["face_usec"] += Time.get_ticks_usec() - started


## 윤곽선을 구역으로 잘라 둔다 (칸마다 큰 윤곽선 전체를 자르지 않게). {"floors": [...], "rocks": [...]}, 각 항목은 [다각형, 범위]
func _chunk_parts(rect: PackedVector2Array, loops: Array[PackedVector2Array], bounds: Array[Rect2]) -> Dictionary:
	var chunk_bounds: Rect2 = _bounds(rect)
	var parts: Dictionary = {"floors": [], "rocks": []}
	for index: int in loops.size():
		if not bounds[index].intersects(chunk_bounds, true):
			continue
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(rect, loops[index]):
			parts["floors" if _is_floor_loop[index] else "rocks"].append([piece, _bounds(piece)])
	return parts


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])


func _center_is_rock(x: int, y: int) -> bool:
	var per: int = _data.per_cell()
	return CaveOutlineData.decode(_data.values[(y * per + per / 2) * _data.nodes().x + x * per + per / 2]) >= _threshold


## 한 높이의 표면: 윤곽선이 지나는 칸은 잘라서 깔고, 바위뿐인 칸은 줄로 합친다.
func _add_surface(triangles: _Triangles, from_x: int, to_x: int, from_y: int, to_y: int, height: float, mixed: PackedByteArray, parts: Dictionary) -> void:
	for y: int in range(from_y, to_y):
		var x: int = from_x
		while x < to_x:
			if mixed[y * _cells.size.x + x] == 1:
				_add_cut_cell(triangles, x, y, height, parts)
				x += 1
			elif _center_is_rock(x, y):
				var color: Color = _rock_color(x, y)
				var run_start: int = x
				while x < to_x and mixed[y * _cells.size.x + x] == 0 and _center_is_rock(x, y) and _rock_color(x, y) == color:
					x += 1
				_add_rect(triangles, Vector2(run_start, y) * _data.cell_px, Vector2(x - run_start, 1) * _data.cell_px, height, color)
			else:
				x += 1


## 칸에서 바닥을 잘라 낸 나머지(와 바닥 속의 바위)를 삼각형으로 나눠 깐다.
func _add_cut_cell(triangles: _Triangles, x: int, y: int, height: float, parts: Dictionary) -> void:
	var rect: Rect2 = Rect2(Vector2(x, y) * _data.cell_px, Vector2.ONE * _data.cell_px)
	var cell: PackedVector2Array = _rect_polygon(rect)
	var pieces: Array[PackedVector2Array] = [cell]
	for part: Array in parts["floors"]:
		var bounds: Rect2 = part[1]
		# 칸 안에 통째로 들어가는 조각은 구멍이 되는데, 작은 구멍은 윤곽 단계에서 없앴다.
		if not bounds.intersects(rect, true) or rect.grow(-0.001).encloses(bounds):
			continue
		var remaining: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in pieces:
			remaining.append_array(Geometry2D.clip_polygons(piece, part[0]))
		pieces = remaining
	for part: Array in parts["rocks"]:
		if (part[1] as Rect2).intersects(rect, true):
			pieces.append_array(Geometry2D.intersect_polygons(cell, part[0]))
	var color: Color = _rock_color(x, y)
	for piece: PackedVector2Array in pieces:
		var cleaned: PackedVector2Array = _without_repeats(piece)
		if cleaned.size() < 3:
			continue
		var indices: PackedInt32Array = _triangulate(cleaned)
		if indices.is_empty():
			stats["failed_polygons"] += 1
			continue
		triangles.add_triangles(cleaned, indices, _origin, height, color)


## 자르면서 생긴 거의 같은 점을 뺀다 (삼각형 나누기가 실패한다).
static func _without_repeats(polygon: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in polygon:
		if result.is_empty() or result[-1].distance_to(point) > REPEAT_DISTANCE:
			result.append(point)
	if result.size() > 1 and result[0].distance_to(result[-1]) <= REPEAT_DISTANCE:
		result.remove_at(result.size() - 1)
	return result


## 다각형을 삼각형으로 나눈다. 귀 자르기가 실패하면(한 직선 위의 점 등) 들로네로 나눠 다각형 안의 삼각형만 남긴다.
static func _triangulate(polygon: PackedVector2Array) -> PackedInt32Array:
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	if not indices.is_empty():
		return indices
	var candidates: PackedInt32Array = Geometry2D.triangulate_delaunay(polygon)
	for corner: int in range(0, candidates.size(), 3):
		var a: Vector2 = polygon[candidates[corner]]
		var b: Vector2 = polygon[candidates[corner + 1]]
		var c: Vector2 = polygon[candidates[corner + 2]]
		if Geometry2D.is_point_in_polygon((a + b + c) / 3.0, polygon):
			indices.append(candidates[corner])
			indices.append(candidates[corner + 1])
			indices.append(candidates[corner + 2])
	return indices


func _rock_color(x: int, y: int) -> Color:
	var index: int = _cells.index_of(x, y)
	return _cells.top_colors[index] if _cells.walls[index] == 1 else _source.top_color


## 이 칸의 바닥 색. 지금 벽인 칸(윤곽이 물러난 곳)은 가장 가까운 바닥 칸의 종류로 체크무늬를 잇는다. 바닥을 그리지 않는 씬이면 투명.
func _floor_color(x: int, y: int) -> Color:
	var index: int = _cells.index_of(x, y)
	if _cells.walls[index] != 1 and _cells.top_colors[index].a > 0.0:
		return _cells.top_colors[index]
	if _floor_chars.is_empty():
		return Color.TRANSPARENT
	for radius: int in range(1, 6):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var nx: int = x + dx
				var ny: int = y + dy
				if maxi(absi(dx), absi(dy)) == radius and nx >= 0 and ny >= 0 and nx < _cells.size.x and ny < _cells.size.y and _cells.walls[_cells.index_of(nx, ny)] != 1:
					var code: int = _source.layout[ny].unicode_at(nx)
					if _floor_chars.has(code):
						var pair: PackedColorArray = _floor_chars[code]
						return pair[(x + y) % pair.size()]
	return _source.top_color


func _add_rect(triangles: _Triangles, position: Vector2, size: Vector2, height: float, color: Color) -> void:
	triangles.add_triangles(_rect_polygon(Rect2(position, size)), PackedInt32Array([0, 1, 2, 0, 2, 3]), _origin, height, color)


func _world(position: Vector2, height: float) -> Vector3:
	return ViewSpace.to_3d(_origin + position, height)


## 이 높이에서 벽 면이 있는 자리: 맨 아래는 윤곽선, 맨 위는 윗면 가장자리, 그 사이는 위로 갈수록 바위 쪽으로 울퉁불퉁하게
func _face_point(loop: int, point: int, height: float) -> Vector2:
	var foot: Vector2 = _data.loops[loop][point]
	if height <= _settings.foot_height_px:
		return foot
	if height >= _top_y:
		return _top_loops[loop][point]
	var ramp: float = (height - _settings.foot_height_px) / (_top_y - _settings.foot_height_px)
	var lean: float = (0.5 + 0.5 * _row_noise.get_noise_3d(foot.x, height, foot.y)) * _settings.max_lean_px * ramp
	return foot + _inward[loop][point] * lean


## 윤곽선 조각 하나의 벽 면. 윤곽선은 바위를 왼쪽에 두고 돌므로 뒤 점에서 앞 점 쪽으로 깔아야 바닥 쪽을 본다.
func _add_face(triangles: _Triangles, loop: int, point: int) -> void:
	var next: int = (point + 1) % _data.loops[loop].size()
	var normal_next: Vector2 = -_inward[loop][next]
	var normal_point: Vector2 = -_inward[loop][point]
	for row: int in _heights.size() - 1:
		var low: float = _heights[row]
		var high: float = _heights[row + 1]
		triangles.add_quad(_world(_face_point(loop, next, low), low), _world(_face_point(loop, point, low), low), _world(_face_point(loop, point, high), high), _world(_face_point(loop, next, high), high), Vector3(normal_next.x, 0.0, normal_next.y), Vector3(normal_point.x, 0.0, normal_point.y), _cells.face_color)


## 삼각형을 모아 메시를 만든다.
class _Triangles:
	var count: int = 0
	var _vertices: PackedVector3Array = PackedVector3Array()
	var _normals: PackedVector3Array = PackedVector3Array()
	var _colors: PackedColorArray = PackedColorArray()
	var _indices: PackedInt32Array = PackedInt32Array()

	## 바닥과 나란한 삼각형들. 위에서 볼 때 앞면이 되도록 삼각형마다 도는 방향을 맞춘다.
	func add_triangles(points: PackedVector2Array, indices: PackedInt32Array, origin: Vector2, height: float, color: Color) -> void:
		var base: int = _vertices.size()
		for point: Vector2 in points:
			_vertices.append(ViewSpace.to_3d(origin + point, height))
			_normals.append(Vector3.UP)
			_colors.append(color)
		for corner: int in range(0, indices.size(), 3):
			var a: int = indices[corner]
			var b: int = indices[corner + 1]
			var c: int = indices[corner + 2]
			if (points[b] - points[a]).cross(points[c] - points[a]) < 0.0:
				var swap: int = b
				b = c
				c = swap
			_indices.append(base + a)
			_indices.append(base + b)
			_indices.append(base + c)
			count += 1

	## a, b(아래), c, d(위) 순서의 벽 면 하나. a·d와 b·c의 법선을 따로 준다.
	func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal_left: Vector3, normal_right: Vector3, color: Color) -> void:
		var base: int = _vertices.size()
		for point: Vector3 in [a, b, c, d]:
			_vertices.append(point)
			_colors.append(color)
		_normals.append(normal_left)
		_normals.append(normal_right)
		_normals.append(normal_right)
		_normals.append(normal_left)
		for offset: int in [0, 1, 2, 0, 2, 3]:
			_indices.append(base + offset)
		count += 2

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
