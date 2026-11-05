extends ScenarioTest
## 시나리오: UI가 받은 클릭은 게임 조작(공격)으로 넘어가지 않는다.
## 핫바 칸(찬 칸·빈 칸) 클릭 → UI에서 누른 채 게임 화면으로 끌기 → 인벤토리 칸 클릭에서는 탄이 나가지 않고,
## 인벤토리 우클릭 메뉴의 항목·바깥 클릭은 게임 조작으로 넘어가지 않으며 메뉴는 바깥 클릭·Esc·인벤토리 닫기로 닫힌다.
## 안내 문구(장식용) 위를 누르면 탄이 나가고,
## 게임 화면을 클릭하면 탄이 나간다 (이 테스트가 공격을 제대로 세는지 확인용).
##
## 마우스 입력은 흉내 낸 것이다. 여기서 통과해도 실제 마우스로 같은지는 눈으로 확인해야 한다.

const WAIT_FRAMES: int = 3
## 버튼을 누르고 있는 시간. 공격 간격(0.4초)보다 길어야 여러 발이 나갈 기회가 있다.
const HOLD_FRAMES: int = 40
const SAFE_POSITION: Vector2 = Vector2(0, 600)
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
## 게임 화면(네크로맨서 오른쪽)의 UI 좌표. 아무 UI도 없는 곳이다.
const WORLD_UI_POSITION: Vector2 = Vector2(420, 180)

var _necromancer: Necromancer
var _shots: int = 0


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


func _on_actor_added(node: Node) -> void:
	if node is Bolt:
		_shots += 1


## from에서 왼쪽 버튼을 누르고 HOLD_FRAMES 동안 to로 옮겨 가며 누르고 있다가 뗀다. 그동안 나간 탄 수를 돌려준다.
func _hold_left(from: Vector2, to: Vector2) -> int:
	var before: int = _shots
	move_mouse_to_ui(from)
	await wait_frames(1)
	press_mouse_at_ui(from, MOUSE_BUTTON_LEFT, true)
	for i: int in HOLD_FRAMES:
		move_mouse_to_ui(from.lerp(to, float(i + 1) / HOLD_FRAMES), MOUSE_BUTTON_MASK_LEFT)
		await wait_frames(1)
	press_mouse_at_ui(to, MOUSE_BUTTON_LEFT, false)
	await wait_frames(WAIT_FRAMES)
	return _shots - before


## position에서 왼쪽 버튼을 누르고 있는 동안 네크로맨서가 공격 버튼을 받았는지 (떼기 전에 확인한다).
func _held_during_press(ui_position: Vector2) -> bool:
	move_mouse_to_ui(ui_position)
	await wait_frames(1)
	press_mouse_at_ui(ui_position, MOUSE_BUTTON_LEFT, true)
	await wait_frames(WAIT_FRAMES)
	var held: bool = _necromancer.is_attack_held()
	press_mouse_at_ui(ui_position, MOUSE_BUTTON_LEFT, false)
	await wait_frames(WAIT_FRAMES)
	return held


