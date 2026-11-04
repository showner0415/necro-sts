extends ScenarioTest
## 시나리오: UI가 받은 클릭은 게임 조작(공격)으로 넘어가지 않는다.
## 핫바 칸(찬 칸·빈 칸) 클릭 → UI에서 누른 채 게임 화면으로 끌기 → 인벤토리 칸 클릭에서는 탄이 나가지 않고,
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

	fired = await _hold_left(WORLD_UI_POSITION, WORLD_UI_POSITION)
	if not _check("게임 화면 클릭은 공격", fired > 0, "게임 화면 %s을 %d프레임 누름: 탄 %d발 (기대 1발 이상)" % [WORLD_UI_POSITION, HOLD_FRAMES, fired]):
		return
	finish(true)
