class_name ItemData
extends Resource
## 줍거나 보유할 수 있는 아이템 한 종류의 정의 (뼈, 머리뼈, 조합 재료 등).

@export var id: StringName
@export var display_name: String

@export_group("임시 도형")
## 그림이 생기기 전까지 바닥에 그릴 사각형의 색과 크기
@export var placeholder_color: Color = Color.WHITE
@export var placeholder_size: Vector2 = Vector2(6, 3)
