class_name AimCursor
extends Node
## 게임 화면 위의 마우스 커서를 조준점 그림으로 바꾼다. 반응이 빠르도록 그림을 따로 그리지 않고 시스템 커서를 바꾼다.
## - 시스템 커서의 "십자(CURSOR_CROSS)" 모양에 조준점 그림을 넣고, 아무 UI도 없는 곳의 기본 모양을 십자로 둔다
## - 클릭을 받는 UI(인벤토리·상자·창고 칸, 메뉴, 핫바 등)는 자기 커서 모양(기본 화살표)을 쓰므로 그 위에서는 화살표로 돌아간다.
##   장식용 UI(mouse_filter IGNORE)는 커서를 바꾸지 않는다
## - 시스템 커서는 창의 실제 픽셀로 그려지므로, 창 배율(정수)이 바뀌면 그 배율의 그림으로 바꾼다
## 지역 씬마다 HUD 안에 하나 있다. 씬이 바뀌어도 새 HUD가 다시 넣는다.

## 배율별 조준점 그림. 0번이 배율 1, 1번이 배율 2 … 창 배율이 이보다 크면 마지막 그림을 쓴다.
@export var textures_by_scale: Array[Texture2D] = []

## 지금 넣어 둔 그림의 배율 (아직 안 넣었으면 0)
var _applied_scale: int = 0


func _ready() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	get_viewport().size_changed.connect(_apply)
	_apply()


## 씬이 바뀔 때는 새 HUD가 다시 넣는다. 그림을 Input에 남겨 두면 끝낼 때 텍스처가 새는 것으로 나와서 풀어 준다.
func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_applied_scale = 0


## 테스트용: 지금 넣어 둔 그림의 배율
func get_applied_scale() -> int:
	return _applied_scale


## 창 배율에 맞는 그림의 번호 (1부터). 그림 수를 넘으면 가장 큰 것.
func get_scale_for_window() -> int:
	var window_scale: int = maxi(1, roundi(get_viewport().get_final_transform().get_scale().x))
	return mini(window_scale, textures_by_scale.size())


func _apply() -> void:
	if textures_by_scale.is_empty():
		return
	var scale: int = get_scale_for_window()
	if scale == _applied_scale:
		return
	_applied_scale = scale
	var texture: Texture2D = textures_by_scale[scale - 1]
	# 가운데 픽셀이 마우스 위치가 되게 한다 (그림 크기는 홀수 × 배율).
	var hotspot: Vector2 = Vector2(floori(texture.get_width() / 2.0), floori(texture.get_height() / 2.0))
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_CROSS, hotspot)
