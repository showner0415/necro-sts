extends RefCounted
## 스크린샷 준비: 맵 전체를 위에서 본다. 카메라를 네크로맨서에게서 떼어 맵 가운데에 두고, 맵이 화면에 다 들어오게 줄인다.
## 맵 크기는 길찾기(NavigationGrid)의 bounds로 안다. HUD는 숨기고 몬스터는 멈춘다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/shallow_cave.tscn --setup=res://tools/screenshot_setups/map_overview.gd --out=<경로>

## 화면 가장자리 여백 비율
const MARGIN: float = 0.98


static func run(scene: Node) -> void:
	var nav: NavigationGrid = scene.get_node("NavigationGrid")
	var bounds: Rect2 = nav.bounds
	var camera: Camera2D = scene.get_viewport().get_camera_2d()
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.global_position = bounds.get_center()
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		camera.set_limit(side, 10000000 if side >= SIDE_RIGHT else -10000000)
	var view: Vector2 = scene.get_viewport().get_visible_rect().size
	var zoom: float = minf(view.x / bounds.size.x, view.y / bounds.size.y) * MARGIN
	camera.zoom = Vector2(zoom, zoom)
	(scene.get_node("HUD") as CanvasLayer).visible = false
	for node: Node in scene.get_tree().get_nodes_in_group(&"monsters"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
