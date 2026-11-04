extends Node2D
## 첫 구현 확인용 임시 지역. 네크로맨서와 쥐 몇 마리를 놓고 HUD·인벤토리 화면을 연결한다.
## 인벤토리는 지역 씬 밖(GameState)에 있으므로, 시작할 때 받아서 네크로맨서와 화면에 넣어 준다.

@onready var _necromancer: Necromancer = $Actors/Necromancer
@onready var _hud: Hud = $HUD
@onready var _inventory_screen: InventoryScreen = $InventoryScreen

var _inventory: Inventory


func _ready() -> void:
	_inventory = GameState.inventory
	_necromancer.inventory = _inventory

	_necromancer.health_changed.connect(_hud.show_health)
	_necromancer.mana.changed.connect(_hud.show_mana)
	_necromancer.died.connect(_on_necromancer_died)
	_hud.show_health(_necromancer.health, _necromancer.max_health)
	_hud.show_mana(_necromancer.mana.current, _necromancer.mana.maximum)

	_inventory.changed.connect(_on_inventory_changed)
	_on_inventory_changed()
	_inventory_screen.bind(_inventory)
	_inventory_screen.open_changed.connect(_on_inventory_open_changed)
	_inventory_screen.drop_requested.connect(_on_drop_requested)


func _on_inventory_changed() -> void:
	var bone_id: StringName = _hud.bone_item.id
	_hud.show_item_count(bone_id, _inventory.get_count(bone_id))
	_hud.show_skull_counts(_inventory.get_skull_counts())


func _on_inventory_open_changed(is_open: bool) -> void:
	# 인벤토리가 열려 있는 동안에는 이동만 하고 공격·줍기는 막는다.
	_necromancer.actions_enabled = not is_open


## 우클릭한 칸의 물건을 통째로 꺼내 네크로맨서 발밑에 놓는다.
func _on_drop_requested(slot_index: int) -> void:
	var stack: ItemStack = _inventory.remove_slot(slot_index)
	if stack != null:
		_necromancer.drop_to_ground(stack)


func _on_necromancer_died() -> void:
	# 죽었을 때 무엇을 잃는지는 아직 미정이다. 임시로 인벤토리를 비우고 지역을 처음부터 다시 시작한다.
	GameState.reset_after_death()
	get_tree().reload_current_scene.call_deferred()
