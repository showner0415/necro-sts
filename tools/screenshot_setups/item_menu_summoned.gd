extends RefCounted
## 스크린샷 준비 (--scene=res://regions/base.tscn): 인벤토리를 열고, 소환 중인 머리뼈(0번 칸)의 우클릭 메뉴를 띄운다.
## 회복하기·뼈 제거는 비활성 + 이유("소환 중"), 핫바에서 빼기에는 "소환이 해제됩니다"(노랑), 버리기에는 "죽은 판정이 됩니다"(빨강) 경고가 보인다.
## 메뉴는 0번 칸 바로 오른쪽에 뜨고 위 끝이 칸 위 끝과 맞는다. 네크로맨서는 처음 자리(거점 바닥 위)에 둔다.
## 조준 고정과 UI 입력 막기는 skull_menu.gd와 같다. 소환 자리가 무작위 방향(undead/summoner.gd의 randf)이라 찍을 때마다 언데드 자리만 다르다 (몸 뒤에 가려 안 보일 때도 있다).
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --setup=res://tools/screenshot_setups/item_menu_summoned.gd --out=<경로>

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 10
## 화면이 자리 잡은 뒤 칸에 마우스를 올리는 때와 메뉴를 띄우는 때 (초). 바로 열면 칸 자리가 정해지기 전이라 메뉴가 엉뚱한 곳에 뜬다.
## 마우스를 먼저 올리는 까닭은 skull_menu.gd와 같다 (정보 줄이 뜬 뒤 창이 자란 자리에 메뉴를 놓게).
const HOVER_DELAY: float = 0.2
const OPEN_DELAY: float = 0.4
## 몸 가운데에서 조준점까지 (오른쪽)
const AIM_DISTANCE: float = 128.0


static func run(scene: Node) -> void:
	scene.get_viewport().gui_disable_input = true
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	var hotbar: Hotbar = scene.get_tree().root.get_node("GameState").hotbar
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	necromancer.inventory.try_add(ItemStack.of_skull(skull))
	necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	hotbar.assign(0, skull)
	necromancer.summoner.toggle_selected()
	var view: RegionView3D = scene.call(&"get_view_3d")
	if view != null:
		view.aim_override = necromancer.get_body_center() + Vector2.RIGHT * AIM_DISTANCE
	var screen: InventoryScreen = scene.get_node("InventoryScreen")
	screen.set_open(true)
	scene.get_tree().create_timer(HOVER_DELAY).timeout.connect(func() -> void: screen.get_slot_control(0).mouse_entered.emit())
	scene.get_tree().create_timer(OPEN_DELAY).timeout.connect(func() -> void: screen.open_menu(0))
