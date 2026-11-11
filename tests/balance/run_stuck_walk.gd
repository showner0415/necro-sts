extends ScenarioTest
## 몸이 벽 모서리에 걸려 멈추는지 잰다. 몸 종류마다 이어진 굴 사이와, 벽에 붙어서 출발하는 짧은 길을 실제 물리와 길찾기(PathFollower)로 걷는다.
## 몬스터 AI·밀려남은 쓰지 않고 걷기만 본다. 판정 없이 표를 낸다. 경로는 여유와 상관없이 같다 (씨앗 고정, 가장 엄격한 여유 0으로 갈 수 있는 길만 고른다).
##
## 실행: bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_stuck_walk.gd
## 사용자 인자: --clearance=<픽셀> 길찾기 여유 (없으면 씬의 값), --hug=<수> 몸마다 벽에 붙어 출발하는 길 수, --cost=1 is_clear 시간만 재고 끝낸다

const SCENE: String = "res://regions/shallow_cave.tscn"
const PNG: String = "res://art_src/maps/shallow_cave.png"
const NECROMANCER_SCENE: String = "res://necromancer/necromancer.tscn"
const MONSTERS: Array[String] = ["rat", "goblin_slinger", "bat", "boar"]
const WORLD_MASK: int = 1
const ROUTE_SEED: int = 20261111
const DEFAULT_HUG: int = 60
## 벽에 붙었다고 보는 거리: 몸에서 이만큼 안에 바위가 있다 (픽셀)
const HUG_PX: float = 5.0
## 벽에 붙어 출발하는 길의 곧은 거리 범위 (픽셀)
const HUG_MIN_DISTANCE: float = 96.0
const HUG_MAX_DISTANCE: float = 400.0
const PICK_ATTEMPTS: int = 200000
const ARRIVE_PX: float = 12.0
const FPS: int = 60
## 이 프레임 동안 이 거리보다 못 움직이면 걸린 것이다
const STUCK_FRAMES: int = 120
const STUCK_PX: float = 3.0
## 길 길이를 걷는 시간의 몇 배 + 몇 초까지 기다릴지
const TIME_RATIO: float = 3.0
const TIME_EXTRA: float = 10.0
const REPORT_PLACES: int = 20
const COST_CALLS: int = 3000
const COST_DISTANCES: Array[float] = [64.0, 200.0, 1000.0]

var _walkers: Array[_Walker] = []
var _bodies: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _walls: PlaceholderWalls
var _nav: NavigationGrid
var _ready_to_walk: bool = false
var _start_frame: int = 0


func get_start_scene() -> String:
	return SCENE


func _on_scene_ready() -> void:
	for monster: Node in get_nodes_in_group(&"monsters"):
		monster.free()
	await wait_frames(4)
	_walls = current_scene.get_node("Walls")
	_nav = get_first_node_in_group(&"navigation_grid")
	_rng.seed = ROUTE_SEED
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	if args.get("cost", "0") == "1":
		_measure_cost()
		finish(true)
		return
	var margin: float = float(args["clearance"]) if args.has("clearance") else _nav.clearance_margin
	_read_bodies()
	# 경로는 가장 엄격한 여유로 골라서 여유가 달라도 같게 한다.
	_set_margin(0.0)
	var routes: Array[Dictionary] = _pick_routes(int(args.get("hug", DEFAULT_HUG)))
	_set_margin(margin)
	for route: Dictionary in routes:
		_walkers.append(_Walker.new(self, route))
	print("여유 %.0f, 몸 %d종류, 걷는 길 %d" % [margin, _bodies.size(), _walkers.size()])
	_start_frame = step_frames
	_ready_to_walk = true


func _set_margin(margin: float) -> void:
	_nav.clearance_margin = margin
	_nav._grids.clear()
	_nav._shapes.clear()


