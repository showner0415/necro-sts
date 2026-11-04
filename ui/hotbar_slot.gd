class_name HotbarSlot
extends Panel
## 핫바 칸 하나. 가리키는 머리뼈의 임시 도형과 내구도 바를 보여준다 (비어 있으면 빈 칸).
## 마우스 입력은 시그널로 알리기만 하고, 실제로 바꾸는 일은 바깥(HotbarView)이 한다.
## - 인벤토리 칸의 머리뼈를 끌어 놓음: assign_requested
## - 다른 핫바 칸을 끌어 놓음: swap_requested
## - 우클릭: clear_requested (핫바에서만 빠진다)

signal assign_requested(index: int, skull: Skull)
signal swap_requested(from_index: int, to_index: int)
signal clear_requested(index: int)

## 끌어서 놓기 데이터의 키: 핫바 칸 번호
const DRAG_KEY: String = "hotbar_slot"

## 핫바에서 몇 번째 칸인지
var index: int = -1

var _skull: Skull

@onready var _icon: ColorRect = %Icon
@onready var _durability_bar: DurabilityBar = %DurabilityBar


## 칸에 보여줄 머리뼈. null이면 빈 칸.
func show_skull(skull: Skull) -> void:
	_skull = skull
	_icon.visible = skull != null
	_durability_bar.show_skull(skull)
	if skull == null:
		return
	_icon.color = skull.data.placeholder_color
	_icon.custom_minimum_size = skull.data.placeholder_size


func get_skull() -> Skull:
	return _skull


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT and _skull != null:
		clear_requested.emit(index)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _skull == null:
		return null
	set_drag_preview(InventorySlot.make_drag_preview(_icon))
	return {DRAG_KEY: index}


## 인벤토리 칸의 머리뼈이거나, 다른 핫바 칸이면 받는다. 뼈 같은 아이템은 받지 않는다.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var dict: Dictionary = data
	if dict.has(DRAG_KEY):
		return true
	return dict.has(InventorySlot.DRAG_KEY) and dict.get(InventorySlot.DRAG_SKULL_KEY) != null


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dict: Dictionary = data
	if dict.has(DRAG_KEY):
		swap_requested.emit(dict[DRAG_KEY], index)
	else:
		assign_requested.emit(index, dict[InventorySlot.DRAG_SKULL_KEY])
