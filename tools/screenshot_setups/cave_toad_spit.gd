extends RefCounted
## 스크린샷 준비: 동굴 두꺼비(제안, 사용자 확인 전) 임시 도형과 부채꼴 뱉기. 다른 몬스터는 치우고, 네크로맨서 오른쪽에 두꺼비 한 마리를 놓는다.
## 두꺼비는 곧바로 예고(깜빡임, 바닥에 빨간 줄 셋)를 시작하고 0.7초 뒤 침 셋을 뱉는다. 예고는 0.4초쯤, 날아가는 침은 0.95초쯤 찍는다.
## 쥐 한 마리를 크기 비교용으로 두꺼비 위에 세운다 (움직이지 않는다). 시야는 끄고 카메라를 2배로 당긴다:
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=0.4 --scene=res://regions/test_region.tscn --setup=res://tools/screenshot_setups/cave_toad_spit.gd --out=<경로>

const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const TOAD_PATH: String = "res://data/monsters/cave_toad.tres"
const RAT_PATH: String = "res://data/monsters/rat.tres"
## 네크로맨서에게서 두꺼비까지 (뱉는 거리 150 안)
const TOAD_OFFSET: Vector2 = Vector2(110, 0)
## 두꺼비에게서 비교용 쥐까지
const RAT_OFFSET: Vector2 = Vector2(0, -40)
const ZOOM: Vector2 = Vector2(2, 2)


static func run(scene: Node) -> void:
	var tree: SceneTree = scene.get_tree()
	for node: Node in tree.get_nodes_in_group(&"monsters"):
		node.free()
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	necromancer.max_health = 10000.0
	necromancer.health = 10000.0
	var vision: Node = scene.call(&"get_vision")
	if vision != null:
		vision.call(&"set_active", false)
	(necromancer.get_node("Camera2D") as Camera2D).zoom = ZOOM
	var parent: Node = necromancer.get_parent()
	var toad: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	toad.data = load(TOAD_PATH)
	parent.add_child(toad)
	toad.global_position = necromancer.global_position + TOAD_OFFSET
	var rat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	rat.data = load(RAT_PATH)
	rat.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(rat)
	rat.global_position = toad.global_position + RAT_OFFSET
