class_name CaveOutline
extends RefCounted
## 맵 PNG의 칸에서 동굴 벽 윤곽을 만드는 규칙. 노드에 의존하지 않는다 (docs/plans/2026-11-10_cave_terrain_plan.md의 1~7단계).
## 흐리기 → 노이즈 → 좁은 길목 보호 → 작은 조각 없애기 → 마칭 스퀘어 윤곽선 → 단순화. 맵 밖은 벽이다.
## 입력은 PNG의 칸 그대로다. 위치로 정해지는 노이즈라 값이 같으면 결과도 같다.

const CELL_PX: int = 32
## 흐리기에 쓸 표준편차의 배수 (이 밖의 칸은 무시한다)
const BLUR_RANGE: float = 3.0
## 없앤 자리나 보호한 자리에 넣는 값이 문턱에서 떨어진 정도
const FLIP_MARGIN: float = 0.02
## 좁은 바닥의 양쪽 끝으로 치는 바닥의 최소 칸 수 (폭 측정용)
const MIN_END_CELLS: int = 8

var settings: CaveOutlineSettings
var _rows: PackedStringArray
var _size: Vector2i
var _walls: PackedByteArray
## 칸 합계 (벽 수, 가로 size.x + 1개씩)
var _sums: PackedInt32Array
var _per: int
var _nodes: Vector2i
var _field: PackedFloat32Array
var _radius: int
## 칸마다 1 = 좁은 길목 보호 구역
var _zone: PackedByteArray = PackedByteArray()
## [칸 안 위치마다] 칸 차이 -radius~radius의 가중치
var _weights: Array[PackedFloat32Array] = []


func _init(rows: PackedStringArray, outline_settings: CaveOutlineSettings) -> void:
	_rows = rows
	settings = outline_settings
	_size = Vector2i(rows[0].length(), rows.size())
	_per = CELL_PX / settings.sample_px
	_nodes = _size * _per + Vector2i.ONE
	_read_walls()


func build() -> CaveOutlineData:
	_blur()
	_add_noise()
	_protect_narrow()
	_remove_specks()
	var data: CaveOutlineData = CaveOutlineData.new()
	data.settings = settings
	data.cell_count = _size
	data.cell_px = CELL_PX
	data.values = _encoded()
	data.cell_states = _cell_states(data.field_per_px() * settings.max_lean_px)
	data.loops = _simplified_loops()
	data.sight_cells = _sight_cells(data.sight_size())
	return data


## 격자 점의 값 (확인용)
func field_at(node: Vector2i) -> float:
	return _field[node.y * _nodes.x + node.x]


func is_rock(node: Vector2i) -> bool:
	return field_at(node) >= settings.threshold


func node_count() -> Vector2i:
	return _nodes


func is_wall_cell(x: int, y: int) -> bool:
	return x < 0 or y < 0 or x >= _size.x or y >= _size.y or _walls[y * _size.x + x] == 1


## 폭이 narrow_width_cells보다 좁은 바닥 칸인지: 그 칸을 덮는 narrow_width_cells 크기의 바닥 정사각형이 없다
func is_narrow_cell(x: int, y: int) -> bool:
	if is_wall_cell(x, y):
		return false
	var width: int = settings.narrow_width_cells
	for top: int in range(y - width + 1, y + 1):
		for left: int in range(x - width + 1, x + 1):
			if left >= 0 and top >= 0 and left + width <= _size.x and top + width <= _size.y and _wall_sum(left, top, left + width, top + width) == 0:
				return false
	return true


## 바위가 PNG 바닥을 덮는 가장 깊은 곳 (PNG의 벽에서 떨어진 거리, 픽셀). only_protected면 좁은 길목 보호 구역 안만 본다.
func deepest_cover_px(only_protected: bool = false) -> float:
	var deepest: float = 0.0
	var reach: int = ceili(settings.blur_sigma_px * BLUR_RANGE / CELL_PX) + 1
	for k: int in _nodes.y:
		for i: int in _nodes.x:
			if _field[k * _nodes.x + i] >= settings.threshold and (not only_protected or _node_in_zone(i, k, _zone)) and not _on_wall_cell(i, k):
				deepest = maxf(deepest, _wall_distance(i, k, reach))
	return deepest


