class_name ChokeFinder
extends RefCounted
## 맵 칸 배치(벽 글자는 쓰는 쪽이 넘겨준다. 맵 PNG는 MapLayout.WALL_CHARS)에서 좁은 길목을 찾아 ChokeData로 만든다. 노드에 의존하지 않는다. 지형을 구울 때 쓴다.
## - 길목 칸: 바닥 칸 중 3×3 바닥 덩어리에 들지 못하는 칸 (폭 2칸 이하, map_stats.gd와 같은 정의). 4방향으로 이어진 것을 한 길목으로 묶는다
## - 입구: 길목 칸에 맞닿은(4방향) 길목이 아닌 바닥 칸들을 8방향으로 묶은 덩어리. 입구가 둘 이상인 길목만 남긴다 (막다른 틈은 길목이 아니다)
## - 대기 자리: 입구 가운데에서 길목 바깥쪽으로 wait_distance칸 나간 곳을 가운데로, 옆으로 wait_spacing칸 간격 wait_count자리.
##   자리가 벽이나 길목이면 wait_search칸 안에서 가장 가까운 넓은 바닥 칸 가운데로 옮기고, 없으면 그 자리는 뺀다
## - 우회 비율: 입구 두 개마다 A*(GridPath)로 잰 "길목을 막은 길 ÷ 길목을 지나는 최단 길". 돌아갈 길이 없으면 -1
## 값은 굽는 쪽이 윤곽 값(CaveOutlineSettings의 "길목" 묶음)에서 넣는다 (from_settings). 아래 기본값은 단위 테스트용이다 (사용자 결정 2026-11-14, 임시값).

## 입구마다 대기 자리 수와 입구에서 떨어뜨리는 거리 (칸, 임시값)
var wait_count: int = 3
var wait_distance: float = 2.0
## 대기 자리끼리 옆 간격과, 자리가 막혔을 때 옮겨 찾는 거리 (칸, 임시값)
var wait_spacing: float = 1.0
var wait_search: int = 2

var _rows: PackedStringArray
var _size: Vector2i
var _cell_px: float
var _wall_chars: String


## 윤곽 값(CaveOutlineSettings)의 "길목" 묶음으로 만든다.
static func from_settings(settings: CaveOutlineSettings) -> ChokeFinder:
	var finder: ChokeFinder = ChokeFinder.new()
	finder.wait_count = settings.choke_wait_count
	finder.wait_distance = settings.choke_wait_distance
	finder.wait_spacing = settings.choke_wait_spacing
	finder.wait_search = settings.choke_wait_search
	return finder


## rows: 칸 글자 줄, cell_px: 칸 한 변 (픽셀), wall_chars: 벽으로 보는 글자들
func find(rows: PackedStringArray, cell_px: float, wall_chars: String) -> Array[ChokeData]:
	_wall_chars = wall_chars
	_rows = rows
	_cell_px = cell_px
	_size = Vector2i(0, rows.size())
	for line: String in rows:
		_size.x = maxi(_size.x, line.length())
	var narrow: Dictionary = {}
	for y: int in _size.y:
		for x: int in _size.x:
			var cell: Vector2i = Vector2i(x, y)
			if is_floor(cell) and not _in_wide_block(cell):
				narrow[cell] = true
	var grid: GridPath = _make_grid()
	var result: Array[ChokeData] = []
	var seen: Dictionary = {}
	for start: Variant in narrow.keys():
		if seen.has(start):
			continue
		var group: Array[Vector2i] = _flood(start, narrow, seen)
		var clusters: Array[Array] = _entrance_clusters(group, narrow)
		if clusters.size() < 2:
			continue
		result.append(_make_choke(group, clusters, narrow, grid))
	return result


func is_floor(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= _rows.size() or cell.x < 0 or cell.x >= _rows[cell.y].length():
		return false
	return not _wall_chars.contains(_rows[cell.y][cell.x])


func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_px


## cell을 덮는 3×3 바닥 덩어리가 있는지
func _in_wide_block(cell: Vector2i) -> bool:
	for oy: int in 3:
		for ox: int in 3:
			var corner: Vector2i = cell - Vector2i(ox, oy)
			var all_floor: bool = true
			for dy: int in 3:
				for dx: int in 3:
					if not is_floor(corner + Vector2i(dx, dy)):
						all_floor = false
						break
				if not all_floor:
					break
			if all_floor:
				return true
	return false


## start에서 4방향으로 이어진 길목 칸들
func _flood(start: Vector2i, narrow: Dictionary, seen: Dictionary) -> Array[Vector2i]:
	var group: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start]
	seen[start] = true
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		group.append(cell)
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if narrow.has(next) and not seen.has(next):
				seen[next] = true
				stack.append(next)
	return group


## 길목에 맞닿은 넓은 바닥 칸들을 8방향으로 이어진 덩어리로 묶는다
func _entrance_clusters(group: Array[Vector2i], narrow: Dictionary) -> Array[Array]:
	var touching: Dictionary = {}
	for cell: Vector2i in group:
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if is_floor(next) and not narrow.has(next):
				touching[next] = true
	var clusters: Array[Array] = []
	var seen: Dictionary = {}
	for start: Variant in touching.keys():
		if seen.has(start):
			continue
		var cluster: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start]
		seen[start] = true
		while not stack.is_empty():
			var cell: Vector2i = stack.pop_back()
			cluster.append(cell)
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var next: Vector2i = cell + Vector2i(dx, dy)
					if touching.has(next) and not seen.has(next):
						seen[next] = true
						stack.append(next)
		clusters.append(cluster)
	return clusters


