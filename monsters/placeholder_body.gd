class_name PlaceholderBody
extends RefCounted
## 그림이 생기기 전까지 몬스터·언데드·시체를 그리는 임시 도형과 그 충돌 모양.
## 모양(원 / 가로로 긴 타원 / 가로로 넓은 마름모)과 크기는 MonsterData에 있다. 기준점은 발밑이고, 도형은 그 위에 놓인다.


## 충돌 모양. 원은 CircleShape2D, 타원은 가로로 눕힌 CapsuleShape2D (shape_rotation()만큼 돌려서 쓴다), 마름모는 ConvexPolygonShape2D.
static func make_shape(data: MonsterData) -> Shape2D:
	var half: Vector2 = data.get_placeholder_half_size()
	if data.placeholder_shape == MonsterData.PlaceholderShape.DIAMOND:
		var polygon: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
		polygon.points = _diamond_points(half)
		return polygon
	if data.placeholder_shape == MonsterData.PlaceholderShape.ELLIPSE:
		var capsule: CapsuleShape2D = CapsuleShape2D.new()
		capsule.radius = half.y
		capsule.height = half.x * 2.0
		return capsule
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = half.x
	return circle


## 충돌 모양을 돌릴 각도 (캡슐은 세로로 서 있으므로 타원이면 눕힌다)
static func shape_rotation(data: MonsterData) -> float:
	return PI / 2.0 if data.placeholder_shape == MonsterData.PlaceholderShape.ELLIPSE else 0.0


## 도형 가운데. 발밑(0, 0) 위로 세로 반지름만큼.
static func center(data: MonsterData) -> Vector2:
	return Vector2(0, -data.get_placeholder_half_size().y)


## canvas의 _draw() 안에서 부른다. at을 가운데로 도형을 그리고, 세로를 flatten배로 줄인다 (시체는 눕힌 모양).
static func draw(canvas: CanvasItem, data: MonsterData, color: Color, at: Vector2, flatten: float = 1.0) -> void:
	var half: Vector2 = data.get_placeholder_half_size()
	if data.placeholder_shape == MonsterData.PlaceholderShape.DIAMOND:
		canvas.draw_set_transform(at, 0.0, Vector2(1.0, flatten))
		canvas.draw_colored_polygon(_diamond_points(half), color)
	else:
		canvas.draw_set_transform(at, 0.0, Vector2(half.x / half.y, flatten))
		canvas.draw_circle(Vector2.ZERO, half.y, color)
	canvas.draw_set_transform(Vector2.ZERO)


## 가운데가 (0, 0)인 마름모의 네 꼭짓점
static func _diamond_points(half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-half.x, 0), Vector2(0, -half.y), Vector2(half.x, 0), Vector2(0, half.y)])
