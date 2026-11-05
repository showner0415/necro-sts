extends RefCounted
## 스크린샷 준비 (--scene=res://regions/base.tscn): 상자 앞에서 창고를 연다.
## 인벤토리(가운데 왼쪽)와 창고(오른쪽)가 나란히 보이고, 양쪽에 뼈·머리뼈가 들어 있다.

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
## 상자 영역 판정이 따라온 뒤에 열도록 기다리는 시간 (초)
const OPEN_DELAY: float = 0.2


static func run(scene: Node) -> void:
	var game_state: Node = scene.get_tree().root.get_node("GameState")
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	var chest: Node2D = scene.get_node("StorageChest")
	necromancer.global_position = chest.global_position
	var inventory: Inventory = game_state.inventory
	var storage: Inventory = game_state.storage
	inventory.try_add(ItemStack.of_item(load(BONE_PATH), 7))
	inventory.try_add(ItemStack.of_skull(Skull.create(load(RAT_SKULL_PATH))))
	storage.try_add(ItemStack.of_item(load(BONE_PATH), 42))
	for i: int in 3:
		storage.try_add(ItemStack.of_skull(Skull.create(load(RAT_SKULL_PATH))))
	# 순간이동 직후에는 상자 영역 판정이 아직이라, 열자마자 "멀어짐"으로 닫힌다. 잠시 뒤에 연다.
	scene.get_tree().create_timer(OPEN_DELAY).timeout.connect(func() -> void: scene.call(&"open_storage"))
