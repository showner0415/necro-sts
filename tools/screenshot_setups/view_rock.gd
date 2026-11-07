extends RefCounted
## 스크린샷 준비: 얕은 굴의 전망 바위에서 박쥐 둥지를 본다. 네크로맨서를 전망 자리에 세우고 몬스터는 멈춘다 (HUD는 그대로).
## 전망 자리: 박쥐가 사는 굴(박쥐 둥지)과 이어지지 않은 굴 중 박쥐 둥지에 가장 가까운 굴(전망 바위)에서, 박쥐 둥지에 가장 가까운 바닥 칸.
## scenario_shallow_cave.gd도 spot()을 써서 같은 자리에서 확인한다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/shallow_cave.tscn --setup=res://tools/screenshot_setups/view_rock.gd --out=<경로>

const MAP_PNG: String = "res://art_src/maps/shallow_cave.png"
const TILE: float = 32.0


static func run(scene: Node) -> void:
	var layout: MapLayout = MapLayout.from_file(MAP_PNG)
	var necromancer: Node2D = scene.get_tree().get_first_node_in_group(&"necromancer")
	necromancer.global_position = (Vector2(spot(layout)) + Vector2(0.5, 0.5)) * TILE
	for node: Node in scene.get_tree().get_nodes_in_group(&"monsters"):
		node.process_mode = Node.PROCESS_MODE_DISABLED


## 전망 자리 (칸). 박쥐가 없으면 (-1, -1)
static func spot(layout: MapLayout) -> Vector2i:
	var bats: Array[Vector2i] = layout.cells_of("bat")
	if bats.is_empty():
		return Vector2i(-1, -1)
	var nest: int = layout.room_at(bats[0])
	var nest_cells: Array[Vector2i] = []
	var others: Array[Vector2i] = []
	for y: int in layout.size.y:
		for x: int in layout.size.x:
			var room: int = layout.room_at(Vector2i(x, y))
			if room == nest:
				nest_cells.append(Vector2i(x, y))
			elif room >= 0 and not layout.rooms[nest].neighbors.has(room):
				others.append(Vector2i(x, y))
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for cell: Vector2i in others:
		for target: Vector2i in nest_cells:
			var distance: float = Vector2(cell).distance_squared_to(Vector2(target))
			if distance < best_distance:
				best_distance = distance
				best = cell
	return best
