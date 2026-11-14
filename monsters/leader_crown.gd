class_name LeaderCrown
extends RefCounted
## 무리 대장 표시: 몸 그림 위쪽 1px 위의 작은 노란 왕관 (사용자 결정 2026-11-14, 코드로 그린 임시 표시. docs/art-direction.md "무리 대장 표시").
## 2D는 몬스터의 _draw가 draw()로, 3D는 BodyLayer가 texture()를 몸과 같은 자리의 작은 사각형으로 그린다.
## 위치는 지금 몸 그림의 머리 쪽(불투명 영역 위 HEAD_ROWS줄의 불투명 픽셀 무게중심) 위다. 비교판과 같은 자리 (사용자 결정 2026-11-14).
## 그림이 없는 몸은 임시 도형의 위쪽 가운데다.

## 왕관 모양 (1 = 칠함), 색, 그림 위쪽과의 간격 (픽셀)
const ROWS: Array[String] = ["1.1.1", "11111"]
const COLOR: Color = Color(0.99607843, 0.68235296, 0.20392157, 1)
const GAP: int = 1
## 머리 쪽을 찾을 때 보는 그림 위쪽 줄 수
const HEAD_ROWS: int = 3

## 그림 텍스처 → (머리 쪽 가운데 x, 불투명 영역 위쪽 y) (그림 기준 픽셀, 한 번만 잰다)
static var _heads: Dictionary = {}
static var _texture: ImageTexture


static func size() -> Vector2i:
	return Vector2i(ROWS[0].length(), ROWS.size())


## 몸 그림(texture, 발밑 기준 왼쪽 위 offset) 위에 놓을 왕관의 왼쪽 위 (발밑 기준)
static func top_left_for_art(texture: Texture2D, offset: Vector2) -> Vector2:
	if not _heads.has(texture):
		_heads[texture] = _measure_head(texture)
	var head: Vector2 = _heads[texture]
	return Vector2(roundf(offset.x + head.x - size().x / 2.0), offset.y + head.y - GAP - size().y)


## 그림 위 HEAD_ROWS줄 불투명 픽셀의 가운데 x와, 불투명 영역 위쪽 y
static func _measure_head(texture: Texture2D) -> Vector2:
	var image: Image = texture.get_image()
	if image == null:
		return Vector2(texture.get_width() / 2.0, 0.0)
	var used: Rect2i = image.get_used_rect()
	var sum_x: float = 0.0
	var count: int = 0
	for y: int in range(used.position.y, mini(used.end.y, used.position.y + HEAD_ROWS)):
		for x: int in range(used.position.x, used.end.x):
			if image.get_pixel(x, y).a > 0.0:
				sum_x += x + 0.5
				count += 1
	var center_x: float = sum_x / count if count > 0 else used.position.x + used.size.x / 2.0
	return Vector2(center_x, used.position.y)


## 몸의 위쪽 끝(발밑 기준 y, 위가 -)만 알 때 왕관의 왼쪽 위 (임시 도형 몸)
static func top_left_for_top(top_y: float) -> Vector2:
	return Vector2(roundf(-size().x / 2.0), top_y - GAP - size().y)


## canvas의 _draw() 안에서 부른다. at은 왕관의 왼쪽 위.
static func draw(canvas: CanvasItem, at: Vector2) -> void:
	for row: int in ROWS.size():
		for column: int in ROWS[row].length():
			if ROWS[row][column] == "1":
				canvas.draw_rect(Rect2(at + Vector2(column, row), Vector2.ONE), COLOR)


## 3D에서 쓰는 왕관 그림
static func texture() -> ImageTexture:
	if _texture == null:
		var image: Image = Image.create(size().x, size().y, false, Image.FORMAT_RGBA8)
		for row: int in ROWS.size():
			for column: int in ROWS[row].length():
				if ROWS[row][column] == "1":
					image.set_pixel(column, row, COLOR)
		_texture = ImageTexture.create_from_image(image)
	return _texture