## 메시가 쓰는 윤곽선(단순화함)이 입력 칸의 바닥 안으로 들어간 가장 깊은 곳 (입력 칸의 벽에서 떨어진 거리, 픽셀). only_protected면 좁은 길목 보호 구역 안만 본다.
func deepest_loop_cover_px(data: CaveOutlineData, only_protected: bool = false) -> float:
	var deepest: float = 0.0
	var reach: int = ceili(settings.blur_sigma_px * BLUR_RANGE / CELL_PX) + 1
	for loop: PackedVector2Array in data.loops:
		for point: Vector2 in loop:
			var cell: Vector2i = Vector2i((point / CELL_PX).floor())
			if is_wall_cell(cell.x, cell.y) or (only_protected and _zone[cell.y * _size.x + cell.x] == 0):
				continue
			var best: float = float(reach * CELL_PX)
			for cy: int in range(cell.y - reach, cell.y + reach + 1):
				for cx: int in range(cell.x - reach, cell.x + reach + 1):
					if is_wall_cell(cx, cy):
						var dx: float = maxf(maxf(cx * CELL_PX - point.x, 0.0), point.x - (cx + 1) * CELL_PX)
						var dy: float = maxf(maxf(cy * CELL_PX - point.y, 0.0), point.y - (cy + 1) * CELL_PX)
						best = minf(best, sqrt(dx * dx + dy * dy))
			deepest = maxf(deepest, best)
	return deepest


## 좁은 바닥 덩어리(양쪽 끝이 있는 곳)마다 지나갈 수 있는 가장 넓은 폭 (픽셀): {"cell": 덩어리의 첫 칸, "width": 폭}
func choke_widths() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for y: int in _size.y:
		for x: int in _size.x:
			if seen.has(Vector2i(x, y)) or not is_narrow_cell(x, y):
				continue
			var group: Array[Vector2i] = _flood_narrow(Vector2i(x, y), seen)
			var width: float = _bottleneck(group)
			if width >= 0.0:
				result.append({"cell": group[0], "width": width, "png_width": _bottleneck(group, true)})
	return result


func _read_walls() -> void:
	_walls.resize(_size.x * _size.y)
	for y: int in _size.y:
		var row: String = _rows[y]
		for x: int in _size.x:
			_walls[y * _size.x + x] = 1 if MapLayout.WALL_CHARS.contains(row[x]) else 0
	_sums.resize((_size.x + 1) * (_size.y + 1))
	_sums.fill(0)
	for y: int in _size.y:
		for x: int in _size.x:
			_sums[(y + 1) * (_size.x + 1) + x + 1] = _walls[y * _size.x + x] + _sums[y * (_size.x + 1) + x + 1] + _sums[(y + 1) * (_size.x + 1) + x] - _sums[y * (_size.x + 1) + x]


## 칸 사각형 안의 벽 수 (끝은 포함하지 않음, 맵 안이어야 한다)
func _wall_sum(x0: int, y0: int, x1: int, y1: int) -> int:
	var line: int = _size.x + 1
	return _sums[y1 * line + x1] - _sums[y0 * line + x1] - _sums[y1 * line + x0] + _sums[y0 * line + x0]


func _make_weights() -> void:
	_radius = ceili(settings.blur_sigma_px * BLUR_RANGE / CELL_PX) + 1
	_weights.clear()
	for phase: int in _per:
		var weights: PackedFloat32Array = PackedFloat32Array()
		weights.resize(_radius * 2 + 1)
		var total: float = 0.0
		for j: int in range(-_radius, _radius + 1):
			var sum: float = 0.0
			# 칸 안을 1픽셀씩 더한다 (칸 하나의 넓이만큼의 가우스).
			for t: int in CELL_PX:
				var distance: float = j * CELL_PX + t + 0.5 - phase * settings.sample_px
				sum += exp(-distance * distance / (2.0 * settings.blur_sigma_px * settings.blur_sigma_px))
			weights[j + _radius] = sum
			total += sum
		for j: int in weights.size():
			weights[j] /= total
		_weights.append(weights)


