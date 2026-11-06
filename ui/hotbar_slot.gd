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

@export_group("테두리")
## 선택된 칸: 칸 바깥쪽에 그리는 얇은 테두리
@export var selected_border_color: Color = Color(1, 1, 1, 1)
@export var selected_border_width: float = 1.0
## 소환 중인 머리뼈가 든 칸: 칸 안쪽 가장자리를 덮는 테두리
@export var summoned_border_color: Color = Color(0.99607843, 0.68235296, 0.20392157, 1)
@export var summoned_border_width: float = 2.0

## 핫바에서 몇 번째 칸인지
var index: int = -1

var _skull: Skull
var _selected: bool = false
var _summoned: bool = false

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


## 선택 테두리(흰색, 바깥쪽)와 소환 중 테두리(노란색, 안쪽)를 켜고 끈다. 둘이 같이 보일 수 있다.
func show_state(selected: bool, summoned: bool) -> void:
	if _selected == selected and _summoned == summoned:
		return
	_selected = selected
	_summoned = summoned
	queue_redraw()


func is_selected() -> bool:
	return _selected


func is_summoned() -> bool:
	return _summoned


func _draw() -> void:
	# 테두리 선은 사각형 둘레를 가운데로 해서 그려지므로, 선 두께의 절반만큼 키우거나 줄여서 안팎을 정한다.
	if _summoned:
		var inset: float = summoned_border_width / 2.0
		draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), summoned_border_color, false, summoned_border_width)
	if _selected:
		var outset: float = selected_border_width / 2.0
		draw_rect(Rect2(-Vector2(outset, outset), size + Vector2(outset, outset) * 2.0), selected_border_color, false, selected_border_width)


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
