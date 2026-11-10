extends RefCounted
## 스크린샷 준비: 지역에 3D 화면 층을 붙인다 (지역 데이터의 view_3d는 그대로 둔다). 이전 중이라 아직 없는 것(몸 등)은 보이지 않는다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/shallow_cave.tscn --setup=res://tools/screenshot_setups/view_3d_on.gd --out=<경로>


static func run(scene: Node) -> void:
	var view: RegionView3D = scene.call(&"add_view_3d")
	# 찍을 때마다 실제 마우스 위치에 따라 카메라가 달라지지 않게 한다.
	view.aim_lead.strength = 0.0
