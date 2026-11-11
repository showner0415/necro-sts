extends ScenarioTest
## 시나리오: 숫자키로 핫바 선택 → G로 소환 → 언데드가 쥐와 싸움 → G로 해제 → R로 체력 회복 → 메뉴로 뼈 제거.
## 1. 2 → 1을 눌러 선택 칸이 바뀌고 선택 테두리가 따라간다
## 2. G: 언데드가 나오고, 처음 소환 뼈·소환 마나를 쓰고, 칸에 소환 중 테두리가 생긴다
## 3. 쥐를 가까이 데려오면 언데드가 쫓아가 싸우고, 네크로맨서도 같이 쏴서 잡는다. 받은 피해 횟수만큼 내구도가 1씩 준다
##    (언데드 쥐 혼자서는 쥐를 이기지 못하는 수치라서 같이 쏜다. 언데드 쥐 수치는 사용자가 그대로 두기로 했다)
## 4. G: 해제되어 언데드가 사라지고, 다친 체력이 머리뼈에 남는다
## 5. R: 모자란 체력 비율만큼 뼈를 써서 체력이 가득 찬다
## 6. 인벤토리 우클릭 메뉴 "뼈 제거 (N개)": 지금 체력만큼 뼈가 인벤토리로 돌아오고, 머리뼈는 처음 소환 전 상태가 된다
##    (마우스는 흉내 낸 입력이다)

const WAIT_FRAMES: int = 3
const FIGHT_TIMEOUT_FRAMES: int = 900
## 남쪽으로 떨어뜨려 다른 쥐가 끼어들지 않게 한다
const SAFE_POSITION: Vector2 = Vector2(0, 600)
## 데려올 쥐를 놓을 자리 (네크로맨서 기준)
const RAT_OFFSET: Vector2 = Vector2(50, 0)
const START_BONES: int = 10
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"

var _necromancer: Necromancer
var _hotbar: Hotbar
var _hotbar_view: HotbarView
var _roster: UndeadRoster
var _bone: ItemData


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


func _tap(key: Key) -> void:
	press_key(key, true)
	await wait_frames(1)
	press_key(key, false)
	await wait_frames(WAIT_FRAMES)


func _bones() -> int:
	return _necromancer.inventory.get_count(_bone.id)


