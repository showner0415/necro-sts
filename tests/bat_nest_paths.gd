extends RefCounted
## 얕은 굴 박쥐 둥지에서, 박쥐가 처음 자리에서 감지하는 칸과 둥지를 지나가는 길을 잰다.
## scenario_shallow_cave.gd(확인)와 tests/balance/run_map_route.gd(몰래 가는 길을 걷는 봇)가 같이 쓴다.
## - 감지하는 칸: 칸 가운데가 어느 박쥐의 처음 자리(PNG의 박쥐 칸 가운데)에서 감지 범위 안이고, 벽이 둘 사이를 가리지 않는 칸 (NavigationGrid.can_see).
##   박쥐는 배회하므로 처음 자리 기준이다
## - 입구: 둥지와 from 굴을 잇는 통로에 닿은 둥지 칸들. 출구: 둥지와 to 굴을 잇는 통로에 닿은 둥지 칸들
## - 기본 길: 입구에서 출구까지 둥지 바닥을 지나는 가장 짧은 길 (8방향, 대각선은 양옆이 바닥일 때만)
## - 몰래 가는 길: 감지 범위보다 sneak_margin만큼 넓게 잡은 칸(벽이 가리지 않는 칸)을 밟지 않는 가장 짧은 길. 박쥐가 배회해 옮겨 가도 걸리지 않게 여유를 둔다

const TILE: float = 32.0
const DIAGONAL: float = 1.4142135
const NEIGHBORS_4: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const NEIGHBORS_8: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## rows: 칸 글자 (윤곽이 있는 지역은 tests/outline_rows.gd의 실제 바닥), objects: PNG의 물건 목록, from_cell·to_cell: 둥지 양쪽 굴의 아무 칸.
## 돌려주는 것: {"detected": {칸: true}, "watched": {칸: true} (감지 범위 + sneak_margin), "entrance": [칸], "exit": [칸],
##   "default_path": [칸], "default_length": 칸 수, "first_detect": 기본 길에서 처음 감지하는 칸까지 걸은 칸 수 (감지하지 않으면 -1),
##   "sneak_path": [칸] (없으면 빈 배열), "sneak_length": 칸 수 (없으면 -1)}
static func measure(rows: PackedStringArray, objects: Array[Dictionary], nav: NavigationGrid, detect_range: float, from_cell: Vector2i, to_cell: Vector2i, sneak_margin: float = 0.0) -> Dictionary:
	var layout: MapLayout = MapLayout.from_rows(rows, objects)
	var nest: int = layout.room_at(layout.cells_of("bat")[0])
	var bats: Array[Vector2] = []
	# 박쥐 둥지의 무리만 본다 (다른 굴의 무리는 이 길과 상관없다).
	for cell: Vector2i in layout.cells_of("bat"):
		if layout.room_at(cell) == nest:
			bats.append(_center(cell))
	var entrance: Array[Vector2i] = doorway(layout, nest, layout.room_at(from_cell))
	var exit: Array[Vector2i] = doorway(layout, nest, layout.room_at(to_cell))
	var detected: Dictionary = _seen_cells(layout, nest, nav, bats, detect_range)
	var watched: Dictionary = _seen_cells(layout, nest, nav, bats, detect_range + sneak_margin)
	var result: Dictionary = {"detected": detected, "watched": watched, "entrance": entrance, "exit": exit}
	var default_path: Array[Vector2i] = _shortest(layout, nest, entrance, exit, {})
	result["default_path"] = default_path
	result["default_length"] = path_length(default_path)
	result["first_detect"] = -1.0
	for i: int in default_path.size():
		if detected.has(default_path[i]):
			result["first_detect"] = path_length(default_path.slice(0, i + 1))
			break
	var sneak_path: Array[Vector2i] = _shortest(layout, nest, entrance, exit, watched)
	result["sneak_path"] = sneak_path
	result["sneak_length"] = path_length(sneak_path) if not sneak_path.is_empty() else -1.0
	return result


## 길의 길이 (칸 수, 대각선은 √2)
static func path_length(path: Array[Vector2i]) -> float:
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += Vector2(path[i] - path[i - 1]).length()
	return total


