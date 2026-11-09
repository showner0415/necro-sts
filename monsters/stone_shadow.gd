class_name StoneShadow
extends Node2D
## 돌이 떨어질 곳을 바닥에 보여 주는 원. 돌(Stone)이 만들고 돌이 사라지면 함께 사라진다.
## 시야(Vision)와 상관없이 항상 보인다 (sight_hidden 그룹에 넣지 않는다).

## 원의 두께 (픽셀)
const LINE_WIDTH: float = 1.0
## 원을 그리는 점의 수
const POINTS: int = 24

var radius: float = 0.0
var color: Color = Color.WHITE


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, POINTS, color, LINE_WIDTH)
