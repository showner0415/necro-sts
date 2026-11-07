extends ScenarioTest
## 시나리오: 거점 창고. 거점에서 시작한다.
## 1. 상자 근처에서 "[F] 창고" 안내 → F로 인벤토리(가운데 왼쪽)와 창고(오른쪽)가 나란히 열린다
## 2. 핫바에 올린 머리뼈를 창고로 끌어 놓으면 핫바 칸이 빈다
## 3. 창고의 뼈를 인벤토리의 뼈 칸에 끌어 놓으면 합쳐진다
## 4. 소환 중인 머리뼈는 창고로 끌어 놓아도 옮겨지지 않는다
## 5. 창고 칸 우클릭 메뉴의 "인벤토리로 옮기기"
## 6. 휠로 창고를 스크롤해 아래 칸(100번째)이 보인다
## 7. 상자에서 멀어지면 둘 다 닫히고, Esc로도 둘 다 닫힌다
## 8. 지역에는 창고 상자와 창고 화면이 없다
## (창고 칸·화면 클릭이 공격으로 넘어가지 않는지도 여기서 확인한다. scenario_ui_click은 지역에서 시작해서 창고가 없다)
## 마우스는 흉내 낸 입력이다. 실제 마우스로 같은지는 눈으로 확인해야 한다.

const WAIT_FRAMES: int = 3
## 순간이동한 뒤 영역 판정과 안내 표시가 따라오기까지 기다리는 프레임
const SETTLE_FRAMES: int = 6
## 맨 아래까지 스크롤하려고 굴리는 휠 횟수 (넉넉하게)
const WHEEL_TICKS: int = 60
const BASE_SCENE: String = "res://regions/base.tscn"
const REGION_DATA_PATH: String = "res://data/regions/test_region.tres"
const REGION_SCENE: String = "res://regions/test_region.tscn"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const SCENE_TIMEOUT_FRAMES: int = 120
## 상자에서 이만큼 떨어지면 판정 영역 밖이다
const AWAY_OFFSET: Vector2 = Vector2(120, 0)

var _game_state: Node
var _inventory: Inventory
var _storage: Inventory
var _inventory_screen: InventoryScreen
var _storage_screen: InventoryScreen
var _necromancer: Necromancer
var _chest: StorageChest


func get_start_scene() -> String:
	return BASE_SCENE


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


func _storage_center(index: int) -> Vector2:
	return _storage_screen.get_slot_control(index).get_global_rect().get_center()


## 그 머리뼈가 든 칸 번호 (없으면 -1)
func _find_skull(container: Inventory, skull: Skull) -> int:
	for i: int in container.get_slot_count():
		if container.get_slot(i) != null and container.get_slot(i).skull == skull:
			return i
	return -1


## 뼈가 든 칸 번호 (없으면 -1)
func _find_bone(container: Inventory) -> int:
	for i: int in container.get_slot_count():
		if container.get_slot(i) != null and not container.get_slot(i).is_skull() and container.get_slot(i).item.id == &"bone":
			return i
	return -1


func _panel_rect(screen: InventoryScreen) -> Rect2:
	return (screen.get_node("Panel") as Control).get_global_rect()


func _open_with_f() -> void:
	_necromancer.global_position = _chest.global_position
	await wait_frames(SETTLE_FRAMES)
	press_key(KEY_F, true)
	press_key(KEY_F, false)
	await wait_frames(WAIT_FRAMES)


