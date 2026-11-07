class_name InventorySlot
extends Panel
## 인벤토리 칸 하나. 비어 있거나, ItemStack 하나(뼈 N개 또는 머리뼈 하나)를 보여준다.
## - 뼈 같은 아이템: 임시 도형과 개수
## - 머리뼈: 임시 도형과 아래쪽 내구도 바 (항상 보임)
## - 아직 무엇인지 드러나지 않은 칸(상자, Inventory.is_locked): 어두운 칸에 "?". 드러나는 중이면 아래쪽에 진행 바.
##   이 칸은 끌거나 이 칸에 놓을 수 없다
## 마우스 입력은 시그널로 알리기만 하고, 실제로 옮기거나 버리는 일은 바깥(InventoryScreen)이 한다.
## - 마우스를 올리고 내림: hovered / unhovered
## - 우클릭: menu_requested (아이템 메뉴)
## - Shift+좌클릭: quick_move_requested (반대쪽으로 바로 옮기기). 이 누름으로는 끌기가 시작되지 않는다
## - 끌어서 다른 칸(같은 화면이나 인벤토리 ↔ 창고)에 놓음: move_requested (Godot 기본 끌어서 놓기 기능을 쓴다)
## 끄는 데이터에는 머리뼈도 담기므로, 핫바 칸이 그것을 받아 바로가기로 놓을 수 있다.

signal hovered(index: int)
signal unhovered(index: int)
signal menu_requested(index: int)
signal quick_move_requested(index: int)
signal move_requested(from_container: Inventory, from_index: int, to_index: int)

## 끌어서 놓기 데이터의 키: 인벤토리 칸 번호
const DRAG_KEY: String = "inventory_slot"
## 끌어서 놓기 데이터의 키: 그 칸이 들어 있는 곳 (인벤토리 또는 창고)
const DRAG_CONTAINER_KEY: String = "container"
## 끌어서 놓기 데이터의 키: 그 칸의 머리뼈 (머리뼈가 아니면 null)
const DRAG_SKULL_KEY: String = "skull"

## 이 칸이 들어 있는 곳 (인벤토리 또는 창고). 화면이 넣어 준다.
var container: Inventory
## 그 안에서 몇 번째 칸인지
var index: int = -1

var _stack: ItemStack
## Shift+좌클릭으로 누른 채면 true. 옮기지 못했을 때(가득 참 등) 그 누름으로 끌기가 시작되지 않게 한다.
var _quick_move_pressed: bool = false

@onready var _icon: ColorRect = %Icon
@onready var _count_label: Label = %CountLabel
@onready var _durability_bar: DurabilityBar = %DurabilityBar
@onready var _hidden_shade: ColorRect = %HiddenShade
@onready var _hidden_label: Label = %HiddenLabel
@onready var _reveal_bar: ColorRect = %RevealBar
@onready var _reveal_fill: ColorRect = %RevealFill


func _ready() -> void:
	mouse_entered.connect(func() -> void: hovered.emit(index))
	mouse_exited.connect(func() -> void: unhovered.emit(index))


## 칸에 보여줄 물건. null이면 빈 칸.
func show_stack(stack: ItemStack) -> void:
	_stack = stack
	_set_hidden(false)
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


## 아직 무엇인지 드러나지 않은 칸으로 보여준다. revealing이면 아래쪽에 progress(0~1)만큼 찬 진행 바.
func show_hidden(revealing: bool, progress: float) -> void:
	_stack = null
	_icon.visible = false
	_count_label.text = ""
	_durability_bar.show_skull(null)
	_set_hidden(true)
	_reveal_bar.visible = revealing
	_reveal_fill.anchor_right = clampf(progress, 0.0, 1.0)


## 테스트용: 드러나지 않은 칸("?")으로 보이는지
func is_showing_hidden() -> bool:
	return _hidden_label.visible


## 테스트용: 진행 바 비율 (진행 바가 안 보이면 -1)
func get_reveal_bar_ratio() -> float:
	return _reveal_fill.anchor_right if _reveal_bar.visible else -1.0


func _set_hidden(hidden: bool) -> void:
	_hidden_shade.visible = hidden
	_hidden_label.visible = hidden
	if not hidden:
		_reveal_bar.visible = false


func get_stack() -> ItemStack:
	return _stack


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null:
		return
	if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		_quick_move_pressed = false
	elif button.pressed and button.button_index == MOUSE_BUTTON_LEFT and button.shift_pressed and _stack != null:
		_quick_move_pressed = true
		quick_move_requested.emit(index)
		accept_event()
	elif button.pressed and button.button_index == MOUSE_BUTTON_RIGHT and _stack != null:
		menu_requested.emit(index)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _stack == null or _quick_move_pressed:
		return null
	set_drag_preview(make_drag_preview(_icon))
	return {DRAG_KEY: index, DRAG_CONTAINER_KEY: container, DRAG_SKULL_KEY: _stack.skull}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# 아직 드러나지 않은 칸에는 놓을 수 없다.
	return data is Dictionary and (data as Dictionary).has(DRAG_KEY) and not (container != null and container.is_locked(index))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dict: Dictionary = data
	move_requested.emit(dict.get(DRAG_CONTAINER_KEY, container), dict[DRAG_KEY], index)


## 끄는 동안 마우스를 따라다니는 그림: 칸의 임시 도형을 그대로 복사한다.
static func make_drag_preview(icon: ColorRect) -> Control:
	var preview: ColorRect = ColorRect.new()
	preview.color = icon.color
	preview.size = icon.custom_minimum_size
	preview.position = -preview.size / 2.0
	var holder: Control = Control.new()
	holder.add_child(preview)
	return holder
