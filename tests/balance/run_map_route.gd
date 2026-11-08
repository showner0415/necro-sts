extends ScenarioTest
## 밸런스 측정 (실제 맵): 플레이어 봇이 얕은 굴의 정해진 길을 지나가며 걸려 온 몬스터와 싸운 결과를 잰다.
## 길 × 조건(혼자 / 쥐 언데드 2마리와 함께) × 실력 단계마다 runs번 지나가서, 지나간 시간·받은 피해·죽은 비율·잡은 수·언데드 죽음·명중률을 표로 낸다.
## - 걷기: 몬스터에게 걸리지 않은 동안은 길찾기로 다음 굴 가운데까지 걷는다 (언데드는 따라온다)
## - 싸우기: 누군가(네크로맨서·언데드)를 노리는 몬스터가 있으면 봇(PlayerBot)이 그 몬스터들만 상대한다. 모두 죽거나 포기하면 다시 걷는다
##   봇의 싸움 움직임은 시험 지역과 같다 (몬스터 쪽으로 곧게 다가가거나 물러난다. 길찾기는 하지 않아 벽에 미끄러질 수 있다)
## - 길에 든 굴의 몬스터만 남기고 나머지는 없앤다. 판마다 맵을 새로 불러오고 난수 시드를 바꾼다
## 판정(통과/실패)을 내지 않으므로 run_all.sh에는 넣지 않는다.
##
## 전부 (헤드리스, 빠르게):
##   bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_map_route.gd
## 일부만: -- --routes=bat --skills=normal --undead=0 --runs=3
## 물러나기도 재려면: --retreat=0,1,2 (1: 언데드를 모두 잃거나 체력이 절반 이하면 싸움을 그만두고 합류 굴의 탈출 B로 물러난다, 2: 체력이 절반 이하일 때만). 1이나 2 중 하나만 줘도 둘 다 잰다
## 창으로 보기 (실제 속도, 한 판):
##   bash tools/godot.sh --path . -s tests/balance/run_map_route.gd -- --routes=boar --skills=normal --undead=2 --runs=1

