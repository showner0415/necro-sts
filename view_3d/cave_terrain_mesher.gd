class_name CaveTerrainMesher
extends RefCounted
## 동굴 벽 윤곽(CaveOutlineData)으로 3D 지형 메시를 만든다. TerrainMesher를 대신해 눈에 보이는 메시만 만든다 (그림자 전용 메시는 칸 상자 그대로).
## - 바닥: 평평하다. 바위뿐인 칸에는 없다
## - 벽 윗면·낮은 윗면(앞벽을 잘라낸 자리): 윤곽의 마칭 스퀘어 삼각형을 깐다. 줄에서 이어진 바위는 합친다
## - 벽 면: 윗면 가장자리의 조각마다 세운다. 맨 아래는 윤곽에 붙이고 위로 갈수록 바위 쪽으로만 들어간다
## - 정점은 격자 값과 월드 위치만으로 정해지므로 구역 경계와 윗면 가장자리에 틈이 생기지 않는다
## - 법선은 벽 면의 수평 방향(윤곽의 기울기), 윗면은 위쪽이다

## 윗면 가장자리에서 윤곽까지 되짚어 갈 때 되풀이하는 횟수
const BASE_SEARCH_STEPS: int = 5
## 칸의 네 변 번호 순서로 도는 자리: 왼쪽 위, 위 변, 오른쪽 위, 오른쪽 변, 오른쪽 아래, 아래 변, 왼쪽 아래, 왼쪽 변
const CORNER_COUNT: int = 4

## 마지막으로 만든 메시의 삼각형 수와 만드는 데 걸린 시간 (확인용)
static var last_triangles: int = 0
static var last_usec: int = 0
## 마지막으로 만든 벽의 가장 큰 기울기 (윗면 가장자리와 윤곽 사이, 픽셀, 확인용)
static var last_max_lean: float = 0.0

var _data: CaveOutlineData
var _settings: CaveOutlineSettings
var _cells: TerrainCells
var _source: PlaceholderWalls
var _per: int
var _sample: float
var _nodes: Vector2i
var _threshold: float
var _origin: Vector2
var _lean_field: float
var _lean_noise: FastNoiseLite
var _row_noise: FastNoiseLite
var _heights: PackedFloat32Array
var _top_y: float
var _cap_y: float
var _cap_px: float
var _floor_chars: Dictionary = {}


## 지역의 벽에 맞는 윤곽 파일이 있으면 새 지형 메시를 돌려주고, 없으면 fallback을 그대로 돌려준다.
static func build_for(walls: PlaceholderWalls, scene_path: String, chunk_cells: int, wall_height_px: float, cap_height_px: float, fallback: Array[ArrayMesh]) -> Array[ArrayMesh]:
	var path: String = "%s_outline.res" % scene_path.get_basename()
	if not ResourceLoader.exists(path):
		push_warning("동굴 지형: 윤곽 파일 없음 (%s). 칸 지형을 그대로 쓴다" % path)
		return fallback
	var cells: TerrainCells = TerrainCells.from_walls(walls)
	var data: CaveOutlineData = load(path)
	if data.cell_count != cells.size:
		push_warning("동굴 지형: 윤곽 파일의 칸 수 %s가 벽 %s와 다르다. 칸 지형을 그대로 쓴다" % [data.cell_count, cells.size])
		return fallback
	var started: int = Time.get_ticks_usec()
	var mesher: CaveTerrainMesher = CaveTerrainMesher.new()
	var meshes: Array[ArrayMesh] = mesher.build(data, cells, walls, chunk_cells, wall_height_px, cap_height_px)
	last_usec = Time.get_ticks_usec() - started
	return meshes


func build(data: CaveOutlineData, cells: TerrainCells, source: PlaceholderWalls, chunk_cells: int, wall_height_px: float, cap_height_px: float) -> Array[ArrayMesh]:
	_data = data
	_settings = data.settings
	_cells = cells
	_source = source
	_per = data.per_cell()
	_sample = float(_settings.sample_px)
	_nodes = data.nodes()
	_threshold = _settings.threshold
	_origin = cells.origin
	_lean_field = data.field_per_px() * _settings.max_lean_px
	_lean_noise = CaveOutline.make_noise(_settings.noise_seed + 2, _settings.lean_noise_px)
	_row_noise = CaveOutline.make_noise(_settings.noise_seed + 3, _settings.lean_noise_px)
	_top_y = wall_height_px
	_cap_y = cap_height_px
	_cap_px = cap_height_px
	_heights = PackedFloat32Array([0.0, _settings.foot_height_px])
	_heights.append_array(_settings.face_rows_px)
	_heights.append(wall_height_px)
	for c: String in source.floor_colors.keys():
		_floor_chars[c.unicode_at(0)] = source.floor_colors[c]
	last_triangles = 0
	last_max_lean = 0.0
	var meshes: Array[ArrayMesh] = []
	for chunk_y: int in range(0, cells.size.y, chunk_cells):
		for chunk_x: int in range(0, cells.size.x, chunk_cells):
			var triangles: _Triangles = _Triangles.new()
			var end_x: int = mini(chunk_x + chunk_cells, cells.size.x)
			for y: int in range(chunk_y, mini(chunk_y + chunk_cells, cells.size.y)):
				_add_cell_row(triangles, chunk_x, end_x, y)
			if triangles.count > 0:
				last_triangles += triangles.count
				meshes.append(triangles.build())
	return meshes


