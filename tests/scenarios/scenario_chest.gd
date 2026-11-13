extends ScenarioTest
## 시나리오: 지역 상자.
## 몬스터 없는 상자 가까이에서 안내 "[F] 상자" → F로 열기(인벤토리 가운데 왼쪽, 상자 오른쪽, 모든 칸 "?") → 상자 창 클릭은 공격으로 안 넘어감
## → 주변(48 안)에서 움직이며 기다리면 앞 칸부터 하나씩 드러남(희귀도 시간, 다음 칸에 진행 바), 맞아도 끊기지 않음
## → 드러난 아이템을 끌어서 가져감 / 드러나지 않은 칸은 끌리지 않음 → 48 밖으로 나가면 인벤토리와 상자가 둘 다 닫힘, 닫힌 동안은 멈춤
## → 다시 열면 드러난 것과 진행이 그대로
## → Shift+좌클릭 빠른 옮기기: 드러나지 않은 칸은 안 옮겨짐, 드러나면 인벤토리로, 인벤토리에서 상자의 드러난 빈 칸으로 (공격으로 안 넘어감).
## 내용물은 무작위라서, 상자의 내용물을 정해진 것으로 바꿔 놓고 확인한다 (실제 데이터 파일은 바꾸지 않는다).

const BONE_PATH: String = "res://data/items/bone.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
## 칸마다 드러나는 시간: 뼈(흔함) 1초, 쥐 머리뼈(고급) 2.5초, 나머지 흔함
const TIMES: Array[float] = [1.0, 2.5, 1.0, 1.0, 1.0, 1.0]
## 상자 앞에 서는 자리 (F 판정 반지름 24 안)
const STAND_OFFSET: Vector2 = Vector2(0, 16)
## 열어 둔 채 움직이는 폭 (48 안)
const WANDER: Vector2 = Vector2(30, 0)
const PHYSICS_FPS: float = 60.0

var _necromancer: Necromancer
var _chest: LootChest
var _chest_screen: InventoryScreen
var _inventory_screen: InventoryScreen


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


func _slots_text() -> String:
	var parts: PackedStringArray = []
	for i: int in _chest.contents.inventory.get_slot_count():
		var slot: InventorySlot = _chest_screen.get_slot_control(i)
		if slot.is_showing_hidden():
			var ratio: float = slot.get_reveal_bar_ratio()
			parts.append("?" if ratio < 0.0 else "?(%.2f)" % ratio)
		else:
			var stack: ItemStack = slot.get_stack()
			parts.append("빈 칸" if stack == null else stack.get_display_name())
	return "[%s]" % ", ".join(parts)


func _press_f() -> void:
	press_key(KEY_F, true)
	await wait_frames(1)
	press_key(KEY_F, false)
	await wait_frames(2)


## 상자 앞 자리를 가운데로 좌우(WANDER)로 오가며 seconds초 기다린다 (열린 채로, 48 안).
func _wander(seconds: float) -> void:
	var center: Vector2 = _chest.global_position + STAND_OFFSET
	var goal: Vector2 = center + WANDER
	for frame: int in roundi(seconds * PHYSICS_FPS):
		if _necromancer.global_position.distance_to(goal) < 3.0:
			goal = center - (goal - center)
		press_moves(_necromancer.global_position.direction_to(goal))
		await wait_frames(1)
	press_moves(Vector2.ZERO)


