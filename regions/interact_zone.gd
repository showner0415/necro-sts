class_name InteractZone
extends Area2D
## 거점 시설(출구, 창고 상자 등)의 공통 동작. 네크로맨서가 영역 안에 있으면 "[F] …" 안내가 뜨고,
## interact(F)를 누르면 interacted로 알린다. 무엇을 할지는 상속한 클래스나 지역 씬이 정한다.

signal interacted

## 영역의 반지름. 판정에 쓴다 (픽셀)
@export var radius: float = 16.0

## false면 안내도 띄우지 않고 F도 받지 않는다 (인벤토리가 열려 있을 때 등). 지역 씬이 정한다.
var enabled: bool = true

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _prompt: Label = %Prompt


func _ready() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	_collision.shape = shape
	_prompt.text = "[%s] %s" % [_action_key_name(&"interact"), get_prompt_label()]
	_prompt.visible = false


## 안내에 쓸 글자 ("[F] " 뒤에 붙는다). 상속한 클래스가 정한다.
func get_prompt_label() -> String:
	return ""


func _physics_process(_delta: float) -> void:
	_prompt.visible = enabled and is_necromancer_inside()


func is_necromancer_inside() -> bool:
	for body: Node2D in get_overlapping_bodies():
		if body is Necromancer:
			return true
	return false


func is_prompt_visible() -> bool:
	return _prompt.visible


func get_prompt_text() -> String:
	return _prompt.text


func _unhandled_input(event: InputEvent) -> void:
	if enabled and event.is_action_pressed(&"interact") and is_necromancer_inside():
		get_viewport().set_input_as_handled()
		interacted.emit()


func _action_key_name(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null:
			return key_event.as_text_physical_keycode()
	return String(action)
