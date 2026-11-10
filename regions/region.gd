class_name Region
extends Node2D
## 지역 씬(거점 포함)의 공통 스크립트. 네크로맨서·HUD·인벤토리 화면을 연결하고, 지역 사이의 이동을 맡는다.
## 인벤토리·핫바는 지역 씬 밖(GameState)에 있으므로, 시작할 때 받아서 네크로맨서와 화면에 넣어 준다.
## - 탈출 지점(EscapePoint): 게이지를 HUD에 보여주고, 다 차면 그 목적지(보통 거점)로 간다
## - 출구(RegionExit, 거점에 둠): F를 누르면 그 목적지 지역으로 간다
## - 창고 상자(StorageChest, 거점에 둠): F를 누르면 창고(오른쪽)와 인벤토리(왼쪽)를 나란히 연다.
##   Tab·Esc를 누르거나 상자에서 멀어지면 둘 다 닫는다. 창고 화면(StorageScreen)이 없는 지역에서는 열 수 없다
## - 지역 상자(LootChest): F를 누르면 그 상자(오른쪽)와 인벤토리(왼쪽)를 나란히 연다 (상자 화면 ChestScreen).
##   열려 있는 동안만 상자의 내용물이 하나씩 드러난다. 상자에서 open_distance보다 멀어지거나 Tab·Esc로 둘 다 닫는다
## - 네크로맨서가 죽으면 인벤토리를 전부 잃고 death_destination(거점)으로 간다
## - 지역 데이터의 limit_vision이 켜져 있으면 플레이어 시야를 제한한다 (Vision, 거점은 끔)
## 다른 씬으로 갈 때 소환 중인 언데드는 일반 해제된다. 네크로맨서는 새 씬에서 새로 만들어지므로 체력·마나가 가득 찬다.

## 3D 층을 켜지 않고 2D로 그리는 실행 인자 (전후 비교용)
const VIEW_2D_ARG: String = "--view_2d"

## 이 지역
@export var data: RegionData
## 죽으면 돌아갈 곳 (거점)
@export var death_destination: RegionData

var _inventory: Inventory
## 다른 씬으로 가는 중이면 true (두 번 가지 않게)
var _traveling: bool = false
## 인벤토리가 열려 있으면 막는 시설들 (출구, 창고 상자)
var _zones: Array[InteractZone] = []
var _chests: Array[StorageChest] = []
## 지역 상자들과 지금 열려 있는 상자 (없으면 null)
var _loot_chests: Array[LootChest] = []
var _open_chest: LootChest

@onready var _necromancer: Necromancer = $Actors/Necromancer
@onready var _hud: Hud = $HUD
@onready var _inventory_screen: InventoryScreen = $InventoryScreen
## 거점에만 있다. 없으면 null.
@onready var _storage_screen: InventoryScreen = get_node_or_null("StorageScreen")
## 지역 상자가 있는 지역에만 있다. 없으면 null.
@onready var _chest_screen: InventoryScreen = get_node_or_null("ChestScreen")


