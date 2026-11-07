class_name NavigationGrid
extends Node
## 벽이 있는 지역에서 몬스터·언데드가 벽을 돌아갈 길을 찾는다. 벽이 있는 지역 씬에 하나 둔다 (그룹 navigation_grid).
## - bounds 안을 cell_size 칸으로 나누고, 몸 크기마다 "그 몸이 칸 가운데에 서면 벽과 겹치는지"를 물리 질의로 한 번 재서
##   막힌 칸을 정한다 (GridPath). 벽은 충돌층 world_mask에 있는 무엇이든 된다 (지금은 PlaceholderWalls)
## - 몸은 사각형으로 어림하고 clearance_margin만큼 줄여서 잰다. 칸이 성겨서 좁은 길목이 막혀 보이지 않게 하려는 것이다.
##   그만큼 모퉁이에서 벽에 스칠 수 있는데, 그건 move_and_slide가 미끄러뜨린다
## - 벽이 하나도 없으면 has_walls()가 false다. 이 노드가 없는 지역(시험 지역, 거점)처럼, 쓰는 쪽은 지금까지처럼 곧장 간다
## 실제로 따라가는 일은 몸마다 하나씩 가진 PathFollower가 한다.

## 칸으로 나눌 바닥 (월드 좌표). 벽과 몬스터가 다니는 곳이 모두 들어가야 한다.
@export var bounds: Rect2 = Rect2(-480, -480, 960, 960)
## 칸 한 변 (픽셀)
@export var cell_size: float = 8.0
## 벽으로 보는 충돌층
@export_flags_2d_physics var world_mask: int = 1
## 막힌 칸·직선을 잴 때 몸 사각형을 이만큼 줄인다 (픽셀)
@export var clearance_margin: float = 4.0
## 따라가는 길을 이 시간(초)마다 다시 찾는다 (목표가 움직이므로)
@export var repath_interval: float = 0.3
## 길의 점에 이 거리 안으로 오면 다음 점으로 간다 (픽셀)
@export var waypoint_arrive_distance: float = 4.0
## 프레임마다 "더 먼 점이 곧장 보이는지" 확인할 최대 개수 (모퉁이를 짧게 도는 데 쓴다)
@export var max_lookahead: int = 3
## 출발·목표 칸이 막혀 있을 때 빈 칸을 찾아볼 거리 (칸 수)
@export var nearest_search_cells: int = 4

## 몸 크기(줄인 반 크기)마다 막힌 칸을 잰 GridPath
var _grids: Dictionary = {}
## 몸 크기(줄인 반 크기)마다 질의에 쓰는 사각형
var _shapes: Dictionary = {}
var _has_walls: bool = false
## 벽이 물리 공간에 들어간 뒤에야 질의할 수 있다. 그 전에는 벽이 없는 것으로 본다.
var _ready_for_queries: bool = false


func _ready() -> void:
	add_to_group(&"navigation_grid")
	# 같은 프레임에 들어온 벽(StaticBody2D)은 물리 프레임이 지나야 질의에 잡힌다.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var whole: RectangleShape2D = RectangleShape2D.new()
	whole.size = bounds.size
	params.shape = whole
	params.transform = Transform2D(0.0, bounds.get_center())
	params.collision_mask = world_mask
	_has_walls = not _space().intersect_shape(params, 1).is_empty()
	_ready_for_queries = true


## 벽이 하나라도 있는지. false면 쓰는 쪽은 곧장 간다.
func has_walls() -> bool:
	return _ready_for_queries and _has_walls


## 반 크기 half_size인 몸(가운데가 from)이 to까지 곧장 갈 때 벽에 막히지 않는지.
func is_clear(from: Vector2, to: Vector2, half_size: Vector2) -> bool:
	if not has_walls():
		return true
	var params: PhysicsShapeQueryParameters2D = _make_params(half_size)
	params.transform = Transform2D(0.0, from)
	params.motion = to - from
	var result: PackedFloat32Array = _space().cast_motion(params)
	return result.size() > 0 and result[0] >= 1.0


## from에서 to가 보이는지: 두 점을 잇는 선을 벽이 가리지 않는지 (몬스터의 감지).
func can_see(from: Vector2, to: Vector2) -> bool:
	if not has_walls():
		return true
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, world_mask)
	return _space().intersect_ray(params).is_empty()


## 반 크기 half_size인 몸이 from에서 to까지 벽을 돌아가는 길 (점들). 갈 수 없으면 빈 배열.
func find_path(from: Vector2, to: Vector2, half_size: Vector2) -> PackedVector2Array:
	if not has_walls():
		return PackedVector2Array([from, to])
	return _grid_for(half_size).find_path(from, to)


## 길을 다시 찾는 간격 (물리 프레임 수)
func get_repath_frames() -> int:
	return maxi(1, roundi(repath_interval * Engine.physics_ticks_per_second))


## 테스트용: 반 크기 half_size인 몸의 막힌 칸 정보
func get_grid(half_size: Vector2) -> GridPath:
	return _grid_for(half_size)


func _space() -> PhysicsDirectSpaceState2D:
	return get_viewport().world_2d.direct_space_state


func _key(half_size: Vector2) -> Vector2:
	return (half_size - Vector2(clearance_margin, clearance_margin)).max(Vector2.ONE)


func _make_params(half_size: Vector2) -> PhysicsShapeQueryParameters2D:
	var key: Vector2 = _key(half_size)
	if not _shapes.has(key):
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = key * 2.0
		_shapes[key] = shape
	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = _shapes[key]
	params.collision_mask = world_mask
	return params


func _grid_for(half_size: Vector2) -> GridPath:
	var key: Vector2 = _key(half_size)
	if _grids.has(key):
		return _grids[key]
	var grid: GridPath = GridPath.new(bounds, cell_size)
	grid.nearest_search_cells = nearest_search_cells
	var params: PhysicsShapeQueryParameters2D = _make_params(half_size)
	var space: PhysicsDirectSpaceState2D = _space()
	var size: Vector2i = grid.get_size()
	for y: int in size.y:
		for x: int in size.x:
			var cell: Vector2i = Vector2i(x, y)
			params.transform = Transform2D(0.0, grid.cell_to_world(cell))
			if not space.intersect_shape(params, 1).is_empty():
				grid.set_solid(cell)
	_grids[key] = grid
	return grid
