@tool
class_name ScaledFrameStyleBox
extends StyleBox
## 고해상도 창 틀: UI 기준 해상도(1920×1080)로 그린 9-slice 틀 그림을 UI 좌표(640×360 기준)에 texture_scale(1/3)로 줄여 그리고,
## 틀 안쪽에 창 판(panel_color)을 칠한다. 공용 테마(ui/theme/ui_theme.tres)의 창 틀 타입 변형이 쓴다.
## StyleBoxTexture는 9-slice 여백을 그림 픽셀 그대로 UI 좌표에 그려서(줄이는 값이 없음) 그림이 3배로 커지므로 만들었다.
## - frame: 틀 그림의 StyleBoxTexture (그림 픽셀 기준 9-slice 여백, 변 반복 방식, draw_center = false)
## - 판은 틀보다 먼저 그린다. 창 가장자리에서 panel_inset만큼 들어간 사각형이라 틀 띠 아래에 숨는다 (틀 바깥 윤곽이 울퉁불퉁해서)
## - 칸·글자가 틀 띠에 겹치지 않게 하는 안쪽 여백은 이 스타일의 content_margin_*(UI 좌표)로 준다

## 9-slice 틀 그림. 여백은 그림 픽셀 단위다
@export var frame: StyleBoxTexture
## 틀 그림 1픽셀을 UI 좌표 몇으로 그릴지 (그림은 1920×1080 기준, UI 좌표는 640×360 기준이라 1/3)
@export var texture_scale: float = 1.0 / 3.0
## 창 판 색 (틀 안쪽)
@export var panel_color: Color = Color(0.09411765, 0.078431375, 0.14509805, 1)
## 창 가장자리에서 판이 시작하는 거리 (UI 좌표). 틀 띠 안쪽 끝보다 바깥이어야 틈이 보이지 않는다
@export var panel_inset: float = 6.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if panel_color.a > 0.0:
		RenderingServer.canvas_item_add_rect(to_canvas_item, rect.grow(-panel_inset), panel_color)
	if frame == null or texture_scale <= 0.0:
		return
	# 틀은 그림 픽셀 단위로 그리고(창 크기를 그림 픽셀로 바꿔서) 그 그림 전체를 texture_scale로 줄인다.
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY.scaled(Vector2(texture_scale, texture_scale)))
	frame.draw(to_canvas_item, Rect2(rect.position / texture_scale, rect.size / texture_scale))
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)