func _add_cell_row(triangles: _Triangles, from_x: int, to_x: int, y: int) -> void:
	var x: int = from_x
	while x < to_x:
		var state: int = _data.cell_states[y * _cells.size.x + x]
		if state == 2:
			# 바위뿐인 칸은 같은 색끼리 윗면과 낮은 윗면을 줄로 합친다.
			var color: Color = _rock_color(x, y)
			var run_start: int = x
			while x < to_x and _data.cell_states[y * _cells.size.x + x] == 2 and _rock_color(x, y) == color:
				x += 1
			_add_rect(triangles, Vector2(run_start, y) * _data.cell_px, Vector2(x - run_start, 1) * _data.cell_px, _top_y, color)
			if _cap_y > 0.0:
				_add_rect(triangles, Vector2(run_start, y) * _data.cell_px, Vector2(x - run_start, 1) * _data.cell_px, _cap_y, color)
			continue
		_add_rect(triangles, Vector2(x, y) * _data.cell_px, Vector2.ONE * _data.cell_px, 0.0, _floor_color(x, y))
		if state == 1:
			_add_mixed_cell(triangles, x, y)
		x += 1


func _rock_color(x: int, y: int) -> Color:
	var index: int = _cells.index_of(x, y)
	return _cells.top_colors[index] if _cells.walls[index] == 1 else _source.top_color


## 이 칸의 바닥 색. 지금 벽인 칸(윤곽이 물러난 곳)은 가장 가까운 바닥 칸의 종류로 체크무늬를 잇는다.
func _floor_color(x: int, y: int) -> Color:
	var index: int = _cells.index_of(x, y)
	if _cells.walls[index] != 1 and _cells.top_colors[index].a > 0.0:
		return _cells.top_colors[index]
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
	triangles.add_polygon([_world(position, height), _world(position + Vector2(size.x, 0), height), _world(position + size, height), _world(position + Vector2(0, size.y), height)], Vector3.UP, color)


func _world(position: Vector2, height: float) -> Vector3:
	return ViewSpace.to_3d(_origin + position, height)


## 윤곽이 지나는 칸: 벽 윗면(기울어 들어간 윤곽)과 낮은 윗면(윤곽)을 격자 칸마다 깔고, 윗면 가장자리마다 벽 면을 세운다.
func _add_mixed_cell(triangles: _Triangles, cell_x: int, cell_y: int) -> void:
	var color: Color = _rock_color(cell_x, cell_y)
	var base_i: int = cell_x * _per
	var base_k: int = cell_y * _per
	var top: PackedFloat32Array = PackedFloat32Array()
	var ground: PackedFloat32Array = PackedFloat32Array()
	top.resize((_per + 1) * (_per + 1))
	ground.resize((_per + 1) * (_per + 1))
	for k: int in _per + 1:
		for i: int in _per + 1:
			var value: float = _value(base_i + i, base_k + k)
			ground[k * (_per + 1) + i] = value
			top[k * (_per + 1) + i] = _top_value(value, Vector2(base_i + i, base_k + k) * _sample)
	_add_surface(triangles, top, base_i, base_k, _top_y, color, true)
	if _cap_y > 0.0:
		_add_surface(triangles, ground, base_i, base_k, _cap_y, color, false)


func _value(i: int, k: int) -> float:
	return CaveOutlineData.decode(_data.values[k * _nodes.x + i])


## 벽 윗면의 값: 윤곽보다 바위 쪽으로 들어가도록, 위치로 정해지는 만큼 뺀다.
func _top_value(value: float, position: Vector2) -> float:
	if value < _threshold or value > _threshold + _lean_field:
		return value
	return value - (0.5 + 0.5 * _lean_noise.get_noise_2dv(position)) * _lean_field