func _read_bodies() -> void:
	var necromancer: Necromancer = (load(NECROMANCER_SCENE) as PackedScene).instantiate()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = necromancer.body_radius
	_bodies.append({"name": "네크로맨서", "shape": circle, "rotation": 0.0, "half": Vector2.ONE * necromancer.body_radius, "speed": necromancer.move_speed})
	necromancer.free()
	for id: String in MONSTERS:
		var data: MonsterData = load("res://data/monsters/%s.tres" % id)
		_bodies.append({"name": id, "shape": PlaceholderBody.make_shape(data), "rotation": PlaceholderBody.shape_rotation(data), "half": data.get_placeholder_half_size(), "speed": data.move_speed})


func _pick_routes(hug_count: int) -> Array[Dictionary]:
	var layout: MapLayout = MapLayout.from_file(PNG)
	var routes: Array[Dictionary] = []
	for body: Dictionary in _bodies:
		for room: int in layout.rooms.size():
			for neighbor: int in layout.rooms[room].neighbors:
				if neighbor < room:
					continue
				var from: Vector2 = _free_near(layout.rooms[room].center, body.half)
				var to: Vector2 = _free_near(layout.rooms[neighbor].center, body.half)
				_add_route(routes, body, from, to, "굴 %d → %d" % [room, neighbor])
		var added: int = 0
		var attempts: int = 0
		while added < hug_count and attempts < PICK_ATTEMPTS:
			attempts += 1
			var start: Vector2 = _random_hug_point(body.half)
			if start == Vector2.INF:
				continue
			var goal: Vector2 = start + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(HUG_MIN_DISTANCE, HUG_MAX_DISTANCE)
			if not _walls.outline.box_has_rock(goal, body.half) and _add_route(routes, body, start, goal, "벽에서 출발"):
				added += 1
	return routes


## 몸 가운데 from에서 to까지 길이 있으면 넣는다.
func _add_route(routes: Array[Dictionary], body: Dictionary, from: Vector2, to: Vector2, kind: String) -> bool:
	var path: PackedVector2Array = _nav.find_path(from, to, body.half)
	if path.size() < 2:
		return false
	var length: float = 0.0
	for index: int in path.size() - 1:
		length += path[index].distance_to(path[index + 1])
	routes.append({"body": body, "from": from, "to": to, "kind": kind, "length": length})
	return true


## 칸 좌표 center 둘레에서 몸이 들어가는 가장 가까운 자리 (몸 가운데, 픽셀)
func _free_near(center: Vector2, half: Vector2) -> Vector2:
	var origin: Vector2 = (center + Vector2(0.5, 0.5)) * _walls.outline.cell_px
	for radius: int in range(0, 200, 8):
		for step: int in 16:
			var point: Vector2 = origin + Vector2.from_angle(TAU * step / 16.0) * radius
			if not _walls.outline.box_has_rock(point, half):
				return point
	return origin


## 몸은 들어가는데 HUG_PX 안에 바위가 있는 자리. 못 찾으면 Vector2.INF
func _random_hug_point(half: Vector2) -> Vector2:
	var data: CaveOutlineData = _walls.outline
	var size: Vector2 = Vector2(data.cell_count * data.cell_px)
	var point: Vector2 = Vector2(_rng.randf() * size.x, _rng.randf() * size.y)
	if data.cell_states[int(point.y / data.cell_px) * data.cell_count.x + int(point.x / data.cell_px)] != CaveOutlineData.CELL_MIXED:
		return Vector2.INF
	if data.box_has_rock(point, half) or not data.box_has_rock(point, half + Vector2.ONE * HUG_PX):
		return Vector2.INF
	return point


## 벽이 가로막는지 묻는 시간: 바닥의 두 점 사이 거리별 한 번 평균
func _measure_cost() -> void:
	var half: Vector2 = Vector2(5, 5)
	var size: Vector2 = Vector2(_walls.grid_size() * _walls.tile_size)
	var floors: Array[Vector2] = []
	while floors.size() < 400:
		var point: Vector2 = Vector2(_rng.randf() * size.x, _rng.randf() * size.y)
		if not _walls.is_wall(_walls.world_to_cell(point)):
			floors.append(point)
	for distance: float in COST_DISTANCES:
		var started: int = Time.get_ticks_usec()
		for call: int in COST_CALLS:
			var from: Vector2 = floors[call % floors.size()]
			_nav.is_clear(from, from + Vector2.from_angle(call * 0.7) * distance, half)
		print("is_clear 거리 %.0f: 한 번 %.1fus" % [distance, float(Time.get_ticks_usec() - started) / COST_CALLS])


