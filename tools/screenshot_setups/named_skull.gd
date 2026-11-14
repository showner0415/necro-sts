extends RefCounted
## 스크린샷 준비 (--scene=res://regions/base.tscn): 네임드 머리뼈 (계획 6b). 인벤토리에 일반 쥐 머리뼈와 "쥐 그레카의 머리뼈"를 넣고
## 둘 다 핫바에 놓은 뒤 인벤토리를 열고 네임드 칸 정보를 띄운다. 네임드 칸만 오른쪽 위에 작은 노란 사각형(임시 표시)이 보인다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --setup=res://tools/screenshot_setups/named_skull.gd --out=<경로>

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const NAMED_NAME: String = "그레카"
const MONSTER_NAME: String = "쥐"


static func run(scene: Node) -> void:
	var game_state: Node = scene.get_tree().root.get_node("GameState")
	var inventory: Inventory = game_state.inventory
	var hotbar: Hotbar = game_state.hotbar
	var plain: Skull = Skull.create(load(RAT_SKULL_PATH))
	var named: Skull = Skull.create_named(load(RAT_SKULL_PATH), MONSTER_NAME, NAMED_NAME)
	inventory.try_add(ItemStack.of_skull(plain))
	inventory.try_add(ItemStack.of_skull(named))
	hotbar.assign(0, plain)
	hotbar.assign(1, named)
	var screen: InventoryScreen = scene.get_node("InventoryScreen")
	screen.set_open(true)
