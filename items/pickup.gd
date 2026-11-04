class_name Pickup
extends Area2D
## 바닥에 떨어진 물건 더미. 안에 ItemStack 하나(뼈 N개 또는 머리뼈 하나)를 담는다.
## 네크로맨서가 근처에서 줍기 키를 누르면 인벤토리로 들어간다.
## 지금 주울 수 있는 더미 위에는 네크로맨서가 set_prompt()로 이름과 안내를 띄운다.

## 키 안내에 쓸 입력 이름. 글자는 이 입력에 묶인 키에서 가져온다.
const PICKUP_ACTION: StringName = &"pickup"
## 인벤토리에 넣을 자리가 없을 때 키 안내 대신 쓰는 글자
const FULL_TEXT: String = "인벤토리 가득 참"

var stack: ItemStack

var _key_text: String

@onready var _prompt: Label = %Prompt


func _ready() -> void:
	_key_text = "[%s]" % _action_key_name(PICKUP_ACTION)
	_prompt.visible = false


func get_display_name() -> String:
	return stack.get_display_name()


## 안내를 보이거나 숨긴다. can_pick_up이 false면 키 안내 대신 "인벤토리 가득 참"을 쓴다.
func set_prompt(prompt_visible: bool, can_pick_up: bool = true) -> void:
	_prompt.visible = prompt_visible
	if prompt_visible:
		_prompt.text = "%s\n%s" % [get_display_name(), _key_text if can_pick_up else FULL_TEXT]


func is_prompt_visible() -> bool:
	return _prompt.visible


func get_prompt_text() -> String:
	return _prompt.text


func _action_key_name(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event == null:
			continue
		if key_event.keycode != KEY_NONE:
			return OS.get_keycode_string(key_event.keycode)
		return key_event.as_text_physical_keycode()
	return String(action)


func _draw() -> void:
	# 그림이 생기기 전까지 쓰는 임시 도형. 기준점(바닥) 위에 사각형을 그린다.
	var size: Vector2 = stack.item.placeholder_size
	draw_rect(Rect2(Vector2(-size.x / 2.0, -size.y), size), stack.item.placeholder_color)
