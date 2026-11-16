class_name GameScreen
extends CanvasLayer
## 3D 화면을 내부 해상도(project.godot의 viewport 크기)의 SubViewport에 그려, 창에 정수 배율로 늘려 놓는다.
## 루트 창은 canvas_items로 실제 해상도를 그리므로, 그 위의 HUD·창(CanvasLayer)은 글자와 그림이 뭉개지지 않는다.
## 3D 세계(World3D)는 루트와 같이 쓴다. 카메라와 3D 화면 위에 그리는 층(팔레트, 도넛·안내)만 SubViewport 안에 둔다.
## RegionView3D가 만든다 (docs/plans/2026-11-14_hd_ui_layer_plan.md의 B 변형).

## HUD·창보다 아래에 그린다
@export var screen_layer: int = -10

var _viewport: SubViewport


func _ready() -> void:
	layer = screen_layer
	var container: SubViewportContainer = SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	# SubViewport 크기를 화면(내부 해상도) 크기에 맞춘다. 루트가 그것을 정수 배율로 늘린다.
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 게임 조작의 클릭을 받아 가지 않는다. SubViewport 안에는 마우스를 받을 것이 없다.
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(_viewport)


## 카메라와 3D 화면 위의 층을 넣을 곳
func get_screen_viewport() -> SubViewport:
	return _viewport