func _make_choke(group: Array[Vector2i], clusters: Array[Array], narrow: Dictionary, grid: GridPath) -> ChokeData:
	var choke: ChokeData = ChokeData.new()
	var group_set: Dictionary = {}
	for cell: Vector2i in group:
		choke.cells.append(Vector2(cell))
		group_set[cell] = true
	# A*는 입구 가운데에 가장 가까운 입구 칸에서 잰다 (꺾인 입구의 가운데는 벽일 수 있다).
	var anchors: PackedVector2Array = PackedVector2Array()
	for cluster: Array in clusters:
		var center: Vector2 = Vector2.ZERO
		var inner: Vector2 = Vector2.ZERO
		var inner_count: int = 0
		for cell: Vector2i in cluster:
			center += cell_center(cell)
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if group_set.has(cell + offset):
					inner += cell_center(cell + offset)
					inner_count += 1
		center /= cluster.size()
		inner /= maxi(inner_count, 1)
		var anchor: Vector2 = cell_center(cluster[0])
		for cell: Vector2i in cluster:
			if cell_center(cell).distance_squared_to(center) < anchor.distance_squared_to(center):
				anchor = cell_center(cell)
		anchors.append(anchor)
		choke.entrances.append(center)
		choke.wait_spots.append(_wait_spots(center, inner.direction_to(center), narrow))
	# 우회 비율: 길목을 지나는 최단 길과, 길목 칸을 잠깐 막고 잰 길
	var through: PackedFloat32Array = PackedFloat32Array()
	for i: int in choke.entrances.size():
		for j: int in range(i + 1, choke.entrances.size()):
			through.append(_path_length(grid, anchors[i], anchors[j]))
	for cell: Vector2i in group:
		grid.set_solid(cell, true)
	var k: int = 0
	for i: int in choke.entrances.size():
		for j: int in range(i + 1, choke.entrances.size()):
			var blocked: float = _path_length(grid, anchors[i], anchors[j])
			choke.detour_ratios.append(blocked / through[k] if blocked > 0.0 and through[k] > 0.0 else -1.0)
			k += 1
	for cell: Vector2i in group:
		grid.set_solid(cell, false)
	return choke


## 입구 가운데에서 바깥쪽(outward)으로 wait_distance칸 나간 곳을 가운데로 옆으로 늘어선 자리들
func _wait_spots(entrance: Vector2, outward: Vector2, narrow: Dictionary) -> PackedVector2Array:
	var spots: PackedVector2Array = PackedVector2Array()
	var side: Vector2 = outward.orthogonal()
	var base: Vector2 = entrance + outward * wait_distance * _cell_px
	for i: int in wait_count:
		var wanted: Vector2 = base + side * (i - (wait_count - 1) / 2.0) * wait_spacing * _cell_px
		var spot: Vector2 = _nearest_wide_floor(wanted, narrow)
		if spot != Vector2.INF and not spots.has(spot):
			spots.append(spot)
	return spots


## point에서 가장 가까운 넓은 바닥(벽도 길목도 아닌) 칸 가운데. point의 칸이 그런 칸이면 point 그대로. wait_search칸 안에 없으면 INF
func _nearest_wide_floor(point: Vector2, narrow: Dictionary) -> Vector2:
	var cell: Vector2i = Vector2i((point / _cell_px).floor())
	if is_floor(cell) and not narrow.has(cell):
		return point
	var best: Vector2 = Vector2.INF
	for dy: int in range(-wait_search, wait_search + 1):
		for dx: int in range(-wait_search, wait_search + 1):
			var next: Vector2i = cell + Vector2i(dx, dy)
			if is_floor(next) and not narrow.has(next):
				var center: Vector2 = cell_center(next)
				if best == Vector2.INF or center.distance_squared_to(point) < best.distance_squared_to(point):
					best = center
	return best


## 벽 칸을 막은 A* 격자 (칸 하나 = 맵 칸 하나)
func _make_grid() -> GridPath:
	var grid: GridPath = GridPath.new(Rect2(Vector2.ZERO, Vector2(_size) * _cell_px), _cell_px)
	grid.nearest_search_cells = 0
	for y: int in _size.y:
		var run_start: int = -1
		for x: int in _size.x:
			var wall: bool = not is_floor(Vector2i(x, y))
			if wall and run_start < 0:
				run_start = x
			elif not wall and run_start >= 0:
				grid.fill_solid_run(y, run_start, x)
				run_start = -1
		if run_start >= 0:
			grid.fill_solid_run(y, run_start, _size.x)
	return grid


## from에서 to까지 길의 길이. 닿지 못하면(막혀서 가장 가까운 곳까지만 가면) -1
func _path_length(grid: GridPath, from: Vector2, to: Vector2) -> float:
	var path: PackedVector2Array = grid.find_path(from, to)
	if path.is_empty() or grid.world_to_cell(path[path.size() - 1]) != grid.world_to_cell(to):
		return -1.0
	var length: float = 0.0
	for i: int in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length
