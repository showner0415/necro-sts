extends ScenarioTest
## 시나리오: 거점 수리 기계. 거점에서 시작한다.
## 1. 기계 근처에서 "[F] 수리 기계" 안내 → F로 인벤토리(가운데 왼쪽)와 수리 창(오른쪽)이 나란히 열린다
## 2. 빈 칸이면 안내 문구, 수리 버튼은 회색
## 3. 뼈는 칸에 끌어 놓아도 들어가지 않는다
## 4. 머리뼈를 끌어 놓으면 칸이 그 머리뼈를 가리킨다 (인벤토리·핫바에 그대로), 필요한 뼈와 가진 뼈를 보여준다
## 5. 뼈가 모자라면 가진 만큼만 수리하고 "뼈 부족"
## 6. 뼈가 넉넉하면 가득 채우고 "내구도 가득" (뼈 1개 = 내구도 1)
## 7. 소환 중인 머리뼈는 "소환 중"으로 수리할 수 없다
## 8. 머리뼈를 버리면 칸이 빈다, 우클릭하면 칸에서만 빠진다
## 9. 수리 창 클릭(칸, 버튼, 창 가장자리)은 공격으로 넘어가지 않는다 (거점에만 있는 UI라 scenario_ui_click 대신 여기서 본다)
## 10. 기계에서 멀어지면·Esc·Tab으로 둘 다 닫힌다
## 11. 지역에는 수리 기계와 수리 창이 없다
## 마우스는 흉내 낸 입력이다. 실제 마우스로 같은지는 눈으로 확인해야 한다.

const WAIT_FRAMES: int = 3
## 순간이동한 뒤 영역 판정과 안내 표시가 따라오기까지 기다리는 프레임
const SETTLE_FRAMES: int = 6
const REGION_DATA_PATH: String = "res://data/regions/test_region.tres"
const REGION_SCENE: String = "res://regions/test_region.tscn"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const SCENE_TIMEOUT_FRAMES: int = 120
## 기계에서 이만큼 떨어지면 판정 영역 밖이다
const AWAY_OFFSET: Vector2 = Vector2(0, 120)
## 수리할 머리뼈의 처음 내구도와 처음 가진 뼈 (모자라게 둔다)
const START_DURABILITY: float = 4.0
const START_BONES: int = 3
## 나중에 더 주는 뼈 (넉넉하게)
const EXTRA_BONES: int = 10

var _game_state: Node
var _inventory: Inventory
var _inventory_screen: InventoryScreen
var _repair_screen: RepairScreen
var _necromancer: Necromancer
var _machine: RepairMachine
var _bone: ItemData


func get_start_scene() -> String:
	return "res://regions/base.tscn"


func _on_scene_ready() -> void:
	_run()


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
	return ok


func _inventory_center(index: int) -> Vector2:
	return _inventory_screen.get_slot_control(index).get_global_rect().get_center()


func _repair_slot_center() -> Vector2:
	return _repair_screen.get_slot_control().get_global_rect().get_center()


func _button_center() -> Vector2:
	return _repair_screen.get_repair_button().get_global_rect().get_center()


func _panel_rect(screen: CanvasLayer) -> Rect2:
	return (screen.get_node("Panel") as Control).get_global_rect()


## 그 머리뼈가 든 인벤토리 칸 번호 (없으면 -1)
func _find_skull(skull: Skull) -> int:
	for i: int in _inventory.get_slot_count():
		if _inventory.get_slot(i) != null and _inventory.get_slot(i).skull == skull:
			return i
	return -1


func _find_bone() -> int:
	for i: int in _inventory.get_slot_count():
		if _inventory.get_slot(i) != null and not _inventory.get_slot(i).is_skull():
			return i
	return -1


func _bones() -> int:
	return _inventory.get_count(_bone.id)


