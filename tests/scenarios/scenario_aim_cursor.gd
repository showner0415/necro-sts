extends ScenarioTest
## 시나리오: 조준점 커서. 거점에서 시작해 창고를 보고, 시험 지역으로 가서 상자를 본다.
## 1. HUD의 AimCursor가 창 배율에 맞는 그림을 넣었고, 기본 커서 모양이 십자(조준점)다
## 2. 게임 화면과 장식용 HUD(체력 바, 뼈 개수, 안내 문구) 위에서는 조준점, 핫바 칸 위에서는 화살표
## 3. 인벤토리 칸·창 위, 우클릭 메뉴 위에서는 화살표. 인벤토리가 열려 있어도 게임 화면 위는 조준점
## 4. 창고 칸 위에서는 화살표 (거점)
## 5. 시험 지역의 상자 칸 위에서는 화살표, 게임 화면은 조준점
## 커서 모양은 마우스 아래 컨트롤로 정해진다: 컨트롤이 없으면 기본 모양(십자 = 조준점), 있으면 그 컨트롤의 모양.
## 실제 시스템 커서가 그렇게 보이는지(따라오는 느낌 포함)는 눈으로 확인해야 한다.

const WAIT_FRAMES: int = 3
const BASE_SCENE: String = "res://regions/base.tscn"
const SETTLE_FRAMES: int = 6
const SCENE_TIMEOUT_FRAMES: int = 120
const REGION_DATA_PATH: String = "res://data/regions/test_region.tres"
const REGION_SCENE: String = "res://regions/test_region.tscn"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
## 지역 상자 앞에 서는 자리 (F 판정 반지름 24 안)
const CHEST_STAND_OFFSET: Vector2 = Vector2(0, 16)
## 게임 화면 쪽으로 보는 자리: 네크로맨서에게서 이만큼 떨어진 월드 좌표 (열린 인벤토리 창과 상자 창 사이)
const GAME_POINT_OFFSET: Vector2 = Vector2(-60, -60)

var _necromancer: Necromancer


func get_start_scene() -> String:
	return BASE_SCENE


func _on_scene_ready() -> void:
	_run()


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
		finish(false)
	return ok


## ui_position에 마우스를 올렸을 때의 커서 모양과, 그 아래 컨트롤 이름("없음"이면 게임 화면)
func _cursor_at(ui_position: Vector2) -> Array:
	move_mouse_to_ui(ui_position)
	await wait_frames(2)
	var hovered: Control = root.gui_get_hovered_control()
	if hovered == null:
		return [Input.CURSOR_CROSS, "없음"]
	return [hovered.get_cursor_shape(hovered.get_local_mouse_position()), hovered.name]


func _shape_name(shape: int) -> String:
	match shape:
		Input.CURSOR_CROSS:
			return "조준점"
		Input.CURSOR_ARROW:
			return "화살표"
	return "모양 %d" % shape


## 여러 자리를 차례로 보고 "이름: 모양(아래 컨트롤)" 글과, 모두 기대한 모양인지를 돌려준다.
func _check_points(points: Dictionary, expected: int) -> Array:
	var parts: PackedStringArray = []
	var ok: bool = true
	for label: String in points:
		var result: Array = await _cursor_at(points[label])
		ok = ok and result[0] == expected
		parts.append("%s: %s(%s)" % [label, _shape_name(result[0]), result[1]])
	return [ok, ", ".join(parts)]


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## 월드 좌표를 UI 좌표(CanvasLayer 기준)로
func _world_to_ui(world_position: Vector2) -> Vector2:
	return root.get_canvas_transform() * world_position


func _press(key: Key) -> void:
	press_key(key, true)
	await wait_frames(1)
	press_key(key, false)
	await wait_frames(WAIT_FRAMES)