const CAVE_SCENE: String = "res://regions/shallow_cave.tscn"
const MAP_PNG: String = "res://art_src/maps/shallow_cave.png"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const UNDEAD_BONES: int = 40
const BAT_PATH: String = "res://data/monsters/bat.tres"
const BAT_PATHS = preload("res://tests/bat_nest_paths.gd")
const RAT_PATH: String = "res://data/monsters/rat.tres"
## 시간 초과한 판의 위치 기록 간격 (초)과, 끝에서 몇 초 동안 움직인 거리를 볼지
const TRACE_INTERVAL: float = 1.0
const TRACE_TAIL: int = 20
## 박쥐 둥지를 지나는 길에서 이 칸 수마다(그리고 꺾이는 칸마다) 걸을 점을 둔다
const NEST_WAYPOINT_EVERY: int = 3
## 몰래 가는 길이 박쥐 감지 범위에서 더 떨어져 지나는 여유 (픽셀). scenario_shallow_cave.gd의 BAT_SNEAK_MARGIN과 같다
const NEST_SNEAK_MARGIN: float = 96.0
## 물러나기 조건: 체력이 최대의 이 비율 이하
const RETREAT_HEALTH_RATIO: float = 0.5
## 물러나기 방식: 0 끝까지 싸우기, 1 언데드를 모두 잃거나 체력이 RETREAT_HEALTH_RATIO 이하면 합류 굴의 탈출 B로, 2 체력이 RETREAT_HEALTH_RATIO 이하일 때만 탈출 B로
const RETREAT_NEVER: int = 0
const RETREAT_UNDEAD_OR_HEALTH: int = 1
const RETREAT_HEALTH_ONLY: int = 2
const RETREAT_NAMES: Array[String] = ["끝까지", "물러나기", "물러나기(체력만)"]
const TILE: float = 32.0
## 길: 이름, 출발 굴, 지나갈 굴들, 몬스터를 남길 굴들 (모두 굴 역할 이름, _find_roles).
## via_monsters가 있으면 굴 대신 남긴 몬스터 중 그 종류가 처음 놓인 자리를, 가까운 것부터 차례로 찾아간다 (일부러 싸우러 갈 때)
## nest_path가 있으면 via의 굴들 앞에 박쥐 둥지를 지나는 길(tests/bat_nest_paths.gd)의 점들을 차례로 걷는다: "default" 입구 → 출구 가장 짧은 길, "sneak" 감지되는 칸을 피하는 길
const ROUTES: Dictionary = {
	&"bat": {"name": "박쥐 길 (갈림 굴 → 박쥐 둥지 → 합류 굴)", "start": "fork", "via": ["bat_nest", "junction"], "keep": ["bat_nest"]},
	&"bat_direct": {"name": "박쥐 길 기본 길 (둥지 입구 → 출구 가장 짧은 길)", "start": "fork", "via": ["junction"], "nest_path": "default", "keep": ["bat_nest"]},
	&"bat_sneak": {"name": "박쥐 길 몰래 (둥지 서쪽 벽 → 바위 뒤 → 북쪽으로 돌아)", "start": "fork", "via": ["junction"], "nest_path": "sneak", "keep": ["bat_nest"]},
	&"boar": {"name": "멧돼지 쪽 (합류 굴 → 빛 드는 굴 → 동굴 입구)", "start": "junction", "via": ["light_room", "cave_mouth"], "keep": ["light_room", "cave_mouth"]},
	&"boar_hunt": {"name": "멧돼지 잡으러 (합류 굴 → 가까운 멧돼지부터 차례로)", "start": "junction", "via": [], "via_monsters": &"boar", "keep": ["light_room", "cave_mouth"]},
}
const DEFAULT_RUNS: int = 5
## 한 판의 시간 한계 (초)
const DEFAULT_TIMEOUT: float = 180.0
const BASE_SEED: int = 2000
## 굴 가운데에서 이 거리 안이면 닿은 것으로 본다 (픽셀)
const ARRIVE_DISTANCE: float = 16.0
const SETTLE_FRAMES: int = 6

var _routes: Array[StringName] = [&"bat", &"bat_direct", &"bat_sneak", &"boar", &"boar_hunt"]
var _skills: Array[StringName] = [&"skilled", &"normal", &"novice"]
var _undead_counts: Array[int] = [0, 2]
## 물러나기 방식들 (RETREAT_NAMES 순서)
var _retreats: Array[int] = [0]
## 잴 지역 씬과 그 배치 PNG (다른 판의 맵과 비교할 때 --scene=, --png=로 바꾼다)
var _scene: String = CAVE_SCENE
var _png: String = MAP_PNG
## 시험용: 0보다 크면 쥐 언데드의 공격 거리(undead_attack_range_override)를 이 값으로 바꾼 데이터 복사본을 쓴다 (실제 .tres는 그대로)
var _undead_attack_range: float = -1.0
var _rat_undead_data: MonsterData
var _runs: int = DEFAULT_RUNS
var _timeout: float = DEFAULT_TIMEOUT
var _layout: MapLayout
var _roles: Dictionary = {}


func get_start_scene() -> String:
	_parse_args()
	return _scene