func _open_with_f() -> void:
	_necromancer.global_position = _machine.global_position
	await wait_frames(SETTLE_FRAMES)
	press_key(KEY_F, true)
	press_key(KEY_F, false)
	await wait_frames(WAIT_FRAMES)


func _run() -> void:
	_game_state = root.get_node("GameState")
	_inventory = _game_state.inventory
	_necromancer = find_necromancer()
	_machine = current_scene.find_children("*", "RepairMachine", true, false).front()
	_inventory_screen = current_scene.get_node("InventoryScreen")
	_repair_screen = current_scene.get_node("RepairScreen")
	_bone = load(BONE_PATH)
	var worn: Skull = Skull.create(load(RAT_SKULL_PATH))
	var summoned: Skull = Skull.create(load(RAT_SKULL_PATH))
	_inventory.try_add(ItemStack.of_skull(worn))
	_inventory.try_add(ItemStack.of_skull(summoned))
	# 소환 중인 머리뼈를 만든다 (처음 소환 뼈를 넉넉히 주고), 그 뒤 뼈를 정해 둔 수만 남긴다.
	_inventory.try_add(ItemStack.of_item(_bone, 50))
	_game_state.hotbar.assign(0, worn)
	_game_state.hotbar.assign(1, summoned)
	_game_state.hotbar.select(1)
	_necromancer.summoner.toggle_selected()
	_inventory.remove_count(_bone.id, _bones() - START_BONES)
	worn.durability = START_DURABILITY
	summoned.durability = START_DURABILITY
	var max_durability: float = worn.data.max_durability

	# 1. 기계에서 F
	_necromancer.global_position = _machine.global_position
	await wait_frames(SETTLE_FRAMES)
	var prompt: String = _machine.get_prompt_text() if _machine.is_prompt_visible() else "(안 보임)"
	press_key(KEY_F, true)
	press_key(KEY_F, false)
	await wait_frames(WAIT_FRAMES)
	var center_x: float = root.get_visible_rect().size.x / 2.0
	var inventory_rect: Rect2 = _panel_rect(_inventory_screen)
	var repair_rect: Rect2 = _panel_rect(_repair_screen)
	var evidence: String = "안내 '%s', 인벤토리 열림 %s (x %.0f~%.0f), 수리 창 열림 %s (x %.0f~%.0f), 화면 가운데 x %.0f, 소환 중 %s" % [
		prompt, _inventory_screen.is_open(), inventory_rect.position.x, inventory_rect.end.x, _repair_screen.is_open(), repair_rect.position.x, repair_rect.end.x, center_x, _necromancer.summoner.roster.is_summoned(summoned)]
	if not _check("F로 수리 기계 열기", prompt == "[F] 수리 기계" and _inventory_screen.is_open() and _repair_screen.is_open() and inventory_rect.end.x <= center_x and repair_rect.position.x >= center_x and _necromancer.summoner.roster.is_summoned(summoned), evidence):
		return

	# 2. 빈 칸
	var button: Button = _repair_screen.get_repair_button()
	if not _check("빈 칸", _repair_screen.get_skull() == null and button.disabled and _repair_screen.get_info_text() == _repair_screen.empty_text, "칸 %s, 버튼 회색 %s, 안내 '%s'" % [_repair_screen.get_skull(), button.disabled, _repair_screen.get_info_text()]):
		return

	# 3. 뼈는 안 들어감
	await drag_ui(_inventory_center(_find_bone()), _repair_slot_center())
	if not _check("뼈는 칸에 안 들어감", _repair_screen.get_skull() == null and _bones() == START_BONES, "뼈를 끌어 놓음: 칸 %s, 뼈 %d개 (기대 %d)" % [_repair_screen.get_skull(), _bones(), START_BONES]):
		return

	# 4. 머리뼈를 끌어 놓음
	var worn_index: int = _find_skull(worn)
	await drag_ui(_inventory_center(worn_index), _repair_slot_center())
	var expected_cost: int = ceili(max_durability - START_DURABILITY)
	var expected_cost_text: String = _repair_screen.cost_format % [_bone.display_name, expected_cost, _bone.display_name, START_BONES]
	evidence = "칸이 그 머리뼈 %s, 인벤토리 %d번에 그대로 %s, 핫바 0번 그대로 %s, 정보 '%s', 비용 '%s' (기대 '%s'), 버튼 쓸 수 있음 %s" % [
		_repair_screen.get_skull() == worn, worn_index, _find_skull(worn) == worn_index, _game_state.hotbar.get_skull(0) == worn,
		_repair_screen.get_info_text().replace("\n", " / "), _repair_screen.get_cost_text(), expected_cost_text, not button.disabled]
	if not _check("머리뼈를 칸에 놓기", _repair_screen.get_skull() == worn and _find_skull(worn) == worn_index and _game_state.hotbar.get_skull(0) == worn and _repair_screen.get_cost_text() == expected_cost_text and not button.disabled, evidence):
		return

	# 5. 뼈가 모자라면 일부 수리
	await click_ui(_button_center())
	evidence = "수리 버튼 클릭: 내구도 %.1f → %.1f (기대 %.1f), 뼈 %d → %d, 버튼 회색 %s, 이유 '%s'" % [
		START_DURABILITY, worn.durability, START_DURABILITY + START_BONES, START_BONES, _bones(), button.disabled, _repair_screen.get_reason_text()]
	if not _check("뼈가 모자라면 가진 만큼 수리", is_equal_approx(worn.durability, START_DURABILITY + START_BONES) and _bones() == 0 and button.disabled and _repair_screen.get_reason_text() == "뼈 부족", evidence):
		return

	# 6. 뼈가 넉넉하면 가득
	_inventory.try_add(ItemStack.of_item(_bone, EXTRA_BONES))
	await wait_frames(WAIT_FRAMES)
	var enabled_after_bones: bool = not button.disabled
	var durability_before: float = worn.durability
	await click_ui(_button_center())
	var used: int = EXTRA_BONES - _bones()
	evidence = "뼈 %d개를 더 받으니 버튼 쓸 수 있음 %s → 클릭: 내구도 %.1f → %.1f / %.1f, 뼈 %d개 씀 (기대 %d), 버튼 회색 %s, 이유 '%s'" % [
		EXTRA_BONES, enabled_after_bones, durability_before, worn.durability, max_durability, used, ceili(max_durability - durability_before), button.disabled, _repair_screen.get_reason_text()]
	if not _check("뼈 1개 = 내구도 1로 가득 채움", enabled_after_bones and is_equal_approx(worn.durability, max_durability) and used == ceili(max_durability - durability_before) and button.disabled and _repair_screen.get_reason_text() == "내구도 가득", evidence):
		return

	# 7. 소환 중인 머리뼈
	var bones_before: int = _bones()
	await drag_ui(_inventory_center(_find_skull(summoned)), _repair_slot_center())
	await click_ui(_button_center())
	evidence = "소환 중인 머리뼈를 놓음: 칸 %s, 버튼 회색 %s, 이유 '%s', 누른 뒤 내구도 %.1f (그대로 %.1f), 뼈 %d → %d" % [
		_repair_screen.get_skull() == summoned, button.disabled, _repair_screen.get_reason_text(), summoned.durability, START_DURABILITY, bones_before, _bones()]
	if not _check("소환 중인 머리뼈는 수리 못 함", _repair_screen.get_skull() == summoned and button.disabled and _repair_screen.get_reason_text() == "소환 중" and is_equal_approx(summoned.durability, START_DURABILITY) and _bones() == bones_before, evidence):
		return

	# 8. 우클릭으로 빼기, 버리면 칸이 빔
	await click_ui(_repair_slot_center(), MOUSE_BUTTON_RIGHT)
	var cleared_by_click: bool = _repair_screen.get_skull() == null
	var still_owned: bool = _find_skull(summoned) != -1
	await drag_ui(_inventory_center(_find_skull(worn)), _repair_slot_center())
	var set_again: bool = _repair_screen.get_skull() == worn
	var ok: bool = await choose_inventory_menu(_inventory_screen, _find_skull(worn), &"drop")
	await wait_frames(WAIT_FRAMES)
	evidence = "우클릭으로 칸 빔 %s (머리뼈는 인벤토리에 그대로 %s) / 다시 놓음 %s → 메뉴로 버림 %s: 칸 빔 %s, 안내 '%s'" % [
		cleared_by_click, still_owned, set_again, ok, _repair_screen.get_skull() == null, _repair_screen.get_info_text()]
	if not _check("칸에서 빼기", cleared_by_click and still_owned and set_again and ok and _repair_screen.get_skull() == null and _repair_screen.get_info_text() == _repair_screen.empty_text, evidence):
		return

	# 9. 수리 창 클릭은 공격으로 넘어가지 않음
	var leaked: bool = false
	for point: Vector2 in [_repair_slot_center(), _button_center(), _panel_rect(_repair_screen).position + Vector2(6, 6)]:
		move_mouse_to_ui(point)
		await wait_frames(1)
		press_mouse_at_ui(point, MOUSE_BUTTON_LEFT, true)
		await wait_frames(WAIT_FRAMES)
		leaked = leaked or _necromancer.is_attack_held()
		press_mouse_at_ui(point, MOUSE_BUTTON_LEFT, false)
		await wait_frames(WAIT_FRAMES)
	if not _check("수리 창 클릭은 공격으로 안 넘어감", not leaked, "칸·수리 버튼·창 가장자리를 누름: 게임 조작으로 넘어감 %s (기대 false)" % leaked):
		return

	# 10. 멀어지면·Esc·Tab으로 닫힘
	_necromancer.global_position = _machine.global_position + AWAY_OFFSET
	await wait_frames(WAIT_FRAMES)
	var away_closed: bool = not _repair_screen.is_open() and not _inventory_screen.is_open()
	await _open_with_f()
	var reopened: bool = _repair_screen.is_open() and _inventory_screen.is_open()
	press_key(KEY_ESCAPE, true)
	press_key(KEY_ESCAPE, false)
	await wait_frames(WAIT_FRAMES)
	var esc_closed: bool = not _repair_screen.is_open() and not _inventory_screen.is_open()
	await _open_with_f()
	press_key(KEY_TAB, true)
	press_key(KEY_TAB, false)
	await wait_frames(WAIT_FRAMES)
	var tab_closed: bool = not _repair_screen.is_open() and not _inventory_screen.is_open()
	if not _check("수리 창 닫기", away_closed and reopened and esc_closed and tab_closed, "멀어지면 둘 다 닫힘 %s, 다시 F로 열림 %s, Esc로 둘 다 닫힘 %s, Tab으로 둘 다 닫힘 %s" % [away_closed, reopened, esc_closed, tab_closed]):
		return

	# 11. 지역에는 수리 기계가 없다
	# Region 타입을 쓰면 오토로드(GameState)보다 먼저 컴파일되어 실패하므로 이름으로 부른다.
	current_scene.call(&"travel_to", load(REGION_DATA_PATH))
	for i: int in SCENE_TIMEOUT_FRAMES:
		await wait_frames(1)
		if current_scene != null and current_scene.scene_file_path == REGION_SCENE:
			break
	await wait_frames(WAIT_FRAMES)
	var machines: int = current_scene.find_children("*", "RepairMachine", true, false).size()
	var screen: Node = current_scene.get_node_or_null("RepairScreen")
	if not _check("지역에는 수리 기계 없음", current_scene.scene_file_path == REGION_SCENE and machines == 0 and screen == null, "%s: 수리 기계 %d개, 수리 창 %s" % [current_scene.scene_file_path, machines, screen]):
		return
	finish(true)