func _run() -> void:
	var game_state: Node = root.get_node("GameState")
	game_state.inventory.try_add(ItemStack.of_skull(Skull.create(load(RAT_SKULL_PATH))))
	game_state.storage.try_add(ItemStack.of_item(load(BONE_PATH), 3))
	_necromancer = find_necromancer()
	var hud: Hud = find_hud()
	var aim: AimCursor = hud.get_node("AimCursor")

	# 1. 배율에 맞는 그림, 기본 모양 십자
	var expected_scale: int = aim.get_scale_for_window()
	if not _check("조준점 그림을 넣음", aim.get_applied_scale() == expected_scale and expected_scale >= 1,
			"넣은 그림 배율 %d (창 배율에 맞는 배율 %d, 그림 %d개)" % [aim.get_applied_scale(), expected_scale, aim.textures_by_scale.size()]):
		return

	# 2. 게임 화면·장식용 HUD는 조준점, 핫바 칸은 화살표
	var game_point: Vector2 = _world_to_ui(_necromancer.global_position + GAME_POINT_OFFSET)
	var hotbar_view: Control = hud.hotbar_view
	var result: Array = await _check_points({
		"게임 화면": game_point,
		"체력 바": _center(hud.get_node("Stats/HealthBar")),
		"뼈 개수": _center(hud.get_node("Stats/BoneLabel")),
		"안내 문구": _center(hud.get_node("%MessageLabel")),
		"마나 바": _center(hud.get_node("BottomLeft/ManaBar")),
	}, Input.CURSOR_CROSS)
	var hotbar: Array = await _check_points({"핫바 칸": _center(hotbar_view.get_child(0))}, Input.CURSOR_ARROW)
	if not _check("게임 화면은 조준점, 핫바는 화살표", result[0] and hotbar[0], "%s / %s" % [result[1], hotbar[1]]):
		return

	# 3. 인벤토리 칸·창, 메뉴는 화살표. 열려 있어도 게임 화면은 조준점
	var inventory_screen: InventoryScreen = current_scene.get_node("InventoryScreen")
	await _press(KEY_TAB)
	var inventory_points: Array = await _check_points({
		"인벤토리 칸": _center(inventory_screen.get_slot_control(0)),
		"인벤토리 창 가장자리": (inventory_screen.get_node("Panel") as Control).get_global_rect().end - Vector2(4, 4),
	}, Input.CURSOR_ARROW)
	await click_ui(_center(inventory_screen.get_slot_control(0)), MOUSE_BUTTON_RIGHT)
	var menu: ItemMenu = inventory_screen.get_menu()
	var menu_points: Array = [false, "메뉴가 안 열림"]
	if menu.is_open():
		menu_points = await _check_points({"메뉴 항목": _center(menu.get_button(&"drop"))}, Input.CURSOR_ARROW)
	await _press(KEY_ESCAPE)
	var open_game: Array = await _check_points({"인벤토리 연 채 게임 화면": game_point}, Input.CURSOR_CROSS)
	await _press(KEY_TAB)
	if not _check("인벤토리·메뉴는 화살표", inventory_points[0] and menu_points[0] and open_game[0], "%s / %s / %s" % [inventory_points[1], menu_points[1], open_game[1]]):
		return

	# 4. 창고 칸은 화살표
	var storage_chest: Node2D = current_scene.find_children("*", "StorageChest", true, false).front()
	_necromancer.global_position = storage_chest.global_position
	await wait_frames(SETTLE_FRAMES)
	await _press(KEY_F)
	var storage_screen: InventoryScreen = current_scene.get_node("StorageScreen")
	var storage_points: Array = await _check_points({"창고 칸": _center(storage_screen.get_slot_control(0))}, Input.CURSOR_ARROW)
	if not _check("창고는 화살표", storage_screen.is_open() and storage_points[0], "창고 열림 %s, %s" % [storage_screen.is_open(), storage_points[1]]):
		return
	await _press(KEY_ESCAPE)

	# 5. 시험 지역의 상자 칸은 화살표, 게임 화면은 조준점
	# Region 타입을 쓰면 오토로드(GameState)보다 먼저 컴파일되어 실패하므로 이름으로 부른다.
	current_scene.call(&"travel_to", load(REGION_DATA_PATH))
	for i: int in SCENE_TIMEOUT_FRAMES:
		await wait_frames(1)
		if current_scene != null and current_scene.scene_file_path == REGION_SCENE:
			break
	await wait_frames(WAIT_FRAMES)
	_necromancer = find_necromancer()
	var chest: Node2D = current_scene.get_node("ChestSafe")
	_necromancer.global_position = chest.global_position + CHEST_STAND_OFFSET
	await wait_frames(SETTLE_FRAMES)
	await _press(KEY_F)
	var chest_screen: InventoryScreen = current_scene.get_node("ChestScreen")
	var chest_points: Array = await _check_points({"상자 칸": _center(chest_screen.get_slot_control(0))}, Input.CURSOR_ARROW)
	var region_game: Array = await _check_points({"지역 게임 화면": _world_to_ui(_necromancer.global_position + GAME_POINT_OFFSET)}, Input.CURSOR_CROSS)
	var region_aim: AimCursor = find_hud().get_node("AimCursor")
	if not _check("상자는 화살표, 지역 게임 화면은 조준점", chest_screen.is_open() and chest_points[0] and region_game[0] and region_aim.get_applied_scale() >= 1,
			"상자 열림 %s, %s / %s, 지역 HUD의 조준점 그림 배율 %d" % [chest_screen.is_open(), chest_points[1], region_game[1], region_aim.get_applied_scale()]):
		return
	finish(true)