func _on_scene_ready() -> void:
	_layout = MapLayout.from_file(_png)
	_find_roles()
	_run_all()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		if parts.size() != 2:
			continue
		var values: PackedStringArray = parts[1].split(",")
		match parts[0]:
			"routes":
				_routes.assign(Array(values).map(func(v: String) -> StringName: return StringName(v)))
			"skills":
				_skills.assign(Array(values).map(func(v: String) -> StringName: return StringName(v)))
			"undead":
				_undead_counts.assign(Array(values).map(func(v: String) -> int: return int(v)))
			"runs":
				_runs = int(parts[1])
			"retreat":
				_retreats.assign(Array(values).map(func(v: String) -> int: return int(v)))
				# 물러나기를 재면 두 조건(언데드를 잃거나 체력 절반 / 체력 절반만)을 늘 나란히 잰다 (사용자 결정)
				for retreat: int in [RETREAT_UNDEAD_OR_HEALTH, RETREAT_HEALTH_ONLY]:
					if not _retreats.has(retreat) and (_retreats.has(RETREAT_UNDEAD_OR_HEALTH) or _retreats.has(RETREAT_HEALTH_ONLY)):
						_retreats.append(retreat)
			"scene":
				_scene = parts[1]
			"undead_attack_range":
				_undead_attack_range = float(parts[1])
			"png":
				_png = parts[1]
			"timeout":
				_timeout = float(parts[1])


## 길에 쓰는 굴 역할만 찾는다 (scenario_shallow_cave.gd의 굴 역할과 같은 뜻)
func _find_roles() -> void:
	var base: int = _layout.room_at(_layout.cells_of("spawn")[0])
	for cell: Vector2i in _layout.cells_of("escape"):
		var room: int = _layout.room_at(cell)
		if not _layout.rooms[base].neighbors.has(room):
			_roles.junction = room
	_roles.bat_nest = _layout.room_at(_layout.cells_of("bat")[0])
	_roles.cave_mouth = _layout.room_at(_layout.cells_of("light")[0])
	for cell: Vector2i in _layout.cells_of("boar"):
		if _layout.room_at(cell) != _roles.cave_mouth:
			_roles.light_room = _layout.room_at(cell)
	# 갈림 굴: 박쥐 둥지와 이어진 1등급 굴
	for room: int in _layout.rooms[_roles.bat_nest].neighbors:
		if _layout.rooms[room].char == "1":
			_roles.fork = room


