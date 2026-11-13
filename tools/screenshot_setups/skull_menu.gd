extends RefCounted
## 스크린샷 준비 (--scene=res://regions/base.tscn): 인벤토리를 열고, 한 번 소환했다가 다친 머리뼈의 우클릭 메뉴를 띄운다.
## 메뉴에 회복하기, 뼈 제거 (N개), 핫바에 등록, 버리기가 보인다.

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
## 머리뼈의 체력 비율 (다친 상태)
const HEALTH_RATIO: float = 0.7
const BONES: int = 3
## 화면이 자리 잡은 뒤에 메뉴를 띄우도록 기다리는 시간 (초)
const OPEN_DELAY: float = 0.2


static func run(scene: Node) -> void:
	var game_state: Node = scene.get_tree().root.get_node("GameState")
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	var inventory: Inventory = game_state.inventory
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	var monster: MonsterData = necromancer.summoner.roster.get_monster(skull)
	skull.awakened = true
	skull.health = monster.undead_max_health * HEALTH_RATIO
	inventory.try_add(ItemStack.of_skull(skull))
	inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var screen: InventoryScreen = scene.get_node("InventoryScreen")
	screen.set_open(true)
	scene.get_tree().create_timer(OPEN_DELAY).timeout.connect(func() -> void: screen.open_menu(0))
