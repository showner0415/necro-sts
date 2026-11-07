class_name ScenarioTest
extends SceneTree
## 시나리오 테스트의 기반 클래스. tests/scenarios/scenario_*.gd가 이 클래스를 상속한다.
## 메인 씬을 띄우고 입력을 흉내 내서 게임 흐름을 끝까지 진행한다.
##
## 작성 규칙:
## - 파일 이름은 scenario_<흐름>.gd
## - 메인 씬(또는 get_start_scene())이 준비되면 _on_scene_ready()가 한 번, 그 뒤 물리 프레임마다 _tick()이 불린다
## - 단계마다 pass_step()/fail_step()으로 근거를 남기고, 모두 끝나면 finish(true)를 부른다
## - 입력은 aim_mouse_at(), press_mouse(), press_key(), press_moves()로 흉내 낸다
##   UI(인벤토리 등)는 move_mouse_to_ui(), press_mouse_at_ui(), drag_ui()로 흉내 낸다
## - 단계가 긴 시나리오는 _on_scene_ready()에서 async 함수를 시작하고 await wait_frames()로 기다려도 된다
## - 흉내 낸 마우스 입력이 통과해도 실제 마우스에서 같다는 보장은 없다. 눈으로도 확인을 받는다
## - 무작위 값은 RANDOM_SEED로 고정되므로 같은 코드면 결과가 매번 같다
##
## 하나만 실행: bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/scenarios/<파일>
## --fixed-fps 60이 없으면 화면 프레임과 물리 프레임이 어긋나서 시간 계산이 틀어진다.

const RANDOM_SEED: int = 1
## 몬스터가 있는 시험 지역. 게임은 거점에서 시작하므로, 지역이 필요한 시나리오는 get_start_scene()에서 이것을 돌려준다.
const TEST_REGION_SCENE: String = "res://regions/test_region.tscn"
## 시작 씬을 불러오기까지 기다리는 최대 물리 프레임 수
const SCENE_LOAD_TIMEOUT_FRAMES: int = 300


## 현재 단계에서 지난 물리 프레임 수. restart_step_timer()로 0이 된다.
var step_frames: int = 0
var _scene_ready: bool = false
## 흉내 낸 마우스의 마지막 창 좌표 (이동량 계산용)
var _last_mouse_window_position: Vector2 = Vector2.ZERO
var _done: bool = false
## 시작 씬을 기다린 프레임 수
var _load_wait_frames: int = 0


func _initialize() -> void:
	var main_scene: String = get_start_scene()
	if main_scene.is_empty():
		fail_step("준비", "메인 씬이 지정되어 있지 않습니다")
		return
	print("메인 씬: %s, 난수 시드 %d" % [main_scene, RANDOM_SEED])
	seed(RANDOM_SEED)
	change_scene_to_file(main_scene)


func _physics_process(_delta: float) -> bool:
	if _done:
		return false
	if not _scene_ready:
		if current_scene == null:
			# 씬을 불러오지 못하면(씬 파일 오류 등) 끝없이 기다리지 않고 실패로 끝낸다.
			_load_wait_frames += 1
			if _load_wait_frames > SCENE_LOAD_TIMEOUT_FRAMES:
				fail_step("준비", "%d프레임 안에 시작 씬(%s)을 불러오지 못했습니다" % [SCENE_LOAD_TIMEOUT_FRAMES, get_start_scene()])
				finish(false)
			return false
		_scene_ready = true
		_on_scene_ready()
		return false
	step_frames += 1
	_tick()
	return false


## 시작할 씬. 기본은 메인 씬(거점)이고, 다른 씬(시험 지역 등)에서 시작하는 시나리오는 이 함수를 덮어쓴다.
func get_start_scene() -> String:
	return ProjectSettings.get_setting("application/run/main_scene", "")


## 메인 씬이 준비된 직후 한 번 불린다.
func _on_scene_ready() -> void:
	pass


## 물리 프레임마다 불린다.
func _tick() -> void:
	pass


func restart_step_timer() -> void:
	step_frames = 0


# --- 결과 ---

func pass_step(step_name: String, evidence: String) -> void:
	print("[통과] %s: %s" % [step_name, evidence])


func fail_step(step_name: String, evidence: String) -> void:
	print("[실패] %s: %s" % [step_name, evidence])
	finish(false)


func finish(success: bool) -> void:
	if _done:
		return
	_done = true
	print("결과: %s" % ("통과" if success else "실패"))
	quit(0 if success else 1)


# --- 입력 흉내 ---

