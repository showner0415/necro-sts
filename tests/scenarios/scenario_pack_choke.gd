extends ScenarioTest
## 시나리오: 좁은 길목 (계획 4b). 길목 시험 동굴(tests/choke_test_cave.tscn)에서 쥐를 코드로 놓는다.
## 굴에는 서로 막힌 두 구역이 있다: 위 구역은 2칸 폭 길목 아래에 3칸 폭 통로가 있어 돌아가는 길이 짧고(우회 비율 1.5 이하), 아래 구역은 돌아갈 길이 없다.
## 1. 구운 길목: 길목 둘, 위 길목은 우회 비율 1.5 이하, 아래 길목은 돌아갈 길 없음
## 2. 돌아갈 길이 없는 길목: 쥐 4마리가 길목 너머 네크로맨서를 쫓으면, 공격권 없이 길목에 들어가는 쥐가 없고,
##    공격권이 없는 쥐는 입구 밖 대기 자리에서 기다리며, 기다리는 동안 거리와 상관없이 공격권을 물어 받은 쥐는 길목에 들어간다
## 3. 기다리던 쥐가 대상을 잃으면(추격 포기) 대기 자리를 내놓는다 (같은 구역에 쥐를 새로 놓고 처음 기다리는 쥐를 포기시킨다)
## 4. 돌아가는 길목: 쥐 4마리가 길목 너머 네크로맨서를 쫓으면, 공격권 없이 길목에 들어가는 쥐가 없고, 기다리지 않고 아래 통로로 돌아간다
## 5. 실제 속도의 쥐가 돌아갈 길 없는 긴 길목(26칸, 약 21초)을 지나는 동안 공격권 시간 제한이 멈춰 공격권을 잃지 않는다
## 쥐는 데이터 복사로 배회 0·체력 크게·추격 포기 없음·빠르게 한다 (긴 길목을 짧은 시간에 지나게. 5단계만 실제 속도). 네크로맨서는 체력을 크게 한다. 실제 .tres는 바꾸지 않는다.

const CHOKE_SCENE: String = "res://tests/choke_test_cave.tscn"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const TOUGH_HEALTH: float = 100000.0
const RAT_SPEED: float = 120.0
const DETOUR_LIMIT: float = 1.5
## 구역마다 네크로맨서 자리와 쥐 자리 (월드 픽셀). 쥐는 왼쪽 굴, 네크로맨서는 오른쪽 굴
const FAR_NECRO: Vector2 = Vector2(1200, 480)
const FAR_RATS: Array[Vector2] = [Vector2(80, 420), Vector2(80, 560), Vector2(140, 420), Vector2(140, 560)]
const NEAR_NECRO: Vector2 = Vector2(1200, 128)
const NEAR_RATS: Array[Vector2] = [Vector2(80, 80), Vector2(80, 240), Vector2(140, 80), Vector2(140, 240)]
## 지켜보는 시간, 대기 자리에 닿았다고 볼 거리 (픽셀), 돌아가는 통로 (위 구역 7~9줄)의 위쪽·아래쪽 끝 y
const WATCH_FRAMES: int = 600
const SPOT_REACH: float = 24.0
## 포기한 뒤 대기 자리를 내놓았는지 볼 때까지 기다리는 프레임 (먼 몸은 4프레임에 한 번 판단한다)
const GIVE_UP_FRAMES: int = 10
## 실제 속도 쥐가 긴 길목을 지나기를 기다리는 최대 시간 (초)
const LONG_CHOKE_SECONDS: float = 45.0
const DETOUR_TOP: float = 7.0 * 32.0
const DETOUR_BOTTOM: float = 10.0 * 32.0

var _necromancer: Necromancer
var _grid: NavigationGrid
var _board: AttackTokenBoard


func get_start_scene() -> String:
	return CHOKE_SCENE


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	_necromancer.max_health = TOUGH_HEALTH
	_necromancer.health = TOUGH_HEALTH
	_grid = get_first_node_in_group(&"navigation_grid") as NavigationGrid
	_board = get_first_node_in_group(&"attack_tokens") as AttackTokenBoard
	await wait_frames(3)
	if not _baked_chokes():
		return
	if not await _wait_at_choke():
		return
	if not await _detour():
		finish(false)
		return
	finish(await _long_choke_keeps_token())


