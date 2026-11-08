extends RefCounted
## 스크린샷 준비: 네크로맨서 씬을 줄마다 8개씩 띄워 8방향(동부터 화면 시계 방향)의 정지 그림과 걷기 프레임을 보여 준다.
## 줄: 정지 그림 / 걷기 프레임 FRAMES[0] / 걷기 프레임 FRAMES[1]. 모두 발밑(노드 위치)이 줄마다 같은 높이라, 기준점이 맞으면 발끝이 가지런하다.
## 발밑마다 1px 점을 찍는다. 복사본은 움직이지 않고(process 꺼짐), 몬스터가 노리지 않게 necromancer 그룹에서 뺀다. 몬스터는 모두 치운다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/test_region.tscn --setup=res://tools/screenshot_setups/necromancer_walk.gd --out=<경로>

const NECROMANCER_SCENE: String = "res://necromancer/necromancer.tscn"
const COUNT: int = 8
## 걷기 줄에서 보여 줄 프레임 번호
const FRAMES: Array[int] = [2, 5]
const SPACING: Vector2 = Vector2(40, 44)
const TOP_OFFSET: Vector2 = Vector2(0, -60)
## 발밑 표시 색 (feae34)
const MARK_COLOR: Color = Color(0.99607843, 0.68235296, 0.20392157, 1)


static func run(scene: Node) -> void:
	var tree: SceneTree = scene.get_tree()
	for node: Node in tree.get_nodes_in_group(&"monsters"):
		node.free()
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	necromancer.visible = false
	var parent: Node = necromancer.get_parent()
	var start: Vector2 = necromancer.global_position + TOP_OFFSET - Vector2(SPACING.x * (COUNT - 1) / 2.0, 0)
	for row: int in FRAMES.size() + 1:
		for i: int in COUNT:
			var copy: Necromancer = (load(NECROMANCER_SCENE) as PackedScene).instantiate()
			copy.get_node("Camera2D").free()
			copy.remove_from_group(&"necromancer")
			copy.process_mode = Node.PROCESS_MODE_DISABLED
			parent.add_child(copy)
			copy.inventory = necromancer.inventory
			copy.global_position = start + Vector2(SPACING.x * i, SPACING.y * row)
			var sprite: FacingSprite = copy.get_node("Sprite")
			var direction: Vector2 = Vector2.from_angle(i * TAU / COUNT)
			sprite.face(direction)
			if row == 0:
				sprite.update_motion(Vector2.ZERO, copy.move_speed)
			else:
				sprite.update_motion(direction * copy.move_speed, copy.move_speed)
				sprite.pause()
				sprite.frame = FRAMES[row - 1]
			var mark: ColorRect = ColorRect.new()
			mark.size = Vector2.ONE
			mark.color = MARK_COLOR
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.z_index = 1
			copy.add_child(mark)