func aim_mouse_at(world_position: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	# 월드 좌표 → 뷰포트 좌표 → 창 좌표
	event.position = root.get_final_transform() * (root.get_canvas_transform() * world_position)
	event.global_position = event.position
	_last_mouse_window_position = event.position
	# root.push_input()은 헤드리스에서 마우스 위치가 반영되지 않아 실제 입력과 같은 경로로 보낸다.
	Input.parse_input_event(event)


## UI 좌표(CanvasLayer 기준, 640×360 안)를 창 좌표로 바꾼다.
func ui_to_window(ui_position: Vector2) -> Vector2:
	return root.get_final_transform() * ui_position


## UI 좌표로 마우스를 옮긴다. held_mask에 누르고 있는 버튼을 넣으면 끄는 중인 움직임이 된다.
func move_mouse_to_ui(ui_position: Vector2, held_mask: int = 0) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = ui_to_window(ui_position)
	event.global_position = event.position
	# Godot는 버튼을 누른 채 움직인 거리를 relative로 누적해서 끌기 시작을 정하므로 꼭 넣는다.
	event.relative = event.position - _last_mouse_window_position
	event.button_mask = held_mask
	_last_mouse_window_position = event.position
	Input.parse_input_event(event)


## UI 좌표에서 마우스 버튼을 누르거나 뗀다. shift가 true면 Shift를 누른 채인 클릭이다.
func press_mouse_at_ui(ui_position: Vector2, button: MouseButton, pressed: bool, shift: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = ui_to_window(ui_position)
	event.global_position = event.position
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(event)


## 왼쪽 버튼으로 from에서 to까지 끌어서 놓는다 (UI 좌표). 여러 프레임에 걸쳐 움직인다.
func drag_ui(from: Vector2, to: Vector2, steps: int = 8) -> void:
	move_mouse_to_ui(from)
	await wait_frames(1)
	press_mouse_at_ui(from, MOUSE_BUTTON_LEFT, true)
	await wait_frames(1)
	for i: int in range(1, steps + 1):
		move_mouse_to_ui(from.lerp(to, float(i) / steps), MOUSE_BUTTON_MASK_LEFT)
		await wait_frames(1)
	press_mouse_at_ui(to, MOUSE_BUTTON_LEFT, false)
	await wait_frames(2)


## UI 좌표에서 마우스 휠을 한 칸 굴린다. down이 true면 아래로.
func scroll_wheel_at_ui(ui_position: Vector2, down: bool = true) -> void:
	move_mouse_to_ui(ui_position)
	await wait_frames(1)
	var button: MouseButton = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	press_mouse_at_ui(ui_position, button, true)
	press_mouse_at_ui(ui_position, button, false)
	await wait_frames(2)


## UI 좌표에서 버튼을 한 번 누르고 뗀다 (흉내 낸 마우스).
func click_ui(ui_position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	move_mouse_to_ui(ui_position)
	await wait_frames(1)
	press_mouse_at_ui(ui_position, button, true)
	await wait_frames(1)
	press_mouse_at_ui(ui_position, button, false)
	await wait_frames(2)


## UI 좌표에서 Shift를 누른 채 좌클릭한다 (빠른 옮기기). 실제 키보드처럼 Shift 키도 눌렀다 뗀다.
func shift_click_ui(ui_position: Vector2) -> void:
	press_key(KEY_SHIFT, true)
	move_mouse_to_ui(ui_position)
	await wait_frames(1)
	press_mouse_at_ui(ui_position, MOUSE_BUTTON_LEFT, true, true)
	await wait_frames(1)
	press_mouse_at_ui(ui_position, MOUSE_BUTTON_LEFT, false, true)
	press_key(KEY_SHIFT, false)
	await wait_frames(2)


## 인벤토리 칸을 우클릭해 메뉴를 열고 action_id 항목을 누른다. 메뉴나 항목이 없으면 false.
func choose_inventory_menu(screen: InventoryScreen, slot_index: int, action_id: StringName) -> bool:
	await click_ui(screen.get_slot_control(slot_index).get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	var button: Button = screen.get_menu().get_button(action_id) if screen.get_menu().is_open() else null
	if button == null:
		return false
	await click_ui(button.get_global_rect().get_center())
	return true


## 물리 프레임 n번을 기다린다. 시나리오를 위에서 아래로 읽히게 쓸 때 await와 함께 쓴다.
func wait_frames(n: int) -> void:
	for i: int in n:
		await physics_frame


## 마지막으로 마우스를 옮긴 자리(aim_mouse_at, move_mouse_to_ui)에서 버튼을 누르거나 뗀다.
## 위치를 비워 두면 Godot이 마우스를 (0, 0)으로 옮겨서 조준이 틀어진다.
func press_mouse(pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = _last_mouse_window_position
	event.global_position = _last_mouse_window_position
	Input.parse_input_event(event)


func press_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	# 실제 키보드처럼 둘 다 넣는다. 프로젝트 입력은 physical_keycode로,
	# Godot 기본 입력(ui_cancel 등)은 keycode로 정해져 있다.
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


## 방향(길이 1 이하)으로 move_* 입력을 누른다. Vector2.ZERO면 모두 뗀다.
func press_moves(direction: Vector2) -> void:
	_set_axis(&"move_left", &"move_right", direction.x)
	_set_axis(&"move_up", &"move_down", direction.y)


func _set_axis(negative: StringName, positive: StringName, value: float) -> void:
	if value < 0.0:
		Input.action_release(positive)
		Input.action_press(negative, -value)
	elif value > 0.0:
		Input.action_release(negative)
		Input.action_press(positive, value)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


# --- 찾기 ---

func find_necromancer() -> Necromancer:
	return get_first_node_in_group(&"necromancer") as Necromancer


func find_hud() -> Hud:
	for node: Node in current_scene.find_children("*", "CanvasLayer", true, false):
		if node is Hud:
			return node
	return null
