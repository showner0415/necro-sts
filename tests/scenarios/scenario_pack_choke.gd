extends ScenarioTest
## 시나리오: 좁은 길목 (계획 4b). 길목 시험 동굴(tests/choke_test_cave.tscn)에서 쥐를 코드로 놓는다.
## 굴에는 서로 막힌 두 구역이 있다: 위 구역은 2칸 폭 길목 아래에 3칸 폭 통로가 있어 돌아가는 길이 짧고(우회 비율 1.5 이하), 아래 구역은 돌아갈 길이 없다.
## 1. 구운 길목: 길목 둘, 위 길목은 우회 비율 1.5 이하, 아래 길목은 돌아갈 길 없음
## 2. 돌아갈 길이 없는 길목: 쥐 4마리가 길목 너머 네크로맨서를 쫓으면, 통행 자리 없이 길목에 들어가는 쥐가 없고,
##    통행 자리가 없는 쥐는 입구 밖 대기 자리에서 기다리며, 기다리는 동안 거리와 상관없이 통행 자리를 물어 받은 쥐는 길목에 들어간다.
##    기다리는 쥐는 공격권(추가 공격권 포함)을 묻지 않아 들지 않는다 (봇 측정 5b, 사용자 결정 2026-11-15)
## 3. 기다리던 쥐가 대상을 잃으면(추격 포기) 대기 자리를 내놓는다 (같은 구역에 쥐를 새로 놓고 처음 기다리는 쥐를 포기시킨다)
## 4. 돌아가는 길목: 쥐 4마리가 길목 너머 네크로맨서를 쫓으면, 통행 자리 없이 길목에 들어가는 쥐가 없고, 기다리지 않고 아래 통로로 돌아간다
## 5. 실제 속도의 쥐가 돌아갈 길 없는 긴 길목(26칸, 약 21초)을 지나는 동안 시간 제한이 멈춰 통행 자리를 잃지 않고,
##    대상에게서 먼 길목 안에서는 공격권을 들지 않으며(대상의 공격권 칸을 비움), 길목을 나오면 통행 자리를 반납한다
## 6. 대상이 길목 입구 가까이(묻는 거리 안)에 있을 때: 투석병 둘이 길목 안 입구에서 3칸 들어간 네크로맨서를 노리면, 통행 자리 없이 길목에 들어가는 투석병이 없고,
##    입구에서 기다리는 투석병은 대상이 묻는 거리(지금 186px) 안이어도 공격권을 들지 않는다 (기다리는 동안은 통행 자리만 묻는다)
## 7. 공격권을 든 쥐가 길목 입구에서 기다리게 되면(곁의 네크로맨서가 길목 안으로 들어감) 기다리는 동안 공격권을 들지 않는다 (기다리기 시작하면 반납, 사용자 결정 2026-11-15)
## 쥐는 데이터 복사로 배회 0·체력 크게·추격 포기 없음·빠르게 한다 (긴 길목을 짧은 시간에 지나게. 5단계만 실제 속도). 네크로맨서는 체력을 크게 한다. 실제 .tres는 바꾸지 않는다.

const CHOKE_SCENE: String = "res://tests/choke_test_cave.tscn"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const GOBLIN_PATH: String = "res://data/monsters/goblin_slinger.tres"
## 6단계: 네크로맨서를 아래 길목 왼쪽 입구에서 길목 안쪽으로 이만큼 들여 세운다 (픽셀, 3칸). 투석병의 묻는 거리(지금 186px)가 대기 자리까지 닿게
const NEAR_ENTRANCE_DEPTH: float = 96.0
## 7단계: 쥐가 공격권을 받으면 네크로맨서를 아래 길목 왼쪽 입구에서 이만큼 안으로 옮긴다 (픽셀, 5칸. 쥐가 길목을 피해 기다리게)
const MOVE_INTO_CHOKE_DEPTH: float = 160.0
## 7단계: 쥐 곁에 둘 네크로맨서 자리 (왼쪽 굴, 쥐가 공격권을 묻는 거리 안)
const NEAR_RAT_NECRO: Vector2 = Vector2(200, 490)
const NEAR_RAT_SPOT: Vector2 = Vector2(150, 490)
## 7단계: 쥐가 공격권을 받기를 기다리는 최대 프레임, 옮긴 뒤 지켜보는 프레임
const TOKEN_WAIT_FRAMES: int = 180
const AFTER_MOVE_FRAMES: int = 120
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
## 5단계에서 "대상에게서 먼" 길목 안이라고 볼 거리 (픽셀). 쥐가 공격권을 묻는 거리(맴도는 거리 64 + 16)보다 넉넉히 길다
const FAR_FROM_TARGET: float = 200.0

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
	if not await _long_choke_keeps_pass():
		finish(false)
		return
	if not await _near_entrance_waits_without_token():
		finish(false)
		return
	finish(await _waiting_releases_held_token())


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