func _run() -> void:
	_necromancer = find_necromancer()
	_necromancer.max_health = 10000.0
	_necromancer.health = 10000.0
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	_chest = current_scene.get_node("ChestSafe")
	_chest_screen = current_scene.get_node("ChestScreen")
	_inventory_screen = current_scene.get_node("InventoryScreen")
	var bone: ItemData = load(BONE_PATH)
	var stacks: Array[ItemStack] = [ItemStack.of_item(bone, 3), ItemStack.of_skull(Skull.create(load(RAT_SKULL_PATH))), null, ItemStack.of_item(bone, 2), null, null]
	_chest.contents = ChestContents.new(stacks, TIMES)

	# 1. 가까이 가면 안내
	_necromancer.global_position = _chest.global_position + STAND_OFFSET
	for frame: int in 30:
		if _chest.is_prompt_visible():
			break
		await wait_frames(1)
	if not _check("상자 안내", _chest.is_prompt_visible() and _chest.get_prompt_text() == "[F] 상자", "안내 보임 %s, 글자 '%s'" % [_chest.is_prompt_visible(), _chest.get_prompt_text()]):
		finish(false)
		return

	# 2. F로 열기: 인벤토리 가운데 왼쪽, 상자 오른쪽, 모든 칸 "?"
	await _press_f()
	var inventory_rect: Rect2 = (_inventory_screen.get_node("Panel") as Control).get_global_rect()
	var chest_rect: Rect2 = (_chest_screen.get_node("Panel") as Control).get_global_rect()
	var all_hidden: bool = range(6).all(func(i: int) -> bool: return _chest_screen.get_slot_control(i).is_showing_hidden())
	var title: Label = _chest_screen.get_node("Panel/Content/Title")
	if not _check("F로 열기", _chest_screen.is_open() and _inventory_screen.is_open() and inventory_rect.end.x <= chest_rect.position.x and all_hidden and title.text == "상자",
			"상자 열림 %s, 인벤토리 열림 %s, 인벤토리 오른쪽 끝 %.0f ≤ 상자 왼쪽 끝 %.0f, 제목 '%s', 칸 %s" % [_chest_screen.is_open(), _inventory_screen.is_open(), inventory_rect.end.x, chest_rect.position.x, title.text, _slots_text()]):
		finish(false)
		return

	# 3. 상자 창(칸·빈 곳)을 클릭해도 공격으로 넘어가지 않는다
	await click_ui(_chest_screen.get_slot_control(4).get_global_rect().get_center())
	var leaked: bool = _necromancer.is_attack_held()
	await click_ui(chest_rect.position + Vector2(4, 4))
	leaked = leaked or _necromancer.is_attack_held()
	if not _check("상자 창 클릭은 공격으로 안 넘어감", not leaked, "칸·창 테두리 클릭 뒤 공격 버튼 눌림 %s" % leaked):
		finish(false)
		return

	# 4. 주변에서 움직이며 기다리면 앞 칸부터 하나씩 드러난다 (맞아도 끊기지 않는다)
	await _wander(0.5)
	var half_text: String = _slots_text()
	var health_before: float = _necromancer.health
	_necromancer.take_damage(1.0)
	await _wander(0.7)
	var first_text: String = _slots_text()
	var first_ok: bool = _chest.contents.is_revealed(0) and not _chest.contents.is_revealed(1) and _chest_screen.get_slot_control(1).get_reveal_bar_ratio() > 0.0
	if not _check("움직이며 기다리면 하나씩 드러남", first_ok and _chest_screen.is_open() and _necromancer.health < health_before,
			"0.5초 뒤 %s → 맞음(체력 %.0f → %.0f) → 1.2초 뒤 %s, 상자 열림 %s, 상자와 거리 %.0f (열린 채 유지 거리 %.0f)" % [
				half_text, health_before, _necromancer.health, first_text, _chest_screen.is_open(), _chest.global_position.distance_to(_necromancer.global_position), _chest.open_distance]):
		finish(false)
		return

	# 5. 드러난 뼈는 끌어서 가져가고, 드러나지 않은 칸은 끌리지 않는다
	var inventory: Inventory = _necromancer.inventory
	var bones_before: int = inventory.get_count(&"bone")
	await drag_ui(_chest_screen.get_slot_control(0).get_global_rect().get_center(), _inventory_screen.get_slot_control(0).get_global_rect().get_center())
	var taken: bool = inventory.get_count(&"bone") == bones_before + 3 and _chest.contents.inventory.get_slot(0) == null
	await drag_ui(_chest_screen.get_slot_control(3).get_global_rect().get_center(), _inventory_screen.get_slot_control(1).get_global_rect().get_center())
	var hidden_stays: bool = _chest.contents.inventory.get_slot(3) != null and inventory.get_count(&"bone") == bones_before + 3
	if not _check("드러난 것만 가져감", taken and hidden_stays,
			"0번 칸(뼈 3) 끌기: 인벤토리 뼈 %d → %d, 0번 빔 %s / 드러나지 않은 3번 칸 끌기: 그대로 %s, 칸 %s" % [
				bones_before, inventory.get_count(&"bone"), _chest.contents.inventory.get_slot(0) == null, hidden_stays, _slots_text()]):
		finish(false)
		return

	# 6. 거리를 벗어나면 닫히고, 닫힌 동안은 진행하지 않는다
	var progress_before: float = 0.0
	press_moves(Vector2.RIGHT)
	var close_frames: int = -1
	for frame: int in 120:
		await wait_frames(1)
		if not _chest_screen.is_open():
			close_frames = frame
			break
	press_moves(Vector2.ZERO)
	var closed_distance: float = _chest.global_position.distance_to(_necromancer.global_position)
	# 닫힌 순간의 진행 (그 전까지는 거리 안이라 진행한다)
	progress_before = _chest.contents.get_reveal_progress()
	await wait_frames(roundi(2.0 * PHYSICS_FPS))
	var paused: bool = absf(_chest.contents.get_reveal_progress() - progress_before) < 0.1
	if not _check("멀어지면 닫히고 멈춤", close_frames >= 0 and not _inventory_screen.is_open() and closed_distance > _chest.open_distance and paused,
			"%d프레임 만에 닫힘 (거리 %.0f > %.0f), 인벤토리도 닫힘 %s, 닫힌 순간 진행 %.2f → 2초 뒤 %.2f (멈춤)" % [
				close_frames, closed_distance, _chest.open_distance, not _inventory_screen.is_open(), progress_before, _chest.contents.get_reveal_progress()]):
		finish(false)
		return

	# 7. 다시 열면 드러난 것과 진행이 그대로
	_necromancer.global_position = _chest.global_position + STAND_OFFSET
	await wait_frames(2)
	var progress_reopen: float = _chest.contents.get_reveal_progress()
	await _press_f()
	_check("다시 열면 그대로", _chest_screen.is_open() and not _chest_screen.get_slot_control(0).is_showing_hidden() and _chest_screen.get_slot_control(1).is_showing_hidden()
			and absf(progress_reopen - progress_before) < 0.1,
		"다시 열림 %s, 칸 %s (0번은 가져가서 빈 칸, 1번은 진행 %.2f에서 이어짐)" % [_chest_screen.is_open(), _slots_text(), progress_reopen])

	# 8. Shift+좌클릭 빠른 옮기기: 드러나지 않은 칸은 안 옮겨짐 → 드러나면 인벤토리로 → 인벤토리에서 상자로 (드러난 빈 칸에)
	var chest_inventory: Inventory = _chest.contents.inventory
	var skull: Skull = chest_inventory.get_slot(1).skull
	await shift_click_ui(_chest_screen.get_slot_control(1).get_global_rect().get_center())
	var hidden_kept: bool = chest_inventory.get_slot(1) != null and not inventory.get_skulls().has(skull)
	await _wander(2.6)
	var revealed: bool = _chest.contents.is_revealed(1)
	await shift_click_ui(_chest_screen.get_slot_control(1).get_global_rect().get_center())
	var skull_index: int = -1
	for i: int in inventory.get_slot_count():
		if inventory.get_slot(i) != null and inventory.get_slot(i).skull == skull:
			skull_index = i
	var taken_out: bool = skull_index != -1 and chest_inventory.get_slot(1) == null
	if skull_index != -1:
		await shift_click_ui(_inventory_screen.get_slot_control(skull_index).get_global_rect().get_center())
	var put_back: bool = chest_inventory.get_slot(0) != null and chest_inventory.get_slot(0).skull == skull and not inventory.get_skulls().has(skull)
	var quick_leaked: bool = _necromancer.is_attack_held()
	_check("Shift+좌클릭 빠른 옮기기", hidden_kept and revealed and taken_out and put_back and not quick_leaked,
		"드러나지 않은 1번 칸: 그대로 %s / 드러남 %s → 인벤토리 %d번으로 %s / 인벤토리 → 상자 0번(드러난 빈 칸) %s, 칸 %s / 공격으로 넘어감 %s" % [
			hidden_kept, revealed, skull_index, taken_out, put_back, _slots_text(), quick_leaked])
	finish(true)
