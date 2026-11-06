extends RefCounted
## 스크린샷 준비: 실제 게임 화면 크기에서 네크로맨서가 쥐(왼쪽)와 멧돼지(오른쪽) 사이에 선 장면. 크기 비교용.
## 두 몬스터는 움직이지 않게 process를 끄고, 나머지 몬스터는 치운다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/test_region.tscn --setup=res://tools/screenshot_setups/necromancer_beside_monsters.gd --out=<경로>

const RAT_OFFSET: Vector2 = Vector2(-28, 0)
const BOAR_OFFSET: Vector2 = Vector2(40, 0)


static func run(scene: Node) -> void:
	var tree: SceneTree = scene.get_tree()
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	var rat: Monster = scene.get_node("Actors/Rat1")
	var boar: Monster = scene.get_node("Actors/Boar1")
	for node: Node in tree.get_nodes_in_group(&"monsters"):
		if node != rat and node != boar:
			node.free()
	for monster: Monster in [rat, boar]:
		monster.process_mode = Node.PROCESS_MODE_DISABLED
	rat.global_position = necromancer.global_position + RAT_OFFSET
	boar.global_position = necromancer.global_position + BOAR_OFFSET
