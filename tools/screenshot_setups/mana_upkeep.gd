extends RefCounted
## 스크린샷 준비 (거점): 쥐 언데드 2마리를 소환한다. 유지비가 자연 회복보다 커서 마나 바 오른쪽에 "-" 숫자가 보인다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --setup=res://tools/screenshot_setups/mana_upkeep.gd --out=<경로>

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 10


static func run(scene: Node) -> void:
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	var hotbar: Hotbar = scene.get_tree().root.get_node("GameState").hotbar
	necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	for i: int in 2:
		var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
		necromancer.inventory.try_add(ItemStack.of_skull(skull))
		hotbar.assign(i, skull)
		hotbar.select(i)
		necromancer.summoner.toggle_selected()
