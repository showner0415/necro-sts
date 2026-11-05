extends ScenarioTest
## 시나리오: 탈출과 거점, 죽었을 때 잃는 것.
## 1. 탈출 지점에 들어가면 게이지가 차고, 중간에 피해를 받아도 끊기지 않는다 (1.5초에 절반)
## 2. 다 차기 전에 벗어나면 게이지가 처음으로 돌아가고 숨는다
## 3. 다시 들어가 3초 있으면 거점으로 간다. 인벤토리는 그대로, 소환 중이던 언데드는 일반 해제(죽은 판정 아님)
## 4. 거점에는 몬스터가 없고, 출구에 서면 "[F] …(으)로" 안내가 뜨고 F로 지역에 간다
## 5. 지역에서 죽으면 인벤토리를 전부 잃고 거점에서 다시 시작한다

const WAIT_FRAMES: int = 3
const PHYSICS_FPS: float = 60.0
const HALF_FRAMES: int = 90
const SCENE_TIMEOUT_FRAMES: int = 400
const BASE_SCENE: String = "res://regions/base.tscn"
const REGION_SCENE: String = "res://regions/test_region.tscn"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const START_BONES: int = 10
## 탈출 지점에서 이만큼 떨어지면 원 밖이다
const OUTSIDE_OFFSET: Vector2 = Vector2(0, 100)

var _game_state: Node
var _bone: ItemData
## 탈출하며 일반 해제되었는지 기록 (unsummoned 시그널의 died)
var _unsummon_events: Array[bool] = []


func get_start_scene() -> String:
	return TEST_REGION_SCENE


func _on_scene_ready() -> void:
	_run()


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
	return ok


func _find_escape_point() -> EscapePoint:
	return current_scene.find_children("*", "EscapePoint", true, false).front()


## 현재 씬이 path가 될 때까지 기다린다. 걸린 물리 프레임 수를 돌려주고, 시간이 지나면 -1.
func _wait_for_scene(path: String) -> int:
	for i: int in SCENE_TIMEOUT_FRAMES:
		await wait_frames(1)
		if current_scene != null and current_scene.scene_file_path == path and current_scene.is_node_ready():
			await wait_frames(WAIT_FRAMES)
			return i + 1
	return -1


func _describe_inventory() -> String:
	var inventory: Inventory = _game_state.inventory
	return "뼈 %d, 머리뼈 %d, 핫바 [%s, %s]" % [inventory.get_count(_bone.id), inventory.get_skulls().size(), _game_state.hotbar.get_skull(0) != null, _game_state.hotbar.get_skull(1) != null]


