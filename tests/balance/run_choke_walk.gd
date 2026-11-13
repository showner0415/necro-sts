extends ScenarioTest
## 좁은 길목마다 몸 종류별로 양쪽 방향을 실제 물리와 길찾기(PathFollower)로 걸어 지나가는지 잰다. 몬스터 AI는 쓰지 않고 걷기만 본다.
## 충돌이나 길찾기를 바꾸기 전후를 비교할 때 쓴다. 제한 시간 안에 지나가지 못한 몸이 있으면 실패로 끝난다. run_all.sh에는 넣지 않는다.
##
## 실행: bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_choke_walk.gd
## 길찾기가 몸을 줄여 보는 여유를 테스트 안에서만 바꾸려면 -- --clearance=<픽셀>

const CLEARANCE_ARG: String = "--clearance="
const SCENE: String = "res://regions/shallow_cave.tscn"
const PNG: String = "res://art_src/maps/shallow_cave.png"
const SETTINGS: String = "res://data/terrain/shallow_cave_outline_settings.tres"
const NECROMANCER_SCENE: String = "res://necromancer/necromancer.tscn"
const MONSTERS: Array[String] = ["rat", "goblin_slinger", "bat", "boar"]
const WORLD_MASK: int = 1
## 목표에 이만큼 가까우면 도착이다 (픽셀)
const ARRIVE_PX: float = 12.0
## 곧은 거리를 걷는 시간의 몇 배까지 기다릴지
const TIME_RATIO: float = 6.0
const MIN_TIME: float = 10.0
const FPS: float = 60.0
## 양쪽 끝 자리로 치는 바닥의 둘레 여유 (칸)
const END_CLEARANCE: int = 1

var _walkers: Array[_Walker] = []
var _bodies: Array[Dictionary] = []
var _chokes: Array[Dictionary] = []


func get_start_scene() -> String:
	return SCENE


func _on_scene_ready() -> void:
	for monster: Node in get_nodes_in_group(&"monsters"):
		monster.free()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(CLEARANCE_ARG):
			(get_first_node_in_group(&"navigation_grid") as NavigationGrid).clearance_margin = arg.trim_prefix(CLEARANCE_ARG).to_float()
	_read_bodies()
	var walls: PlaceholderWalls = current_scene.get_node("Walls")
	var outline: CaveOutline = CaveOutline.new(MapLayout.from_file(PNG).rows, load(SETTINGS))
	var seen: Dictionary = {}
	var size: Vector2i = walls.grid_size()
	for y: int in size.y:
		for x: int in size.x:
			if not seen.has(Vector2i(x, y)) and outline.is_narrow_cell(x, y):
				_add_choke(outline, outline._flood_narrow(Vector2i(x, y), seen), walls, size)
	print("길목 %d곳, 걷는 몸 %d" % [_chokes.size(), _walkers.size()])


func _read_bodies() -> void:
	var necromancer: Necromancer = (load(NECROMANCER_SCENE) as PackedScene).instantiate()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = necromancer.body_radius
	_bodies.append({"name": "네크로맨서", "shape": circle, "rotation": 0.0, "half": Vector2.ONE * necromancer.body_radius, "speed": necromancer.move_speed})
	necromancer.free()
	for id: String in MONSTERS:
		var data: MonsterData = load("res://data/monsters/%s.tres" % id)
		_bodies.append({"name": id, "shape": PlaceholderBody.make_shape(data), "rotation": PlaceholderBody.shape_rotation(data), "half": data.get_placeholder_half_size(), "speed": data.move_speed})


func _add_choke(outline: CaveOutline, group: Array[Vector2i], walls: PlaceholderWalls, size: Vector2i) -> void:
	var low: Vector2i = group[0]
	var high: Vector2i = group[0]
	var in_group: Dictionary = {}
	for cell: Vector2i in group:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
		in_group[cell] = true
	var window: Rect2i = Rect2i(low - Vector2i.ONE * 3, high - low + Vector2i.ONE * 7).intersection(Rect2i(Vector2i.ZERO, size))
	var ends: Array[Dictionary] = outline._window_ends(window, in_group)
	if ends.size() < 2 or ends[1].size() < CaveOutline.MIN_END_CELLS:
		return
	var a: Vector2i = _end_cell(ends[0], (low + high) / 2, walls)
	var b: Vector2i = _end_cell(ends[1], (low + high) / 2, walls)
	var choke: Dictionary = {"cell": group[0], "results": {}}
	_chokes.append(choke)
	for body: Dictionary in _bodies:
		_walkers.append(_Walker.new(self, body, walls.cell_center(a), walls.cell_center(b), choke))
		_walkers.append(_Walker.new(self, body, walls.cell_center(b), walls.cell_center(a), choke))