## 1. 구운 길목
func _baked_chokes() -> bool:
	var index: ChokeIndex = _grid.get_choke_index()
	if index == null or index.chokes.size() != 2:
		fail_step("구운 길목", "길목 %s (기대 2)" % ("없음" if index == null else str(index.chokes.size())))
		return false
	var near: float = index.chokes[index.choke_at(Vector2(640, 112))].detour_ratio(0, 1)
	var far: float = index.chokes[index.choke_at(Vector2(640, 470))].detour_ratio(0, 1)
	var ok: bool = near > 0.0 and near <= DETOUR_LIMIT and far < 0.0
	if ok:
		pass_step("구운 길목", "길목 2곳: 위 길목 우회 비율 %.2f (≤ %.1f), 아래 길목 돌아갈 길 없음" % [near, DETOUR_LIMIT])
	else:
		fail_step("구운 길목", "위 길목 우회 비율 %.2f, 아래 길목 %.2f" % [near, far])
	return ok


func _tough_rat() -> MonsterData:
	var data: MonsterData = (load(RAT_PATH) as MonsterData).duplicate()
	data.wander_speed = 0.0
	data.max_health = TOUGH_HEALTH
	data.move_speed = RAT_SPEED
	data.chase_attacker_limit = 0.0
	data.chase_lost_time = 0.0
	data.chase_time_limit = 0.0
	return data


func _spawn_rats(spots: Array[Vector2]) -> Array[Monster]:
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	var data: MonsterData = _tough_rat()
	var rats: Array[Monster] = []
	for spot: Vector2 in spots:
		var rat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		rat.data = data
		rat.position = spot
		_necromancer.get_parent().add_child(rat)
		rats.append(rat)
	return rats


## 쥐마다 길목 밖 → 안으로 들어가는 순간에 그 대상(네크로맨서)의 공격권을 들고 있었는지 센다.
## 돌려주는 값: {"entered_with": 공격권 들고 들어간 수, "entered_without": 없이 들어간 수, "waited": 대기 자리에 닿은 쥐 수, "detoured": 돌아가는 통로로 간 쥐 수}
func _watch(rats: Array[Monster], index: ChokeIndex) -> Dictionary:
	var inside: Dictionary = {}
	var waited: Dictionary = {}
	var detoured: Dictionary = {}
	var with_token: int = 0
	var without_token: int = 0
	for rat: Monster in rats:
		inside[rat] = index.choke_at(rat.global_position) >= 0
	for frame: int in WATCH_FRAMES:
		await wait_frames(1)
		for rat: Monster in rats:
			var now_inside: bool = index.choke_at(rat.global_position) >= 0
			if now_inside and not inside[rat]:
				if _board.tokens.held_target(rat) == _necromancer:
					with_token += 1
				else:
					without_token += 1
			inside[rat] = now_inside
			var follower: PathFollower = rat.get_path_follower()
			if follower.is_waiting_at_choke() and rat.global_position.distance_to(follower.get_waiting_spot()) <= SPOT_REACH:
				waited[rat] = true
			if rat.global_position.y > DETOUR_TOP and rat.global_position.y < DETOUR_BOTTOM and rat.global_position.x > 9.0 * 32.0:
				detoured[rat] = true
	return {"entered_with": with_token, "entered_without": without_token, "waited": waited.size(), "detoured": detoured.size()}


## 2. 돌아갈 길이 없는 길목에서 기다리기
func _wait_at_choke() -> bool:
	_necromancer.global_position = FAR_NECRO
	var rats: Array[Monster] = _spawn_rats(FAR_RATS)
	await wait_frames(3)
	for rat: Monster in rats:
		rat.take_damage(0.01, _necromancer)
	var seen: Dictionary = await _watch(rats, _grid.get_choke_index())
	var ok: bool = seen.entered_without == 0 and seen.waited >= 2 and seen.entered_with >= 1
	var evidence: String = "%.0f초 동안 쥐 %d마리: 공격권 없이 길목에 들어간 수 %d, 공격권을 들고 들어간 수 %d, 입구 밖 대기 자리에서 기다린 쥐 %d마리" % [
			WATCH_FRAMES / float(Engine.physics_ticks_per_second), rats.size(), seen.entered_without, seen.entered_with, seen.waited]
	if ok:
		pass_step("돌아갈 길이 없는 길목", evidence)
	else:
		fail_step("돌아갈 길이 없는 길목", evidence)
		return false
	return await _give_up_frees_spot()