func _ready() -> void:
	_inventory = GameState.inventory
	_necromancer.inventory = _inventory
	_necromancer.summoner.bind(_inventory, GameState.hotbar)
	_necromancer.summoner.message.connect(_hud.show_message)

	_necromancer.health_changed.connect(_hud.show_health)
	_necromancer.mana.changed.connect(_hud.show_mana)
	_necromancer.died.connect(_on_necromancer_died)
	_necromancer.harvest_progress_changed.connect(_hud.show_harvest_progress)
	_hud.show_health(_necromancer.health, _necromancer.max_health)
	_hud.show_mana(_necromancer.mana.current, _necromancer.mana.maximum)

	_inventory.changed.connect(_on_inventory_changed)
	_on_inventory_changed()
	var roster: UndeadRoster = _necromancer.summoner.roster
	var transfer: ItemTransfer = ItemTransfer.new(_inventory, roster)
	_inventory_screen.bind(_inventory, roster, GameState.hotbar, _necromancer.drop_to_ground, transfer)
	# 빠른 옮기기(Shift+좌클릭)를 못 했을 때의 안내("창고 가득 참" 등)는 핫바 위 안내 문구 자리에 띄운다.
	for screen: InventoryScreen in [_inventory_screen, _storage_screen, _chest_screen]:
		if screen != null:
			screen.message.connect(_hud.show_message)
	if _storage_screen != null:
		_storage_screen.bind(GameState.storage, roster, GameState.hotbar, _necromancer.drop_to_ground, transfer, _inventory)
		_storage_screen.open_changed.connect(_on_storage_open_changed)
	_inventory_screen.open_changed.connect(_on_inventory_open_changed)
	_hud.hotbar_view.bind(GameState.hotbar, _necromancer.summoner.roster)
	if data != null and data.limit_vision:
		_add_vision()
	if wants_view_3d():
		add_view_3d()

	for node: Node in find_children("*", "EscapePoint", true, false):
		var point: EscapePoint = node as EscapePoint
		point.progress_changed.connect(_hud.show_escape_progress)
		point.escaped.connect(travel_to)
	for node: Node in find_children("*", "InteractZone", true, false):
		# 릴리스 빌드에서 스스로 없어지는 개발용 출구는 건너뛴다.
		if node.is_queued_for_deletion():
			continue
		_zones.append(node as InteractZone)
		if node is RegionExit:
			(node as RegionExit).travel_requested.connect(travel_to)
		elif node is LootChest and _chest_screen != null:
			var loot_chest: LootChest = node as LootChest
			loot_chest.interacted.connect(open_chest.bind(loot_chest))
			_loot_chests.append(loot_chest)
		elif node is StorageChest and _storage_screen != null:
			(node as StorageChest).interacted.connect(open_storage)
			_chests.append(node as StorageChest)
	if _chest_screen != null and not _loot_chests.is_empty():
		# 상자 화면은 열 때마다 그 상자로 바꾼다 (set_container). 처음에는 첫 상자로 묶어 둔다.
		_chest_screen.bind(_loot_chests[0].contents.inventory, roster, GameState.hotbar, _necromancer.drop_to_ground, transfer, _inventory)
		_chest_screen.open_changed.connect(_on_chest_open_changed)


## destination 지역 씬으로 간다. 소환 중인 언데드는 일반 해제된다 (머리뼈의 체력·내구도는 그대로).
func travel_to(destination: RegionData) -> void:
	if _traveling or destination == null:
		return
	_traveling = true
	_necromancer.summoner.roster.unsummon_all()
	# 물리 처리 중(탈출 지점 판정 등)에 씬을 바꾸지 않도록 미룬다.
	get_tree().change_scene_to_file.call_deferred(destination.scene_path)


## 창고(오른쪽)와 인벤토리(왼쪽)를 나란히 연다. 창고 화면이 없는 지역에서는 아무것도 하지 않는다.
func open_storage() -> void:
	if _storage_screen == null:
		return
	_inventory_screen.open_storage = GameState.storage
	_storage_screen.set_open(true)
	_inventory_screen.set_open(true)


## 지역 상자(오른쪽)와 인벤토리(왼쪽)를 나란히 연다. 이미 드러난 칸은 그대로 드러나 있다.
func open_chest(chest: LootChest) -> void:
	if _chest_screen == null or chest.contents == null:
		return
	_open_chest = chest
	_chest_screen.set_container(chest.contents.inventory, chest.contents)
	_chest_screen.set_title(chest.data.display_name)
	_inventory_screen.open_storage = chest.contents.inventory
	_chest_screen.set_open(true)
	_inventory_screen.set_open(true)


## 테스트용: 지금 열려 있는 지역 상자 (없으면 null)
func get_open_chest() -> LootChest:
	return _open_chest


