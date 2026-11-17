extends RefCounted
## 스크린샷 준비 (--scene=res://regions/base.tscn): storage_open.gd처럼 창고를 열고, 조준을 고정해 카메라가 실제 마우스를 따라 움직이지 않게 한다.
## HUD·창의 글자와 3D 화면을 함께 볼 때 쓴다 (찍을 때마다 같은 화면).
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --setup=res://tools/screenshot_setups/hd_ui_storage.gd --out=<경로>

const STORAGE_OPEN_PATH: String = "res://tools/screenshot_setups/storage_open.gd"
## 몸 가운데에서 조준점까지 (오른쪽)
const AIM_DISTANCE: float = 128.0


static func run(scene: Node) -> void:
	load(STORAGE_OPEN_PATH).run(scene)
	var view: RegionView3D = scene.call(&"get_view_3d")
	if view == null:
		return
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	view.aim_override = necromancer.get_body_center() + Vector2.RIGHT * AIM_DISTANCE
