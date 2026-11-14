extends ShallowCaveScenario
## 시나리오: 얕은 굴을 걷기. 구조는 scenario_shallow_cave.gd, 언데드는 scenario_shallow_cave_undead.gd.
## 8. 구간별 걷기 시간 (걷기, 몬스터는 없앰): 도착 지점 → 입구 굴, 입구 굴 → 갈림 굴, 갈림 굴 → 합류 굴(박쥐 길, 거미 길),
##    합류 굴 → 동굴 입구, 도착 지점 → 동굴 입구 전체. 문서 기준값과 함께 출력한다
## 11. 갈림 굴에서 갈림길 하나(박쥐 길, 거미 길 각각)를 넘어 합류 굴의 탈출 B로 거점에 간다. 그동안 멧돼지는 아무도 노리지 않는다 (멧돼지만 남긴다)
## 12. 지역을 나갔다 다시 들어오면 몬스터가 처음 상태로 다시 놓인다 (임시 규칙)

const BASE_SCENE: String = "res://regions/base.tscn"
const CAVE_REGION: String = "res://data/regions/shallow_cave.tres"
const BASE_REGION: String = "res://data/regions/base.tres"
## 문서(docs/maps/shallow_cave_design.md 4장)의 걷기 시간 기준 (초)
const TARGET_TO_ENTRANCE: float = 10.0
const TARGET_TO_FORK: float = 40.0
const TARGET_FORK_TO_JUNCTION: float = 60.0
const TARGET_JUNCTION_TO_MOUTH: float = 25.0
const TARGET_TOTAL: float = 210.0
const SCENE_TIMEOUT_FRAMES: int = 300
## 11. 탈출 지점에 선 뒤 거점에 가기를 기다리는 최대 프레임 (탈출 3초 + 여유)
const ESCAPE_WAIT_FRAMES: int = 60 * 5


func _run_steps() -> void:
	if not _find_roles():
		return
	if not await _walk_times():
		return
	if not await _escape_without_boars():
		return
	if not await _monsters_reset():
		return
	finish(true)


# --- 8. 걷기 시간 ---

func _walk_times() -> bool:
	for node: Node in get_nodes_in_group(&"monsters"):
		node.queue_free()
	await wait_frames(2)
	var necromancer: Necromancer = find_necromancer()
	var spawn: Vector2 = _cell_center(_layout.cells_of("spawn")[0])
	necromancer.global_position = spawn
	await wait_frames(2)
	var nav: NavigationGrid = current_scene.get_node("NavigationGrid")
	var started: int = Time.get_ticks_msec()
	nav.get_grid(Vector2(necromancer.body_radius, necromancer.body_radius))
	var grid_ms: int = Time.get_ticks_msec() - started
	var to_entrance: float = await _walk_to(necromancer, _room_center(_roles.entrance))
	var to_fork: float = await _walk_to(necromancer, _room_center(_roles.fork))
	var bat_path: float = await _walk_rooms(necromancer, ["bat_nest", "junction"])
	var to_mouth: float = await _walk_rooms(necromancer, ["cave_mouth"])
	await _walk_to(necromancer, _room_center(_roles.junction))
	# 거미 길은 합류 굴에서 거꾸로 걸어 잰다 (같은 길이다)
	var spider_path: float = await _walk_rooms(necromancer, ["egg", "web", "spider_gate", "fork"])
	necromancer.global_position = spawn
	await wait_frames(2)
	var total: float = await _walk_to(necromancer, _room_center(_roles.cave_mouth))
	var ok: bool = to_entrance > 0.0 and to_fork > 0.0 and bat_path > 0.0 and spider_path > 0.0 and to_mouth > 0.0 and total > 0.0
	return _check("구간별 걷기 시간", ok, "도착 지점 → 입구 굴 %s (기준 약 %.0f초), 입구 굴 → 갈림 굴 %s (기준 약 %.0f초), 갈림 굴 → 합류 굴 박쥐 길 %s · 거미 길 %s (기준 약 %.0f초, 굴 가운데를 지나며), 합류 굴 → 동굴 입구 %s (기준 약 %.0f초), 도착 지점 → 동굴 입구 전체 %s (가장 짧은 길, 기준 약 %.0f초), 걷기 %.0f/초, 네크로맨서 크기 길찾기 칸 계산 %dms" % [
		_seconds(to_entrance), TARGET_TO_ENTRANCE, _seconds(to_fork), TARGET_TO_FORK, _seconds(bat_path), _seconds(spider_path), TARGET_FORK_TO_JUNCTION,
		_seconds(to_mouth), TARGET_JUNCTION_TO_MOUTH, _seconds(total), TARGET_TOTAL, necromancer.move_speed, grid_ms])


