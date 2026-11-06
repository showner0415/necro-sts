class_name StaminaRing
extends Node2D
## 네크로맨서 바로 오른쪽에 뜨는 도넛 모양 스태미나 바.
## 12시 방향에서 시작해 시계 방향으로 남은 비율만큼 채운다. 그래서 줄어들 때는 끝이 시계 반대 방향으로 물러나고,
## 다시 찰 때는 그 끝이 시계 방향으로 되돌아온다. 가득 차면 숨긴다.

## 도넛 가운데까지의 반지름 (픽셀)
@export var radius: float = 4.0
## 도넛 두께 (픽셀)
@export var thickness: float = 2.0
## 원을 그릴 때 쓰는 점 수
@export var point_count: int = 24
## 남은 스태미나 색 (임시값, Endesga 32의 63c74d)
@export var fill_color: Color = Color(0.3882353, 0.78039217, 0.3019608, 1)
## 빈 부분 색 (Endesga 32의 262b44)
@export var track_color: Color = Color(0.14901961, 0.16862746, 0.26666668, 1)

var _stamina: Stamina


func bind(stamina: Stamina) -> void:
	_stamina = stamina
	_stamina.changed.connect(_on_changed)
	_on_changed(_stamina.current, _stamina.maximum)


## 테스트용: 지금 그리고 있는 채움 비율 (숨겨져 있으면 1)
func get_shown_ratio() -> float:
	return _stamina.get_ratio() if _stamina != null else 1.0


func _on_changed(_current: float, _maximum: float) -> void:
	visible = not _stamina.is_full()
	queue_redraw()


func _draw() -> void:
	if _stamina == null:
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, point_count, track_color, thickness)
	var ratio: float = _stamina.get_ratio()
	if ratio <= 0.0:
		return
	# 화면 좌표는 y가 아래로 커서, 각도가 커지면 시계 방향이다. 12시는 -PI/2.
	var start: float = -PI / 2.0
	draw_arc(Vector2.ZERO, radius, start, start + ratio * TAU, maxi(2, ceili(point_count * ratio)), fill_color, thickness)
