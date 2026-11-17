extends RefCounted
## 스크린샷 준비 (--scene=res://regions/base.tscn): 인벤토리를 열고, 한 번 소환했다가 다친 머리뼈의 우클릭 메뉴를 띄운다.
## 메뉴에 회복하기, 뼈 제거 (N개), 핫바에 등록, 버리기가 보인다. 메뉴는 0번 칸 바로 오른쪽에 뜨고 위 끝이 칸 위 끝과 맞는다.
## 찍을 때마다 같은 그림이 되게 조준을 몸 오른쪽에 고정하고(카메라가 실제 마우스를 따라가지 않게),
## UI 입력을 막는다(실제 마우스가 메뉴 위에 있어도 항목이 올림 상태가 되지 않게).
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --setup=res://tools/screenshot_setups/skull_menu.gd --out=<경로>

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
## 머리뼈의 체력 비율 (다친 상태)
const HEALTH_RATIO: float = 0.7
const BONES: int = 3
## 화면이 자리 잡은 뒤 칸에 마우스를 올리는 때와 메뉴를 띄우는 때 (초).
## 실제로는 칸에 마우스를 올려 정보 줄(세 줄)이 먼저 뜨고, 창이 그만큼 자란 뒤에 우클릭한다. 바로 열면 메뉴를 놓은 뒤 창이 자라 칸이 1.5 올라간다.
const HOVER_DELAY: float = 0.2
const OPEN_DELAY: float = 0.4
## 몸 가운데에서 조준점까지 (오른쪽)
const AIM_DISTANCE: float = 128.0


static func run(scene: Node) -> void:
	scene.get_viewport().gui_disable_input = true
	var game_state: Node = scene.get_tree().root.get_node("GameState")
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	var inventory: Inventory = game_state.inventory
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	var monster: MonsterData = necromancer.summoner.roster.get_monster(skull)
	skull.awakened = true
	skull.health = monster.undead_max_health * HEALTH_RATIO
	inventory.try_add(ItemStack.of_skull(skull))
	inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var view: RegionView3D = scene.call(&"get_view_3d")
	if view != null:
		view.aim_override = necromancer.get_body_center() + Vector2.RIGHT * AIM_DISTANCE
	var screen: InventoryScreen = scene.get_node("InventoryScreen")
	screen.set_open(true)
	scene.get_tree().create_timer(HOVER_DELAY).timeout.connect(func() -> void: screen.get_slot_control(0).mouse_entered.emit())
	scene.get_tree().create_timer(OPEN_DELAY).timeout.connect(func() -> void: screen.open_menu(0))