## 격자 칸마다 표면을 깐다. 줄에서 이어진 바위는 사각형 하나로 합친다. with_faces면 윗면 가장자리마다 벽 면을 세운다.
func _add_surface(triangles: _Triangles, values: PackedFloat32Array, base_i: int, base_k: int, height: float, color: Color, with_faces: bool) -> void:
	var line: int = _per + 1
	for k: int in _per:
		var i: int = 0
		while i < _per:
			var a: float = values[k * line + i]
			var b: float = values[k * line + i + 1]
			var c: float = values[(k + 1) * line + i + 1]
			var d: float = values[(k + 1) * line + i]
			if a >= _threshold and b >= _threshold and c >= _threshold and d >= _threshold:
				var run_start: int = i
				while i < _per and values[k * line + i] >= _threshold and values[k * line + i + 1] >= _threshold and values[(k + 1) * line + i + 1] >= _threshold and values[(k + 1) * line + i] >= _threshold:
					i += 1
				_add_rect(triangles, Vector2(base_i + run_start, base_k + k) * _sample, Vector2(i - run_start, 1) * _sample, height, color)
				continue
			if a >= _threshold or b >= _threshold or c >= _threshold or d >= _threshold:
				_add_contour_cell(triangles, base_i + i, base_k + k, a, b, c, d, height, color, with_faces)
			i += 1


## 윤곽이 지나는 격자 칸 하나. 둘레를 시계 방향으로 돌며 바위인 모서리와 윤곽이 지나는 변의 점을 모아 다각형을 만든다.
func _add_contour_cell(triangles: _Triangles, i: int, k: int, a: float, b: float, c: float, d: float, height: float, color: Color, with_faces: bool) -> void:
	var corners: Array[Vector2] = [Vector2(i, k) * _sample, Vector2(i + 1, k) * _sample, Vector2(i + 1, k + 1) * _sample, Vector2(i, k + 1) * _sample]
	var values: Array[float] = [a, b, c, d]
	# 네 변의 점. 같은 변을 쓰는 옆 칸과 같은 값이 나오도록 늘 왼쪽·위쪽 점에서 잰다.
	var crossings: Array[Vector2] = [_crossing(corners[0], a, corners[1], b), _crossing(corners[1], b, corners[2], c), _crossing(corners[3], d, corners[2], c), _crossing(corners[0], a, corners[3], d)]
	var diagonal_a: bool = a >= _threshold and c >= _threshold and b < _threshold and d < _threshold
	var diagonal_b: bool = b >= _threshold and d >= _threshold and a < _threshold and c < _threshold
	if (diagonal_a or diagonal_b) and (a + b + c + d) * 0.25 < _threshold:
		# 안장점에서 가운데가 바닥이면 바위 모서리 둘이 따로 있다.
		var first: int = 0 if diagonal_a else 1
		_emit_polygon(triangles, [crossings[(first + 3) % CORNER_COUNT], corners[first], crossings[first]], [true, false, true], height, color, with_faces)
		_emit_polygon(triangles, [crossings[(first + 1) % CORNER_COUNT], corners[(first + 2) % CORNER_COUNT], crossings[(first + 2) % CORNER_COUNT]], [true, false, true], height, color, with_faces)
		return
	var points: Array[Vector2] = []
	var on_contour: Array[bool] = []
	for corner: int in CORNER_COUNT:
		var rock: bool = values[corner] >= _threshold
		if rock:
			points.append(corners[corner])
			on_contour.append(false)
		if rock != (values[(corner + 1) % CORNER_COUNT] >= _threshold):
			points.append(crossings[corner])
			on_contour.append(true)
	_emit_polygon(triangles, points, on_contour, height, color, with_faces)


func _crossing(from: Vector2, from_value: float, to: Vector2, to_value: float) -> Vector2:
	if (from_value >= _threshold) == (to_value >= _threshold):
		return from
	return from.lerp(to, (_threshold - from_value) / (to_value - from_value))


func _emit_polygon(triangles: _Triangles, points: Array[Vector2], on_contour: Array[bool], height: float, color: Color, with_faces: bool) -> void:
	var world: Array[Vector3] = []
	for point: Vector2 in points:
		world.append(_world(point, height))
	triangles.add_polygon(world, Vector3.UP, color)
	if not with_faces:
		return
	for index: int in points.size():
		var next: int = (index + 1) % points.size()
		if on_contour[index] and on_contour[next]:
			_add_face(triangles, points[index], points[next])


