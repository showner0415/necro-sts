class_name ShallowCaveScenario
extends ScenarioTest
## 얕은 굴 시나리오의 공용 부분: 배치 PNG 읽기, 굴 역할 찾기, 걷기. tests/scenarios/scenario_shallow_cave*.gd가 상속한다.
## 시나리오 하나가 시간 제한(tests/run_all.sh)에 닿지 않게 구조·걷기·언데드로 나눴다.
## 상속하는 쪽은 _run_steps()에서 필요한 때 _find_roles()를 부르고, 단계를 모두 지나면 finish(true)를 부른다.

const MAP_PNG: String = "res://art_src/maps/shallow_cave.png"
const CAVE_SCENE: String = "res://regions/shallow_cave.tscn"
const VIEW_ROCK_SETUP: String = "res://tools/screenshot_setups/view_rock.gd"
## 굴 역할마다 [입구 수, 이어진 굴 역할들] (배치도 그대로)
const EXPECTED_ROOMS: Dictionary = {
	"base": [1, ["entrance"]],
	"entrance": [4, ["base", "rat_nest", "puddle", "mushroom"]],
	"mushroom": [2, ["entrance", "rat_nest"]],
	"rat_nest": [6, ["entrance", "mushroom", "view_rock", "collapsed", "side", "fork"]],
	"view_rock": [1, ["rat_nest"]],
	"collapsed": [1, ["rat_nest"]],
	"side": [2, ["rat_nest", "puddle"]],
	"puddle": [4, ["entrance", "side", "fork", "dead_end"]],
	"dead_end": [1, ["puddle"]],
	"fork": [5, ["rat_nest", "puddle", "bat_nest", "spider_gate", "shelter"]],
	"shelter": [1, ["fork"]],
	"bat_nest": [4, ["fork", "nest_back", "bat_lower", "junction"]],
	"nest_back": [1, ["bat_nest"]],
	"bat_lower": [1, ["bat_nest"]],
	"spider_gate": [3, ["fork", "web", "spider_side"]],
	"web": [2, ["spider_gate", "egg"]],
	"spider_side": [2, ["spider_gate", "egg"]],
	"egg": [4, ["web", "spider_side", "junction", "mud"]],
	"junction": [5, ["bat_nest", "egg", "junction_side", "light_room", "cave_mouth"]],
	"junction_side": [1, ["junction"]],
	"light_room": [2, ["junction", "cave_mouth"]],
	"mud": [2, ["egg", "cave_mouth"]],
	"cave_mouth": [3, ["junction", "light_room", "mud"]],
}
## 굴 가운데에서 이 거리 안이면 닿은 것으로 본다 (픽셀)
const ARRIVE_DISTANCE: float = 16.0
## 한 구간을 걷는 최대 시간 (프레임). 도착 지점 → 동굴 입구 전체도 한 구간이다
const WALK_TIMEOUT_FRAMES: int = 60 * 300
const SETTLE_FRAMES: int = 6
const TILE: float = 32.0
## 무리 자리 물건(MapLayout.LEGEND) → 그 무리에 드는 종 (data/packs/*.tres). 굴 역할은 무리 자리도 그 종이 사는 곳으로 본다 (계획 8a)
const PACK_SPECIES: Dictionary = {
	"pack_rat_big": ["rat"],
	"pack_rat_gang": ["rat"],
	"pack_boar": ["boar"],
	"pack_goblin": ["goblin_slinger"],
	"pack_mixed": ["boar", "rat"],
}

var _layout: MapLayout
## 굴 역할 → 굴 번호 (_find_roles)
var _roles: Dictionary = {}
## _phase_begin()을 부른 때의 실제 시간(밀리초)과 물리 프레임 (_phase_end가 걸린 시간을 출력한다)
var _phase_msec: int = 0
var _phase_frame: int = 0


func get_start_scene() -> String:
	return CAVE_SCENE


func _on_scene_ready() -> void:
	_layout = MapLayout.from_file(MAP_PNG)
	await wait_frames(SETTLE_FRAMES)
	_run_steps()


## 상속하는 쪽의 단계들
func _run_steps() -> void:
	pass


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
		finish(false)
	return ok


func _rooms_with(object: String) -> Array[int]:
	var result: Array[int] = []
	for cell: Vector2i in _cells_with(object):
		var room: int = _layout.room_at(cell)
		if room >= 0 and not result.has(room):
			result.append(room)
	return result


func _room_center(room: int) -> Vector2:
	return (_layout.rooms[room].center + Vector2(0.5, 0.5)) * TILE


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE

## PNG의 한 마리 몬스터 칸 수 (무리 자리는 세지 않는다)
func _monster_cells() -> int:
	var count: int = 0
	for object: String in ["rat", "boar", "bat", "goblin_slinger", "spider"]:
		count += _layout.cells_of(object).size()
	return count


## 지금 씬에 있어야 할 몬스터 수: PNG의 한 마리 칸 + 무리 자리(PackSpawn)마다 만든 무리원 (무리원 수는 던전 시드로 정해진다, 계획 8a)
func _expected_monsters() -> int:
	var count: int = _monster_cells()
	for node: Node in current_scene.find_children("*", "Node2D", true, false):
		if node is PackSpawn:
			count += (node as PackSpawn).get_members().size()
	return count


