class_name RepairScreen
extends CanvasLayer
## 거점 수리 기계의 창. 인벤토리(가운데 왼쪽)와 나란히 오른쪽에 뜬다.
## - 칸에 인벤토리의 머리뼈를 끌어 놓으면 그 머리뼈가 수리 대상이 된다 (가리키기만 하고 인벤토리에서 빼지 않는다)
## - 칸을 우클릭하면 칸에서만 빠진다. 가리키던 머리뼈가 인벤토리에서 사라지면(창고로 옮김, 버림) 칸이 빈다
## - 정보 줄: 머리뼈 이름, 내구도, 다 채우는 데 드는 뼈와 가진 뼈
## - 수리 버튼: 뼈를 써서 내구도를 채운다. 모자라면 가진 만큼 일부만 채운다 (SkullRepair)
##   못 쓸 때는 회색 버튼과 이유(소환 중, 내구도 가득, 뼈 부족)를 보여준다
## Esc를 누르면 닫히고, 열고 닫을 때 open_changed로 알린다. 기계에서 멀어지면 지역 씬이 닫는다.

signal open_changed(is_open: bool)

## 빈 칸일 때 안내
@export var empty_text: String = "머리뼈를 끌어 놓으세요"
## 정보 줄. 순서대로 이름, 지금 내구도, 최대 내구도
@export var durability_format: String = "%s\n내구도 %d / %d"
## 비용 줄. 순서대로 비용 아이템 이름, 다 채우는 데 드는 개수, 가진 개수
@export var cost_format: String = "필요한 %s %d개 (가진 %s %d개)"
@export var summoned_reason: String = "소환 중"
@export var full_reason: String = "내구도 가득"
@export var no_cost_item_reason: String = "%s 부족"
## 쓸 수 없는 이유의 글자 색
@export var reason_color: Color = Color(0.54509807, 0.60784316, 0.7058824, 1)

var _repair: SkullRepair
var _inventory: Inventory
var _roster: UndeadRoster
## 비용 아이템 이름 (정보 줄에 쓴다)
var _cost_name: String = ""
var _skull: Skull

@onready var _slot: RepairSlot = %Slot
@onready var _info_label: Label = %InfoLabel
@onready var _cost_label: Label = %CostLabel
@onready var _repair_button: Button = %RepairButton
@onready var _reason_label: Label = %ReasonLabel


func _ready() -> void:
	visible = false
	_slot.skull_dropped.connect(set_skull)
	_slot.clear_requested.connect(set_skull.bind(null))
	_repair_button.pressed.connect(repair)
	_reason_label.add_theme_color_override("font_color", reason_color)


## 수리 규칙과 네크로맨서의 인벤토리를 연결한다. cost_name은 비용 아이템의 이름 (예: "뼈").
func bind(repair_rule: SkullRepair, inventory: Inventory, roster: UndeadRoster, cost_name: String) -> void:
	_repair = repair_rule
	if _inventory != inventory:
		if _inventory != null:
			_inventory.changed.disconnect(_on_inventory_changed)
		_inventory = inventory
		_inventory.changed.connect(_on_inventory_changed)
	if _roster != roster:
		if _roster != null:
			_roster.changed.disconnect(_refresh)
		_roster = roster
		# 소환·해제하면 버튼 상태(소환 중)가 바뀌므로 다시 그린다.
		if _roster != null:
			_roster.changed.connect(_refresh)
	_cost_name = cost_name
	_refresh()


func is_open() -> bool:
	return visible


func set_open(open: bool) -> void:
	if visible == open:
		return
	visible = open
	_refresh()
	open_changed.emit(open)


## 수리할 머리뼈를 정한다. 인벤토리에 없는 머리뼈(창고 칸에서 끌어 온 것 등)는 받지 않는다. null이면 칸을 비운다.
func set_skull(skull: Skull) -> void:
	if skull != null and (_inventory == null or not _inventory.get_skulls().has(skull)):
		return
	_skull = skull
	_refresh()


func get_skull() -> Skull:
	return _skull


## 수리 버튼을 누른 것과 같다. 실제로 수리했으면 true.
func repair() -> bool:
	if _repair == null:
		return false
	var result: SkullRepair.Result = _repair.repair(_skull)
	_refresh()
	return result == SkullRepair.Result.OK


## 테스트·디버그용
func get_slot_control() -> RepairSlot:
	return _slot


func get_repair_button() -> Button:
	return _repair_button


func get_info_text() -> String:
	return _info_label.text


func get_cost_text() -> String:
	return _cost_label.text


func get_reason_text() -> String:
	return _reason_label.text if _reason_label.visible else ""


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _on_inventory_changed() -> void:
	# 가리키던 머리뼈가 인벤토리에서 사라지면(창고로 옮김, 버림) 칸을 비운다.
	if _skull != null and not _inventory.get_skulls().has(_skull):
		_skull = null
	_refresh()


func _refresh() -> void:
	if _slot == null:
		return
	_slot.show_skull(_skull)
	if _skull == null:
		_info_label.text = empty_text
		_cost_label.text = ""
	else:
		_info_label.text = durability_format % [_skull.get_display_name(), ceili(_skull.durability), ceili(_skull.data.max_durability)]
		var cost: int = _repair.get_cost(_skull) if _repair != null else 0
		var owned: int = _repair.get_owned_count() if _repair != null else 0
		_cost_label.text = cost_format % [_cost_name, cost, _cost_name, owned]
	var result: SkullRepair.Result = _repair.check(_skull) if _repair != null else SkullRepair.Result.NO_SKULL
	_repair_button.disabled = result != SkullRepair.Result.OK
	var reason: String = _reason_for(result)
	_reason_label.text = reason
	_reason_label.visible = not reason.is_empty()


func _reason_for(result: SkullRepair.Result) -> String:
	match result:
		SkullRepair.Result.SUMMONED:
			return summoned_reason
		SkullRepair.Result.FULL:
			return full_reason
		SkullRepair.Result.NO_COST_ITEM:
			return no_cost_item_reason % _cost_name
	# 빈 칸은 정보 줄의 안내로 충분하다.
	return ""