## 이 칸 둘레 흐리기 범위가 모두 벽이면 1, 모두 바닥이면 0, 섞였으면 -1
func _block_uniform(cx: int, cy: int) -> int:
	var margin: int = _radius + 1
	var x0: int = cx - margin
	var y0: int = cy - margin
	var x1: int = cx + margin + 1
	var y1: int = cy + margin + 1
	var inside: bool = x0 >= 0 and y0 >= 0 and x1 <= _size.x and y1 <= _size.y
	var cx0: int = clampi(x0, 0, _size.x)
	var cy0: int = clampi(y0, 0, _size.y)
	var cx1: int = clampi(x1, 0, _size.x)
	var cy1: int = clampi(y1, 0, _size.y)
	var walls: int = _wall_sum(cx0, cy0, cx1, cy1)
	if walls == (cx1 - cx0) * (cy1 - cy0):
		return 1
	return 0 if walls == 0 and inside else -1


func _blur() -> void:
	_make_weights()
	_field.resize(_nodes.x * _nodes.y)
	_field.fill(1.0)
	# 가로로 흐린 값: 칸 줄마다 격자 점 가로 수만큼
	var horizontal: PackedFloat32Array = PackedFloat32Array()
	horizontal.resize(_size.y * _nodes.x)
	for y: int in _size.y:
		var line: int = y * _size.x
		for i: int in _nodes.x:
			var cell: int = i / _per
			var weights: PackedFloat32Array = _weights[i % _per]
			var value: float = 0.0
			for j: int in range(-_radius, _radius + 1):
				var x: int = cell + j
				value += weights[j + _radius] * (1.0 if x < 0 or x >= _size.x else float(_walls[line + x]))
			horizontal[y * _nodes.x + i] = value
	for cy: int in _size.y + 1:
		for cx: int in _size.x + 1:
			var uniform: int = _block_uniform(cx, cy)
			if uniform == 1:
				continue
			var end_i: int = mini((cx + 1) * _per, _nodes.x)
			var end_k: int = mini((cy + 1) * _per, _nodes.y)
			for k: int in range(cy * _per, end_k):
				var weights: PackedFloat32Array = _weights[k % _per]
				var row_cell: int = k / _per
				for i: int in range(cx * _per, end_i):
					var value: float = 0.0
					if uniform == -1:
						for j: int in range(-_radius, _radius + 1):
							var y: int = row_cell + j
							value += weights[j + _radius] * (1.0 if y < 0 or y >= _size.y else horizontal[y * _nodes.x + i])
					_field[k * _nodes.x + i] = value


func _add_noise() -> void:
	var large: FastNoiseLite = make_noise(settings.noise_seed, settings.large_noise_px)
	var small: FastNoiseLite = make_noise(settings.noise_seed + 1, settings.small_noise_px)
	var band: float = settings.large_noise_strength + settings.small_noise_strength
	for k: int in _nodes.y:
		for i: int in _nodes.x:
			var index: int = k * _nodes.x + i
			var value: float = _field[index]
			if absf(value - settings.threshold) <= band:
				var x: float = i * settings.sample_px
				var y: float = k * settings.sample_px
				_field[index] = value + large.get_noise_2d(x, y) * settings.large_noise_strength + small.get_noise_2d(x, y) * settings.small_noise_strength


static func make_noise(noise_seed: int, feature_px: float) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise.seed = noise_seed
	noise.frequency = 1.0 / feature_px
	return noise


