extends RefCounted
## 스크린샷 준비 (--scene=res://regions/base.tscn): 수리 기계 앞에서 수리 창을 연다.
## 인벤토리(가운데 왼쪽)와 수리 창(오른쪽)이 나란히 보이고, 수리 칸에 내구도가 닳은 머리뼈가 들어 있다.

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
## 칸에 넣을 머리뼈의 내구도와 가진 뼈 (모자라게 둬서 비용 줄이 잘 보이게)
const WORN_DURABILITY: float = 3.0
const BONES: int = 4
## 기계 영역 판정이 따라온 뒤에 열도록 기다리는 시간 (초)
const OPEN_DELAY: float = 0.2


static func run(scene: Node) -> void:
	var game_state: Node = scene.get_tree().root.get_node("GameState")
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	var machine: RepairMachine = scene.get_node("RepairMachine")
	# 기계 바로 아래(화면 앞쪽)에 세워 기계가 가려지지 않게 한다. 판정 반지름 안이다.
	necromancer.global_position = machine.global_position + Vector2(0, 16)
	var inventory: Inventory = game_state.inventory
	var worn: Skull = Skull.create(load(RAT_SKULL_PATH))
	worn.durability = WORN_DURABILITY
	inventory.try_add(ItemStack.of_skull(worn))
	inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	inventory.try_add(ItemStack.of_skull(Skull.create(load(RAT_SKULL_PATH))))
	# 순간이동 직후에는 영역 판정이 아직이라, 열자마자 "멀어짐"으로 닫힌다. 잠시 뒤에 연다.
	scene.get_tree().create_timer(OPEN_DELAY).timeout.connect(func() -> void:
		scene.call(&"open_repair", machine)
		(scene.get_node("RepairScreen") as RepairScreen).set_skull(worn))