func _physics_process(delta: float) -> void:
	# 상자가 열려 있는 동안만 내용물이 드러난다. 상자에서 멀어지면 닫는다.
	if _open_chest != null and _chest_screen.is_open():
		if _open_chest.is_in_open_range(_necromancer.global_position):
			_open_chest.contents.advance(delta)
		else:
			_chest_screen.set_open(false)
	# 마나 초당 변화량: 유지비는 소환·해제로, 회복 여부는 마나가 가득 찼는지로 바뀌므로 매 프레임 다시 계산한다.
	var upkeep: float = _necromancer.summoner.roster.get_upkeep_per_second()
	_hud.show_mana_change(_necromancer.mana.get_change_per_second(upkeep), _necromancer.mana.has_change(upkeep))
	# 상자에서 멀어지면 창고를 닫는다.
	if _storage_screen != null and _storage_screen.is_open() and not _chests.any(func(chest: StorageChest) -> bool: return chest.is_necromancer_inside()):
		_storage_screen.set_open(false)


## 상자가 닫히면(Esc, 멀어짐, Tab) 인벤토리도 같이 닫는다.
func _on_chest_open_changed(is_open: bool) -> void:
	if is_open:
		return
	_open_chest = null
	_inventory_screen.open_storage = null
	_inventory_screen.set_open(false)


## 창고가 닫히면(Esc, 멀어짐, Tab) 인벤토리도 같이 닫는다.
func _on_storage_open_changed(is_open: bool) -> void:
	if is_open:
		return
	_inventory_screen.open_storage = null
	_inventory_screen.set_open(false)


func _on_inventory_changed() -> void:
	var bone_id: StringName = _hud.bone_item.id
	_hud.show_item_count(bone_id, _inventory.get_count(bone_id))
	_hud.show_skull_counts(_inventory.get_skull_counts())


func _on_inventory_open_changed(is_open: bool) -> void:
	# 인벤토리가 열려 있는 동안에는 이동만 하고 공격·줍기·출구 사용은 막는다.
	_necromancer.actions_enabled = not is_open
	for zone: InteractZone in _zones:
		zone.enabled = not is_open
	# 인벤토리를 닫으면 같이 열려 있던 창고도 닫는다.
	if not is_open and _storage_screen != null:
		_storage_screen.set_open(false)
	if not is_open and _chest_screen != null:
		_chest_screen.set_open(false)


func _on_necromancer_died() -> void:
	# 지역에서 죽으면 인벤토리의 물건을 전부 잃고 거점에서 다시 시작한다 (창고는 아직 없다).
	GameState.reset_after_death()
	travel_to(death_destination)


## 시야 제한(Vision)을 붙인다. 몸(Actors)보다 앞에 있는 그림(바닥·벽·상자·탈출 지점 등)을 지형으로 넘겨 어둡게 한다.
func _add_vision() -> void:
	var vision: Vision = Vision.new()
	vision.name = "Vision"
	var actors: Node = _necromancer.get_parent()
	var terrain: Array[CanvasItem] = []
	for child: Node in get_children():
		if child.get_index() < actors.get_index() and child is CanvasItem:
			terrain.append(child as CanvasItem)
	vision.setup(_necromancer, get_node_or_null("Walls") as PlaceholderWalls, terrain)
	add_child(vision)


## 확인용: 이 지역의 시야 (시야 제한이 없는 지역이면 null)
func get_vision() -> Vision:
	return get_node_or_null("Vision") as Vision


## 이 지역을 3D 화면 층으로 그릴지. 헤드리스(테스트·측정)에서는 규칙만 돌리므로 그리지 않는다.
## 2D 화면과 비교하려면 실행 인자 --view_2d를 준다. 시제품 층(View3D)이 있는 씬은 그 층을 쓴다.
func wants_view_3d() -> bool:
	return data != null and data.view_3d and DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has(VIEW_2D_ARG) and get_node_or_null("View3D") == null


## 3D 화면 층을 붙인다. 이미 있으면 그것을 돌려준다.
func add_view_3d() -> RegionView3D:
	var existing: RegionView3D = get_view_3d()
	if existing != null:
		return existing
	var view: RegionView3D = RegionView3D.new()
	view.name = "RegionView3D"
	view.setup(_necromancer, get_vision())
	add_child(view)
	return view


## 이 지역의 3D 화면 층 (없으면 null)
func get_view_3d() -> RegionView3D:
	return get_node_or_null("RegionView3D") as RegionView3D