func _protect_narrow() -> void:
	var ring: int = settings.protect_ring_cells
	_zone.resize(_size.x * _size.y)
	_zone.fill(0)
	for y: int in _size.y:
		for x: int in _size.x:
			if not is_narrow_cell(x, y):
				continue
			for dy: int in range(maxi(y - ring, 0), mini(y + ring + 1, _size.y)):
				for dx: int in range(maxi(x - ring, 0), mini(x + ring + 1, _size.x)):
					_zone[dy * _size.x + dx] = 1
	var reach: int = ceili(settings.protect_guard_px / CELL_PX) + 1
	for k: int in _nodes.y:
		for i: int in _nodes.x:
			var index: int = k * _nodes.x + i
			if _node_in_zone(i, k, _zone):
				_field[index] -= settings.protect_field_bias
			if _field[index] >= settings.threshold and _node_in_zone(i, k, _zone) and _wall_distance(i, k, reach) > settings.protect_guard_px:
				_field[index] = settings.threshold - FLIP_MARGIN


## 칸 모서리의 점은 맞닿은 칸 모두에 든다.
func _node_in_zone(i: int, k: int, zone: PackedByteArray) -> bool:
	for cy: int in [(k - 1) / _per if k > 0 else 0, mini(k / _per, _size.y - 1)]:
		for cx: int in [(i - 1) / _per if i > 0 else 0, mini(i / _per, _size.x - 1)]:
			if zone[cy * _size.x + cx] == 1:
				return true
	return false


## 격자 점이 PNG 벽 칸 위(테두리 포함)인지
func _on_wall_cell(i: int, k: int) -> bool:
	return _wall_distance(i, k, 1) == 0.0


## 격자 점에서 가장 가까운 PNG 벽 칸까지 거리 (픽셀). reach칸 안에 벽이 없으면 reach칸 거리. 벽 칸 위면 0.
func _wall_distance(i: int, k: int, reach: int) -> float:
	var x: float = float(i * settings.sample_px)
	var y: float = float(k * settings.sample_px)
	var cell_x: int = i / _per
	var cell_y: int = k / _per
	var best: float = INF
	for cy: int in range(cell_y - reach, cell_y + reach + 1):
		for cx: int in range(cell_x - reach, cell_x + reach + 1):
			if not is_wall_cell(cx, cy):
				continue
			var dx: float = maxf(maxf(cx * CELL_PX - x, 0.0), x - (cx + 1) * CELL_PX)
			var dy: float = maxf(maxf(cy * CELL_PX - y, 0.0), y - (cy + 1) * CELL_PX)
			best = minf(best, sqrt(dx * dx + dy * dy))
	return best if best != INF else float(reach * CELL_PX)


func _remove_specks() -> void:
	var limit: int = roundi(settings.min_piece_px * settings.min_piece_px / (settings.sample_px * settings.sample_px))
	var checked: PackedInt32Array = PackedInt32Array()
	checked.resize(_field.size())
	checked.fill(-1)
	var stamp: int = 0
	var t: float = settings.threshold
	var neighbors: PackedInt32Array = PackedInt32Array([-1, 1, -_nodes.x, _nodes.x])
	for k: int in range(1, _nodes.y - 1):
		for i: int in range(1, _nodes.x - 1):
			var index: int = k * _nodes.x + i
			var rock: bool = _field[index] >= t
			# 경계에 닿은 점에서만 시작한다. 큰 덩어리는 limit을 넘는 순간 멈춘다.
			if checked[index] >= 0 or ((_field[index - 1] >= t) == rock and (_field[index + 1] >= t) == rock and (_field[index - _nodes.x] >= t) == rock and (_field[index + _nodes.x] >= t) == rock):
				continue
			stamp += 1
			var stack: Array[int] = [index]
			var piece: Array[int] = []
			var touches_border: bool = false
			checked[index] = stamp
			while not stack.is_empty() and piece.size() <= limit:
				var current: int = stack.pop_back()
				piece.append(current)
				var cx: int = current % _nodes.x
				var cy: int = current / _nodes.x
				if cx == 0 or cy == 0 or cx == _nodes.x - 1 or cy == _nodes.y - 1:
					touches_border = true
					continue
				for offset: int in neighbors:
					var next: int = current + offset
					if checked[next] != stamp and (_field[next] >= t) == rock:
						checked[next] = stamp
						stack.append(next)
			if stack.is_empty() and piece.size() < limit and not touches_border:
				var replacement: float = t + (-FLIP_MARGIN if rock else FLIP_MARGIN)
				for node: int in piece:
					_field[node] = replacement


