class_name View3DCheck
extends ScenarioTest
## 창을 띄워 3D 층의 화면을 재는 검사들의 공통 부분.

const COLOR_TOLERANCE: float = 1.5 / 255.0
## 시제품 굴: 벽과 쥐가 있는 작은 씬. 시제품 층을 지우고 새 층을 붙여서 쓴다
const PROTO_CAVE_SCENE: String = "res://proto_25d/proto_cave.tscn"


## 지금 씬에 3D 층을 붙인다. 시제품 층이 있으면 먼저 지운다. HUD는 화면 비교에 방해되므로 숨긴다.
func open_layer() -> RegionView3D:
	var proto: Node = current_scene.get_node_or_null("View3D")
	if proto != null:
		proto.free()
	var view: RegionView3D = current_scene.call(&"add_view_3d")
	# 색을 2D 색과 비교하는 검사들이므로 팔레트 후처리는 끈다 (팔레트 자체는 check_vision_3d.gd가 본다).
	view.get_palette().set_enabled(false)
	(current_scene.get_node("HUD") as CanvasLayer).visible = false
	return view


## 시야가 있는 지역이면 끈다 (색·위치 검사에서 시야 밖 몸이 숨지 않게).
func disable_vision() -> void:
	var vision: Vision = current_scene.call(&"get_vision")
	if vision != null:
		vision.set_active(false)


func capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func colors_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= COLOR_TOLERANCE and absf(a.g - b.g) <= COLOR_TOLERANCE and absf(a.b - b.b) <= COLOR_TOLERANCE


## 몬스터를 자기 차례 없이 세워 둔다. 충돌은 켜 둬서 탄에 맞는다.
func freeze_monster(monster: Monster) -> void:
	monster.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	monster.process_mode = Node.PROCESS_MODE_DISABLED
