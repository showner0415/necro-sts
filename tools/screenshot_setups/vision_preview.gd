extends RefCounted
## 스크린샷 준비: 플레이어 시야. 얕은 굴의 쥐 굴들에서 가장 큰 바위 서쪽에 네크로맨서를 세우고 동쪽(바위 쪽)을 보게 한다.
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
	# 쥐 굴이 여러 개이고 바위가 없는 굴도 있으므로, 쥐가 있는 모든 굴에서 가장 큰 바위를 고른다.
	var rat_rooms: Dictionary = {}
	# 쥐 무리 자리도 쥐 굴로 본다 (계획 8a). 섞인 무리(진흙 굴, 2등급)는 빼서 예전처럼 1등급 쥐 굴에서 고른다
	var rat_cells: Array[Vector2i] = layout.cells_of("rat")
	for pack: String in ["pack_rat_big", "pack_rat_gang"]:
		rat_cells.append_array(layout.cells_of(pack))
	for cell: Vector2i in rat_cells:
		rat_rooms[layout.room_at(cell)] = true
	var rock: Dictionary = {}
	for r: Dictionary in layout.rocks:
		if rat_rooms.has(r.room) and (rock.is_empty() or r.cells.size() > rock.cells.size()):
			rock = r
	if rock.is_empty():
		push_error("쥐가 있는 굴에 바위가 없음")
		return
	var rect: Rect2i = rock.rect
	var rock_center: Vector2 = (Vector2(rect.position) + Vector2(rect.size) / 2.0) * TILE
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	necromancer.global_position = Vector2(rect.position.x * TILE - STAND_OFF * TILE, rock_center.y)
	var vision: Vision = (scene as Region).get_vision()
	vision.facing_override = Vector2.RIGHT
	var parent: Node = necromancer.get_parent()
	# 몸이 실제 마우스 쪽을 보면 찍을 때마다 그림이 달라지므로 조준을 동쪽 고정 지점으로 묶는다 (전후 비교용).
	var aim_marker: Node2D = Node2D.new()
	parent.add_child(aim_marker)
	aim_marker.global_position = necromancer.get_body_center() + Vector2.RIGHT * TILE * STAND_OFF
	necromancer.aim_provider = aim_marker.get_global_position
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