func _encoded() -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(_field.size())
	for index: int in _field.size():
		bytes[index] = CaveOutlineData.encode(_field[index])
	return bytes


## 칸마다 상태. 벽 윗면이 안쪽으로 들어가는 만큼(lean_field)을 빼도 바위면 바위뿐이다.
func _cell_states(lean_field: float) -> PackedByteArray:
	var states: PackedByteArray = PackedByteArray()
	states.resize(_size.x * _size.y)
	for cy: int in _size.y:
		for cx: int in _size.x:
			var low: float = INF
			var high: float = -INF
			for k: int in range(cy * _per, (cy + 1) * _per + 1):
				for i: int in range(cx * _per, (cx + 1) * _per + 1):
					var value: float = _field[k * _nodes.x + i]
					low = minf(low, value)
					high = maxf(high, value)
			states[cy * _size.x + cx] = 2 if low - lean_field >= settings.threshold else (0 if high < settings.threshold else 1)
	return states


## 시야 판정용 작은 칸마다 1 = 가운데가 바위
func _sight_cells(size: Vector2i) -> PackedByteArray:
	var cells: PackedByteArray = PackedByteArray()
	cells.resize(size.x * size.y)
	var ratio: int = settings.sight_cell_px / settings.sample_px
	for y: int in size.y:
		for x: int in size.x:
			cells[y * size.x + x] = 1 if is_rock(Vector2i(x * ratio + ratio / 2, y * ratio + ratio / 2)) else 0
	return cells


## 마칭 스퀘어로 닫힌 윤곽선을 만들고 단순화한다.
func _simplified_loops() -> Array[PackedVector2Array]:
	var next: Dictionary = {}
	var positions: Dictionary = {}
	for k: int in _nodes.y - 1:
		for i: int in _nodes.x - 1:
			_add_segments(i, k, next, positions)
	var loops: Array[PackedVector2Array] = []
	while not next.is_empty():
		var current: Variant = next.keys()[0]
		var line: PackedVector2Array = PackedVector2Array()
		while next.has(current):
			line.append(positions[current])
			var following: Variant = next[current]
			next.erase(current)
			current = following
		loops.append(_simplify_closed(line))
	return loops


## 격자 칸 (i, k)의 윤곽 조각을 넣는다. 변의 번호로 끝점을 이어 닫힌 선을 찾는다.
func _add_segments(i: int, k: int, next: Dictionary, positions: Dictionary) -> void:
	var line: int = _nodes.x
	var a: float = _field[k * line + i]
	var b: float = _field[k * line + i + 1]
	var c: float = _field[(k + 1) * line + i + 1]
	var d: float = _field[(k + 1) * line + i]
	var t: float = settings.threshold
	var mask: int = (1 if a >= t else 0) | (2 if b >= t else 0) | (4 if c >= t else 0) | (8 if d >= t else 0)
	if mask == 0 or mask == 15:
		return
	for pair: Array in _segment_edges(mask, (a + b + c + d) * 0.25 >= t):
		var from: Vector2i = _edge_key(i, k, pair[0])
		var to: Vector2i = _edge_key(i, k, pair[1])
		positions[from] = _edge_point(i, k, pair[0], a, b, c, d)
		positions[to] = _edge_point(i, k, pair[1], a, b, c, d)
		next[from] = to


## 변 번호: 0 위, 1 오른쪽, 2 아래, 3 왼쪽. mask의 비트: 1 왼쪽 위, 2 오른쪽 위, 4 오른쪽 아래, 8 왼쪽 아래.
func _segment_edges(mask: int, center_rock: bool) -> Array:
	match mask:
		1: return [[3, 0]]
		2: return [[0, 1]]
		3: return [[3, 1]]
		4: return [[1, 2]]
		6: return [[0, 2]]
		7: return [[3, 2]]
		8: return [[2, 3]]
		9: return [[2, 0]]
		11: return [[2, 1]]
		12: return [[1, 3]]
		13: return [[1, 0]]
		14: return [[0, 3]]
		5: return [[3, 2], [1, 0]] if center_rock else [[3, 0], [1, 2]]
		10: return [[0, 3], [2, 1]] if center_rock else [[0, 1], [2, 3]]
	return []


