class_name PathFollower
extends RefCounted
## 몸 하나가 목표 지점까지 벽을 돌아서 가는 방향을 정한다. 몬스터·언데드가 하나씩 가진다.
## - 지역에 NavigationGrid가 없거나 벽이 하나도 없으면 곧장 목표 쪽이다 (길찾기 전과 같은 직선 이동)
## - 목표까지 몸이 지나갈 직선에 벽이 없어도 곧장 간다
## - 벽이 가로막으면 NavigationGrid가 찾은 길(칸 가운데를 잇는 점들)을 따라간다.
##   다음 점들 중 벽 없이 곧장 갈 수 있는 가장 먼 점으로 가서 모퉁이를 짧게 돈다
## - 목표가 움직이므로 길은 정해진 간격(NavigationGrid.repath_interval)마다, 또는 길 끝에 닿으면 다시 찾는다
## - 길목 피하기(get_direction의 avoid_chokes): 공격권 없는 몬스터는 길목을 지나지 않고 돌아가거나 입구 밖 대기 자리에서 기다린다 (계획 4b)
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
## 지난 길을 길목 피하기로 찾았는지 (바뀌면 길을 다시 찾는다)
var _planned_avoiding: bool = false
## 길목 입구 밖에서 기다리는 대기 자리 (발밑 좌표, 기다리지 않으면 INF)
var _waiting_spot: Vector2 = Vector2.INF
## 피하지 않던 중에 들어간 길목 번호 (그 안에서는 공격권을 잃어도 빠져나간다. 길목 밖이면 -1)
var _free_choke: int = -1


func _init(half_size: Vector2, center_offset: Vector2) -> void:
	_half_size = half_size
	_center_offset = center_offset


## body가 goal(발밑 좌표)로 가려면 지금 움직일 방향 (길이 1, 이미 닿았으면 0)
## avoid_chokes면 가려는 길이 지나는 길목(NavigationGrid의 구운 길목)을 피한다 (공격권 없는 몬스터, 계획 4b):
## (피하지 않던 중에 들어간 길목 안이면 빠져나가고, 피하던 중에 가장자리를 밟았으면 계속 피한다)
## 우회 비율이 한계 이하면 길목을 막고 돌아가고, 아니면 가까운 입구의 대기 자리로 가서 멈춘다.
func get_direction(body: Node2D, goal: Vector2, avoid_chokes: bool = false) -> Vector2:
	var straight: Vector2 = body.global_position.direction_to(goal)
	var grid: NavigationGrid = _find_grid(body)
	if grid == null or not grid.has_walls():
		return straight
	var from: Vector2 = body.global_position + _center_offset
	var to: Vector2 = goal + _center_offset
	var chokes: ChokeIndex = grid.get_choke_index() if avoid_chokes else null
	# 피하지 않던 중에(공격권을 들고) 들어간 길목 안이면, 공격권을 잃어도 피하지 않고 빠져나간다.
	# 피하던 중에 가장자리를 밟은 것(모퉁이에서 지나침, 밀려남)은 계속 피한다.
	var index: ChokeIndex = grid.get_choke_index()
	var inside: int = index.choke_at(from) if index != null else -1
	if inside < 0:
		_free_choke = -1
	elif not avoid_chokes:
		_free_choke = inside
	if chokes != null and inside >= 0 and inside == _free_choke:
		chokes = null
	if chokes == null:
		_stop_waiting(grid, body)
	if grid.is_clear(from, to, _half_size) and (chokes == null or chokes.first_choke_on_path(PackedVector2Array([from, to])) < 0):
		_path.clear()
		_stop_waiting(grid, body)
		return straight
	var frame: int = Engine.get_physics_frames()
	if _index >= _path.size() - 1 or frame - _planned_frame >= grid.get_repath_frames() or _planned_avoiding != (chokes != null):
		_plan(grid, body, from, to, chokes)
		_planned_frame = frame
	# 대기 자리에 닿았으면 멈춘다. 곧장 갈 수 있으면 곧장 간다.
	if _waiting_spot != Vector2.INF:
		var spot: Vector2 = _waiting_spot + _center_offset
		if from.distance_to(spot) <= grid.waypoint_arrive_distance:
			return Vector2.ZERO
		if grid.is_clear(from, spot, _half_size):
			return from.direction_to(spot)
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


## 길을 새로 찾는다. chokes가 있으면(길목 피하기) 찾은 길이 지나는 첫 길목을 보고, 돌아가거나 대기 자리로 가는 길로 바꾼다.
func _plan(grid: NavigationGrid, body: Node2D, from: Vector2, to: Vector2, chokes: ChokeIndex) -> void:
	_path = grid.find_path(from, to, _half_size)
	_index = 0
	_planned_avoiding = chokes != null
	if chokes == null:
		return
	var choke: int = chokes.first_choke_on_path(_path)
	if choke < 0:
		_stop_waiting(grid, body)
		return
	if chokes.can_detour(choke, from, to, grid.choke_detour_limit):
		_stop_waiting(grid, body)
		_path = grid.find_path_without_choke(from, to, _half_size, choke)
		return
	var entrance: int = chokes.nearest_entrance(choke, from)
	var spot: Vector2 = grid.wait_spots.claim(body, choke, entrance, chokes.chokes[choke].wait_spots[entrance], body.global_position)
	if spot == Vector2.INF:
		# 대기 자리가 없으면 입구에서 기다린다.
		spot = chokes.chokes[choke].entrances[entrance]
	_waiting_spot = spot
	_path = grid.find_path(from, spot + _center_offset, _half_size)


func _stop_waiting(grid: NavigationGrid, body: Node2D) -> void:
	if _waiting_spot != Vector2.INF:
		grid.wait_spots.release(body)
		_waiting_spot = Vector2.INF



## 기다림을 끝내고 대기 자리를 내놓는다 (쓰는 쪽이 대상을 잃고 배회로 돌아갈 때 부른다).
func stop_waiting(body: Node2D) -> void:
	var grid: NavigationGrid = _find_grid(body)
	if grid != null:
		_stop_waiting(grid, body)


## body(몸 가운데)가 든 길목 번호. 길목이 없거나 밖이면 -1
func choke_at_body(body: Node2D) -> int:
	var grid: NavigationGrid = _find_grid(body)
	var index: ChokeIndex = grid.get_choke_index() if grid != null else null
	return index.choke_at(body.global_position + _center_offset) if index != null else -1

## 길목 입구 밖 대기 자리에서 기다리는 중인지 (공격권 없이 길목을 피하는 중)
func is_waiting_at_choke() -> bool:
	return _waiting_spot != Vector2.INF


## 테스트·디버그용: 기다리는 대기 자리 (발밑 좌표, 기다리지 않으면 INF)
func get_waiting_spot() -> Vector2:
	return _waiting_spot


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
