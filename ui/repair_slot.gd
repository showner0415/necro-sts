class_name RepairSlot
extends Panel
## 수리 기계 창의 머리뼈 칸. 인벤토리의 머리뼈를 끌어 놓으면 그 머리뼈를 가리킨다.
## 핫바처럼 가리키기만 한다: 머리뼈는 인벤토리에서 빠지지 않는다 (핫바 등록도 그대로).
## 마우스 입력은 시그널로 알리기만 하고, 실제로 바꾸는 일은 바깥(RepairScreen)이 한다.
## - 인벤토리 칸의 머리뼈를 끌어 놓음: skull_dropped (뼈 같은 아이템은 받지 않는다)
## - 우클릭: clear_requested (칸에서만 빠진다)

signal skull_dropped(skull: Skull)
signal clear_requested

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
		clear_requested.emit()
		accept_event()


## 인벤토리 칸의 머리뼈만 받는다. 창고 칸의 머리뼈인지는 바깥(RepairScreen)이 걸러 낸다.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has(InventorySlot.DRAG_KEY) and (data as Dictionary).get(InventorySlot.DRAG_SKULL_KEY) != null


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	skull_dropped.emit((data as Dictionary)[InventorySlot.DRAG_SKULL_KEY])