## 쥐마다 길목 밖 → 안으로 들어가는 순간에 그 대상(네크로맨서)의 통행 자리를 들고 있었는지 센다.
## 돌려주는 값: {"entered_with": 통행 자리 들고 들어간 수, "entered_without": 없이 들어간 수, "waited": 대기 자리에 닿은 쥐 수,
## "detoured": 돌아가는 통로로 간 쥐 수, "waiting_token_frames": 대기 자리에서 기다리는 쥐가 공격권을 든 프레임 수}
## ask_distance가 0보다 크면 "waiting_near_frames"(기다리는 몸이 대상에게서 그 거리 안에 있던 프레임 수)도 센다.
func _watch(rats: Array[Monster], index: ChokeIndex, ask_distance: float = 0.0) -> Dictionary:
	var inside: Dictionary = {}
	var waited: Dictionary = {}
	var detoured: Dictionary = {}
	var with_pass: int = 0
	var without_pass: int = 0
	var waiting_token_frames: int = 0
	var waiting_near_frames: int = 0
	for rat: Monster in rats:
		inside[rat] = index.choke_at(rat.global_position) >= 0
	for frame: int in WATCH_FRAMES:
		await wait_frames(1)
		for rat: Monster in rats:
			var now_inside: bool = index.choke_at(rat.global_position) >= 0
			if now_inside and not inside[rat]:
				if _board.passes.held_target(rat) == _necromancer:
					with_pass += 1
				else:
					without_pass += 1
			inside[rat] = now_inside
			var follower: PathFollower = rat.get_path_follower()
			if follower.is_waiting_at_choke():
				if rat.global_position.distance_to(follower.get_waiting_spot()) <= SPOT_REACH:
					waited[rat] = true
				if _board.tokens.is_holding(rat):
					waiting_token_frames += 1
				if ask_distance > 0.0 and rat.global_position.distance_to(_necromancer.global_position) <= ask_distance:
					waiting_near_frames += 1
			if rat.global_position.y > DETOUR_TOP and rat.global_position.y < DETOUR_BOTTOM and rat.global_position.x > 9.0 * 32.0:
				detoured[rat] = true
	return {"entered_with": with_pass, "entered_without": without_pass, "waited": waited.size(), "detoured": detoured.size(), "waiting_token_frames": waiting_token_frames, "waiting_near_frames": waiting_near_frames}


## 2. 돌아갈 길이 없는 길목에서 기다리기
func _wait_at_choke() -> bool:
	_necromancer.global_position = FAR_NECRO
	var rats: Array[Monster] = _spawn_rats(FAR_RATS)
	await wait_frames(3)
	for rat: Monster in rats:
		rat.take_damage(0.01, _necromancer)
	var seen: Dictionary = await _watch(rats, _grid.get_choke_index())
	var ok: bool = seen.entered_without == 0 and seen.waited >= 2 and seen.entered_with >= 1 and seen.waiting_token_frames == 0
	var evidence: String = "%.0f초 동안 쥐 %d마리: 통행 자리 없이 길목에 들어간 수 %d, 통행 자리를 들고 들어간 수 %d, 입구 밖 대기 자리에서 기다린 쥐 %d마리, 기다리는 쥐가 공격권을 든 프레임 %d" % [
			WATCH_FRAMES / float(Engine.physics_ticks_per_second), rats.size(), seen.entered_without, seen.entered_with, seen.waited, seen.waiting_token_frames]
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
	var evidence: String = "%.0f초 동안 쥐 %d마리: 통행 자리 없이 길목에 들어간 수 %d, 대기 자리에서 기다린 쥐 %d마리, 아래 통로로 돌아간 쥐 %d마리" % [
			WATCH_FRAMES / float(Engine.physics_ticks_per_second), rats.size(), seen.entered_without, seen.waited, seen.detoured]
	if ok:
		pass_step("돌아가는 길목", evidence)
	else:
		fail_step("돌아가는 길목", evidence)
	return ok


