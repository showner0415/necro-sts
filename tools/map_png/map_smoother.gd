class_name MapSmoother
extends RefCounted
## 맵 배치(MapLayout)의 벽 가장자리를 동굴처럼 울퉁불퉁하게 다듬는다. 노드에 의존하지 않는다.
## PNG의 반듯한 칸 경계(직선 통로, 네모난 굴)를 그대로 두지 않고, 경계 칸을 조금씩 깎거나(벽 → 바닥) 메운다(바닥 → 벽).
## 같은 PNG·같은 seed면 결과가 늘 같다. 칸마다 위치로 정한 난수를 쓰므로 PNG 한 곳을 고쳐도 먼 곳의 결과는 그대로다.
##
## 지키는 것 (어기는 변경은 하지 않는다):
## - 보호 칸은 바꾸지 않는다: 좁은 곳(3×3 바닥 덩어리에 들지 못하는 바닥 칸 = 너비 2 이하인 곳)과 그 옆의 벽,
##   굴 중심(굴 가운데에서 ROOM_CORE_RADIUS칸 안), 물건(몬스터·상자·탈출·도착 지점) 칸과 그 둘레, 막아 둔 길목과 그 둘레, 맵 테두리
## - 바닥 칸은 모두 2×2 바닥 덩어리에 든다 (이동하는 길은 최소 2칸). 원래 3칸 이상 넓던 곳은 3×3 덩어리에 남는다 (넓은 통로가 좁은 길목이 되지 않게)
## - 메워도 바닥이 끊기지 않는다. 깎는 칸 둘레의 바닥은 모두 원래 같은 덩어리(같은 굴 또는 같은 통로)여야 한다:
##   굴과 통로, 통로와 통로가 새로 이어지지 않으니 입구가 합쳐지거나 지름길이 생기지 않는다
## - 원래 경계에서 깎는 깊이는 MAX_CARVE_DEPTH칸, 메우는 깊이는 MAX_FILL_DEPTH칸까지

## 기본 난수 씨앗 (tools/map_from_png.gd가 쓰고, 시나리오가 같은 결과인지 확인할 때 쓴다). 바꾸면 다른 모양으로 다듬어진다.
const DEFAULT_SEED: int = 1
## 경계 칸을 무작위로 바꾸는 횟수와 확률
const NOISE_PASSES: int = 2
const CARVE_CHANCE: float = 0.35
const FILL_CHANCE: float = 0.3
## 굴 가운데에서 이 거리(칸) 안은 바꾸지 않는다
const ROOM_CORE_RADIUS: float = 3.0
## 원래 바닥에서 이 거리(칸, 8방향) 안의 벽만 깎는다
const MAX_CARVE_DEPTH: int = 2
## 원래 벽에서 이 거리(칸, 8방향) 안의 바닥만 메운다
const MAX_FILL_DEPTH: int = 1
## 깎을 칸 둘레의 바닥끼리 이 걸음 수 안에 이어져 있어야 깎는다 (멀리 돌아가야 닿는 바닥이면 지름길이 생긴다)
const SHORTCUT_STEPS: int = 6
## 마지막 정리: 둘레 8칸 중 이만큼 이상이 바닥인 벽은 깎고, 벽인 바닥은 메운다 (튀어나온 한 칸·패인 한 칸 정리)
const CLEAN_NEIGHBORS: int = 6

const NEIGHBORS_4: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var _size: Vector2i
## 지금 칸 글자 (줄마다 Array[String])
var _grid: Array[Array] = []
var _protected: Dictionary = {}
## 원래 3×3 바닥 덩어리에 들던 바닥 칸
var _wide: Dictionary = {}
var _carve_depth: Dictionary = {}
var _fill_depth: Dictionary = {}
## 바닥 칸마다 원래 속한 덩어리 (MapLayout.segment_at). 깎은 칸은 이웃의 덩어리를 받는다.
var _segment: Dictionary = {}
var _seed: int


## layout을 다듬은 줄들. layout은 바꾸지 않는다.
static func smooth(layout: MapLayout, seed_value: int) -> PackedStringArray:
	var smoother: MapSmoother = MapSmoother.new()
	return smoother._run(layout, seed_value)


## rows의 바닥 칸이 모두 2×2 바닥 덩어리에 드는지 (이동하는 길이 최소 2칸인지). 어긋난 칸들을 돌려준다.
static func narrow_cells(rows: PackedStringArray) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in rows.size():
		for x: int in rows[y].length():
			if not _is_floor_char(rows, Vector2i(x, y)):
				continue
			if not _in_block_rows(rows, Vector2i(x, y), 2):
				result.append(Vector2i(x, y))
	return result


