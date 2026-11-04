class_name InventorySlot
extends Panel
## 인벤토리 칸 하나. 비어 있거나, ItemStack 하나(뼈 N개 또는 머리뼈 하나)를 보여준다.
## - 뼈 같은 아이템: 임시 도형과 개수
## - 머리뼈: 임시 도형과 아래쪽 내구도 바 (항상 보임, 현재 / 최대 비율만큼 채워짐)
## 마우스 입력은 시그널로 알리기만 하고, 실제로 옮기거나 버리는 일은 바깥(InventoryScreen)이 한다.
## - 마우스를 올리고 내림: hovered / unhovered
## - 우클릭: drop_requested
## - 끌어서 다른 칸에 놓음: move_requested (Godot 기본 끌어서 놓기 기능을 쓴다)

signal hovered(index: int)
signal unhovered(index: int)
signal drop_requested(index: int)
signal move_requested(from_index: int, to_index: int)

## 끌어서 놓기 데이터에 칸 번호를 담을 때 쓰는 키
const DRAG_KEY: String = "inventory_slot"

@export_group("내구도 바 색")
@export var durability_color: Color = Color(0.11764706, 0.7372549, 0.4509804, 1)
## 비율이 이 값 이하이면 low 색 (0~1)
@export_range(0.0, 1.0) var low_durability_ratio: float = 0.5
@export var low_durability_color: Color = Color(0.9764706, 0.7607843, 0.16862746, 1)
## 비율이 이 값 이하이면 critical 색 (0~1)
@export_range(0.0, 1.0) var critical_durability_ratio: float = 0.25
@export var critical_durability_color: Color = Color(0.9098039, 0.23137255, 0.23137255, 1)

## 인벤토리에서 몇 번째 칸인지
var index: int = -1

var _stack: ItemStack

@onready var _icon: ColorRect = %Icon
@onready var _count_label: Label = %CountLabel
@onready var _durability_bar: ProgressBar = %DurabilityBar


func _ready() -> void:
	# 칸마다 바 색이 달라지므로 스타일을 복사해서 이 칸만 바꾼다.
	_durability_bar.add_theme_stylebox_override("fill", _durability_bar.get_theme_stylebox("fill").duplicate())
	mouse_entered.connect(func() -> void: hovered.emit(index))
	mouse_exited.connect(func() -> void: unhovered.emit(index))


## 칸에 보여줄 물건. null이면 빈 칸.
func show_stack(stack: ItemStack) -> void:
	_stack = stack
	_icon.visible = stack != null
	_count_label.text = ""
	_durability_bar.visible = false
	if stack == null:
		return
	_icon.color = stack.item.placeholder_color
	# 아이콘 그림이 생기기 전까지 바닥에 그리는 임시 도형을 같은 크기로 보여준다.
	_icon.custom_minimum_size = stack.item.placeholder_size
	if stack.is_skull():
		_durability_bar.visible = true
		_durability_bar.max_value = stack.skull.data.max_durability
		_durability_bar.value = stack.skull.durability
		(_durability_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = _durability_bar_color(_durability_bar.ratio)
	else:
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
	# 끄는 동안 마우스를 따라다니는 그림: 칸의 임시 도형을 그대로 복사한다.
	var preview: ColorRect = ColorRect.new()
	preview.color = _icon.color
	preview.size = _icon.custom_minimum_size
	preview.position = -preview.size / 2.0
	var holder: Control = Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return {DRAG_KEY: index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has(DRAG_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	move_requested.emit((data as Dictionary)[DRAG_KEY], index)


func _durability_bar_color(ratio: float) -> Color:
	if ratio <= critical_durability_ratio:
		return critical_durability_color
	if ratio <= low_durability_ratio:
		return low_durability_color
	return durability_color
