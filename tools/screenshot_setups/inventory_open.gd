extends RefCounted
## 스크린샷 준비 (--scene=res://regions/base.tscn): 인벤토리만 연다 (창고 없이). 창 틀·칸·글자를 볼 때 쓴다.
## 칸에 뼈와 머리뼈 여러 종류를 넣고, 다친 쥐 머리뼈 칸에 마우스를 올린 것처럼 정보 줄(세 줄)을 띄운다.
## 조준을 고정해 카메라가 실제 마우스를 따라 움직이지 않게 한다 (찍을 때마다 같은 화면).
## UI가 실제 마우스를 받지 않게 한다: 실제 커서가 창 위에 있으면 칸 정보가 바뀌어 창 높이가 찍을 때마다 달라졌다 (그린 모습은 그대로).
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --setup=res://tools/screenshot_setups/inventory_open.gd --out=<경로>

const BONE_PATH: String = "res://data/items/bone.tres"
const SKULL_PATHS: Array[String] = [
	"res://data/skulls/rat_skull.tres",
	"res://data/skulls/boar_skull.tres",
	"res://data/skulls/bat_skull.tres",
	"res://data/skulls/goblin_slinger_skull.tres",
	"res://data/skulls/cave_toad_skull.tres",
]
const BONES: int = 7
## 정보 줄을 띄울 칸 (첫 머리뼈)
const HOVER_INDEX: int = 1
## 그 머리뼈의 체력 비율 (다친 상태, 정보 줄이 세 줄이 되게 한 번 소환한 것으로 둔다)
const HEALTH_RATIO: float = 0.5
## 몸 가운데에서 조준점까지 (오른쪽)
const AIM_DISTANCE: float = 128.0
## 화면이 자리 잡은 뒤에 정보 줄을 띄우도록 기다리는 시간 (초)
const HOVER_DELAY: float = 0.2


static func run(scene: Node) -> void:
	var game_state: Node = scene.get_tree().root.get_node("GameState")
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	var inventory: Inventory = game_state.inventory
	inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	for i: int in SKULL_PATHS.size():
		var skull: Skull = Skull.create(load(SKULL_PATHS[i]))
		if i == 0:
			var monster: MonsterData = necromancer.summoner.roster.get_monster(skull)
			skull.awakened = true
			skull.health = monster.undead_max_health * HEALTH_RATIO
		inventory.try_add(ItemStack.of_skull(skull))
	var screen: InventoryScreen = scene.get_node("InventoryScreen")
	screen.set_open(true)
	_ignore_mouse(scene)
	scene.get_tree().create_timer(HOVER_DELAY).timeout.connect(func() -> void: screen.get_slot_control(HOVER_INDEX).hovered.emit(HOVER_INDEX))
	var view: RegionView3D = scene.call(&"get_view_3d")
	if view != null:
		view.aim_override = necromancer.get_body_center() + Vector2.RIGHT * AIM_DISTANCE


## node와 그 아래 모든 Control이 실제 마우스를 받지 않게 한다
static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