## 봇이 따라 걸을 점들 (월드 좌표): 방향이 바뀌는 칸과 every칸마다, 그리고 끝 칸
static func waypoints(path: Array[Vector2i], every: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i: int in path.size():
		var last: bool = i == path.size() - 1
		var turn: bool = i > 0 and not last and path[i] - path[i - 1] != path[i + 1] - path[i]
		if last or turn or i % every == 0:
			points.append(_center(path[i]))
	return points


## 굴 room의 칸 중, 칸 가운데가 어느 박쥐에게서 reach 안이고 벽이 가리지 않는 칸
static func _seen_cells(layout: MapLayout, room: int, nav: NavigationGrid, bats: Array[Vector2], reach: float) -> Dictionary:
	var seen: Dictionary = {}
	for y: int in layout.size.y:
		for x: int in layout.size.x:
			var cell: Vector2i = Vector2i(x, y)
			if layout.room_at(cell) != room:
				continue
			var point: Vector2 = _center(cell)
			for bat: Vector2 in bats:
				if bat.distance_to(point) <= reach and nav.can_see(bat, point):
					seen[cell] = true
					break
	return seen


static func _center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## 굴 a와 굴 b를 잇는 통로에 닿은, 굴 a의 칸들 (MapLayout의 굴 번호). 박쥐 둥지 말고 다른 굴의 입구를 찾을 때도 쓴다
static func doorway(layout: MapLayout, a: int, b: int) -> Array[Vector2i]:
	# 통로 덩어리마다 닿은 굴들
	var touches: Dictionary = {}
	for y: int in layout.size.y:
		for x: int in layout.size.x:
			var segment: String = layout.segment_at(Vector2i(x, y))
			if not segment.begins_with("p"):
				continue
			for offset: Vector2i in NEIGHBORS_4:
				var room: int = layout.room_at(Vector2i(x, y) + offset)
				if room >= 0:
					if not touches.has(segment):
						touches[segment] = {}
					touches[segment][room] = true
	var cells: Array[Vector2i] = []
	for y: int in layout.size.y:
		for x: int in layout.size.x:
			var cell: Vector2i = Vector2i(x, y)
			if layout.room_at(cell) != a:
				continue
			for offset: Vector2i in NEIGHBORS_4:
				var segment: String = layout.segment_at(cell + offset)
				if segment.begins_with("p") and touches[segment].has(a) and touches[segment].has(b):
					cells.append(cell)
					break
	return cells


## 굴 room 안에서 starts 중 한 칸에서 goals 중 한 칸까지 가장 짧은 길. avoid의 칸은 밟지 않는다. 없으면 빈 배열.
static func _shortest(layout: MapLayout, room: int, starts: Array[Vector2i], goals: Array[Vector2i], avoid: Dictionary) -> Array[Vector2i]:
	var cost: Dictionary = {}
	var previous: Dictionary = {}
	var open: Array[Vector2i] = []
	for cell: Vector2i in starts:
		if not avoid.has(cell):
			cost[cell] = 0.0
			open.append(cell)
	var done: Dictionary = {}
	while not open.is_empty():
		var best: int = 0
		for i: int in open.size():
			if cost[open[i]] < cost[open[best]]:
				best = i
		var cell: Vector2i = open[best]
		open.remove_at(best)
		if done.has(cell):
			continue
		done[cell] = true
		if goals.has(cell):
			var path: Array[Vector2i] = [cell]
			while previous.has(path[0]):
				path.push_front(previous[path[0]])
			return path
		for offset: Vector2i in NEIGHBORS_8:
			var next: Vector2i = cell + offset
			if layout.room_at(next) != room or avoid.has(next) or done.has(next):
				continue
			if offset.x != 0 and offset.y != 0 and (layout.is_wall(cell + Vector2i(offset.x, 0)) or layout.is_wall(cell + Vector2i(0, offset.y))):
				continue
			var next_cost: float = cost[cell] + (DIAGONAL if offset.x != 0 and offset.y != 0 else 1.0)
			if next_cost < cost.get(next, INF):
				cost[next] = next_cost
				previous[next] = cell
				open.append(next)
	return []