func _edge_key(i: int, k: int, edge: int) -> Vector2i:
	match edge:
		0: return Vector2i(i * 2 + 1, k * 2)
		1: return Vector2i((i + 1) * 2, k * 2 + 1)
		2: return Vector2i(i * 2 + 1, (k + 1) * 2)
	return Vector2i(i * 2, k * 2 + 1)


func _edge_point(i: int, k: int, edge: int, a: float, b: float, c: float, d: float) -> Vector2:
	var t: float = settings.threshold
	var corner: Vector2 = Vector2(i, k)
	var point: Vector2
	match edge:
		0: point = corner + Vector2((t - a) / (b - a), 0.0)
		1: point = corner + Vector2(1.0, (t - b) / (c - b))
		2: point = corner + Vector2((t - d) / (c - d), 1.0)
		_: point = corner + Vector2(0.0, (t - a) / (d - a))
	return point * settings.sample_px


## 닫힌 선을 오차 안에서 줄인다 (더글러스-포이커, 가장 먼 두 점에서 나눠서).
func _simplify_closed(line: PackedVector2Array) -> PackedVector2Array:
	if line.size() < 4:
		return line
	var far: int = 0
	var far_distance: float = -1.0
	for index: int in line.size():
		var distance: float = line[0].distance_squared_to(line[index])
		if distance > far_distance:
			far_distance = distance
			far = index
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(line.size() + 1)
	keep.fill(0)
	keep[0] = 1
	keep[far] = 1
	var closed: PackedVector2Array = line.duplicate()
	closed.append(line[0])
	var stack: Array[Vector2i] = [Vector2i(0, far), Vector2i(far, line.size())]
	while not stack.is_empty():
		var span: Vector2i = stack.pop_back()
		var worst: int = -1
		var worst_distance: float = settings.simplify_px
		for index: int in range(span.x + 1, span.y):
			var distance: float = Geometry2D.get_closest_point_to_segment(closed[index], closed[span.x], closed[span.y]).distance_to(closed[index])
			if distance > worst_distance:
				worst_distance = distance
				worst = index
		if worst >= 0:
			keep[worst] = 1
			stack.append(Vector2i(span.x, worst))
			stack.append(Vector2i(worst, span.y))
	var result: PackedVector2Array = PackedVector2Array()
	for index: int in line.size():
		if keep[index] == 1:
			result.append(line[index])
	return result


func _flood_narrow(start: Vector2i, seen: Dictionary) -> Array[Vector2i]:
	var group: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start]
	seen[start] = true
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		group.append(cell)
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if not seen.has(next) and is_narrow_cell(next.x, next.y):
				seen[next] = true
				stack.append(next)
	return group


## 좁은 바닥 덩어리의 양쪽 끝 사이를 지나갈 수 있는 가장 넓은 폭 (픽셀). 끝이 둘 안 되면(구석 등) -1.
func _bottleneck(group: Array[Vector2i], png_only: bool = false) -> float:
	var low: Vector2i = group[0]
	var high: Vector2i = group[0]
	var in_group: Dictionary = {}
	for cell: Vector2i in group:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
		in_group[cell] = true
	var margin: int = 3
	var window: Rect2i = Rect2i(low - Vector2i.ONE * margin, high - low + Vector2i.ONE * (margin * 2 + 1)).intersection(Rect2i(Vector2i.ZERO, _size))
	var ends: Array[Dictionary] = _window_ends(window, in_group)
	# 끝이 작으면 지나가는 길이 아니라 막다른 오목한 곳이다.
	if ends.size() < 2 or ends[1].size() < MIN_END_CELLS:
		return -1.0
	var area: Rect2i = Rect2i(window.position * _per, window.size * _per + Vector2i.ONE)
	var distances: PackedFloat32Array = _chamfer(area, png_only)
	var best: float = 0.0
	var radius_low: float = 0.0
	var radius_high: float = float(CELL_PX * 3)
	for step: int in 12:
		var radius: float = (radius_low + radius_high) * 0.5
		if _connected(area, distances, radius, ends[0], ends[1]):
			best = radius
			radius_low = radius
		else:
			radius_high = radius
	return best * 2.0


