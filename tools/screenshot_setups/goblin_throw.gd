extends RefCounted
## 스크린샷 준비 (시험 지역): 네크로맨서를 고블린 투석병 2마리 앞(던지는 거리 안)에 세우고 체력을 크게 해서,
## 돌이 날아오는 장면을 찍는다. 카메라를 2배로 당긴다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --scene=res://regions/test_region.tscn --setup=res://tools/screenshot_setups/goblin_throw.gd --seconds=1.3 --out=<경로>

## 투석병 무리 가운데에서 네크로맨서를 세울 자리
const STAND_OFFSET: Vector2 = Vector2(-120, 0)
const ZOOM: Vector2 = Vector2(2, 2)


static func run(scene: Node) -> void:
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	var center: Vector2 = Vector2.ZERO
	var count: int = 0
	for node: Node in scene.get_tree().get_nodes_in_group(&"monsters"):
		var monster: Monster = node as Monster
		if monster.data.id == &"goblin_slinger":
			center += monster.global_position
			count += 1
	if count > 0:
		necromancer.global_position = center / count + STAND_OFFSET
	necromancer.max_health = 10000.0
	necromancer.health = 10000.0
	(necromancer.get_node("Camera2D") as Camera2D).zoom = ZOOM
