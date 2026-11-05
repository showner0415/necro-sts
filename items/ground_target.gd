class_name GroundTarget
extends Area2D
## 네크로맨서가 근처에서 E(pickup 입력)로 다루는 바닥의 대상 (바닥 더미, 시체)의 공통 부분.
## 대상 위에 이름과 키 안내를 띄운다. 네크로맨서가 줍기 범위 안에서 가장 가까운 대상 하나에만 set_prompt()로 띄운다.
## 씬에는 %Prompt 라벨이 있어야 한다.

## 키 안내에 쓸 입력 이름. 글자는 이 입력에 묶인 키에서 가져온다.
const PICKUP_ACTION: StringName = &"pickup"
## 인벤토리에 넣을 자리가 없을 때 키 안내 대신 쓰는 글자
const FULL_TEXT: String = "인벤토리 가득 참"

var _key_text: String

@onready var _prompt: Label = %Prompt


func _ready() -> void:
	_key_text = "[%s]" % _action_key_name(PICKUP_ACTION)
	_prompt.visible = false


## 안내에 보여줄 이름. 상속한 쪽에서 정한다.
func get_display_name() -> String:
	return ""


## E 대상이 될 수 있는지. false면 가까이 가도 안내가 뜨지 않는다 (빈 시체 등).
func is_available() -> bool:
	return true


## 지금 인벤토리로 받을 수 있는지. false면 키 안내 대신 "인벤토리 가득 참"을 띄운다.
func can_receive(_inventory: Inventory) -> bool:
	return true


## 안내를 보이거나 숨긴다. can_use가 false면 키 안내 대신 "인벤토리 가득 참"을 쓴다.
func set_prompt(prompt_visible: bool, can_use: bool = true) -> void:
	_prompt.visible = prompt_visible
	if prompt_visible:
		_prompt.text = "%s\n%s" % [get_display_name(), _key_text if can_use else FULL_TEXT]


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