## rows에서 start로부터 4방향으로 걸어서 닿는 바닥 칸들
static func reachable(rows: PackedStringArray, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		for offset: Vector2i in NEIGHBORS_4:
			var n: Vector2i = cell + offset
			if not seen.has(n) and _is_floor_char(rows, n):
				seen[n] = true
				stack.append(n)
	return seen


static func _is_floor_char(rows: PackedStringArray, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= rows[cell.y].length():
		return false
	return not MapLayout.WALL_CHARS.contains(rows[cell.y][cell.x])


static func _in_block_rows(rows: PackedStringArray, cell: Vector2i, block: int) -> bool:
	for oy: int in block:
		for ox: int in block:
			var corner: Vector2i = cell - Vector2i(ox, oy)
			var all_floor: bool = true
			for by: int in block:
				for bx: int in block:
					if not _is_floor_char(rows, corner + Vector2i(bx, by)):
						all_floor = false
						break
				if not all_floor:
					break
			if all_floor:
				return true
	return false


func _run(layout: MapLayout, seed_value: int) -> PackedStringArray:
	_seed = seed_value
	_size = layout.size
	for row: String in layout.rows:
		var line: Array[String] = []
		for i: int in row.length():
			line.append(row[i])
		_grid.append(line)
	_prepare(layout)
	for pass_index: int in NOISE_PASSES:
		for y: int in range(1, _size.y - 1):
			for x: int in range(1, _size.x - 1):
				var cell: Vector2i = Vector2i(x, y)
				if _protected.has(cell):
					continue
				var roll: float = _random(cell, pass_index)
				if _is_floor(cell):
					if roll < FILL_CHANCE:
						_try_fill(cell)
				elif roll < CARVE_CHANCE:
					_try_carve(cell)
	# 정리: 튀어나온 벽 한 칸, 패인 바닥 한 칸
	for y: int in range(1, _size.y - 1):
		for x: int in range(1, _size.x - 1):
			var cell: Vector2i = Vector2i(x, y)
			if _protected.has(cell):
				continue
			var floors: int = _count_floor_8(cell)
			if not _is_floor(cell) and floors >= CLEAN_NEIGHBORS:
				_try_carve(cell)
			elif _is_floor(cell) and 8 - floors >= CLEAN_NEIGHBORS:
				_try_fill(cell)
	var result: PackedStringArray = []
	for line: Array in _grid:
		result.append("".join(PackedStringArray(line)))
	return result


func _prepare(layout: MapLayout) -> void:
	# 원래 경계에서의 거리 (8방향, 깊이 제한까지만)
	for y: int in _size.y:
		for x: int in _size.x:
			var cell: Vector2i = Vector2i(x, y)
			if x == 0 or y == 0 or x == _size.x - 1 or y == _size.y - 1:
				_protected[cell] = true
			var c: String = _grid[y][x]
			if c == "x":
				_protect_around(cell, 1)
			if _is_floor(cell):
				_segment[cell] = layout.segment_at(cell)
				if _in_block(cell, 3):
					_wide[cell] = true
				else:
					# 좁은 곳(너비 2 이하)과 그 옆 벽은 그대로 둔다.
					_protect_around(cell, 1)
				var wall_distance: int = _nearest_distance(cell, false, MAX_FILL_DEPTH)
				if wall_distance >= 0:
					_fill_depth[cell] = true
			else:
				var floor_distance: int = _nearest_distance(cell, true, MAX_CARVE_DEPTH)
				if floor_distance >= 0:
					_carve_depth[cell] = true
	for o: Dictionary in layout.objects:
		_protect_around(o.cell, 1)
	# 굴 안의 바위·기둥은 깎지 않는다 (둘레를 메우는 것은 너비 규칙 안에서 된다).
	for rock: Dictionary in layout.rocks:
		for cell: Vector2i in rock.cells:
			_protected[cell] = true
	for room: Dictionary in layout.rooms:
		var center: Vector2 = room.center
		var r: int = ceili(ROOM_CORE_RADIUS)
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				var cell: Vector2i = Vector2i(roundi(center.x) + dx, roundi(center.y) + dy)
				if Vector2(cell).distance_to(center) <= ROOM_CORE_RADIUS:
					_protected[cell] = true


func _protect_around(cell: Vector2i, radius: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			_protected[cell + Vector2i(dx, dy)] = true


## cell에서 limit칸(8방향) 안에 바닥(want_floor=true) 또는 벽이 있으면 그 거리, 없으면 -1
func _nearest_distance(cell: Vector2i, want_floor: bool, limit: int) -> int:
	for d: int in range(1, limit + 1):
		for dy: int in range(-d, d + 1):
			for dx: int in range(-d, d + 1):
				if maxi(absi(dx), absi(dy)) != d:
					continue
				var n: Vector2i = cell + Vector2i(dx, dy)
				if _inside(n) and _is_floor(n) == want_floor:
					return d
	return -1


func _random(cell: Vector2i, pass_index: int) -> float:
	return float(absi(hash([cell.x, cell.y, pass_index, _seed])) % 10007) / 10007.0


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y


func _is_floor(cell: Vector2i) -> bool:
	return _inside(cell) and not MapLayout.WALL_CHARS.contains(_grid[cell.y][cell.x])


func _count_floor_8(cell: Vector2i) -> int:
	var count: int = 0
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if (dx != 0 or dy != 0) and _is_floor(cell + Vector2i(dx, dy)):
				count += 1
	return count


func _in_block(cell: Vector2i, block: int) -> bool:
	for oy: int in block:
		for ox: int in block:
			var corner: Vector2i = cell - Vector2i(ox, oy)
			var all_floor: bool = true
			for by: int in block:
				for bx: int in block:
					if not _is_floor(corner + Vector2i(bx, by)):
						all_floor = false
						break
				if not all_floor:
					break
			if all_floor:
				return true
	return false


## 바닥 칸을 벽으로 메운다. 둘레 바닥이 2칸(원래 넓던 곳은 3칸) 너비를 잃거나 끊기면 되돌린다.
func _try_fill(cell: Vector2i) -> void:
	if not _fill_depth.has(cell):
		return
	var floor_neighbors: Array[Vector2i] = []
	for offset: Vector2i in NEIGHBORS_4:
		if _is_floor(cell + offset):
			floor_neighbors.append(cell + offset)
	if floor_neighbors.size() == 4:
		return
	var old: String = _grid[cell.y][cell.x]
	_grid[cell.y][cell.x] = "#"
	if not _widths_ok(cell) or not _connected(floor_neighbors, 2 + SHORTCUT_STEPS):
		_grid[cell.y][cell.x] = old
		return


## 벽 칸을 바닥으로 깎는다. 새 칸이 2×2 바닥에 들지 못하거나, 떨어져 있던 바닥이 이어지면 되돌린다.
func _try_carve(cell: Vector2i) -> void:
	if not _carve_depth.has(cell):
		return
	var counts: Dictionary = {}
	var floor_neighbors: Array[Vector2i] = []
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var n: Vector2i = cell + Vector2i(dx, dy)
			if (dx != 0 or dy != 0) and _is_floor(n):
				floor_neighbors.append(n)
				if absi(dx) + absi(dy) == 1:
					var c: String = _grid[n.y][n.x]
					counts[c] = counts.get(c, 0) + 1
	if counts.is_empty():
		return
	# 둘레 바닥이 모두 같은 덩어리(같은 굴 또는 같은 통로)여야 깎는다. 굴과 통로, 통로와 통로를 이으면
	# 입구가 합쳐지거나 지름길이 생긴다.
	var segment: String = _segment.get(floor_neighbors[0], "")
	for n: Vector2i in floor_neighbors:
		if _segment.get(n, "") != segment:
			return
	# 같은 덩어리라도 둘레 바닥끼리 가까운 걸음으로 이어져 있어야 한다 (덩어리가 휘어 벽을 사이에 두고 마주 볼 때).
	if not _connected(floor_neighbors, SHORTCUT_STEPS):
		return
	var best: String = counts.keys()[0]
	for c: String in counts:
		if counts[c] > counts[best]:
			best = c
	_grid[cell.y][cell.x] = best
	if not _in_block(cell, 2):
		_grid[cell.y][cell.x] = "#"
		return
	_segment[cell] = segment


## cell 둘레(5×5)의 바닥 칸이 너비를 지키는지: 모두 2×2 덩어리에, 원래 넓던 칸은 3×3 덩어리에 든다.
func _widths_ok(cell: Vector2i) -> bool:
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var n: Vector2i = cell + Vector2i(dx, dy)
			if not _is_floor(n):
				continue
			if not _in_block(n, 3 if _wide.has(n) else 2):
				return false
	return true


## cells(바닥 칸들)가 서로 max_steps 걸음(4방향) 안에 모두 닿는지
func _connected(cells: Array[Vector2i], max_steps: int) -> bool:
	if cells.size() <= 1:
		return true
	var start: Vector2i = cells[0]
	var distance: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if distance[current] >= max_steps:
			continue
		for offset: Vector2i in NEIGHBORS_4:
			var n: Vector2i = current + offset
			if not distance.has(n) and _is_floor(n):
				distance[n] = distance[current] + 1
				queue.append(n)
	for c: Vector2i in cells:
		if not distance.has(c):
			return false
	return true