func _run_all() -> void:
	var lines: PackedStringArray = []
	lines.append("| 길 | 조건 | 물러나기 | 실력 | 판 | 죽음 | 물러나 탈출 | 지나간 시간 (살아남은 판) | 받은 피해 평균 / 최대 | 잡은 수 / 남긴 몬스터 | 언데드 죽음 | 언데드가 같은 프레임에 함께 죽은 판 / 언데드가 죽은 판 | 시간 초과 | 명중률 |")
	lines.append("|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	for route_id: StringName in _routes:
		for undead_count: int in _undead_counts:
			for retreat: int in _retreats:
				for skill_id: StringName in _skills:
					var results: Array[Dictionary] = []
					for run: int in _runs:
						results.append(await _pass(route_id, undead_count, skill_id, run, retreat))
					lines.append(_row(route_id, undead_count, retreat, skill_id, results))
					print(lines[-1])
	print("")
	print("\n".join(lines))
	finish(true)


func _pass(route_id: StringName, undead_count: int, skill_id: StringName, run: int, retreat: int) -> Dictionary:
	await _reload_scene()
	seed(BASE_SEED + run)
	var route: Dictionary = ROUTES[route_id]
	var keep_rooms: Array[int] = []
	for role: String in route["keep"]:
		keep_rooms.append(_roles[role])
	var kept: Array[Monster] = []
	for node: Node in get_nodes_in_group(&"monsters"):
		var monster: Monster = node as Monster
		if keep_rooms.has(_layout.room_at(Vector2i((monster.global_position / TILE).floor()))):
			kept.append(monster)
		else:
			monster.free()
	var necromancer: Necromancer = find_necromancer()
	necromancer.global_position = _room_center(_roles[route["start"]])
	await wait_frames(SETTLE_FRAMES)
	var bot: PlayerBot = PlayerBot.new(self, necromancer, skill_id)
	bot.arena_radius = INF
	bot.monster_filter = func(monster: Monster) -> bool: return monster.get_target() != null
	if undead_count > 0:
		var skulls: Array[Skull] = _give_undead(necromancer, undead_count)
		bot.set_undead_skulls(skulls)
		var hotbar: Hotbar = root.get_node("GameState").hotbar
		for i: int in skulls.size():
			hotbar.select(i)
			necromancer.summoner.toggle_selected()
		await wait_frames(SETTLE_FRAMES)

	var goals: Array[Vector2] = []
	if route.has("nest_path"):
		var nest: Dictionary = BAT_PATHS.measure((current_scene.get_node("Walls") as PlaceholderWalls).layout, _layout.objects, current_scene.get_node("NavigationGrid"),
			(load(BAT_PATH) as MonsterData).detect_range, Vector2i(_layout.rooms[_roles.fork].center.round()), Vector2i(_layout.rooms[_roles.junction].center.round()), NEST_SNEAK_MARGIN)
		goals.append_array(BAT_PATHS.waypoints(nest["default_path"] if route["nest_path"] == "default" else nest["sneak_path"], NEST_WAYPOINT_EVERY))
	for role: String in route["via"]:
		goals.append(_room_center(_roles[role]))
	if route.has("via_monsters"):
		var spots: Array[Vector2] = []
		for monster: Monster in kept:
			if monster.data.id == route["via_monsters"]:
				spots.append(monster.global_position)
		var from: Vector2 = necromancer.global_position
		while not spots.is_empty():
			spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(from) < b.distance_to(from))
			from = spots.pop_front()
			goals.append(from)
	var follower: PathFollower = PathFollower.new(Vector2(necromancer.body_radius, necromancer.body_radius), Vector2(0, -necromancer.body_radius))
	var result: Dictionary = {"died": false, "timeout": false, "escaped": false}
	var escape_point: Vector2 = Vector2.ZERO
	for cell: Vector2i in _layout.cells_of("escape"):
		if _layout.room_at(cell) == _roles.junction:
			escape_point = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
	var max_health: float = necromancer.max_health
	necromancer.died.connect(func() -> void: result["died"] = true)
	var time: float = 0.0
	var delta: float = 1.0 / Engine.physics_ticks_per_second
	var goal_index: int = 0
	## 잡은 몬스터: 트리에서 빠질 때 체력이 0 이하인 것 (네크로맨서가 죽어 지역 씬이 바뀌며 빠진 것은 세지 않는다)
	var killed_set: Dictionary = {}
	for monster: Monster in kept:
		monster.tree_exiting.connect(func() -> void:
			if monster.health <= 0.0:
				killed_set[monster.get_instance_id()] = true)
	var fighting: bool = false
	## 탈출하면 네크로맨서가 씬과 함께 사라지므로, 마지막으로 본 체력을 남겨 둔다
	var last_health: float = max_health
	## 시간 초과한 판을 살펴보려고 TRACE_INTERVAL초마다 남기는 네크로맨서 위치
	var trace: Array[Vector2] = []
	while true:
		await physics_frame
		time += delta
		if result["died"]:
			break
		# 죽지 않았는데 지역 씬이 바뀌었으면 탈출 B로 거점에 간 것이다.
		if not is_instance_valid(necromancer) or current_scene == null or current_scene.scene_file_path != _scene:
			result["escaped"] = true
			break
		if _undead_attack_range > 0.0:
			_apply_undead_attack_range()
		if int(time / TRACE_INTERVAL) > trace.size() - 1:
			trace.append(necromancer.global_position)
		if time >= _timeout:
			result["timeout"] = true
			_print_timeout(run, necromancer, bot, escape_point, kept, trace)
			break
		last_health = necromancer.health
		if retreat != RETREAT_NEVER and not bot.retreating and (necromancer.health <= max_health * RETREAT_HEALTH_RATIO or (retreat == RETREAT_UNDEAD_OR_HEALTH and bot.lost_all_undead())):
			bot.retreat_to(escape_point)
		if bot.retreating:
			bot.tick(delta)
			continue
		var engaged: bool = false
		for monster: Variant in kept:
			if is_instance_valid(monster) and not (monster as Monster).is_queued_for_deletion() and (monster as Monster).health > 0.0 and (monster as Monster).get_target() != null:
				engaged = true
		if engaged:
			fighting = true
			bot.tick(delta)
			continue
		if fighting:
			bot.release_all()
			fighting = false
		if goal_index >= goals.size():
			break
		if necromancer.global_position.distance_to(goals[goal_index]) <= ARRIVE_DISTANCE:
			goal_index += 1
			press_moves(Vector2.ZERO)
			continue
		press_moves(follower.get_direction(necromancer, goals[goal_index]))
	if not result["escaped"]:
		bot.release_all()
	bot.finish_tracking(result["died"])
	result["time"] = time
	result["damage"] = max_health if result["died"] else (max_health - necromancer.health if is_instance_valid(necromancer) else max_health - last_health)
	# 언데드 둘 이상이 같은 물리 프레임에 죽은 판정이 되었는지
	var frames: Dictionary = {}
	result["undead_same_frame"] = false
	for frame: int in bot.undead_death_frames:
		result["undead_same_frame"] = result["undead_same_frame"] or frames.has(frame)
		frames[frame] = true
	result["killed"] = killed_set.size()
	result["kept"] = kept.size()
	result["shots"] = bot.shots
	result["hits"] = bot.hits
	result["undead_died"] = bot.undead_died
	return result