func _run() -> void:
	_game_state = root.get_node("GameState")
	_bone = load(BONE_PATH)
	var necromancer: Necromancer = find_necromancer()
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	necromancer.inventory.try_add(ItemStack.of_skull(skull))
	necromancer.inventory.try_add(ItemStack.of_item(_bone, START_BONES))
	_game_state.hotbar.assign(0, skull)
	necromancer.summoner.toggle_selected()
	necromancer.summoner.roster.unsummoned.connect(func(_s: Skull, died: bool) -> void: _unsummon_events.append(died))
	if not _check("준비", necromancer.summoner.roster.is_summoned(skull), "쥐 언데드 소환 중 %s, %s" % [necromancer.summoner.roster.is_summoned(skull), _describe_inventory()]):
		return
	var hud: Hud = find_hud()
	var point: EscapePoint = _find_escape_point()

	# 1. 들어가서 절반 + 중간에 피해
	necromancer.global_position = point.global_position
	await wait_frames(HALF_FRAMES / 2)
	var before_hit: float = hud.get_escape_progress()
	necromancer.take_damage(1.0)
	await wait_frames(HALF_FRAMES / 2)
	var evidence: String = "%d프레임(%.1f초): 게이지 %.2f (피해 직전 %.2f), 게이지 보임 %s, 네크로맨서 체력 %.0f" % [
		HALF_FRAMES, HALF_FRAMES / PHYSICS_FPS, hud.get_escape_progress(), before_hit, hud.is_escape_gauge_visible(), necromancer.health]
	if not _check("게이지가 차고 피해로 끊기지 않음", absf(hud.get_escape_progress() - 0.5) < 0.05 and hud.get_escape_progress() > before_hit and hud.is_escape_gauge_visible(), evidence):
		return

	# 2. 벗어나면 초기화
	necromancer.global_position = point.global_position + OUTSIDE_OFFSET
	await wait_frames(WAIT_FRAMES)
	if not _check("벗어나면 게이지 초기화", hud.get_escape_progress() == 0.0 and not hud.is_escape_gauge_visible() and point.get_progress() == 0.0,
			"원 밖으로 옮긴 뒤 게이지 %.2f, 보임 %s, 아직 지역 %s" % [hud.get_escape_progress(), hud.is_escape_gauge_visible(), current_scene.scene_file_path == REGION_SCENE]):
		return

	# 3. 3초 있으면 거점
	var health_before: float = skull.health
	var durability_before: float = skull.durability
	var region_health: float = necromancer.health
	var region_mana: float = necromancer.mana.current
	necromancer.global_position = point.global_position
	var frames: int = await _wait_for_scene(BASE_SCENE)
	var seconds: float = frames / PHYSICS_FPS
	evidence = "들어간 뒤 %d프레임(%.2f초) 만에 거점 도착, 해제 기록 %s (true면 죽은 판정), 머리뼈 체력 %.1f → %.1f, 내구도 %.0f → %.0f, %s" % [
		frames, seconds, _unsummon_events, health_before, skull.health, durability_before, skull.durability, _describe_inventory()]
	var kept: bool = _game_state.inventory.get_skulls().has(skull) and _game_state.inventory.get_count(_bone.id) == START_BONES - roster_bone_cost(skull)
	if not _check("3초 뒤 거점 도착", frames > 0 and seconds >= 3.0 and seconds < 3.2 and _unsummon_events == [false] and kept, evidence):
		return

	# 3-1. 거점에 오면 체력과 마나가 가득 참
	necromancer = find_necromancer()
	evidence = "지역에서 체력 %.0f / 마나 %.1f → 거점에서 체력 %.0f / %.0f, 마나 %.1f / %.1f" % [
		region_health, region_mana, necromancer.health, necromancer.max_health, necromancer.mana.current, necromancer.mana.maximum]
	if not _check("거점에 오면 체력·마나 가득", region_health < necromancer.max_health and region_mana < necromancer.mana.maximum
			and necromancer.health == necromancer.max_health and necromancer.mana.current == necromancer.mana.maximum, evidence):
		return

	# 4. 거점: 몬스터 없음, 출구 안내와 F
	var monsters: int = get_nodes_in_group(&"monsters").size()
	var exit: RegionExit = current_scene.find_children("*", "RegionExit", true, false).front()
	necromancer.global_position = exit.global_position
	await wait_frames(WAIT_FRAMES)
	evidence = "몬스터 %d마리, 출구 안내 보임 %s ('%s'), 소환 중 %d마리, 네크로맨서 체력 %.0f / %.0f" % [
		monsters, exit.is_prompt_visible(), exit.get_prompt_text(), necromancer.summoner.roster.get_count(), necromancer.health, necromancer.max_health]
	if not _check("거점", monsters == 0 and exit.is_prompt_visible() and exit.get_prompt_text() == "[F] 시험 지역(으)로" and necromancer.summoner.roster.get_count() == 0, evidence):
		return
	press_key(KEY_F, true)
	press_key(KEY_F, false)
	frames = await _wait_for_scene(REGION_SCENE)
	if not _check("F로 지역에 나감", frames > 0, "F를 누른 뒤 %d프레임 만에 %s, %s" % [frames, current_scene.scene_file_path, _describe_inventory()]):
		return

	# 5. 죽으면 전부 잃고 거점
	necromancer = find_necromancer()
	var before: String = _describe_inventory()
	necromancer.take_damage(necromancer.max_health)
	frames = await _wait_for_scene(BASE_SCENE)
	var empty: bool = true
	for i: int in _game_state.inventory.get_slot_count():
		if _game_state.inventory.get_slot(i) != null:
			empty = false
	if not _check("죽으면 전부 잃고 거점", frames > 0 and empty and _game_state.hotbar.get_skull(0) == null,
			"죽기 전 %s → %d프레임 만에 %s, 죽은 뒤 %s, 인벤토리 전부 빔 %s" % [before, frames, current_scene.scene_file_path, _describe_inventory(), empty]):
		return
	finish(true)


## 처음 소환에 쓴 뼈 개수
func roster_bone_cost(skull: Skull) -> int:
	return MonsterDatabase.find(skull.data.source_monster_id).summon_bone_cost
