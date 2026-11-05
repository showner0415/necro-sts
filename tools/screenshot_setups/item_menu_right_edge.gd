extends RefCounted
## 스크린샷 준비: 인벤토리를 열고, 오른쪽 끝 열(4번 칸)의 머리뼈 메뉴를 띄운다.
## 오른쪽에 공간이 없으므로 메뉴가 칸 왼쪽에 떠야 한다. 처음 소환 전이라 회복하기는 회색("체력 가득").

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const RIGHT_EDGE_SLOT: int = 4


static func run(scene: Node) -> void:
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	var inventory: Inventory = necromancer.inventory
	inventory.try_add(ItemStack.of_item(load(BONE_PATH), 10))
	inventory.try_add(ItemStack.of_skull(Skull.create(load(RAT_SKULL_PATH))))
	inventory.move_slot(1, RIGHT_EDGE_SLOT)
	var screen: InventoryScreen = scene.get_node("InventoryScreen")
	screen.set_open(true)
	screen.open_menu(RIGHT_EDGE_SLOT)