func _room_center(room: int) -> Vector2:
	return (_layout.rooms[room].center + Vector2(0.5, 0.5)) * TILE


## 쥐의 머리뼈를 count개 인벤토리에 넣고 핫바 칸에 차례로 놓는다.
func _give_undead(necromancer: Necromancer, count: int) -> Array[Skull]:
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	var skulls: Array[Skull] = []
	for i: int in count:
		var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
		necromancer.inventory.try_add(ItemStack.of_skull(skull))
		hotbar.assign(i, skull)
		skulls.append(skull)
	necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), UNDEAD_BONES))
	return skulls


## 얕은 굴을 새로 불러오고, 전역 상태(인벤토리·핫바)를 비운다.
func _reload_scene() -> void:
	await physics_frame
	await physics_frame
	root.get_node("GameState").call(&"reset_after_death")
	var old_scene: Node = current_scene
	change_scene_to_file(_scene)
	while current_scene == old_scene or current_scene == null or not current_scene.is_node_ready():
		await physics_frame


func _row(route_id: StringName, undead_count: int, retreat: int, skill_id: StringName, results: Array[Dictionary]) -> String:
	var died: int = results.filter(func(r: Dictionary) -> bool: return r["died"]).size()
	var escaped: int = results.filter(func(r: Dictionary) -> bool: return r["escaped"]).size()
	var same_frame: int = results.filter(func(r: Dictionary) -> bool: return r["undead_same_frame"]).size()
	var undead_lost_runs: int = results.filter(func(r: Dictionary) -> bool: return r["undead_died"] > 0).size()
	var timeouts: int = results.filter(func(r: Dictionary) -> bool: return r["timeout"]).size()
	var alive: Array = results.filter(func(r: Dictionary) -> bool: return not r["died"] and not r["timeout"])
	var times: Array = alive.map(func(r: Dictionary) -> float: return r["time"])
	var damages: Array = results.map(func(r: Dictionary) -> float: return r["damage"])
	var shots: int = 0
	var hits: int = 0
	var killed: int = 0
	var kept: int = 0
	var undead_died: int = 0
	for r: Dictionary in results:
		shots += r["shots"]
		hits += r["hits"]
		killed += r["killed"]
		kept += r["kept"]
		undead_died += r["undead_died"]
	return "| %s | %s | %s | %s | %d | %.0f%% | %.0f%% | %s | %.1f / %.1f | %.1f / %d | %.1f | %d / %d | %d | %s |" % [
		ROUTES[route_id]["name"], _condition_name(undead_count), RETREAT_NAMES[retreat], PlayerBot.SKILLS[skill_id]["name"], results.size(),
		100.0 * died / results.size(), 100.0 * escaped / results.size(), "%.1f초" % _mean(times) if not times.is_empty() else "-", _mean(damages), damages.max(),
		float(killed) / results.size(), kept / results.size(), float(undead_died) / results.size(), same_frame, undead_lost_runs, timeouts, "%.0f%%" % (100.0 * hits / shots) if shots > 0 else "-"]


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / values.size()


