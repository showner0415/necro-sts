extends RefCounted
## 스크린샷 준비: 네크로맨서 씬(necromancer.tscn)을 8개 더 띄워 8방향을 한 줄로 보여 준다 (동부터 화면 시계 방향).
## 각자의 탄이 나가는 자리(get_shot_origin, 지금은 몸 가운데)에 노란 점을 찍는다. 몬스터는 모두 치운다.
## 복사본은 움직이지 않고(process 꺼짐), 몬스터가 노리지 않게 necromancer 그룹에서 뺀다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/test_region.tscn --setup=res://tools/screenshot_setups/necromancer_8_directions.gd --out=<경로>

const NECROMANCER_SCENE: String = "res://necromancer/necromancer.tscn"
const COUNT: int = 8
## 복사본 사이 간격과, 진짜 네크로맨서에서 줄까지의 거리
const SPACING: float = 40.0
const ROW_OFFSET: Vector2 = Vector2(0, -50)
## 탄 자리 표시 색 (feae34)
const MARK_COLOR: Color = Color(0.99607843, 0.68235296, 0.20392157, 1)


static func run(scene: Node) -> void:
	var tree: SceneTree = scene.get_tree()
	for node: Node in tree.get_nodes_in_group(&"monsters"):
		node.free()
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	var parent: Node = necromancer.get_parent()
	var start: Vector2 = necromancer.global_position + ROW_OFFSET - Vector2(SPACING * (COUNT - 1) / 2.0, 0)
	for i: int in COUNT:
		var copy: Necromancer = (load(NECROMANCER_SCENE) as PackedScene).instantiate()
		copy.get_node("Camera2D").free()
		copy.remove_from_group(&"necromancer")
		copy.process_mode = Node.PROCESS_MODE_DISABLED
		parent.add_child(copy)
		copy.inventory = necromancer.inventory
		copy.global_position = start + Vector2(SPACING * i, 0)
		var sprite: FacingSprite = copy.get_node("Sprite")
		sprite.face(Vector2.from_angle(i * TAU / COUNT))
		var mark: ColorRect = ColorRect.new()
		mark.size = Vector2.ONE
		mark.color = MARK_COLOR
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.z_index = 1
		copy.add_child(mark)
		mark.position = copy.get_shot_origin() - copy.global_position
		print("방향 %d: 탄 자리 %s" % [i, mark.position])