## 끝 덩어리에서 길목에 가장 가깝고 둘레가 모두 바닥인 칸
func _end_cell(cells: Dictionary, center: Vector2i, walls: PlaceholderWalls) -> Vector2i:
	var best: Vector2i = cells.keys()[0]
	var best_distance: float = INF
	for cell: Vector2i in cells.keys():
		var open: bool = true
		for dy: int in range(-END_CLEARANCE, END_CLEARANCE + 1):
			for dx: int in range(-END_CLEARANCE, END_CLEARANCE + 1):
				open = open and not walls.is_wall(cell + Vector2i(dx, dy))
		var distance: float = Vector2(cell).distance_to(Vector2(center))
		if open and distance < best_distance:
			best = cell
			best_distance = distance
	return best


func _tick() -> void:
	var running: int = 0
	for walker: _Walker in _walkers:
		if walker.step(step_frames):
			running += 1
	if running > 0:
		return
	var failures: int = 0 if not _walkers.is_empty() else 1
	for choke: Dictionary in _chokes:
		var lines: PackedStringArray = PackedStringArray()
		for name: String in choke.results.keys():
			lines.append("%s %s" % [name, " / ".join(PackedStringArray(choke.results[name]))])
			for result: String in choke.results[name]:
				if result.begins_with("실패"):
					failures += 1
		print("칸 %s: %s" % [choke.cell, " · ".join(lines)])
	if failures == 0:
		pass_step("길목 걷기", "모든 몸이 모든 길목을 양쪽으로 지나감 (걸린 시간은 초, 괄호는 곧은 거리를 걷는 시간의 배수)")
	else:
		fail_step("길목 걷기", "지나가지 못한 경우 %d" % failures)
	finish(failures == 0)


class _Walker:
	var _body: CharacterBody2D
	var _follower: PathFollower
	var _goal: Vector2
	var _speed: float
	var _limit_frames: int
	var _ideal: float
	var _name: String
	var _choke: Dictionary
	var _center_offset: Vector2
	var _done: bool = false

	func _init(test: SceneTree, data: Dictionary, from: Vector2, to: Vector2, choke: Dictionary) -> void:
		_name = data.name
		_choke = choke
		_speed = data.speed
		_center_offset = Vector2(0, -(data.half as Vector2).y)
		_goal = to - _center_offset
		_ideal = from.distance_to(to) / _speed
		_limit_frames = int(maxf(_ideal * TIME_RATIO, MIN_TIME) * FPS)
		_follower = PathFollower.new(data.half, _center_offset)
		_body = CharacterBody2D.new()
		_body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		_body.collision_layer = 0
		_body.collision_mask = WORLD_MASK
		var shape: CollisionShape2D = CollisionShape2D.new()
		shape.shape = data.shape
		shape.rotation = data.rotation
		shape.position = _center_offset
		_body.add_child(shape)
		test.current_scene.add_child(_body)
		_body.global_position = from - _center_offset

	## 아직 걷는 중이면 true
	func step(frames: int) -> bool:
		if _done:
			return false
		if _body.global_position.distance_to(_goal) <= ARRIVE_PX:
			_finish("%.1f (%.1f배)" % [frames / FPS, frames / FPS / _ideal])
			return false
		if frames >= _limit_frames:
			_finish("실패 (멈춘 칸 %s, 목표까지 %.0fpx)" % [Vector2i(_body.global_position / 32.0), _body.global_position.distance_to(_goal)])
			return false
		_body.velocity = _follower.get_direction(_body, _goal) * _speed
		_body.move_and_slide()
		return true

	func _finish(result: String) -> void:
		_done = true
		if not _choke.results.has(_name):
			_choke.results[_name] = []
		_choke.results[_name].append(result)
