extends RefCounted
## 스크린샷 준비: 조준점 그림이 바닥 위에서 어떻게 보이는지 본다.
## 시스템 커서는 게임 화면 캡처에 찍히지 않으므로, 배율 1 그림(게임 픽셀 크기 그대로)을 화면 위에 따로 올려서 찍는다.
## 네크로맨서 오른쪽으로 바닥 체크무늬 두 색 위에 하나씩, 가장 가까운 몬스터(있으면) 위에 하나 둔다.
## 거점(밝은 바닥)·시험 지역(어두운 바닥) 둘 다 이 스크립트로 찍는다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --setup=res://tools/screenshot_setups/aim_cursor_preview.gd --out=<경로>
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/test_region.tscn --setup=res://tools/screenshot_setups/aim_cursor_preview.gd --out=<경로>

const TEXTURE_PATH: String = "res://assets/ui/aim_cursor/aim_cursor_x1.png"
## 네크로맨서 기준 조준점 자리 (월드 좌표). 바닥 칸이 32px라 32 떨어진 두 자리는 다른 색 칸에 놓인다.
const FLOOR_OFFSETS: Array[Vector2] = [Vector2(48, -8), Vector2(80, -8)]


static func run(scene: Node) -> void:
	var tree: SceneTree = scene.get_tree()
	var necromancer: Node2D = tree.get_first_node_in_group(&"necromancer")
	var points: Array[Vector2] = []
	for offset: Vector2 in FLOOR_OFFSETS:
		points.append(necromancer.global_position + offset)
	var nearest: Node2D = null
	for node: Node in tree.get_nodes_in_group(&"monsters"):
		var monster: Node2D = node as Node2D
		monster.process_mode = Node.PROCESS_MODE_DISABLED
		if nearest == null or monster.global_position.distance_to(necromancer.global_position) < nearest.global_position.distance_to(necromancer.global_position):
			nearest = monster
	if nearest != null:
		# 몬스터 몸 가운데쯤 (기준점이 발밑이라 조금 위)
		points.append(nearest.global_position + Vector2(0, -8))
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	scene.add_child(layer)
	var texture: Texture2D = load(TEXTURE_PATH)
	var canvas: Transform2D = scene.get_viewport().get_canvas_transform()
	for point: Vector2 in points:
		var rect: TextureRect = TextureRect.new()
		rect.texture = texture
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 가운데 픽셀이 그 자리에 오게 한다 (커서의 hotspot과 같다).
		rect.position = (canvas * point - Vector2(floori(texture.get_width() / 2.0), floori(texture.get_height() / 2.0))).round()
		layer.add_child(rect)
