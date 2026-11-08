extends RefCounted
## 스크린샷 준비: 플레이어 시야. 얕은 굴의 쥐 둥지에서 가장 큰 바위 서쪽에 네크로맨서를 세우고 동쪽(바위 쪽)을 보게 한다.
## 쥐 넷을 세운다: 부채꼴 안 정면(보임), 바위 바로 뒤(안 보임), 부채꼴 밖 위쪽(안 보임), 몸 바로 뒤 둘레 원 안(보임).
## 다른 몬스터는 치우고, 세운 쥐는 움직이지 않는다. 쥐마다 발밑에 1px 점을 찍어 안 보이는 쥐 자리도 알 수 있게 한다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/shallow_cave.tscn --setup=res://tools/screenshot_setups/vision_preview.gd --out=<경로>

const MAP_PNG: String = "res://art_src/maps/shallow_cave.png"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const TILE: float = 32.0
## 바위에서 네크로맨서까지 (칸)
const STAND_OFF: float = 4.0
## 점 색 (feae34)
const MARK_COLOR: Color = Color(0.99607843, 0.68235296, 0.20392157, 1)


static func run(scene: Node) -> void:
	var tree: SceneTree = scene.get_tree()
	for node: Node in tree.get_nodes_in_group(&"monsters"):
		node.free()
	var layout: MapLayout = MapLayout.from_file(MAP_PNG)
	var rat_room: int = layout.room_at(layout.cells_of("rat")[0])
	var rock: Dictionary = {}
	for r: Dictionary in layout.rocks:
		if r.room == rat_room and (rock.is_empty() or r.cells.size() > rock.cells.size()):
			rock = r
	var rect: Rect2i = rock.rect
	var rock_center: Vector2 = (Vector2(rect.position) + Vector2(rect.size) / 2.0) * TILE
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	necromancer.global_position = Vector2(rect.position.x * TILE - STAND_OFF * TILE, rock_center.y)
	var vision: Vision = (scene as Region).get_vision()
	vision.facing_override = Vector2.RIGHT
	var parent: Node = necromancer.get_parent()
	_place(parent, necromancer.global_position + Vector2(2.5 * TILE, -1.0 * TILE))
	_place(parent, Vector2(rect.end.x * TILE + 1.5 * TILE, rock_center.y))
	_place(parent, necromancer.global_position + Vector2(0.5 * TILE, -3.5 * TILE))
	_place(parent, necromancer.global_position + Vector2(-1.0 * TILE, 0.0))


static func _place(parent: Node, at: Vector2) -> void:
	var rat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	rat.data = load(RAT_PATH)
	rat.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(rat)
	rat.global_position = at
	var mark: ColorRect = ColorRect.new()
	mark.size = Vector2.ONE
	mark.color = MARK_COLOR
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.position = at
	mark.z_index = 2
	parent.add_child(mark)