## 조건 열의 이름. 시험용 바꾼 값이 있으면 덧붙인다.
func _condition_name(undead_count: int) -> String:
	var label: String = "혼자" if undead_count == 0 else "쥐 언데드 %d" % undead_count
	if _undead_attack_range > 0.0:
		label += " (언데드 공격 거리 %.0f)" % _undead_attack_range
	return label




## 소환된 쥐 언데드를 공격 거리만 바꾼 데이터 복사본으로 바꾼다 (다시 소환되면 그때 다시 바꾼다).
func _apply_undead_attack_range() -> void:
	if _rat_undead_data == null:
		_rat_undead_data = (load(RAT_PATH) as MonsterData).duplicate()
		_rat_undead_data.undead_attack_range_override = _undead_attack_range
	for node: Node in get_nodes_in_group(&"undead"):
		var undead: Undead = node as Undead
		if undead != null and undead.data != _rat_undead_data and undead.data.id == _rat_undead_data.id:
			undead.data = _rat_undead_data


## 시간 초과한 판: 물러나는 중이었는지, 어디서 멈췄는지, 마지막 TRACE_TAIL초 동안 움직인 거리, 노리는 몬스터.
func _print_timeout(run: int, necromancer: Necromancer, bot: PlayerBot, escape_point: Vector2, kept: Array[Monster], trace: Array[Vector2]) -> void:
	var moved: float = 0.0
	for i: int in range(maxi(trace.size() - TRACE_TAIL, 1), trace.size()):
		moved += trace[i].distance_to(trace[i - 1])
	var hunters: PackedStringArray = []
	for monster: Variant in kept:
		if is_instance_valid(monster) and (monster as Monster).health > 0.0 and (monster as Monster).get_target() != null:
			hunters.append(_hunter_summary(monster as Monster, necromancer))
	print("시간 초과 판 %d: 물러나는 중 %s, 네크로맨서 칸 %s 체력 %.0f, 탈출 지점까지 %.0f px, 마지막 %d초 동안 움직인 거리 %.0f px, 지난 위치(칸) %s, 노리는 몬스터 %s" % [
		run, bot.retreating, (necromancer.global_position / TILE).floor(), necromancer.health, necromancer.global_position.distance_to(escape_point), TRACE_TAIL, moved,
		trace.slice(maxi(trace.size() - 8, 0)).map(func(p: Vector2) -> Vector2: return (p / TILE).floor()), hunters])


## 시간 초과 기록용 몬스터 요약: 종류, 칸, 체력, 대상까지 거리. 돌진하는 몬스터는 상태와 대상 쪽으로 벽까지 거리도.
func _hunter_summary(monster: Monster, necromancer: Necromancer) -> String:
	var text: String = "%s 칸 %s 체력 %.0f 거리 %.1f" % [monster.data.id, (monster.global_position / TILE).floor(), monster.health, monster.global_position.distance_to(necromancer.global_position)]
	var charge: ChargeBehavior = monster.get_behavior() as ChargeBehavior
	if charge != null:
		var rooms: PackedStringArray = []
		for i: int in 8:
			rooms.append("%.0f" % charge.get_room(monster, Vector2.from_angle(i * TAU / 8)))
		text += " 상태 %s 벽까지 %.0f, 8방향(동부터 시계) 벽까지 [%s], 물러날 방향 %s, 속도 %s" % [ChargeBehavior.State.keys()[charge.get_state()], charge.get_room(monster, monster.global_position.direction_to(necromancer.global_position)), ",".join(rooms), charge.call(&"_back_off_direction", monster, necromancer).snapped(Vector2(0.01, 0.01)), monster.velocity.round()]
	return text
