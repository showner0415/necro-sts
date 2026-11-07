extends RefCounted
## 스크린샷 준비: 기본 공격 탄 크기 후보를 실제 게임 화면 크기에서 쥐(위)·박쥐(아래) 사이에 놓고 비교한다.
## 후보마다 한 줄씩 세로로 쥐 → 탄 → 박쥐를 둔다. 왼쪽부터 CANDIDATE_RADII 순서.
## 몬스터와 박쥐 무리는 움직이지 않게 process를 끄고, 나머지 몬스터는 치운다. 탄도 날아가지 않게 멈춘다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/test_region.tscn --setup=res://tools/screenshot_setups/bolt_size_candidates.gd --out=<경로>

## 비교할 탄 반지름 (보이는 크기 = 맞는 범위)
const CANDIDATE_RADII: Array[float] = [2.0, 3.0, 5.0]
## 첫 줄의 위치 (네크로맨서 기준)와 줄 사이 간격
const FIRST_COLUMN_OFFSET: Vector2 = Vector2(-48, -90)
const COLUMN_SPACING: float = 48.0
## 쥐·탄·박쥐 사이 세로 간격
const ROW_SPACING: float = 22.0


static func run(scene: Node) -> void:
	var tree: SceneTree = scene.get_tree()
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	var rats: Array[Monster] = []
	var bats: Array[Monster] = []
	for i: int in CANDIDATE_RADII.size():
		rats.append(scene.get_node("Actors/Rat%d" % (i + 1)))
		bats.append(scene.get_node("Actors/Bat%d" % (i + 1)))
	for node: Node in tree.get_nodes_in_group(&"monsters"):
		if not rats.has(node) and not bats.has(node):
			node.free()
	scene.get_node("BatPack").process_mode = Node.PROCESS_MODE_DISABLED
	for i: int in CANDIDATE_RADII.size():
		var column: Vector2 = necromancer.global_position + FIRST_COLUMN_OFFSET + Vector2(COLUMN_SPACING * i, 0)
		rats[i].process_mode = Node.PROCESS_MODE_DISABLED
		bats[i].process_mode = Node.PROCESS_MODE_DISABLED
		rats[i].global_position = column
		bats[i].global_position = column + Vector2(0, ROW_SPACING * 2.0)
		var bolt: Bolt = necromancer.bolt_scene.instantiate()
		bolt.visual_radius = CANDIDATE_RADII[i]
		bolt.hit_radius = CANDIDATE_RADII[i]
		bolt.process_mode = Node.PROCESS_MODE_DISABLED
		necromancer.get_parent().add_child(bolt)
		bolt.global_position = column + Vector2(0, ROW_SPACING)