## 3. 기다리던 쥐가 대상을 잃으면(추격 포기) 대기 자리를 내놓는다 (같은 구역에 쥐를 새로 놓고 처음 기다리는 쥐를 포기시킨다)
func _give_up_frees_spot() -> bool:
	var rats: Array[Monster] = _spawn_rats(FAR_RATS)
	await wait_frames(3)
	for rat: Monster in rats:
		rat.take_damage(0.01, _necromancer)
	var waiting: Monster = null
	for frame: int in WATCH_FRAMES:
		for rat: Monster in rats:
			if rat.get_path_follower().is_waiting_at_choke() and _grid.wait_spots.spot_index(rat) >= 0:
				waiting = rat
		if waiting != null:
			break
		await wait_frames(1)
	if waiting == null:
		fail_step("포기하면 대기 자리를 내놓음", "기다리는 쥐가 없음")
		return false
	var before: int = _grid.wait_spots.spot_index(waiting)
	waiting.clear_pack_target()
	await wait_frames(GIVE_UP_FRAMES)
	var freed: bool = waiting.get_target() == null and _grid.wait_spots.spot_index(waiting) < 0 and not waiting.get_path_follower().is_waiting_at_choke()
	var evidence: String = "포기 전 대기 자리 %d번, %d프레임 뒤 대상 %s, 대기 자리 %d (없음 -1), 기다리는 중 %s" % [
			before, GIVE_UP_FRAMES, waiting.get_target(), _grid.wait_spots.spot_index(waiting), waiting.get_path_follower().is_waiting_at_choke()]
	if freed:
		pass_step("포기하면 대기 자리를 내놓음", evidence)
	else:
		fail_step("포기하면 대기 자리를 내놓음", evidence)
	return freed


## 4. 돌아가는 길목
func _detour() -> bool:
	_necromancer.global_position = NEAR_NECRO
	var rats: Array[Monster] = _spawn_rats(NEAR_RATS)
	await wait_frames(3)
	for rat: Monster in rats:
		rat.take_damage(0.01, _necromancer)
	var seen: Dictionary = await _watch(rats, _grid.get_choke_index())
	var ok: bool = seen.entered_without == 0 and seen.waited == 0 and seen.detoured >= 2
	var evidence: String = "%.0f초 동안 쥐 %d마리: 공격권 없이 길목에 들어간 수 %d, 대기 자리에서 기다린 쥐 %d마리, 아래 통로로 돌아간 쥐 %d마리" % [
			WATCH_FRAMES / float(Engine.physics_ticks_per_second), rats.size(), seen.entered_without, seen.waited, seen.detoured]
	if ok:
		pass_step("돌아가는 길목", evidence)
	else:
		fail_step("돌아가는 길목", evidence)
	return ok


## 5. 실제 속도의 쥐가 돌아갈 길 없는 긴 길목을 지나는 동안 공격권 시간 제한이 멈춰 공격권을 잃지 않는다
func _long_choke_keeps_token() -> bool:
	_necromancer.global_position = FAR_NECRO
	var data: MonsterData = _tough_rat()
	data.move_speed = (load(RAT_PATH) as MonsterData).move_speed
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	var rat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	rat.data = data
	rat.position = FAR_RATS[0]
	_necromancer.get_parent().add_child(rat)
	await wait_frames(3)
	rat.take_damage(0.01, _necromancer)
	var index: ChokeIndex = _grid.get_choke_index()
	var frames: int = roundi(LONG_CHOKE_SECONDS * Engine.physics_ticks_per_second)
	var inside_frames: int = 0
	var lost_inside: int = 0
	var exited: bool = false
	for frame: int in frames:
		await wait_frames(1)
		var inside: bool = index.choke_at(rat.global_position) >= 0
		if inside:
			inside_frames += 1
			if _board.tokens.held_target(rat) != _necromancer:
				lost_inside += 1
		elif inside_frames > 0:
			exited = true
			break
	var seconds: float = inside_frames / float(Engine.physics_ticks_per_second)
	var ok: bool = exited and lost_inside == 0 and seconds > _board.hold_time_limit
	var evidence: String = "속도 %.0f 쥐가 길목 안에 %.1f초 (공격권 시간 제한 %.0f초), 길목 안에서 공격권 없던 프레임 %d, 빠져나옴 %s" % [data.move_speed, seconds, _board.hold_time_limit, lost_inside, exited]
	if ok:
		pass_step("긴 길목에서 공격권 유지", evidence)
	else:
		fail_step("긴 길목에서 공격권 유지", evidence)
	return ok
