class_name PathFollower
extends RefCounted
## 몸 하나가 목표 지점까지 벽을 돌아서 가는 방향을 정한다. 몬스터·언데드가 하나씩 가진다.
## - 지역에 NavigationGrid가 없거나 벽이 하나도 없으면 곧장 목표 쪽이다 (길찾기 전과 같은 직선 이동)
## - 목표까지 몸이 지나갈 직선에 벽이 없어도 곧장 간다
## - 벽이 가로막으면 NavigationGrid가 찾은 길(칸 가운데를 잇는 점들)을 따라간다.
##   다음 점들 중 벽 없이 곧장 갈 수 있는 가장 먼 점으로 가서 모퉁이를 짧게 돈다
## - 목표가 움직이므로 길은 정해진 간격(NavigationGrid.repath_interval)마다, 또는 길 끝에 닿으면 다시 찾는다
## 벽과의 거리는 몸의 가운데(발밑이 아니라 충돌 모양의 가운데)로 잰다.

## 몸의 가로·세로 반 크기
var _half_size: Vector2
## 발밑(global_position)에서 몸 가운데까지
var _center_offset: Vector2
var _grid: NavigationGrid
var _grid_searched: bool = false
var _path: PackedVector2Array = PackedVector2Array()
var _index: int = 0
var _planned_frame: int = -1


func _init(half_size: Vector2, center_offset: Vector2) -> void:
	_half_size = half_size
	_center_offset = center_offset


## body가 goal(발밑 좌표)로 가려면 지금 움직일 방향 (길이 1, 이미 닿았으면 0)
func get_direction(body: Node2D, goal: Vector2) -> Vector2:
	var straight: Vector2 = body.global_position.direction_to(goal)
	var grid: NavigationGrid = _find_grid(body)
	if grid == null or not grid.has_walls():
		return straight
	var from: Vector2 = body.global_position + _center_offset
	var to: Vector2 = goal + _center_offset
	if grid.is_clear(from, to, _half_size):
		_path.clear()
		return straight
	var frame: int = Engine.get_physics_frames()
	if _index >= _path.size() - 1 or frame - _planned_frame >= grid.get_repath_frames():
		_path = grid.find_path(from, to, _half_size)
		_index = 0
		_planned_frame = frame
	# 길이 없으면(갇혔거나 바닥 밖) 곧장 간다.
	if _path.size() < 2:
		return straight
	while _index < _path.size() - 1 and from.distance_to(_path[_index]) <= grid.waypoint_arrive_distance:
		_index += 1
	var checks: int = 0
	while _index < _path.size() - 1 and checks < grid.max_lookahead and grid.is_clear(from, _path[_index + 1], _half_size):
		_index += 1
		checks += 1
	return from.direction_to(_path[_index])


## body에서 goal(발밑 좌표)까지 몸이 곧장 갈 때 벽에 막히지 않는지. 벽이 없는 지역이면 항상 true.
func is_line_clear(body: Node2D, goal: Vector2) -> bool:
	var grid: NavigationGrid = _find_grid(body)
	if grid == null:
		return true
	return grid.is_clear(body.global_position + _center_offset, goal + _center_offset, _half_size)


## body가 point(발밑 좌표)를 볼 수 있는지: 몸 가운데에서 point의 같은 높이까지 벽이 가리지 않는지. 벽이 없는 지역이면 항상 true.
func can_see(body: Node2D, point: Vector2) -> bool:
	var grid: NavigationGrid = _find_grid(body)
	if grid == null:
		return true
	return grid.can_see(body.global_position + _center_offset, point + _center_offset)


## 테스트·디버그용: 지금 따라가는 길 (벽이 없어 곧장 가는 중이면 빈 배열)
func get_path() -> PackedVector2Array:
	return _path


func _find_grid(body: Node2D) -> NavigationGrid:
	# 몸은 지역 씬과 함께 만들어지고 사라지므로, 한 번 찾은 결과(없음 포함)를 계속 쓴다.
	if not _grid_searched:
		_grid_searched = true
		_grid = body.get_tree().get_first_node_in_group(&"navigation_grid") as NavigationGrid
	return _grid if is_instance_valid(_grid) else null
