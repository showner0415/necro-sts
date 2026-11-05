class_name InventoryScreen
extends CanvasLayer
## 칸으로 된 보관함 화면. 네크로맨서의 인벤토리(Tab으로 여닫음)와 거점 창고가 같은 스크립트를 쓴다.
## 칸 수만큼 칸을 항상 보여준다 (빈 칸 포함). 물건은 들어 있는 칸 위치에 보인다.
## - 칸에 마우스를 올리면 아래쪽 정보 줄에 이름(머리뼈는 내구도·체력·회복에 필요한 뼈, 뼈는 개수)을 보여준다
## - 칸을 끌어서 다른 칸(이 화면이나 다른 화면)에 놓으면 ItemTransfer 규칙으로 옮긴다 (바깥에 놓으면 아무 일도 없다)
## - 칸을 우클릭하면 메뉴(ItemMenu)를 띄운다. 항목은 아이템 데이터의 actions + 이 화면의 container_actions 중 보이는 것
## 열려 있어도 게임은 멈추지 않는다. 열고 닫을 때 open_changed로 알린다.

signal open_changed(is_open: bool)

@export var slot_scene: PackedScene
## 이 입력으로 여닫는다. 비워 두면 키로 여닫지 않는다 (창고는 상자에서 연다).
@export var toggle_action: StringName = &"inventory"
## true면 열려 있을 때 Esc(ui_cancel)로 닫는다.
@export var close_on_cancel: bool = false
## 아이템 종류와 상관없이 칸에 붙는 메뉴 항목 (창고로·인벤토리로 옮기기)
@export var container_actions: Array[ItemAction] = []

## 지금 열려 있는 창고. 인벤토리 화면은 창고가 열릴 때 지역 씬이 넣어 주고, 닫히면 null이 된다.
var open_storage: Inventory:
	set(value):
		open_storage = value
		if _menu != null:
			_menu.close()

## 이 화면이 보여주는 곳 (인벤토리 또는 창고)
var _container: Inventory
## 네크로맨서의 인벤토리 (창고 화면에서도 메뉴·옮기기 규칙에 쓴다)
var _player_inventory: Inventory
## 머리뼈 체력·회복 뼈를 계산한다. 없으면 내구도만 보여준다.
var _roster: UndeadRoster
var _transfer: ItemTransfer
var _slots: Array[InventorySlot] = []
## 마우스가 올라가 있는 칸 (-1이면 없음)
var _hovered_index: int = -1
## 메뉴 항목을 실행할 때 쓰는 환경. 메뉴가 열려 있을 때만 있다.
var _menu_context: ItemActionContext
## 메뉴를 열 때 그 칸에 있던 물건. 그 사이 칸이 바뀌면 메뉴를 닫는다.
var _menu_stack: ItemStack
## 메뉴에 보이는 항목 (메뉴를 열 때 정한다)
var _menu_actions: Array[ItemAction] = []
var _hotbar: Hotbar
var _drop_to_ground: Callable

@onready var _grid: GridContainer = %Grid
@onready var _info_label: Label = %InfoLabel
@onready var _menu: ItemMenu = %ItemMenu


func _ready() -> void:
	visible = false
	_menu.action_chosen.connect(_on_menu_action_chosen)
	_menu.closed.connect(_on_menu_closed)


## 보여줄 곳(container)을 연결하고 칸을 만든다.
## - drop_to_ground(stack): 메뉴의 버리기가 꺼낸 물건을 바닥에 놓을 때 쓴다
## - transfer: 칸 옮기기 규칙. 없으면 같은 화면 안의 옮기기만 한다
## - player_inventory: 네크로맨서의 인벤토리. 비워 두면 container가 인벤토리다
func bind(container: Inventory, roster: UndeadRoster = null, hotbar: Hotbar = null, drop_to_ground: Callable = Callable(), transfer: ItemTransfer = null, player_inventory: Inventory = null) -> void:
	_container = container
	_player_inventory = player_inventory if player_inventory != null else container
	_container.changed.connect(_refresh)
	_roster = roster
	_hotbar = hotbar
	_drop_to_ground = drop_to_ground
	_transfer = transfer
	# 소환 중에 피해를 받으면 내구도·체력이 바뀌므로 다시 그린다.
	if _roster != null:
		_roster.changed.connect(_refresh)
	for i: int in _container.get_slot_count():
		var slot: InventorySlot = slot_scene.instantiate()
		slot.index = i
		slot.container = _container
		_grid.add_child(slot)
		slot.hovered.connect(_on_slot_hovered)
		slot.unhovered.connect(_on_slot_unhovered)
		slot.menu_requested.connect(open_menu)
		slot.move_requested.connect(_on_slot_move_requested)
		_slots.append(slot)
	_refresh()


func is_open() -> bool:
	return visible


func set_open(open: bool) -> void:
	if visible == open:
		return
	if not open:
		_menu.close()
	visible = open
	_hovered_index = -1
	_refresh()
	open_changed.emit(open)


