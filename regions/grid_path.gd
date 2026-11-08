class_name GridPath
extends RefCounted
## 바닥을 같은 크기의 칸으로 나누고, 막힌 칸을 피해 길을 찾는다 (Godot의 AStarGrid2D). 노드·물리에 의존하지 않는다.
## 어떤 칸이 막혔는지는 쓰는 쪽(NavigationGrid)이 정해 준다.
## - 길은 칸 가운데를 잇는 점들이다. 대각선은 양옆 칸이 둘 다 비어 있을 때만 간다 (모퉁이를 깎다가 벽에 걸리지 않게)
## - 출발·목표 칸이 막혀 있으면(벽에 붙어 서 있음) nearest_search_cells칸 안에서 가장 가까운 빈 칸을 대신 쓴다
## - 목표에 닿을 수 없으면 닿을 수 있는 곳 중 목표에 가장 가까운 곳까지의 길이다

## 출발·목표 칸이 막혀 있을 때 빈 칸을 찾아볼 거리 (칸 수)
var nearest_search_cells: int = 4

var _astar: AStarGrid2D = AStarGrid2D.new()
var _origin: Vector2
var _cell_size: float
var _size: Vector2i
var _solid_count: int = 0


## bounds: 칸으로 나눌 바닥 (월드 좌표), cell_size: 칸 한 변 (픽셀)
func _init(bounds: Rect2, cell_size: float) -> void:
	_origin = bounds.position
	_cell_size = cell_size
	_size = Vector2i(ceili(bounds.size.x / cell_size), ceili(bounds.size.y / cell_size))
	_astar.region = Rect2i(Vector2i.ZERO, _size)
	_astar.cell_size = Vector2(cell_size, cell_size)
	# 길의 점이 칸 가운데에 오게 한다.
	_astar.offset = _origin + Vector2(cell_size, cell_size) / 2.0
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()


## 칸 수 (가로, 세로)
func get_size() -> Vector2i:
	return _size


## 월드 좌표가 들어 있는 칸. 바닥 밖이면 가장 가까운 가장자리 칸.
func world_to_cell(point: Vector2) -> Vector2i:
	var cell: Vector2i = Vector2i(((point - _origin) / _cell_size).floor())
	return cell.clamp(Vector2i.ZERO, _size - Vector2i.ONE)


## 칸 가운데의 월드 좌표
func cell_to_world(cell: Vector2i) -> Vector2:
	return _origin + (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_size


func set_solid(cell: Vector2i, solid: bool = true) -> void:
	if _astar.is_point_solid(cell) == solid:
		return
	_astar.set_point_solid(cell, solid)
	_solid_count += 1 if solid else -1


## row 줄의 from 칸부터 to 칸 앞까지를 한 번에 막는다. 막힌 칸이 없던 새 격자에만 쓴다 (칸마다 set_solid를 부르는 것보다 훨씬 빠르다).
func fill_solid_run(row: int, from: int, to: int) -> void:
	if to <= from:
		return
	_astar.fill_solid_region(Rect2i(from, row, to - from, 1), true)
	_solid_count += to - from


func is_solid(cell: Vector2i) -> bool:
	return _astar.is_point_solid(cell)


## 막힌 칸이 하나라도 있는지
func has_solid() -> bool:
	return _solid_count > 0


## from에서 to까지 막힌 칸을 피해 가는 길 (칸 가운데 점들, 첫 점은 출발 칸). 갈 수 없으면 빈 배열.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start: Vector2i = _nearest_open(world_to_cell(from))
	var goal: Vector2i = _nearest_open(world_to_cell(to))
	if start.x < 0 or goal.x < 0:
		return PackedVector2Array()
	return _astar.get_point_path(start, goal, true)


## cell이 비어 있으면 그대로, 막혀 있으면 nearest_search_cells칸 안에서 가장 가까운 빈 칸. 없으면 (-1, -1).
func _nearest_open(cell: Vector2i) -> Vector2i:
	if not _astar.is_point_solid(cell):
		return cell
	for ring: int in range(1, nearest_search_cells + 1):
		var best: Vector2i = Vector2i(-1, -1)
		var best_distance: int = 0
		for dy: int in range(-ring, ring + 1):
			for dx: int in range(-ring, ring + 1):
				# 이번 고리(가운데에서 ring칸 떨어진 테두리)만 본다.
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var candidate: Vector2i = cell + Vector2i(dx, dy)
				if not _astar.is_in_boundsv(candidate) or _astar.is_point_solid(candidate):
					continue
				var distance: int = dx * dx + dy * dy
				if best.x < 0 or distance < best_distance:
					best = candidate
					best_distance = distance
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)