func _tick() -> void:
	if not _ready_to_walk:
		return
	var running: int = 0
	for walker: _Walker in _walkers:
		if walker.step(step_frames - _start_frame):
			running += 1
	if running == 0:
		_report()
		finish(not _walkers.is_empty())


func _report() -> void:
	var places: Dictionary = {}
	print("| 몸 | 길 종류 | 걸음 | 도착 | 걸림 | 시간 초과 | 평균 배수 |")
	print("|---|---|---|---|---|---|---|")
	for body: Dictionary in _bodies:
		for kind: String in ["굴 사이", "벽에서 출발"]:
			var count: int = 0
			var arrived: int = 0
			var stuck: int = 0
			var late: int = 0
			var ratio: float = 0.0
			for walker: _Walker in _walkers:
				if walker.body.name != body.name or walker.kind.begins_with("굴") != (kind == "굴 사이"):
					continue
				count += 1
				match walker.result:
					"도착":
						arrived += 1
						ratio += walker.ratio
					"걸림":
						stuck += 1
						places["%s %s (%s, 멈춘 자리 %s, 목표 %s, 길찾기 길의 점 %d)" % [walker.body.name, walker.end_cell, walker.kind, walker.end_position, walker.goal, walker.path_points]] = true
					_:
						late += 1
						places["%s %s 시간 초과 (%s)" % [walker.body.name, walker.end_cell, walker.kind]] = true
			print("| %s | %s | %d | %d | %d | %d | %.2f |" % [body.name, kind, count, arrived, stuck, late, ratio / maxi(arrived, 1)])
	print("걸리거나 시간을 넘긴 자리 %d곳:" % places.size())
	for place: String in places.keys().slice(0, REPORT_PLACES):
		print("  ", place)


class _Walker:
	var body: Dictionary
	var kind: String
	var result: String = ""
	var ratio: float = 0.0
	var end_cell: Vector2i
	var end_position: Vector2
	var goal: Vector2
	var path_points: int = 0
	var _node: CharacterBody2D
	var _follower: PathFollower
	var _goal: Vector2
	var _ideal: float
	var _limit: int
	var _history: PackedVector2Array = PackedVector2Array()

	func _init(test: SceneTree, route: Dictionary) -> void:
		body = route.body
		kind = route.kind
		var offset: Vector2 = Vector2(0, -(body.half as Vector2).y)
		_goal = route.to - offset
		_ideal = route.length / body.speed
		_limit = int((_ideal * TIME_RATIO + TIME_EXTRA) * FPS)
		_follower = PathFollower.new(body.half, offset)
		_node = CharacterBody2D.new()
		_node.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		_node.collision_layer = 0
		_node.collision_mask = WORLD_MASK
		var shape: CollisionShape2D = CollisionShape2D.new()
		shape.shape = body.shape
		shape.rotation = body.rotation
		shape.position = offset
		_node.add_child(shape)
		test.current_scene.add_child(_node)
		_node.global_position = route.from - offset

	## 아직 걷는 중이면 true
	func step(frames: int) -> bool:
		if not result.is_empty():
			return false
		if _node.global_position.distance_to(_goal) <= ARRIVE_PX:
			ratio = frames / float(FPS) / _ideal
			_end("도착")
			return false
		if frames >= _limit:
			_end("시간 초과")
			return false
		_history.append(_node.global_position)
		if _history.size() > STUCK_FRAMES and _history[_history.size() - 1 - STUCK_FRAMES].distance_to(_node.global_position) < STUCK_PX:
			_end("걸림")
			return false
		_node.velocity = _follower.get_direction(_node, _goal) * body.speed
		_node.move_and_slide()
		return true

	func _end(outcome: String) -> void:
		result = outcome
		end_cell = Vector2i(_node.global_position / 32.0)
		end_position = _node.global_position
		goal = _goal
		path_points = _follower.get_path().size()
		_node.queue_free()
