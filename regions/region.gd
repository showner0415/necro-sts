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
## 다른 씬으로 갈 때 소환 중인 언데드는 일반 해제된다. 네크로맨서는 새 씬에서 새로 만들어지므로 체력·마나가 가득 찬다.

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
	if _storage_screen != null:
		_storage_screen.bind(GameState.storage, roster, GameState.hotbar, _necromancer.drop_to_ground, transfer, _inventory)
		_storage_screen.open_changed.connect(_on_storage_open_changed)
	_inventory_screen.open_changed.connect(_on_inventory_open_changed)
	_hud.hotbar_view.bind(GameState.hotbar, _necromancer.summoner.roster)

	for node: Node in find_children("*", "EscapePoint", true, false):
		var point: EscapePoint = node as EscapePoint
		point.progress_changed.connect(_hud.show_escape_progress)
		point.escaped.connect(travel_to)
	for node: Node in find_children("*", "InteractZone", true, false):
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