## 굴 역할 순서대로 굴 가운데를 지나 걷는다. 걸린 시간 합(초), 하나라도 못 가면 -1
func _walk_rooms(necromancer: Necromancer, roles: Array) -> float:
	var total: float = 0.0
	for role: String in roles:
		var walked: float = await _walk_to(necromancer, _room_center(_roles[role]))
		if walked < 0.0:
			return -1.0
		total += walked
	return total


# --- 11. 갈림길 하나를 넘어 멧돼지를 만나지 않고 탈출 B ---

func _escape_without_boars() -> bool:
	var results: PackedStringArray = []
	for route: Array in [["bat_nest", "junction"], ["spider_gate", "web", "egg", "junction"]]:
		current_scene.call(&"travel_to", load(BASE_REGION))
		if not await _wait_scene(BASE_SCENE):
			return _check("탈출 B까지 멧돼지 없이", false, "거점에 가지 못함")
		current_scene.call(&"travel_to", load(CAVE_REGION))
		if not await _wait_scene(CAVE_SCENE):
			return _check("탈출 B까지 멧돼지 없이", false, "얕은 굴에 다시 들어가지 못함")
		await wait_frames(SETTLE_FRAMES)
		var boars: Array[Monster] = []
		for node: Node in get_nodes_in_group(&"monsters"):
			if (node as Monster).data.id == &"boar":
				boars.append(node as Monster)
			else:
				node.queue_free()
		var necromancer: Necromancer = find_necromancer()
		necromancer.global_position = _room_center(_roles.fork)
		await wait_frames(2)
		var goals: Array[Vector2] = []
		for role: String in route:
			goals.append(_room_center(_roles[role]))
		for cell: Vector2i in _layout.cells_of("escape"):
			if _layout.room_at(cell) == _roles.junction:
				goals.append(_cell_center(cell))
		var targeted: PackedStringArray = []
		var frames: int = 0
		var follower: PathFollower = PathFollower.new(Vector2(necromancer.body_radius, necromancer.body_radius), Vector2(0, -necromancer.body_radius))
		for goal: Vector2 in goals:
			while necromancer.global_position.distance_to(goal) > ARRIVE_DISTANCE and frames < WALK_TIMEOUT_FRAMES:
				press_moves(follower.get_direction(necromancer, goal))
				await wait_frames(1)
				frames += 1
				_note_boar_targets(boars, targeted)
		press_moves(Vector2.ZERO)
		var escaped: bool = false
		for i: int in ESCAPE_WAIT_FRAMES:
			await wait_frames(1)
			if current_scene != null and current_scene.scene_file_path == BASE_SCENE:
				escaped = true
				break
			_note_boar_targets(boars, targeted)
		var name: String = "박쥐 길" if route[0] == "bat_nest" else "거미 길"
		results.append("%s: 갈림 굴 → 탈출 B %.1f초, 거점 도착 %s, 멧돼지 %d마리 중 누군가를 노린 멧돼지 %s" % [name, frames / float(Engine.physics_ticks_per_second), escaped, boars.size(), targeted])
		if not escaped or not targeted.is_empty() or boars.is_empty():
			return _check("탈출 B까지 멧돼지 없이", false, " / ".join(results))
	return _check("탈출 B까지 멧돼지 없이", true, "멧돼지만 남긴 채 갈림 굴에서 걸음: " + " / ".join(results))


func _note_boar_targets(boars: Array[Monster], targeted: PackedStringArray) -> void:
	for boar: Monster in boars:
		if is_instance_valid(boar) and boar.get_target() != null and not targeted.has(boar.name):
			targeted.append(boar.name)


# --- 12. 다시 들어오면 몬스터가 다시 놓임 ---

func _monsters_reset() -> bool:
	current_scene.call(&"travel_to", load(BASE_REGION))
	if not await _wait_scene(BASE_SCENE):
		return _check("거점으로", false, "거점에 가지 못함")
	current_scene.call(&"travel_to", load(CAVE_REGION))
	if not await _wait_scene(CAVE_SCENE):
		return _check("얕은 굴로", false, "얕은 굴에 다시 들어가지 못함")
	await wait_frames(SETTLE_FRAMES)
	var count: int = get_nodes_in_group(&"monsters").size()
	return _check("다시 들어오면 몬스터가 처음대로", count == _expected_monsters(), "몬스터를 없앤 뒤 거점에 갔다 오니 몬스터 %d마리 (PNG의 한 마리 %d + 무리원 %d)" % [count, _monster_cells(), _expected_monsters() - _monster_cells()])


func _wait_scene(path: String) -> bool:
	for i: int in SCENE_TIMEOUT_FRAMES:
		await wait_frames(1)
		if current_scene != null and current_scene.scene_file_path == path and current_scene.is_node_ready():
			return true
	return false
