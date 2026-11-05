extends RefCounted
## 스크린샷 준비 (--scene=res://regions/base.tscn): 창고를 열고 맨 아래까지 스크롤한다.
## 마지막 줄(96~100번째 칸)에 넣은 물건이 보여야 한다.

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
## 상자 영역 판정이 따라온 뒤에 열도록 기다리는 시간 (초)
const OPEN_DELAY: float = 0.2
## 칸 배치가 끝난 뒤 스크롤하도록 기다리는 시간 (초)
const SCROLL_DELAY: float = 0.6


static func run(scene: Node) -> void:
	var game_state: Node = scene.get_tree().root.get_node("GameState")
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	necromancer.global_position = (scene.get_node("StorageChest") as Node2D).global_position
	var storage: Inventory = game_state.storage
	storage.try_add(ItemStack.of_item(load(BONE_PATH), 42))
	storage.try_add(ItemStack.of_skull(Skull.create(load(RAT_SKULL_PATH))))
	storage.move_slot(0, storage.get_slot_count() - 1)
	storage.move_slot(1, storage.get_slot_count() - 3)
	# 순간이동 직후에는 상자 영역 판정이 아직이라, 열자마자 "멀어짐"으로 닫힌다. 잠시 뒤에 연다.
	scene.get_tree().create_timer(OPEN_DELAY).timeout.connect(func() -> void: scene.call(&"open_storage"))
	var scroll: ScrollContainer = scene.get_node("StorageScreen").get_node("%Scroll")
	scene.get_tree().create_timer(SCROLL_DELAY).timeout.connect(func() -> void: scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value))
