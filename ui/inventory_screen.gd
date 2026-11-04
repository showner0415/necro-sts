class_name InventoryScreen
extends CanvasLayer
## inventory 입력(Tab)으로 여닫는 인벤토리 화면.
## 인벤토리 칸 수만큼 칸을 항상 보여준다 (빈 칸 포함). 물건은 들어 있는 칸 위치에 보인다.
## - 칸에 마우스를 올리면 아래쪽 정보 줄에 이름(머리뼈는 내구도, 뼈는 개수)을 보여준다
## - 칸을 끌어서 다른 칸에 놓으면 옮기거나 자리를 바꾼다 (인벤토리 바깥에 놓으면 아무 일도 없다)
## - 칸을 우클릭하면 drop_requested로 알린다. 실제로 버리는 일은 지역 씬이 한다
## 열려 있어도 게임은 멈추지 않는다. 열고 닫을 때 open_changed로 알린다.

signal open_changed(is_open: bool)
signal drop_requested(slot_index: int)

@export var slot_scene: PackedScene

var _inventory: Inventory
var _slots: Array[InventorySlot] = []
## 마우스가 올라가 있는 칸 (-1이면 없음)
var _hovered_index: int = -1

@onready var _grid: GridContainer = %Grid
@onready var _info_label: Label = %InfoLabel


func _ready() -> void:
	visible = false


## 보여줄 인벤토리를 연결하고 칸을 만든다.
func bind(inventory: Inventory) -> void:
	_inventory = inventory
	_inventory.changed.connect(_refresh)
	for i: int in _inventory.get_slot_count():
		var slot: InventorySlot = slot_scene.instantiate()
		slot.index = i
		_grid.add_child(slot)
		slot.hovered.connect(_on_slot_hovered)
		slot.unhovered.connect(_on_slot_unhovered)
		slot.drop_requested.connect(func(index: int) -> void: drop_requested.emit(index))
		slot.move_requested.connect(_on_slot_move_requested)
		_slots.append(slot)
	_refresh()


func is_open() -> bool:
	return visible


func set_open(open: bool) -> void:
	if visible == open:
		return
	visible = open
	_hovered_index = -1
	_refresh()
	open_changed.emit(open)


## 테스트·디버그용: 그 번호의 칸
func get_slot_control(index: int) -> InventorySlot:
	return _slots[index]


## 테스트·디버그용: 정보 줄의 글자
func get_info_text() -> String:
	return _info_label.text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory"):
		set_open(not visible)
		get_viewport().set_input_as_handled()


func _on_slot_hovered(index: int) -> void:
	_hovered_index = index
	_update_info()


func _on_slot_unhovered(index: int) -> void:
	if _hovered_index == index:
		_hovered_index = -1
		_update_info()


func _on_slot_move_requested(from_index: int, to_index: int) -> void:
	_inventory.move_slot(from_index, to_index)


func _refresh() -> void:
	for i: int in _slots.size():
		_slots[i].show_stack(_inventory.get_slot(i))
	_update_info()


func _update_info() -> void:
	var stack: ItemStack = _inventory.get_slot(_hovered_index) if _hovered_index != -1 else null
	if stack == null:
		_info_label.text = ""
	elif stack.is_skull():
		_info_label.text = "%s\n내구도 %d / %d" % [stack.get_display_name(), ceili(stack.skull.durability), ceili(stack.skull.data.max_durability)]
	else:
		_info_label.text = "%s\n%d개" % [stack.get_display_name(), stack.count]