## object가 있는 칸: 그 물건의 칸, 몬스터 종이면 그 종이 드는 무리 자리 칸도 (PACK_SPECIES)
func _cells_with(object: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = _layout.cells_of(object)
	for pack: String in PACK_SPECIES:
		if (PACK_SPECIES[pack] as Array).has(object):
			cells.append_array(_layout.cells_of(pack))
	return cells


## 굴마다 역할을 내용물과 연결로 찾는다. 못 찾은 역할이 있으면 실패
func _find_roles() -> bool:
	_roles.clear()
	var base: int = _layout.room_at(_layout.cells_of("spawn")[0])
	_roles.base = base
	for room: int in _rooms_with("escape"):
		if _layout.rooms[base].neighbors.has(room):
			_roles.entrance = room
		elif _layout.rooms[room].entrances == 1:
			_roles.shelter = room
		else:
			_roles.junction = room
	if _roles.has("entrance"):
		_roles.fork = _find_fork(_roles.entrance)
	var bat_rooms: Array[int] = _rooms_with("bat")
	for room: int in bat_rooms:
		if _layout.rooms[room].entrances > 1:
			_roles.bat_nest = room
		else:
			_roles.bat_lower = room
	var view: Vector2i = load(VIEW_ROCK_SETUP).spot(_layout)
	if view.x >= 0:
		_roles.view_rock = _layout.room_at(view)
	if _roles.has("entrance") and _roles.has("view_rock"):
		for room: int in _layout.rooms[_roles.entrance].neighbors:
			if room == base:
				continue
			if _layout.rooms[room].neighbors.has(_roles.view_rock):
				_roles.rat_nest = room
			elif _layout.rooms[room].neighbors.has(_roles.get("fork", -1)):
				_roles.puddle = room
			else:
				_roles.mushroom = room
	if _roles.has("rat_nest") and _roles.has("puddle"):
		for room: int in _layout.rooms[_roles.rat_nest].neighbors:
			if _layout.rooms[_roles.puddle].neighbors.has(room) and _layout.rooms[room].entrances == 2:
				_roles.side = room
	for room: int in _layout.rooms.size():
		if _layout.rooms[room].neighbors.size() != 1 or room == _roles.get("view_rock", -1):
			continue
		var only: int = _layout.rooms[room].neighbors[0]
		if only == _roles.get("puddle", -1):
			_roles.dead_end = room
		elif only == _roles.get("rat_nest", -1):
			_roles.collapsed = room
		elif only == _roles.get("bat_nest", -1) and not bat_rooms.has(room):
			_roles.nest_back = room
		elif only == _roles.get("junction", -1):
			_roles.junction_side = room
	var spider_rooms: Array[int] = _rooms_with("spider")
	for room: int in spider_rooms:
		if _layout.rooms[room].neighbors.has(_roles.get("fork", -1)):
			_roles.spider_gate = room
		elif _layout.rooms[room].neighbors.has(_roles.get("junction", -1)):
			_roles.egg = room
		else:
			_roles.web = room
	for room: int in _layout.rooms.size():
		var neighbors: Array = _layout.rooms[room].neighbors
		if not spider_rooms.has(room) and neighbors.has(_roles.get("spider_gate", -1)) and neighbors.has(_roles.get("egg", -1)):
			_roles.spider_side = room
	var mouth_rooms: Array[int] = _rooms_with("light")
	if not mouth_rooms.is_empty():
		_roles.cave_mouth = mouth_rooms[0]
	for room: int in _rooms_with("boar"):
		if room == _roles.get("cave_mouth", -1):
			continue
		if _layout.rooms[room].neighbors.has(_roles.get("junction", -1)):
			_roles.light_room = room
		else:
			_roles.mud = room
	var missing: PackedStringArray = []
	for role: String in EXPECTED_ROOMS:
		if not _roles.has(role) or _roles[role] < 0:
			missing.append(role)
	return _check("굴 역할 찾기", missing.is_empty(), "찾은 역할 %s, 못 찾은 역할 %s" % [_roles, missing])


## 단계 시간 재기 시작. 시나리오가 시간 제한(tests/run_all.sh)에 가까워질 때 어느 단계가 오래 걸리는지 보려고 둔다
func _phase_begin() -> void:
	_phase_msec = Time.get_ticks_msec()
	_phase_frame = Engine.get_physics_frames()


## _phase_begin() 뒤로 걸린 실제 시간·게임 시간과, 엔진이 시작한 뒤 지난 실제 시간을 출력한다 (판정 없음)
func _phase_end(phase: String) -> void:
	var now: int = Time.get_ticks_msec()
	print("[시간] %s: 실제 %.1f초, 게임 %.1f초 (엔진 시작부터 실제 %.1f초)" % [phase, (now - _phase_msec) / 1000.0, (Engine.get_physics_frames() - _phase_frame) / float(Engine.physics_ticks_per_second), now / 1000.0])


func _seconds(value: float) -> String:
	return "%.1f초" % value if value > 0.0 else "닿지 못함"


func _find_fork(entrance: int) -> int:
	for first: int in _layout.rooms[entrance].neighbors:
		for second: int in _layout.rooms[first].neighbors:
			if second != entrance and not _layout.rooms[entrance].neighbors.has(second) and _layout.rooms[second].entrances >= 3:
				return second
	return -1


## 네크로맨서를 길찾기 방향으로 걸려서 goal까지 간다. 걸린 시간(초), 못 가면 -1.
func _walk_to(necromancer: Necromancer, goal: Vector2) -> float:
	var follower: PathFollower = PathFollower.new(Vector2(necromancer.body_radius, necromancer.body_radius), Vector2(0, -necromancer.body_radius))
	var frames: int = 0
	while necromancer.global_position.distance_to(goal) > ARRIVE_DISTANCE and frames < WALK_TIMEOUT_FRAMES:
		press_moves(follower.get_direction(necromancer, goal))
		await wait_frames(1)
		frames += 1
	press_moves(Vector2.ZERO)
	await wait_frames(2)
	if frames >= WALK_TIMEOUT_FRAMES:
		return -1.0
	return frames / float(Engine.physics_ticks_per_second)