## 5. 실제 속도의 쥐가 돌아갈 길 없는 긴 길목을 지나는 동안 시간 제한이 멈춰 통행 자리를 잃지 않고,
##    대상에게서 먼 길목 안에서는 공격권을 들지 않으며, 길목을 나오면 통행 자리를 반납한다
func _long_choke_keeps_pass() -> bool:
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
	var far_token_frames: int = 0
	var exited: bool = false
	for frame: int in frames:
		await wait_frames(1)
		var inside: bool = index.choke_at(rat.global_position) >= 0
		if inside:
			inside_frames += 1
			if _board.passes.held_target(rat) != _necromancer:
				lost_inside += 1
			if _board.tokens.is_holding(rat) and rat.global_position.distance_to(_necromancer.global_position) > FAR_FROM_TARGET:
				far_token_frames += 1
		elif inside_frames > 0:
			exited = true
			break
	# 길목을 나온 뒤 한 프레임이 지나야 반납이 보인다 (반납은 그 몸의 물리 프레임에서 한다)
	await wait_frames(1)
	var released: bool = not _board.passes.is_holding(rat)
	var seconds: float = inside_frames / float(Engine.physics_ticks_per_second)
	var ok: bool = exited and lost_inside == 0 and far_token_frames == 0 and released and seconds > _board.hold_time_limit
	var evidence: String = "속도 %.0f 쥐가 길목 안에 %.1f초 (시간 제한 %.0f초), 길목 안에서 통행 자리 없던 프레임 %d, 대상에게서 %.0fpx 넘게 먼 길목 안에서 공격권을 든 프레임 %d, 빠져나옴 %s, 나온 뒤 통행 자리 반납 %s" % [
			data.move_speed, seconds, _board.hold_time_limit, lost_inside, FAR_FROM_TARGET, far_token_frames, exited, released]
	if ok:
		pass_step("긴 길목에서 통행 자리 유지", evidence)
	else:
		fail_step("긴 길목에서 통행 자리 유지", evidence)
	return ok


## 6. 대상이 길목 입구 가까이(묻는 거리 안)에 있을 때: 투석병 둘이 돌아갈 길 없는 길목 안 입구 가까이 선 네크로맨서를 노리면,
##    통행 자리 없이 길목에 들어가는 투석병이 없고, 입구에서 기다리는 투석병은 대상이 묻는 거리 안이어도 공격권을 들지 않는다
func _near_entrance_waits_without_token() -> bool:
	var index: ChokeIndex = _grid.get_choke_index()
	var far_choke: int = index.choke_at(Vector2(640, 470))
	var entrances: PackedVector2Array = index.chokes[far_choke].entrances
	var left: Vector2 = entrances[0]
	for entrance: Vector2 in entrances:
		if entrance.x < left.x:
			left = entrance
	_necromancer.global_position = left + Vector2(NEAR_ENTRANCE_DEPTH, 0.0)
	if index.choke_at(_necromancer.global_position) != far_choke:
		fail_step("입구 가까운 대상", "네크로맨서 자리 %s가 아래 길목 안이 아님 (왼쪽 입구 %s)" % [_necromancer.global_position, left])
		return false
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	var data: MonsterData = (load(GOBLIN_PATH) as MonsterData).duplicate()
	data.wander_speed = 0.0
	data.max_health = TOUGH_HEALTH
	data.chase_attacker_limit = 0.0
	data.chase_lost_time = 0.0
	data.chase_time_limit = 0.0
	var goblins: Array[Monster] = []
	for i: int in 2:
		var goblin: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		goblin.data = data
		goblin.position = FAR_RATS[i]
		_necromancer.get_parent().add_child(goblin)
		goblins.append(goblin)
	await wait_frames(3)
	for goblin: Monster in goblins:
		goblin.take_damage(0.01, _necromancer)
	# 묻는 거리는 행동 조각이 데이터에서 셈한 값을 그대로 쓴다 (값이 바뀌어도 "묻는 거리 안" 경우를 따라가게)
	var ask_distance: float = data.behavior.get_token_ask_distance(data.get_enemy_stats())
	var seen: Dictionary = await _watch(goblins, index, ask_distance)
	var ok: bool = seen.entered_without == 0 and seen.waiting_token_frames == 0 and seen.waiting_near_frames > 0
	var evidence: String = "%.0f초 동안 투석병 %d마리, 네크로맨서는 왼쪽 입구에서 %.0fpx 안: 통행 자리 없이 길목에 들어간 수 %d, 통행 자리를 들고 들어간 수 %d, 대기 자리에서 기다린 투석병 %d마리, 기다리며 대상이 묻는 거리(%.0fpx) 안이던 프레임 %d, 기다리며 공격권을 든 프레임 %d" % [
			WATCH_FRAMES / float(Engine.physics_ticks_per_second), goblins.size(), NEAR_ENTRANCE_DEPTH, seen.entered_without, seen.entered_with, seen.waited, ask_distance, seen.waiting_near_frames, seen.waiting_token_frames]
	if ok:
		pass_step("입구 가까운 대상", evidence)
	else:
		fail_step("입구 가까운 대상", evidence)
	return ok


