extends RefCounted
## 스크린샷 준비: 인벤토리를 열고, 소환 중인 머리뼈(0번 칸)의 우클릭 메뉴를 띄운다.
## 회복하기는 회색 + 이유("소환 중"), 핫바에서 빼기에는 "소환이 해제됩니다", 버리기에는 "죽은 판정이 됩니다" 경고가 보인다.

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const SAFE_POSITION: Vector2 = Vector2(0, 600)


static func run(scene: Node) -> void:
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	necromancer.position = SAFE_POSITION
	var hotbar: Hotbar = scene.get_tree().root.get_node("GameState").hotbar
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	necromancer.inventory.try_add(ItemStack.of_skull(skull))
	necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), 10))
	hotbar.assign(0, skull)
	necromancer.summoner.toggle_selected()
	var screen: InventoryScreen = scene.get_node("InventoryScreen")
	screen.set_open(true)
	screen.open_menu(0)
