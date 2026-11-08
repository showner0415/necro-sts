extends RefCounted
## 스크린샷 준비: 언데드 시야와 빛 겹침. vision_preview.gd와 같은 자리(얕은 굴 쥐 둥지, 네크로맨서는 동쪽을 봄)에
## 쥐 언데드 둘을 소환해 세운다: 하나는 네크로맨서 북동쪽에서 동쪽을 봄(플레이어 빛과 겹침), 하나는 네크로맨서 북쪽 위에서 북쪽을 봄(언데드 빛만).
## 언데드는 움직이지 않게 멈춰 둔다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/shallow_cave.tscn --setup=res://tools/screenshot_setups/vision_undead_overlap.gd --out=<경로>

const PREVIEW: String = "res://tools/screenshot_setups/vision_preview.gd"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const TILE: float = 32.0


static func run(scene: Node) -> void:
	(load(PREVIEW) as GDScript).call(&"run", scene)
	var tree: SceneTree = scene.get_tree()
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	var game_state: Node = scene.get_node("/root/GameState")
	var hotbar: Hotbar = game_state.get(&"hotbar")
	necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), 40))
	var spots: Array[Array] = [
		[Vector2(1.0, -1.5) * TILE, Vector2.RIGHT],
		[Vector2(0.0, -2.5) * TILE, Vector2.UP],
	]
	for i: int in spots.size():
		var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
		necromancer.inventory.try_add(ItemStack.of_skull(skull))
		hotbar.assign(i, skull)
		hotbar.select(i)
		necromancer.summoner.toggle_selected()
	var undead_nodes: Array[Node] = tree.get_nodes_in_group(&"undead")
	for i: int in mini(undead_nodes.size(), spots.size()):
		var undead: Undead = undead_nodes[i] as Undead
		undead.process_mode = Node.PROCESS_MODE_DISABLED
		undead.global_position = necromancer.global_position + spots[i][0]
		undead.facing = spots[i][1]
	print("언데드 %d마리를 세움" % undead_nodes.size())