## 7. 공격권을 든 쥐가 길목 입구에서 기다리게 되면 그 공격권을 반납한다: 쥐가 곁의 네크로맨서에게서 공격권을 받는 순간
##    네크로맨서를 아래 길목 안으로 옮기면, 쥐는 통행 자리 없이 길목을 피해 기다리게 되고 기다리는 동안 공격권을 들지 않는다
func _waiting_releases_held_token() -> bool:
	var index: ChokeIndex = _grid.get_choke_index()
	var far_choke: int = index.choke_at(Vector2(640, 470))
	var entrances: PackedVector2Array = index.chokes[far_choke].entrances
	var left: Vector2 = entrances[0]
	for entrance: Vector2 in entrances:
		if entrance.x < left.x:
			left = entrance
	_necromancer.global_position = NEAR_RAT_NECRO
	var rats: Array[Monster] = _spawn_rats([NEAR_RAT_SPOT])
	var rat: Monster = rats[0]
	await wait_frames(3)
	rat.take_damage(0.01, _necromancer)
	var held: bool = false
	for frame: int in TOKEN_WAIT_FRAMES:
		await wait_frames(1)
		if _board.tokens.held_target(rat) == _necromancer:
			held = true
			break
	if not held:
		fail_step("기다리면 든 공격권 반납", "%d프레임 안에 쥐가 공격권을 받지 못함" % TOKEN_WAIT_FRAMES)
		return false
	_necromancer.global_position = left + Vector2(MOVE_INTO_CHOKE_DEPTH, 0.0)
	var waiting_frames: int = 0
	var waiting_token_frames: int = 0
	for frame: int in AFTER_MOVE_FRAMES:
		await wait_frames(1)
		if rat.get_path_follower().is_waiting_at_choke():
			waiting_frames += 1
			if _board.tokens.is_holding(rat):
				waiting_token_frames += 1
	var ok: bool = waiting_frames > 0 and waiting_token_frames == 0 and index.choke_at(_necromancer.global_position) == far_choke
	var evidence: String = "공격권을 든 쥐 곁의 네크로맨서를 길목 안(왼쪽 입구에서 %.0fpx)으로 옮긴 뒤 %d프레임: 쥐가 기다린 프레임 %d, 기다리며 공격권을 든 프레임 %d" % [
			MOVE_INTO_CHOKE_DEPTH, AFTER_MOVE_FRAMES, waiting_frames, waiting_token_frames]
	if ok:
		pass_step("기다리면 든 공격권 반납", evidence)
	else:
		fail_step("기다리면 든 공격권 반납", evidence)
	return ok
