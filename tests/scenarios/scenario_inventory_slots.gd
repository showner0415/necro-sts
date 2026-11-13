extends ScenarioTest
## 시나리오: 고정 칸 인벤토리.
## "인벤토리 가득 참" 안내 → 가득 차면 줍기 실패 → 열기 → 칸에 마우스 올림 정보(머리뼈 내구도·체력·필요한 뼈) → 우클릭 메뉴로 버리기 →
## 빈 칸으로 끌어 옮기기 → 물건 있는 칸으로 끌어 자리 바꾸기 → 바깥에 놓아 취소 → 버린 자리로 다시 줍기.
##
## 마우스 입력은 흉내 낸 것이다. 여기서 통과해도 실제 마우스로 같은지는 눈으로 확인해야 한다.

const WAIT_FRAMES: int = 3
## 남쪽으로 떨어뜨려 몬스터가 쫓아오지 않게 한다
const SAFE_POSITION: Vector2 = Vector2(0, 600)
const FULL_TEXT: String = "인벤토리 가득 참"
const KEY_TEXT: String = "[E]"
const BONE_PATH: String = "res://data/items/bone.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
## 인벤토리 바깥(게임 화면 왼쪽)의 UI 좌표
const OUTSIDE_UI_POSITION: Vector2 = Vector2(100, 300)

var _necromancer: Necromancer
var _inventory: Inventory
var _screen: InventoryScreen


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


func _slot_center(index: int) -> Vector2:
	return _screen.get_slot_control(index).get_global_rect().get_center()


func _describe_slots() -> String:
	var parts: PackedStringArray = []
	for i: int in _inventory.get_slot_count():
		var stack: ItemStack = _inventory.get_slot(i)
		if stack == null:
			parts.append("%d:빈칸" % i)
		elif stack.is_skull():
			parts.append("%d:머리뼈%.0f" % [i, stack.skull.durability])
		else:
			parts.append("%d:%s×%d" % [i, stack.item.id, stack.count])
	return ", ".join(parts)


func _pickups() -> Array[Pickup]:
	var result: Array[Pickup] = []
	for node: Node in current_scene.find_children("*", "Area2D", true, false):
		if node is Pickup and not node.is_queued_for_deletion():
			result.append(node)
	return result


