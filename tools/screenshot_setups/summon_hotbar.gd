extends RefCounted
## 스크린샷 준비: 핫바 0번에 소환 중인 쥐의 머리뼈(선택 + 소환 중 테두리),
## 1번에 소환하지 않은 머리뼈를 두고 0번을 선택한다. 선택 테두리(흰색)와 소환 중 테두리(노란색)가 같이 보인다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --setup=res://tools/screenshot_setups/summon_hotbar.gd --out=<경로>

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 10
## 쥐가 오지 않는 남쪽
const SAFE_POSITION: Vector2 = Vector2(0, 600)


static func run(scene: Node) -> void:
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	necromancer.position = SAFE_POSITION
	var hotbar: Hotbar = scene.get_tree().root.get_node("GameState").hotbar
	var first: Skull = Skull.create(load(RAT_SKULL_PATH))
	var second: Skull = Skull.create(load(RAT_SKULL_PATH))
	necromancer.inventory.try_add(ItemStack.of_skull(first))
	necromancer.inventory.try_add(ItemStack.of_skull(second))
	necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	hotbar.assign(0, first)
	hotbar.assign(1, second)
	hotbar.select(0)
	necromancer.summoner.toggle_selected()