## 격자 값을 위치로 읽는다 (양선형)
func _field(position: Vector2) -> float:
	var grid: Vector2 = position / _sample
	var i: int = clampi(floori(grid.x), 0, _nodes.x - 2)
	var k: int = clampi(floori(grid.y), 0, _nodes.y - 2)
	var fx: float = grid.x - i
	var fy: float = grid.y - k
	return lerpf(lerpf(_value(i, k), _value(i + 1, k), fx), lerpf(_value(i, k + 1), _value(i + 1, k + 1), fx), fy)


## 값이 커지는 쪽 (바위 쪽)
func _rock_direction(position: Vector2) -> Vector2:
	var gradient: Vector2 = Vector2(_field(position + Vector2(_sample, 0)) - _field(position - Vector2(_sample, 0)), _field(position + Vector2(0, _sample)) - _field(position - Vector2(0, _sample)))
	return gradient.normalized() if gradient != Vector2.ZERO else Vector2.RIGHT


## 윗면 가장자리의 점에서 바닥 쪽으로 윤곽까지 되짚어 간 점. 벽의 맨 아래다.
func _foot_of(top: Vector2) -> Vector2:
	var limit: float = _settings.max_lean_px * 2.0
	var point: Vector2 = top
	var travelled: float = 0.0
	for step: int in BASE_SEARCH_STEPS:
		var excess: float = _field(point) - _threshold
		if excess <= 0.0 or travelled >= limit:
			break
		var distance: float = minf(excess / _data.field_per_px(), limit - travelled)
		point -= _rock_direction(point) * distance
		travelled += distance
	return point


## 이 높이에서 벽 면이 있는 자리: 맨 아래는 윤곽, 맨 위는 윗면 가장자리, 그 사이는 위로 갈수록 바위 쪽으로 울퉁불퉁하게
func _face_point(top: Vector2, foot: Vector2, height: float) -> Vector2:
	if height <= _settings.foot_height_px:
		return foot
	if height >= _top_y:
		return top
	var ramp: float = (height - _settings.foot_height_px) / (_top_y - _settings.foot_height_px)
	var lean: float = (0.5 + 0.5 * _row_noise.get_noise_3d(foot.x, height, foot.y)) * _settings.max_lean_px * ramp
	return foot + _rock_direction(foot) * minf(lean, _settings.max_lean_px)


func _add_face(triangles: _Triangles, a: Vector2, b: Vector2) -> void:
	var foot_a: Vector2 = _foot_of(a)
	var foot_b: Vector2 = _foot_of(b)
	last_max_lean = maxf(last_max_lean, a.distance_to(foot_a))
	var normal_a: Vector2 = -_rock_direction(a)
	var normal_b: Vector2 = -_rock_direction(b)
	# 앞면에서 볼 때 시계 방향이 되도록 a → b의 방향을 고른다 (벽은 바닥 쪽을 본다).
	var along: Vector2 = b - a
	if Vector2(along.y, -along.x).dot(normal_a + normal_b) < 0.0:
		var swap: Vector2 = a
		a = b
		b = swap
		swap = foot_a
		foot_a = foot_b
		foot_b = swap
		swap = normal_a
		normal_a = normal_b
		normal_b = swap
	var normal_3d_a: Vector3 = Vector3(normal_a.x, 0.0, normal_a.y)
	var normal_3d_b: Vector3 = Vector3(normal_b.x, 0.0, normal_b.y)
	for row: int in _heights.size() - 1:
		var low: float = _heights[row]
		var high: float = _heights[row + 1]
		triangles.add_quad(_world(_face_point(a, foot_a, low), low), _world(_face_point(b, foot_b, low), low), _world(_face_point(b, foot_b, high), high), _world(_face_point(a, foot_a, high), high), normal_3d_a, normal_3d_b, _cells.face_color)


## 삼각형을 모아 메시를 만든다.
class _Triangles:
	var count: int = 0
	var _vertices: PackedVector3Array = PackedVector3Array()
	var _normals: PackedVector3Array = PackedVector3Array()
	var _colors: PackedColorArray = PackedColorArray()
	var _indices: PackedInt32Array = PackedInt32Array()

	## 볼록한 다각형을 부채꼴로. 앞면에서 볼 때 시계 방향 순서여야 한다.
	func add_polygon(points: Array[Vector3], normal: Vector3, color: Color) -> void:
		var base: int = _vertices.size()
		for point: Vector3 in points:
			_vertices.append(point)
			_normals.append(normal)
			_colors.append(color)
		for index: int in range(1, points.size() - 1):
			_indices.append(base)
			_indices.append(base + index)
			_indices.append(base + index + 1)
			count += 1

	## a, b(아래), c, d(위) 순서의 벽 면 하나. 왼쪽·오른쪽 법선을 따로 준다.
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