func _run() -> void:
	_necromancer = find_necromancer()
	_necromancer.position = SAFE_POSITION
	_necromancer.get_parent().child_entered_tree.connect(_on_actor_added)
	var game_state: Node = root.get_node("GameState")
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	game_state.inventory.try_add(ItemStack.of_skull(skull))
	game_state.hotbar.assign(0, skull)
	var hotbar_view: HotbarView = find_hud().hotbar_view
	var screen: InventoryScreen = current_scene.find_children("*", "CanvasLayer", true, false).filter(func(n: Node) -> bool: return n is InventoryScreen).front()
	await wait_frames(WAIT_FRAMES)

	var filled: Vector2 = hotbar_view.get_slot_control(0).get_global_rect().get_center()
	var fired: int = await _hold_left(filled, filled)
	if not _check("핫바 찬 칸 클릭", fired == 0, "핫바 0번 칸을 %d프레임 누름: 탄 %d발 (기대 0)" % [HOLD_FRAMES, fired]):
		return

	var empty: Vector2 = hotbar_view.get_slot_control(1).get_global_rect().get_center()
	fired = await _hold_left(empty, empty)
	if not _check("핫바 빈 칸 클릭", fired == 0, "핫바 1번(빈) 칸을 %d프레임 누름: 탄 %d발 (기대 0)" % [HOLD_FRAMES, fired]):
		return

	fired = await _hold_left(empty, WORLD_UI_POSITION)
	if not _check("UI에서 눌러 게임 화면으로 끌기", fired == 0, "핫바에서 누른 채 게임 화면으로 옮김: 탄 %d발 (기대 0)" % fired):
		return

	press_key(KEY_TAB, true)
	press_key(KEY_TAB, false)
	await wait_frames(WAIT_FRAMES)
	var slot: Vector2 = screen.get_slot_control(0).get_global_rect().get_center()
	fired = await _hold_left(slot, slot)
	press_key(KEY_TAB, true)
	press_key(KEY_TAB, false)
	await wait_frames(WAIT_FRAMES)
	if not _check("인벤토리 칸 클릭", fired == 0 and not screen.is_open(), "인벤토리 0번 칸을 %d프레임 누름: 탄 %d발 (기대 0), 다시 닫힘 %s" % [HOLD_FRAMES, fired, not screen.is_open()]):
		return

	# 인벤토리 우클릭 메뉴. 인벤토리가 열려 있으면 탄은 원래 안 나가므로, 클릭이 게임 조작까지 갔는지(is_attack_held)로 본다.
	var menu: ItemMenu = screen.get_menu()
	press_key(KEY_TAB, true)
	press_key(KEY_TAB, false)
	await wait_frames(WAIT_FRAMES)
	await click_ui(slot, MOUSE_BUTTON_RIGHT)
	if not _check("메뉴 열림", menu.is_open(), "인벤토리 0번 칸 우클릭: 메뉴 열림 %s" % menu.is_open()):
		return
	var heal_button: Button = menu.get_button(&"heal_skull")
	var held: bool = await _held_during_press(heal_button.get_global_rect().get_center())
	if not _check("메뉴 항목 클릭", not held and menu.is_open(), "회색 항목 '%s'을 누름: 게임 조작으로 넘어감 %s (기대 false), 메뉴 그대로 열림 %s" % [heal_button.text, held, menu.is_open()]):
		return
	held = await _held_during_press(WORLD_UI_POSITION)
	if not _check("메뉴 바깥 클릭", not held and not menu.is_open() and screen.is_open(), "메뉴 바깥 %s을 누름: 게임 조작으로 넘어감 %s (기대 false), 메뉴 닫힘 %s, 인벤토리는 열려 있음 %s" % [WORLD_UI_POSITION, held, not menu.is_open(), screen.is_open()]):
		return
	await click_ui(slot, MOUSE_BUTTON_RIGHT)
	press_key(KEY_ESCAPE, true)
	press_key(KEY_ESCAPE, false)
	await wait_frames(WAIT_FRAMES)
	if not _check("Esc로 메뉴 닫기", not menu.is_open() and screen.is_open(), "메뉴 닫힘 %s, 인벤토리는 열려 있음 %s" % [not menu.is_open(), screen.is_open()]):
		return
	await click_ui(slot, MOUSE_BUTTON_RIGHT)
	press_key(KEY_TAB, true)
	press_key(KEY_TAB, false)
	await wait_frames(WAIT_FRAMES)
	if not _check("인벤토리를 닫으면 메뉴도 닫힘", not menu.is_open() and not screen.is_open(), "메뉴 닫힘 %s, 인벤토리 닫힘 %s" % [not menu.is_open(), not screen.is_open()]):
		return

	# 안내 문구는 장식용(IGNORE)이라 그 위를 눌러도 게임 화면 클릭으로 공격이 나가야 한다.
	var hud: Hud = find_hud()
	hud.show_message("테스트 안내 문구")
	var message_label: Label = hud.get_node("%MessageLabel")
	var message_point: Vector2 = message_label.get_global_rect().position + Vector2(8, message_label.size.y / 2.0)
	fired = await _hold_left(message_point, message_point)
	if not _check("안내 문구 위 클릭은 공격", fired > 0, "안내 문구 %s를 %d프레임 누름: 탄 %d발 (기대 1발 이상)" % [message_point, HOLD_FRAMES, fired]):
		return

	# 탈출 게이지도 장식용(IGNORE)이다.
	hud.show_escape_progress(0.5)
	var gauge_point: Vector2 = hud.get_node("%EscapeBar").get_global_rect().get_center()
	fired = await _hold_left(gauge_point, gauge_point)
	hud.show_escape_progress(0.0)
	if not _check("탈출 게이지 위 클릭은 공격", fired > 0, "탈출 게이지 %s를 %d프레임 누름: 탄 %d발 (기대 1발 이상)" % [gauge_point, HOLD_FRAMES, fired]):
		return

	fired = await _hold_left(WORLD_UI_POSITION, WORLD_UI_POSITION)
	if not _check("게임 화면 클릭은 공격", fired > 0, "게임 화면 %s을 %d프레임 누름: 탄 %d발 (기대 1발 이상)" % [WORLD_UI_POSITION, HOLD_FRAMES, fired]):
		return
	finish(true)