## 창 안에서 좁은 칸을 뺀 바닥 칸을 이어진 덩어리로 나눈다. 칸이 많은 덩어리를 앞에 둔다.
func _window_ends(window: Rect2i, in_group: Dictionary) -> Array[Dictionary]:
	var seen: Dictionary = {}
	var ends: Array[Dictionary] = []
	for y: int in range(window.position.y, window.end.y):
		for x: int in range(window.position.x, window.end.x):
			var start: Vector2i = Vector2i(x, y)
			if seen.has(start) or in_group.has(start) or is_wall_cell(x, y):
				continue
			var cells: Dictionary = {}
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var cell: Vector2i = stack.pop_back()
				cells[cell] = true
				for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = cell + step
					if window.has_point(next) and not seen.has(next) and not in_group.has(next) and not is_wall_cell(next.x, next.y):
						seen[next] = true
						stack.append(next)
			ends.append(cells)
	ends.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.size() > b.size())
	return ends


## 창 안의 격자 점마다 가장 가까운 바위까지의 거리 (픽셀, 두 번 훑는 근사)
func _chamfer(area: Rect2i, png_only: bool = false) -> PackedFloat32Array:
	var distances: PackedFloat32Array = PackedFloat32Array()
	distances.resize(area.size.x * area.size.y)
	var diagonal: float = settings.sample_px * sqrt(2.0)
	var straight: float = float(settings.sample_px)
	var line: int = area.size.x
	for k: int in area.size.y:
		for i: int in line:
			var index: int = k * line + i
			var node: Vector2i = area.position + Vector2i(i, k)
			var value: float = 0.0 if (_on_wall_cell(node.x, node.y) if png_only else is_rock(node)) else 1.0e6
			if i > 0:
				value = minf(value, distances[index - 1] + straight)
			if k > 0:
				value = minf(value, distances[index - line] + straight)
				if i > 0:
					value = minf(value, distances[index - line - 1] + diagonal)
				if i < line - 1:
					value = minf(value, distances[index - line + 1] + diagonal)
			distances[index] = value
	for k: int in range(area.size.y - 1, -1, -1):
		for i: int in range(line - 1, -1, -1):
			var index: int = k * line + i
			var value: float = distances[index]
			if i < line - 1:
				value = minf(value, distances[index + 1] + straight)
			if k < area.size.y - 1:
				value = minf(value, distances[index + line] + straight)
				if i < line - 1:
					value = minf(value, distances[index + line + 1] + diagonal)
				if i > 0:
					value = minf(value, distances[index + line - 1] + diagonal)
			distances[index] = value
	return distances


## 바위에서 radius 넘게 떨어진 점만 밟아 from 덩어리에서 to 덩어리로 갈 수 있는지
func _connected(area: Rect2i, distances: PackedFloat32Array, radius: float, from: Dictionary, to: Dictionary) -> bool:
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(distances.size())
	seen.fill(0)
	var stack: Array[int] = []
	var line: int = area.size.x
	for k: int in area.size.y:
		for i: int in line:
			var index: int = k * line + i
			if distances[index] >= radius and from.has((area.position + Vector2i(i, k)) / _per):
				seen[index] = 1
				stack.append(index)
	while not stack.is_empty():
		var current: int = stack.pop_back()
		var i: int = current % line
		var k: int = current / line
		if to.has((area.position + Vector2i(i, k)) / _per):
			return true
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nx: int = i + step.x
			var ny: int = k + step.y
			if nx < 0 or ny < 0 or nx >= line or ny >= area.size.y:
				continue
			var next: int = ny * line + nx
			if seen[next] == 0 and distances[next] >= radius:
				seen[next] = 1
				stack.append(next)
	return false
