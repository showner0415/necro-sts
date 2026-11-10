extends RefCounted
## 스크린샷 준비: vision_preview와 같은 자리(얕은 굴의 쥐 굴 바위 앞)에 3D 화면 층을 붙인다. 2D 기준 화면(docs/plans/2.5d_shots/baseline_2d_shallow_cave.png)과 비교할 때 쓴다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --scene=res://regions/shallow_cave.tscn --setup=res://tools/screenshot_setups/view_3d_preview.gd --out=<경로>

const VisionPreview: GDScript = preload("res://tools/screenshot_setups/vision_preview.gd")
const View3dOn: GDScript = preload("res://tools/screenshot_setups/view_3d_on.gd")


static func run(scene: Node) -> void:
	VisionPreview.run(scene)
	View3dOn.run(scene)