func _run() -> void:
	_game_state = root.get_node("GameState")
	_inventory = _game_state.inventory
	_storage = _game_state.storage
	_necromancer = find_necromancer()
	_chest = current_scene.find_children("*", "StorageChest", true, false).front()
	_inventory_screen = current_scene.get_node("InventoryScreen")
	_storage_screen = current_scene.get_node("StorageScreen")
	var bone: ItemData = load(BONE_PATH)
	var hotbar_skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	var summoned_skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	_inventory.try_add(ItemStack.of_skull(hotbar_skull))
	_inventory.try_add(ItemStack.of_item(bone, 5))
	_inventory.try_add(ItemStack.of_skull(summoned_skull))
	_storage.try_add(ItemStack.of_item(bone, 3))
	_game_state.hotbar.assign(0, hotbar_skull)
	_game_state.hotbar.assign(1, summoned_skull)
	_game_state.hotbar.select(1)
	_necromancer.summoner.toggle_selected()

	# 1. 상자에서 F
	_necromancer.global_position = _chest.global_position
	await wait_frames(SETTLE_FRAMES)
	var prompt: String = _chest.get_prompt_text() if _chest.is_prompt_visible() else "(안 보임)"
	press_key(KEY_F, true)
	press_key(KEY_F, false)
	await wait_frames(WAIT_FRAMES)
	var center_x: float = root.get_visible_rect().size.x / 2.0
	var inventory_rect: Rect2 = _panel_rect(_inventory_screen)
	var storage_rect: Rect2 = _panel_rect(_storage_screen)
	var evidence: String = "안내 '%s', 인벤토리 열림 %s (x %.0f~%.0f), 창고 열림 %s (x %.0f~%.0f), 화면 가운데 x %.0f, 창고 칸 %d" % [
		prompt, _inventory_screen.is_open(), inventory_rect.position.x, inventory_rect.end.x, _storage_screen.is_open(), storage_rect.position.x, storage_rect.end.x, center_x, _storage.get_slot_count()]
	if not _check("F로 창고 열기", prompt == "[F] 창고" and _inventory_screen.is_open() and _storage_screen.is_open() and inventory_rect.end.x <= center_x and storage_rect.position.x >= center_x and _storage.get_slot_count() == 100, evidence):
		return

	# 2. 핫바 머리뼈 → 창고
	await drag_ui(_inventory_center(0), _storage_center(1))
	evidence = "인벤토리 0번 → 창고 1번 끌기: 창고 1번이 그 머리뼈 %s, 인벤토리 0번 빔 %s, 핫바 0번 빔 %s" % [
		_storage.get_slot(1) != null and _storage.get_slot(1).skull == hotbar_skull, _inventory.get_slot(0) == null, _game_state.hotbar.get_skull(0) == null]
	if not _check("핫바 머리뼈를 창고로", _storage.get_slot(1) != null and _storage.get_slot(1).skull == hotbar_skull and _inventory.get_slot(0) == null and _game_state.hotbar.get_skull(0) == null, evidence):
		return

	# 3. 창고 뼈 → 인벤토리 뼈 칸 (합치기). 인벤토리 뼈는 처음 소환에 일부 썼다.
	var bones_before: int = _inventory.get_slot(1).count
	var storage_bones: int = _storage.get_slot(0).count
	await drag_ui(_storage_center(0), _inventory_center(1))
	evidence = "창고 0번(뼈 %d) → 인벤토리 1번(뼈 %d) 끌기: 인벤토리 1번 %s개, 창고 0번 빔 %s" % [storage_bones, bones_before,
		_inventory.get_slot(1).count if _inventory.get_slot(1) != null else -1, _storage.get_slot(0) == null]
	if not _check("뼈 합치기", _inventory.get_slot(1) != null and _inventory.get_slot(1).count == bones_before + storage_bones and _storage.get_slot(0) == null, evidence):
		return

	# 4. 소환 중인 머리뼈 → 창고 (막힘)
	await drag_ui(_inventory_center(2), _storage_center(2))
	evidence = "소환 중인 머리뼈(인벤토리 2번) → 창고 2번 끌기: 인벤토리에 그대로 %s, 창고 2번 빔 %s, 소환 중 %s" % [
		_inventory.get_slot(2) != null and _inventory.get_slot(2).skull == summoned_skull, _storage.get_slot(2) == null, _necromancer.summoner.roster.is_summoned(summoned_skull)]
	if not _check("소환 중인 머리뼈는 못 옮김", _inventory.get_slot(2) != null and _storage.get_slot(2) == null and _necromancer.summoner.roster.is_summoned(summoned_skull), evidence):
		return

	# 5. 창고 메뉴로 인벤토리에 보내기
	var ok: bool = await choose_inventory_menu(_storage_screen, 1, &"send_to_inventory")
	var back: bool = _inventory.get_skulls().has(hotbar_skull)
	if not _check("창고 메뉴 '인벤토리로 옮기기'", ok and back and _storage.get_slot(1) == null, "메뉴 항목 누름 %s, 머리뼈가 인벤토리로 돌아옴 %s, 창고 1번 빔 %s" % [ok, back, _storage.get_slot(1) == null]):
		return

	# 5-1. Shift+좌클릭 빠른 옮기기: 양방향, 뼈 합치기, 소환 중, 가득 참. 공격으로 넘어가지 않는다
	var skull_index: int = _find_skull(_inventory, hotbar_skull)
	var hud: Hud = find_hud()
	await shift_click_ui(_inventory_center(skull_index))
	var to_storage: bool = _storage.get_slot(0) != null and _storage.get_slot(0).skull == hotbar_skull and _inventory.get_slot(skull_index) == null
	_storage.try_add(ItemStack.of_item(bone, 4))
	var bone_index: int = _find_bone(_storage)
	var inventory_bones: int = _inventory.get_count(&"bone")
	await shift_click_ui(_storage_center(bone_index))
	var merged: bool = _inventory.get_count(&"bone") == inventory_bones + 4 and _storage.get_slot(bone_index) == null and _inventory.get_slot(skull_index) == null
	await shift_click_ui(_inventory_center(2))
	var summoned_text: String = hud.get_message()
	var summoned_stays: bool = _inventory.get_slot(2) != null and _inventory.get_slot(2).skull == summoned_skull
	var filler: Array[Skull] = []
	while _inventory.can_add(ItemStack.of_skull(Skull.create(load(RAT_SKULL_PATH)))):
		var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
		filler.append(skull)
		_inventory.try_add(ItemStack.of_skull(skull))
	await shift_click_ui(_storage_center(0))
	var full_text: String = hud.get_message()
	var full_stays: bool = _storage.get_slot(0) != null and _storage.get_slot(0).skull == hotbar_skull
	var shift_leaked: bool = _necromancer.is_attack_held()
	evidence = "인벤토리 머리뼈 → 창고 0번 %s / 창고 뼈 4 → 인벤토리 뼈 %d → %d (새 칸 안 씀 %s) / 소환 중 머리뼈: 그대로 %s, 안내 '%s' / 인벤토리 가득(머리뼈 %d개 채움): 창고에 그대로 %s, 안내 '%s' / 공격으로 넘어감 %s" % [
		to_storage, inventory_bones, _inventory.get_count(&"bone"), merged, summoned_stays, summoned_text, filler.size(), full_stays, full_text, shift_leaked]
	if not _check("Shift+좌클릭 빠른 옮기기", to_storage and merged and summoned_stays and summoned_text == "소환 중" and full_stays and full_text == "인벤토리 가득 참" and not shift_leaked, evidence):
		return
	for skull: Skull in filler:
		_inventory.remove_slot(_find_skull(_inventory, skull))
	# 머리뼈 칸 위에 마우스가 남으면 정보 줄이 세 줄이 되어 스크롤 영역이 줄어든다. 다음 단계(스크롤)는 정보 줄이 빈 상태에서 잰다.
	move_mouse_to_ui(Vector2.ZERO)
	await wait_frames(WAIT_FRAMES)

	# 6. 스크롤
	var last_index: int = _storage.get_slot_count() - 1
	var scroll: ScrollContainer = _storage_screen.get_node("%Scroll")
	var scroll_rect: Rect2 = scroll.get_global_rect()
	var last_visible_before: bool = scroll_rect.encloses(_storage_screen.get_slot_control(last_index).get_global_rect())
	var before: int = scroll.scroll_vertical
	for i: int in WHEEL_TICKS:
		await scroll_wheel_at_ui(scroll_rect.get_center())
	var last_visible_after: bool = scroll_rect.encloses(_storage_screen.get_slot_control(last_index).get_global_rect())
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	evidence = "휠 %d번(창고 스크롤 영역 가운데, 칸 위): 스크롤 %d → %d (최대 %.0f), 100번째 칸 보임 %s → %s (칸 %s, 영역 %s)" % [WHEEL_TICKS, before, scroll.scroll_vertical, bar.max_value - bar.page, last_visible_before, last_visible_after, _storage_screen.get_slot_control(last_index).get_global_rect(), scroll_rect]
	if not _check("창고 스크롤", scroll.scroll_vertical > before and not last_visible_before and last_visible_after, evidence):
		return

	# 창고 칸·창고 빈 곳 클릭은 게임 조작(공격)으로 넘어가지 않는다
	var leaked: bool = false
	# 맨 아래까지 스크롤했으므로 보이는 마지막 칸을 누른다.
	for point: Vector2 in [_storage_center(last_index), _panel_rect(_storage_screen).position + Vector2(6, 6)]:
		move_mouse_to_ui(point)
		await wait_frames(1)
		press_mouse_at_ui(point, MOUSE_BUTTON_LEFT, true)
		await wait_frames(WAIT_FRAMES)
		leaked = leaked or _necromancer.is_attack_held()
		press_mouse_at_ui(point, MOUSE_BUTTON_LEFT, false)
		await wait_frames(WAIT_FRAMES)
	if not _check("창고 클릭은 공격으로 안 넘어감", not leaked, "창고 칸과 창고 화면 가장자리를 누름: 게임 조작으로 넘어감 %s (기대 false)" % leaked):
		return

	# 7. 멀어지면 닫힘, Esc로 닫힘
	_necromancer.global_position = _chest.global_position + AWAY_OFFSET
	await wait_frames(WAIT_FRAMES)
	var away_closed: bool = not _storage_screen.is_open() and not _inventory_screen.is_open()
	await _open_with_f()
	var reopened: bool = _storage_screen.is_open()
	press_key(KEY_ESCAPE, true)
	press_key(KEY_ESCAPE, false)
	await wait_frames(WAIT_FRAMES)
	var esc_closed: bool = not _storage_screen.is_open() and not _inventory_screen.is_open()
	if not _check("창고 닫기", away_closed and reopened and esc_closed, "멀어지면 둘 다 닫힘 %s, 다시 F로 열림 %s, Esc로 둘 다 닫힘 %s" % [away_closed, reopened, esc_closed]):
		return

	# 8. 지역에는 창고가 없다
	# Region 타입을 쓰면 오토로드(GameState)보다 먼저 컴파일되어 실패하므로 이름으로 부른다.
	current_scene.call(&"travel_to", load(REGION_DATA_PATH))
	for i: int in SCENE_TIMEOUT_FRAMES:
		await wait_frames(1)
		if current_scene != null and current_scene.scene_file_path == REGION_SCENE:
			break
	await wait_frames(WAIT_FRAMES)
	var chests: int = current_scene.find_children("*", "StorageChest", true, false).size()
	var storage_screen: Node = current_scene.get_node_or_null("StorageScreen")
	if not _check("지역에는 창고 없음", current_scene.scene_file_path == REGION_SCENE and chests == 0 and storage_screen == null, "%s: 창고 상자 %d개, 창고 화면 %s" % [current_scene.scene_file_path, chests, storage_screen]):
		return
	finish(true)
