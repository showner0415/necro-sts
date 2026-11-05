extends RefCounted
## 스크린샷 준비 (--scene=res://regions/test_region.tscn): 네크로맨서를 탈출 지점 위에 둔다. --seconds=1.5로 찍으면 게이지가 반쯤 찬다 (탈출에 3초).

static func run(scene: Node) -> void:
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	var point: EscapePoint = scene.find_children("*", "EscapePoint", true, false).front()
	necromancer.global_position = point.global_position
