extends RefCounted
## 스크린샷 준비: 쥐 그림 확인. 네크로맨서 바로 오른쪽에 쥐 한 마리(남서쪽을 봄), 위에 8방향 쥐 한 줄(동부터 화면 시계 방향)을 세운다.
## 쥐마다 발밑(노드 위치)에 1px 점을 찍는다. 기준점이 맞으면 점이 발 바로 아래에 있고, 한 줄의 쥐가 같은 높이에 선다 (방향마다 들썩이지 않음).
## 다른 몬스터는 치우고, 세운 쥐는 움직이지 않는다 (process 꺼짐).
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/test_region.tscn --setup=res://tools/screenshot_setups/rat_sprite.gd --out=<경로>

const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const COUNT: int = 8
const SPACING: float = 36.0
const ROW_OFFSET: Vector2 = Vector2(0, -56)
const BESIDE_OFFSET: Vector2 = Vector2(28, 0)
## 발밑 표시 색 (feae34)
const MARK_COLOR: Color = Color(0.99607843, 0.68235296, 0.20392157, 1)


static func run(scene: Node) -> void:
	var tree: SceneTree = scene.get_tree()
	for node: Node in tree.get_nodes_in_group(&"monsters"):
		node.free()
	var necromancer: Node2D = tree.get_first_node_in_group(&"necromancer")
	var parent: Node = necromancer.get_parent()
	_place(parent, necromancer.global_position + BESIDE_OFFSET, Vector2(-1, 1))
	var start: Vector2 = necromancer.global_position + ROW_OFFSET - Vector2(SPACING * (COUNT - 1) / 2.0, 0)
	for i: int in COUNT:
		_place(parent, start + Vector2(SPACING * i, 0), Vector2.from_angle(i * TAU / COUNT))


static func _place(parent: Node, at: Vector2, facing: Vector2) -> void:
	var rat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	rat.data = load(RAT_PATH)
	rat.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(rat)
	rat.global_position = at
	for child: Node in rat.get_children():
		if child is FacingSprite:
			(child as FacingSprite).face(facing)
			(child as FacingSprite).update_motion(Vector2.ZERO, 1.0)
	var mark: ColorRect = ColorRect.new()
	mark.size = Vector2.ONE
	mark.color = MARK_COLOR
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.z_index = 1
	rat.add_child(mark)
