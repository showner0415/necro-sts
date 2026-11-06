class_name ItemMenu
extends Control
## 인벤토리 칸 우클릭 메뉴. 화면 전체를 덮는 투명한 판(이 노드) 위에 항목 목록(Panel)을 띄운다.
## - 항목은 아이템 데이터의 actions 순서대로 버튼 하나씩. 쓸 수 없는 항목은 회색 + 이유, 경고가 있으면 경고 색
## - 칸 오른쪽에 띄우고, 화면 오른쪽에 공간이 없으면 왼쪽에 띄운다
## - 바깥(투명한 판)을 클릭하거나 Esc를 누르면 닫힌다. 그 클릭은 여기서 받아 내므로 게임 조작으로 넘어가지 않는다
## 항목을 누르면 action_chosen으로 알리기만 하고, 실행은 바깥(InventoryScreen)이 한다.

signal action_chosen(action: ItemAction)
signal closed

## 칸과 메뉴 사이 간격 (픽셀)
@export var gap: float = 2.0
@export var font_size: int = 12
## 쓸 수 없는 항목의 글자 색
@export var disabled_color: Color = Color(0.60784316, 0.67058825, 0.69803923, 1)
## 되돌릴 수 없는 손해 경고(예: "죽은 판정이 됩니다")가 붙은 항목의 글자 색. 빨간색은 이 경우에만 쓴다.
@export var loss_warning_color: Color = Color(0.9098039, 0.23137255, 0.23137255, 1)
## 되돌릴 수 있는 결과 경고(예: "소환이 해제됩니다")가 붙은 항목의 글자 색. 핫바의 소환 중 테두리와 같은 노란색.
@export var caution_warning_color: Color = Color(0.9764706, 0.7607843, 0.16862746, 1)

var _buttons: Dictionary[StringName, Button] = {}

@onready var _panel: PanelContainer = %Panel
@onready var _items: VBoxContainer = %Items


func _ready() -> void:
	visible = false


func is_open() -> bool:
	return visible


## slot_rect(화면 좌표) 옆에 actions를 띄운다. states는 actions와 같은 순서의 상태.
func open(slot_rect: Rect2, actions: Array[ItemAction], states: Array[ItemActionState]) -> void:
	for child: Node in _items.get_children():
		_items.remove_child(child)
		child.queue_free()
	_buttons.clear()
	for action: ItemAction in actions:
		var button: Button = Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# 마우스로만 쓴다. 포커스를 받으면 Space(구르기)·Enter에 눌려 버린다.
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", font_size)
		button.add_theme_color_override("font_disabled_color", disabled_color)
		button.pressed.connect(func() -> void: action_chosen.emit(action))
		_items.add_child(button)
		_buttons[action.id] = button
	show_states(actions, states)
	visible = true
	_place(slot_rect)


## 열려 있는 동안 상태가 바뀌면(뼈 개수, 소환 등) 다시 그린다.
func show_states(actions: Array[ItemAction], states: Array[ItemActionState]) -> void:
	for i: int in actions.size():
		var button: Button = _buttons.get(actions[i].id)
		if button == null:
			continue
		var state: ItemActionState = states[i]
		button.disabled = not state.enabled
		button.text = state.label if not state.label.is_empty() else actions[i].label
		if not state.enabled and not state.reason.is_empty():
			button.text += " (%s)" % state.reason
		if not state.warning.is_empty():
			button.text += " - %s" % state.warning
			var color: Color = loss_warning_color if state.warning_kind == ItemActionState.WarningKind.LOSS else caution_warning_color
			button.add_theme_color_override("font_color", color)
			button.add_theme_color_override("font_hover_color", color)
		else:
			button.remove_theme_color_override("font_color")
			button.remove_theme_color_override("font_hover_color")


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## 테스트·디버그용: 그 항목의 버튼 (없으면 null)
func get_button(action_id: StringName) -> Button:
	return _buttons.get(action_id)


## 테스트·디버그용: 항목 목록의 화면 위치
func get_panel_rect() -> Rect2:
	return _panel.get_global_rect()


func _place(slot_rect: Rect2) -> void:
	_panel.reset_size()
	var menu_size: Vector2 = _panel.get_combined_minimum_size()
	var screen: Rect2 = get_viewport_rect()
	var x: float = slot_rect.end.x + gap
	if x + menu_size.x > screen.end.x:
		x = slot_rect.position.x - gap - menu_size.x
	var y: float = clampf(slot_rect.position.y, screen.position.y, screen.end.y - menu_size.y)
	_panel.position = Vector2(x, y)


## 메뉴 바깥(투명한 판)을 누르면 닫는다. 누른 클릭은 여기서 받아 낸다.
func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		close()
		accept_event()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
