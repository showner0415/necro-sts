class_name InventorySlot
extends Panel
## 인벤토리 칸 하나. 비어 있거나, ItemStack 하나(뼈 N개 또는 머리뼈 하나)를 보여준다.
## - 뼈 같은 아이템: 임시 도형과 개수
## - 머리뼈: 임시 도형과 아래쪽 내구도 바 (항상 보임)
## 마우스 입력은 시그널로 알리기만 하고, 실제로 옮기거나 버리는 일은 바깥(InventoryScreen)이 한다.
## - 마우스를 올리고 내림: hovered / unhovered
## - 우클릭: drop_requested
## - 끌어서 다른 인벤토리 칸에 놓음: move_requested (Godot 기본 끌어서 놓기 기능을 쓴다)
## 끄는 데이터에는 머리뼈도 담기므로, 핫바 칸이 그것을 받아 바로가기로 놓을 수 있다.

signal hovered(index: int)
signal unhovered(index: int)
signal drop_requested(index: int)
signal move_requested(from_index: int, to_index: int)

## 끌어서 놓기 데이터의 키: 인벤토리 칸 번호
const DRAG_KEY: String = "inventory_slot"
## 끌어서 놓기 데이터의 키: 그 칸의 머리뼈 (머리뼈가 아니면 null)
const DRAG_SKULL_KEY: String = "skull"

## 인벤토리에서 몇 번째 칸인지
var index: int = -1

var _stack: ItemStack

@onready var _icon: ColorRect = %Icon
@onready var _count_label: Label = %CountLabel
@onready var _durability_bar: DurabilityBar = %DurabilityBar


func _ready() -> void:
	mouse_entered.connect(func() -> void: hovered.emit(index))
	mouse_exited.connect(func() -> void: unhovered.emit(index))


## 칸에 보여줄 물건. null이면 빈 칸.
func show_stack(stack: ItemStack) -> void:
	_stack = stack
	_icon.visible = stack != null
	_count_label.text = ""
	_durability_bar.show_skull(stack.skull if stack != null else null)
	if stack == null:
		return
	_icon.color = stack.item.placeholder_color
	# 아이콘 그림이 생기기 전까지 바닥에 그리는 임시 도형을 같은 크기로 보여준다.
	_icon.custom_minimum_size = stack.item.placeholder_size
	if not stack.is_skull():
		_count_label.text = str(stack.count)


func get_stack() -> ItemStack:
	return _stack


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT and _stack != null:
		drop_requested.emit(index)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _stack == null:
		return null
	set_drag_preview(make_drag_preview(_icon))
	return {DRAG_KEY: index, DRAG_SKULL_KEY: _stack.skull}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has(DRAG_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	move_requested.emit((data as Dictionary)[DRAG_KEY], index)


## 끄는 동안 마우스를 따라다니는 그림: 칸의 임시 도형을 그대로 복사한다.
static func make_drag_preview(icon: ColorRect) -> Control:
	var preview: ColorRect = ColorRect.new()
	preview.color = icon.color
	preview.size = icon.custom_minimum_size
	preview.position = -preview.size / 2.0
	var holder: Control = Control.new()
	holder.add_child(preview)
	return holder