func _run() -> void:
	_necromancer = find_necromancer()
	# 테스트 스크립트는 오토로드보다 먼저 컴파일돼 GameState 이름을 못 쓴다. 지역 씬이 넣어 준 같은 인벤토리를 쓴다.
	_inventory = _necromancer.inventory
	_screen = current_scene.find_children("*", "CanvasLayer", true, false).filter(func(n: Node) -> bool: return n is InventoryScreen).front()
	_necromancer.position = SAFE_POSITION

	# 준비: 머리뼈로 칸을 모두 채운다. 칸마다 내구도를 다르게 해서 어느 것이 어디 있는지 알아볼 수 있게 한다.
	var rat_skull: SkullData = load(RAT_SKULL_PATH)
	for i: int in _inventory.get_slot_count():
		var skull: Skull = Skull.create(rat_skull)
		skull.durability = rat_skull.max_durability - i
		_inventory.try_add(ItemStack.of_skull(skull))
	print("[준비] 칸 %d개를 머리뼈로 채움: %s" % [_inventory.get_slot_count(), _describe_slots()])

	# 발밑에 뼈 더미를 놓는다 (뼈 칸이 없으므로 넣을 자리가 없다)
	var bone_pickup: Pickup = _necromancer.pickup_scene.instantiate()
	bone_pickup.stack = ItemStack.of_item(load(BONE_PATH), 2)
	_necromancer.get_parent().add_child(bone_pickup)
	bone_pickup.global_position = _necromancer.global_position
	await wait_frames(WAIT_FRAMES)

	var expected_full: String = "뼈\n%s" % FULL_TEXT
	if not _check("가득 참 안내", bone_pickup.is_prompt_visible() and bone_pickup.get_prompt_text() == expected_full,
			"안내 보임 %s, 글자 '%s' (기대 '%s')" % [bone_pickup.is_prompt_visible(), bone_pickup.get_prompt_text().replace("\n", " / "), expected_full.replace("\n", " / ")]):
		return

	press_key(KEY_E, true)
	press_key(KEY_E, false)
	await wait_frames(WAIT_FRAMES)
	if not _check("가득 차면 줍기 실패", is_instance_valid(bone_pickup) and not bone_pickup.is_queued_for_deletion() and _inventory.get_count(&"bone") == 0,
			"E를 누른 뒤 더미 남음 %s, 인벤토리 뼈 %d" % [is_instance_valid(bone_pickup) and not bone_pickup.is_queued_for_deletion(), _inventory.get_count(&"bone")]):
		return

	# 인벤토리 열기
	press_key(KEY_TAB, true)
	press_key(KEY_TAB, false)
	await wait_frames(WAIT_FRAMES)
	if not _check("열기", _screen.is_open(), "열림 %s" % _screen.is_open()):
		return

	# 마우스 올림: 3번 칸 (내구도 7)
	move_mouse_to_ui(_slot_center(3))
	await wait_frames(WAIT_FRAMES)
	# 아직 소환한 적 없는 머리뼈: 체력은 가득, 회복 대신 처음 소환 뼈를 보여준다.
	var rat: MonsterData = MonsterDatabase.find(rat_skull.source_monster_id)
	var expected_info: String = "%s\n내구도 7 / 10 · 체력 %d / %d\n처음 소환 뼈 %d개" % [rat_skull.display_name, ceili(rat.undead_max_health), ceili(rat.undead_max_health), rat.summon_bone_cost]
	if not _check("마우스 올림 정보", _screen.get_info_text() == expected_info,
			"마우스 아래 %s, 정보 줄 '%s' (기대 '%s')" % [root.gui_get_hovered_control(), _screen.get_info_text().replace("\n", " / "), expected_info.replace("\n", " / ")]):
		return

	# 우클릭 메뉴로 버리기: 2번 칸
	var dropped: ItemStack = _inventory.get_slot(2)
	var pickups_before: int = _pickups().size()
	if not await choose_inventory_menu(_screen, 2, &"drop"):
		fail_step("메뉴로 버리기", "2번 칸 메뉴에서 버리기 항목을 누르지 못함")
		return
	var dropped_pickup: Pickup = null
	for pickup: Pickup in _pickups():
		if pickup.stack == dropped:
			dropped_pickup = pickup
	var drop_distance: float = dropped_pickup.global_position.distance_to(_necromancer.global_position) if dropped_pickup else INF
	if not _check("메뉴로 버리기", _inventory.get_slot(2) == null and dropped_pickup != null and drop_distance <= _necromancer.drop_scatter_radius + 0.01,
			"2번 칸 비었음 %s, 바닥 더미 %d → %d개, 버린 머리뼈가 바닥에 있음 %s (발밑에서 %.1f), 칸: %s" % [
				_inventory.get_slot(2) == null, pickups_before, _pickups().size(), dropped_pickup != null, drop_distance, _describe_slots()]):
		return

	# 끌어서 빈 칸으로 옮기기: 0번 → 2번(방금 빈 칸)
	var stack0: ItemStack = _inventory.get_slot(0)
	var stack1: ItemStack = _inventory.get_slot(1)
	await drag_ui(_slot_center(0), _slot_center(2))
	if not _check("빈 칸으로 옮기기", _inventory.get_slot(0) == null and _inventory.get_slot(2) == stack0,
			"0번 → 2번 끌기 후 칸: %s" % _describe_slots()):
		return

	# 끌어서 물건 있는 칸에 놓기: 1번 → 2번 (자리 바꾸기)
	await drag_ui(_slot_center(1), _slot_center(2))
	if not _check("자리 바꾸기", _inventory.get_slot(1) == stack0 and _inventory.get_slot(2) == stack1,
			"1번 → 2번 끌기 후 칸: %s" % _describe_slots()):
		return

	# 바깥에 놓기: 3번 → 인벤토리 바깥 (취소)
	var before: String = _describe_slots()
	await drag_ui(_slot_center(3), OUTSIDE_UI_POSITION)
	var after: String = _describe_slots()
	if not _check("바깥에 놓으면 취소", before == after and _pickups().size() == pickups_before + 1,
			"3번 → 바깥 끌기 전후 칸이 같음 %s, 바닥 더미 수 %d (버리지 않음)" % [before == after, _pickups().size()]):
		return

	# 닫고, 빈 0번 칸이 생겼으니 발밑 물건을 다시 주울 수 있다
	press_key(KEY_TAB, true)
	press_key(KEY_TAB, false)
	await wait_frames(WAIT_FRAMES)
	var prompted: Pickup = null
	for pickup: Pickup in _pickups():
		if pickup.is_prompt_visible():
			prompted = pickup
	if not _check("자리 생기면 줍기 안내", prompted != null and prompted.get_prompt_text().ends_with(KEY_TEXT),
			"안내가 뜬 더미: %s" % (prompted.get_prompt_text().replace("\n", " / ") if prompted else "없음")):
		return
	press_key(KEY_E, true)
	press_key(KEY_E, false)
	await wait_frames(WAIT_FRAMES)
	if not _check("다시 줍기", _inventory.get_slot(0) != null and not is_instance_valid(prompted),
			"주운 뒤 칸: %s" % _describe_slots()):
		return
	finish(true)
