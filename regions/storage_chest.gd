class_name StorageChest
extends InteractZone
## 거점의 창고 상자. 네크로맨서가 가까이에서 F를 누르면 interacted로 알리고, 지역 씬이 창고 화면을 연다.
## 판정 영역(radius)은 상자 그림보다 넓다. 그 안에 있는 동안만 창고가 열려 있는다.

@export_group("임시 도형")
## 상자 그림의 크기 (기준점은 바닥 가운데)
@export var box_size: Vector2 = Vector2(20, 14)
@export var box_color: Color = Color(0.61960787, 0.27058825, 0.22352941, 1)
@export var lid_color: Color = Color(0.8039216, 0.40784314, 0.23921569, 1)
@export var lid_height: float = 4.0


func get_prompt_label() -> String:
	return "창고"


func _draw() -> void:
	# 그림이 생기기 전까지 쓰는 임시 도형: 상자와 뚜껑.
	draw_rect(Rect2(Vector2(-box_size.x / 2.0, -box_size.y), box_size), box_color)
	draw_rect(Rect2(Vector2(-box_size.x / 2.0, -box_size.y), Vector2(box_size.x, lid_height)), lid_color)
