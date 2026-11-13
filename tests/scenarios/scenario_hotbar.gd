extends ScenarioTest
## 시나리오: 핫바(머리뼈 바로가기).
## 인벤토리에서 핫바로 끌기(바로가기, 인벤토리에 그대로) → 뼈는 거부 → 같은 종류 머리뼈 둘은 두 칸 → 이미 핫바에 있는 머리뼈는 새 칸으로 옮김 → 핫바끼리 자리 바꾸기 →
## 바깥에 놓아 취소 → 핫바 내구도 바 → 우클릭으로 핫바에서만 빼기 → 인벤토리 칸을 옮겨도 유지 → 인벤토리 메뉴로 버리면 핫바가 빔.
##
## 마우스 입력은 흉내 낸 것이다. 여기서 통과해도 실제 마우스로 같은지는 눈으로 확인해야 한다.

const WAIT_FRAMES: int = 3
const SAFE_POSITION: Vector2 = Vector2(0, 600)
const BONE_PATH: String = "res://data/items/bone.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
## 인벤토리·핫바 바깥(게임 화면 가운데)의 UI 좌표
const OUTSIDE_UI_POSITION: Vector2 = Vector2(320, 120)

var _necromancer: Necromancer
var _inventory: Inventory
var _hotbar: Hotbar
var _screen: InventoryScreen
var _hotbar_view: HotbarView


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


func _inventory_center(index: int) -> Vector2:
	return _screen.get_slot_control(index).get_global_rect().get_center()


func _hotbar_center(index: int) -> Vector2:
	return _hotbar_view.get_slot_control(index).get_global_rect().get_center()


func _name_of(skull: Skull) -> String:
	if skull == null:
		return "빈칸"
	return "머리뼈%.0f" % skull.durability


func _describe() -> String:
	var inventory_parts: PackedStringArray = []
	for i: int in _inventory.get_slot_count():
		var stack: ItemStack = _inventory.get_slot(i)
		if stack != null:
			inventory_parts.append("%d:%s" % [i, _name_of(stack.skull) if stack.is_skull() else "뼈×%d" % stack.count])
	return "핫바 [%s, %s] / 인벤토리 {%s}" % [_name_of(_hotbar.get_skull(0)), _name_of(_hotbar.get_skull(1)), ", ".join(inventory_parts)]


func _run() -> void:
	_necromancer = find_necromancer()
	_necromancer.position = SAFE_POSITION
	# 테스트 스크립트에서는 GameState 이름을 못 쓰므로 노드로 찾는다.
	var game_state: Node = root.get_node("GameState")
	_inventory = game_state.inventory
	_hotbar = game_state.hotbar
	_screen = current_scene.find_children("*", "CanvasLayer", true, false).filter(func(n: Node) -> bool: return n is InventoryScreen).front()
	_hotbar_view = find_hud().hotbar_view

	# 준비: 0번 뼈, 1~3번 머리뼈 (내구도 10, 5, 1)
	var rat_skull: SkullData = load(RAT_SKULL_PATH)
	_inventory.try_add(ItemStack.of_item(load(BONE_PATH), 4))
	var skulls: Array[Skull] = []
	for durability: float in [10.0, 5.0, 1.0]:
		var skull: Skull = Skull.create(rat_skull)
		skull.durability = durability
		skulls.append(skull)
		_inventory.try_add(ItemStack.of_skull(skull))
	var a: Skull = skulls[0]
	var b: Skull = skulls[1]
	print("[준비] %s" % _describe())

	press_key(KEY_TAB, true)
	press_key(KEY_TAB, false)
	await wait_frames(WAIT_FRAMES)

	await drag_ui(_inventory_center(1), _hotbar_center(0))
	if not _check("인벤토리 → 핫바", _hotbar.get_skull(0) == a and _inventory.get_slot(1).skull == a,
			"1번 칸 머리뼈를 핫바 0에 놓음: %s (인벤토리 1번 칸에 그대로 있음 %s)" % [_describe(), _inventory.get_slot(1).skull == a]):
		return

	await drag_ui(_inventory_center(0), _hotbar_center(1))
	if not _check("뼈는 거부", _hotbar.get_skull(1) == null and _inventory.get_count(&"bone") == 4,
			"뼈 칸을 핫바 1에 놓음: %s" % _describe()):
		return

	await drag_ui(_inventory_center(2), _hotbar_center(1))
	if not _check("같은 종류 두 칸", _hotbar.get_skull(0) == a and _hotbar.get_skull(1) == b,
			"2번 칸 머리뼈를 핫바 1에 놓음: %s" % _describe()):
		return

	await drag_ui(_inventory_center(1), _hotbar_center(1))
	if not _check("이미 있는 머리뼈는 옮김", _hotbar.get_skull(0) == null and _hotbar.get_skull(1) == a,
			"핫바 0에 있던 머리뼈를 다시 핫바 1에 놓음 (b를 덮어씀): %s" % _describe()):
		return

	_hotbar.assign(0, b)
	await wait_frames(1)
	await drag_ui(_hotbar_center(0), _hotbar_center(1))
	if not _check("핫바끼리 자리 바꾸기", _hotbar.get_skull(0) == a and _hotbar.get_skull(1) == b,
			"핫바 0 → 핫바 1 끌기: %s" % _describe()):
		return

	var before: String = _describe()
	await drag_ui(_hotbar_center(0), OUTSIDE_UI_POSITION)
	if not _check("바깥에 놓으면 취소", _describe() == before, "핫바 0 → 바깥 끌기 전후 같음: %s" % _describe()):
		return

	var bar: DurabilityBar = _hotbar_view.get_slot_control(1).get_node("%DurabilityBar")
	if not _check("핫바 내구도 바", bar.visible and is_equal_approx(bar.ratio, 0.5) and bar.get_fill_color() == bar.low_color,
			"핫바 1 (내구도 5/10) 바 보임 %s, 비율 %.2f, 노랑 %s" % [bar.visible, bar.ratio, bar.get_fill_color() == bar.low_color]):
		return

	move_mouse_to_ui(_hotbar_center(0))
	await wait_frames(1)
	press_mouse_at_ui(_hotbar_center(0), MOUSE_BUTTON_RIGHT, true)
	press_mouse_at_ui(_hotbar_center(0), MOUSE_BUTTON_RIGHT, false)
	await wait_frames(WAIT_FRAMES)
	if not _check("우클릭은 핫바에서만 빼기", _hotbar.get_skull(0) == null and _inventory.get_skulls().has(a),
			"핫바 0 우클릭: %s (머리뼈 인벤토리에 그대로 %s)" % [_describe(), _inventory.get_skulls().has(a)]):
		return

	_hotbar.assign(0, a)
	await drag_ui(_inventory_center(1), _inventory_center(7))
	if not _check("인벤토리 칸을 옮겨도 유지", _inventory.get_slot(7) != null and _inventory.get_slot(7).skull == a and _hotbar.get_skull(0) == a,
			"인벤토리 1 → 7 끌기 후: %s" % _describe()):
		return

	if not await choose_inventory_menu(_screen, 7, &"drop"):
		fail_step("버리면 핫바가 빔", "7번 칸 메뉴에서 버리기 항목을 누르지 못함")
		return
	if not _check("버리면 핫바가 빔", _hotbar.get_skull(0) == null and _hotbar.get_skull(1) == b and not _hotbar_view.get_slot_control(0).get_node("%Icon").visible,
			"인벤토리 7번 우클릭 메뉴로 버린 뒤: %s, 핫바 0 그림 보임 %s" % [_describe(), _hotbar_view.get_slot_control(0).get_node("%Icon").visible]):
		return
	finish(true)
