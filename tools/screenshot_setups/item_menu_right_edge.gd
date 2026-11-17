extends RefCounted
## 스크린샷 준비 (--scene=res://regions/base.tscn): 상자 앞에서 창고를 열고, 창고 오른쪽 끝 열(4번 칸)의 머리뼈 메뉴를 띄운다.
## 인벤토리를 가득 채워 두므로 메뉴가 "인벤토리로 옮기기 (인벤토리 가득 참)"(비활성)로 넓어져, 칸 오른쪽에 띄우면 화면 오른쪽 끝을 넘는다.
## 그래서 메뉴가 칸 왼쪽에 떠야 한다: 메뉴 오른쪽 끝 = 칸 왼쪽 끝 − 간격 (UI 좌표 480 = 482 − 2, 메뉴 폭 188).
## 인벤토리 창을 화면 왼쪽에 둔 뒤로는 인벤토리 칸에서는 이 규칙이 걸리지 않는다 (2026-11-17 확인).
## 조준 고정과 UI 입력 막기는 skull_menu.gd와 같다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --setup=res://tools/screenshot_setups/item_menu_right_edge.gd --out=<경로>

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
## 창고 오른쪽 끝 열의 칸 (창고는 5열)
const RIGHT_EDGE_SLOT: int = 4
## 상자 영역 판정이 따라온 뒤에 창고를 여는 때, 창고 칸 자리가 정해진 뒤 칸에 마우스를 올리는 때, 메뉴를 여는 때 (초).
## 마우스를 먼저 올리는 까닭은 skull_menu.gd와 같다 (정보 줄이 뜬 뒤 창이 자란 자리에 메뉴를 놓게).
const STORAGE_OPEN_DELAY: float = 0.2
const HOVER_DELAY: float = 0.4
const MENU_OPEN_DELAY: float = 0.6
## 몸 가운데에서 조준점까지 (오른쪽)
const AIM_DISTANCE: float = 128.0


static func run(scene: Node) -> void:
	scene.get_viewport().gui_disable_input = true
	var game_state: Node = scene.get_tree().root.get_node("GameState")
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	necromancer.global_position = (scene.get_node("StorageChest") as Node2D).global_position
	var inventory: Inventory = game_state.inventory
	var storage: Inventory = game_state.storage
	# 인벤토리를 뼈 한 칸과 머리뼈로 가득 채운다 (받을 자리가 없어야 "가득 참"이 붙는다).
	inventory.try_add(ItemStack.of_item(load(BONE_PATH), 10))
	while inventory.try_add(ItemStack.of_skull(Skull.create(load(RAT_SKULL_PATH)))):
		pass
	storage.try_add(ItemStack.of_skull(Skull.create(load(RAT_SKULL_PATH))))
	storage.move_slot(0, RIGHT_EDGE_SLOT)
	var view: RegionView3D = scene.call(&"get_view_3d")
	if view != null:
		view.aim_override = necromancer.get_body_center() + Vector2.RIGHT * AIM_DISTANCE
	# 순간이동 직후에는 상자 영역 판정이 아직이라, 열자마자 "멀어짐"으로 닫힌다. 잠시 뒤에 연다.
	scene.get_tree().create_timer(STORAGE_OPEN_DELAY).timeout.connect(func() -> void: scene.call(&"open_storage"))
	var screen: InventoryScreen = scene.get_node("StorageScreen")
	scene.get_tree().create_timer(HOVER_DELAY).timeout.connect(func() -> void: screen.get_slot_control(RIGHT_EDGE_SLOT).mouse_entered.emit())
	scene.get_tree().create_timer(MENU_OPEN_DELAY).timeout.connect(func() -> void: screen.open_menu(RIGHT_EDGE_SLOT))