func _run() -> void:
	_necromancer = find_necromancer()
	_necromancer.position = SAFE_POSITION
	_roster = _necromancer.summoner.roster
	_hotbar_view = find_hud().hotbar_view
	_hotbar = root.get_node("GameState").hotbar
	_bone = load(BONE_PATH)
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	_necromancer.inventory.try_add(ItemStack.of_item(_bone, START_BONES))
	_hotbar.assign(0, skull)
	var monster: MonsterData = _roster.get_monster(skull)
	await wait_frames(WAIT_FRAMES)

	# 1. 숫자키 선택
	await _tap(KEY_2)
	var after_two: String = "선택 %d, 테두리 [%s, %s]" % [_hotbar.selected_index, _hotbar_view.get_slot_control(0).is_selected(), _hotbar_view.get_slot_control(1).is_selected()]
	var two_ok: bool = _hotbar.selected_index == 1 and _hotbar_view.get_slot_control(1).is_selected() and not _hotbar_view.get_slot_control(0).is_selected()
	await _tap(KEY_1)
	var one_ok: bool = _hotbar.selected_index == 0 and _hotbar_view.get_slot_control(0).is_selected() and not _hotbar_view.get_slot_control(1).is_selected()
	if not _check("숫자키 선택", two_ok and one_ok, "2 누름: %s → 1 누름: 선택 %d" % [after_two, _hotbar.selected_index]):
		return

	# 2. G로 소환
	var mana_before: float = _necromancer.mana.current
	await _tap(KEY_G)
	var undead: Undead = _necromancer.summoner.get_undead(skull)
	var mana_spent: float = mana_before - _necromancer.mana.current
	var evidence: String = "소환 수 %d, 언데드 노드 %s, 뼈 %d → %d (처음 소환 비용 %d), 마나 %.2f 줄어듦 (소환 비용 %.1f), 체력 %.1f / %.1f, 소환 중 테두리 %s" % [
		_roster.get_count(), undead != null, START_BONES, _bones(), monster.summon_bone_cost, mana_spent, monster.summon_mana_cost,
		skull.health, monster.undead_max_health, _hotbar_view.get_slot_control(0).is_summoned()]
	# 기다린 몇 프레임 동안 자연 회복·유지 마나가 섞이므로 조금의 차이는 허용한다.
	var mana_ok: bool = absf(mana_spent - monster.summon_mana_cost) < 0.5
	if not _check("G로 소환", undead != null and _roster.is_summoned(skull) and _bones() == START_BONES - monster.summon_bone_cost and mana_ok and skull.health == monster.undead_max_health and _hotbar_view.get_slot_control(0).is_summoned(), evidence):
		return

	# 3. 쥐와 싸움
	var rat: Monster = current_scene.get_node("Actors/Rat1")
	rat.global_position = _necromancer.global_position + RAT_OFFSET
	var necro_health: float = _necromancer.health
	var durability_before: float = skull.durability
	restart_step_timer()
	press_mouse(true)
	while is_instance_valid(rat) and not rat.is_queued_for_deletion():
		if step_frames > FIGHT_TIMEOUT_FRAMES or not _roster.is_summoned(skull):
			press_mouse(false)
			fail_step("쥐와 싸움", "%d프레임 안에 끝나지 않았거나 언데드가 사라짐 (소환 중 %s, 쥐 체력 %.1f)" % [step_frames, _roster.is_summoned(skull), rat.health])
			return
		aim_mouse_at(rat.global_position + Vector2(0, -rat.data.placeholder_radius))
		await wait_frames(1)
	press_mouse(false)
	var hits: int = roundi(monster.undead_max_health - skull.health)
	evidence = "네크로맨서와 같이 쏴서 %d프레임 만에 쥐 처치. 언데드 체력 %.1f / %.1f (피해 %d번), 내구도 %.0f → %.0f, 네크로맨서 체력 %.1f → %.1f" % [
		step_frames, skull.health, monster.undead_max_health, hits, durability_before, skull.durability, necro_health, _necromancer.health]
	if not _check("쥐와 싸움", hits > 0 and skull.durability == durability_before - hits and _roster.is_summoned(skull), evidence):
		return

	# 4. G로 해제
	var health_kept: float = skull.health
	await _tap(KEY_G)
	evidence = "소환 수 %d, 언데드 노드 남음 %s, 머리뼈 체력 %.1f (해제 전 %.1f), 소환 중 테두리 %s" % [
		_roster.get_count(), is_instance_valid(undead) and not undead.is_queued_for_deletion(), skull.health, health_kept, _hotbar_view.get_slot_control(0).is_summoned()]
	if not _check("G로 해제", not _roster.is_summoned(skull) and not is_instance_valid(undead) and skull.health == health_kept and not _hotbar_view.get_slot_control(0).is_summoned(), evidence):
		return

	# 5. R로 회복
	var expected_cost: int = UndeadRules.heal_bone_cost(skull.health, monster.undead_max_health, monster.summon_bone_cost)
	var bones_before: int = _bones()
	await _tap(KEY_R)
	evidence = "체력 %.1f → %.1f / %.1f, 뼈 %d → %d (기대 비용 %d), 안내 '%s'" % [
		health_kept, skull.health, monster.undead_max_health, bones_before, _bones(), expected_cost, find_hud().get_message()]
	if not _check("R로 회복", expected_cost > 0 and skull.health == monster.undead_max_health and _bones() == bones_before - expected_cost, evidence):
		return

	# 6. 메뉴로 뼈 제거
	var screen: InventoryScreen = current_scene.get_node("InventoryScreen")
	await _tap(KEY_TAB)
	var skull_index: int = -1
	for i: int in _necromancer.inventory.get_slot_count():
		var stack: ItemStack = _necromancer.inventory.get_slot(i)
		if stack != null and stack.skull == skull:
			skull_index = i
	var stored: int = _roster.get_stored_bones(skull)
	bones_before = _bones()
	await click_ui(screen.get_slot_control(skull_index).get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	var button: Button = screen.get_menu().get_button(&"remove_bones") if screen.get_menu().is_open() else null
	var button_text: String = button.text if button != null else "(메뉴 항목 없음)"
	if button != null:
		await click_ui(button.get_global_rect().get_center())
	await wait_frames(WAIT_FRAMES)
	move_mouse_to_ui(screen.get_slot_control(skull_index).get_global_rect().get_center())
	await wait_frames(WAIT_FRAMES)
	var hover_info: String = screen.get_info_text().replace("\n", " / ")
	await _tap(KEY_TAB)
	evidence = "메뉴 '%s' 누름: 뼈 %d → %d (돌려받을 뼈 %d = 처음 소환 비용 %d), 깨움 %s, 체력 %.1f, 머리뼈는 인벤토리에 그대로 %s, 정보 줄 '%s'" % [
		button_text, bones_before, _bones(), stored, monster.summon_bone_cost, skull.awakened, skull.health, _necromancer.inventory.get_skulls().has(skull), hover_info]
	if not _check("메뉴로 뼈 제거", button != null and button_text == "뼈 제거 (%d개)" % stored and stored == monster.summon_bone_cost and _bones() == bones_before + stored and not skull.awakened and _necromancer.inventory.get_skulls().has(skull) and hover_info.contains("처음 소환 뼈 %d개" % monster.summon_bone_cost), evidence):
		return
	finish(true)