## 그 칸의 메뉴를 칸 옆에 띄운다. 빈 칸이거나 보이는 항목이 없으면 아무것도 하지 않는다.
func open_menu(index: int) -> void:
	var stack: ItemStack = _container.get_slot(index)
	if stack == null:
		return
	var context: ItemActionContext = ItemActionContext.new()
	context.inventory = _player_inventory
	context.container = _container
	context.storage = _container if _container != _player_inventory else open_storage
	context.hotbar = _hotbar
	context.roster = _roster
	context.transfer = _transfer
	context.slot_index = index
	context.drop_to_ground = _drop_to_ground
	_menu_actions.clear()
	for action: ItemAction in stack.item.actions + container_actions:
		if action.is_visible_in(context):
			_menu_actions.append(action)
	if _menu_actions.is_empty():
		return
	_menu_context = context
	_menu_stack = stack
	# 메뉴가 칸을 덮어 마우스가 칸을 벗어나도, 메뉴를 연 칸의 정보는 계속 보여준다.
	_hovered_index = index
	_update_info()
	_menu.open(_slots[index].get_global_rect(), _menu_actions, _menu_states())


## 테스트·디버그용: 아이템 메뉴
func get_menu() -> ItemMenu:
	return _menu


## 테스트·디버그용: 그 번호의 칸
func get_slot_control(index: int) -> InventorySlot:
	return _slots[index]


## 테스트·디버그용: 정보 줄의 글자
func get_info_text() -> String:
	return _info_label.text


func _unhandled_input(event: InputEvent) -> void:
	if not toggle_action.is_empty() and event.is_action_pressed(toggle_action):
		set_open(not visible)
		get_viewport().set_input_as_handled()
	elif close_on_cancel and visible and event.is_action_pressed(&"ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _menu_states() -> Array[ItemActionState]:
	var states: Array[ItemActionState] = []
	for action: ItemAction in _menu_actions:
		states.append(action.get_state(_menu_context))
	return states


func _on_menu_action_chosen(action: ItemAction) -> void:
	var context: ItemActionContext = _menu_context
	_menu.close()
	if context != null and action.get_state(context).enabled:
		action.execute(context)


func _on_menu_closed() -> void:
	_menu_context = null
	_menu_stack = null


func _on_slot_hovered(index: int) -> void:
	if _menu.is_open():
		return
	_hovered_index = index
	_update_info()


func _on_slot_unhovered(index: int) -> void:
	if _menu.is_open():
		return
	if _hovered_index == index:
		_hovered_index = -1
		_update_info()


## 이 화면의 to_index 칸에 다른 칸(이 화면이나 다른 화면)의 물건을 놓았다.
## 소환 중인 머리뼈가 창고로 나가게 되면 ItemTransfer가 막는다 (아무 일도 없이 원래 칸에 남는다).
func _on_slot_move_requested(from_container: Inventory, from_index: int, to_index: int) -> void:
	if _transfer != null:
		_transfer.move(from_container, from_index, _container, to_index)
	elif from_container == _container:
		_container.move_slot(from_index, to_index)


func _refresh() -> void:
	for i: int in _slots.size():
		_slots[i].show_stack(_container.get_slot(i))
	_update_info()
	if _menu.is_open():
		# 메뉴를 연 칸의 물건이 바뀌었으면 닫고, 그대로면 항목 상태(뼈 부족, 소환 중 등)만 다시 그린다.
		if _menu_context.get_stack() != _menu_stack:
			_menu.close()
		else:
			_menu.show_states(_menu_actions, _menu_states())


func _update_info() -> void:
	var stack: ItemStack = _container.get_slot(_hovered_index) if _hovered_index != -1 else null
	if stack == null:
		_info_label.text = ""
	elif stack.is_skull():
		_info_label.text = _skull_info(stack.skull)
	else:
		_info_label.text = "%s\n%d개" % [stack.get_display_name(), stack.count]


## "쥐의 머리뼈 / 내구도 7 / 10 · 체력 2 / 4 / 회복 뼈 2개" 세 줄.
## 아직 소환한 적 없는 머리뼈는 체력을 가득으로 보여주고, 회복 대신 처음 소환에 드는 뼈를 보여준다.
func _skull_info(skull: Skull) -> String:
	var name_line: String = skull.get_display_name()
	var durability_text: String = "내구도 %d / %d" % [ceili(skull.durability), ceili(skull.data.max_durability)]
	var monster: MonsterData = _roster.get_monster(skull) if _roster != null else null
	if monster == null:
		return "%s\n%s" % [name_line, durability_text]
	var health: float = skull.health if skull.awakened else monster.undead_max_health
	# 체력은 0.5가 남아도 0으로 보이지 않게 올림한다.
	var health_text: String = "체력 %d / %d" % [ceili(snappedf(health, UndeadRules.TOLERANCE)), ceili(monster.undead_max_health)]
	var bone_line: String = ("회복 뼈 %d개" if skull.awakened else "처음 소환 뼈 %d개") % _roster.get_heal_bone_cost(skull)
	return "%s\n%s · %s\n%s" % [name_line, durability_text, health_text, bone_line]
