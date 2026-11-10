class_name PlaceholderArt
extends RefCounted
## 그림이 없는 몸(임시 도형)을 3D에서 그릴 흰 형판 그림. 몸 색은 재질에서 곱한다 (예고 깜빡임으로 색이 바뀌어도 그림을 다시 만들지 않는다).
## 모양이 같으면 같은 그림을 다시 쓴다.

## 모양 → PlaceholderArt
static var _cache: Dictionary = {}

var texture: Texture2D
## 기준점(발밑)에서 그림 왼쪽 위까지 (픽셀)
var offset: Vector2 = Vector2.ZERO


## 몬스터 도형. flatten: 세로 비율 (시체는 눕힌 모양). on_feet가 true면 도형 가운데가 발밑이고 (시체), false면 도형 아래가 발밑이다.
static func for_body(data: MonsterData, flatten: float, on_feet: bool) -> PlaceholderArt:
	var half: Vector2 = data.get_placeholder_half_size()
	var is_diamond: bool = data.placeholder_shape == MonsterData.PlaceholderShape.DIAMOND
	var key: String = "%s:%s:%s:%s" % [half, flatten, on_feet, is_diamond]
	if not _cache.has(key):
		var center_y: float = 0.0 if on_feet else PlaceholderBody.center(data).y
		_cache[key] = _make(Vector2(half.x, half.y * flatten), center_y, is_diamond)
	return _cache[key]


## 바닥 위에 놓인 사각형 (줍는 물건). 아래 가운데가 발밑이다.
static func for_box(size: Vector2) -> PlaceholderArt:
	var key: String = "box:%s" % size
	if not _cache.has(key):
		var image: Image = Image.create_empty(ceili(size.x), ceili(size.y), false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		var art: PlaceholderArt = PlaceholderArt.new()
		art.texture = ImageTexture.create_from_image(image)
		art.offset = (Vector2(-size.x / 2.0, -size.y)).floor()
		_cache[key] = art
	return _cache[key]


## half: 가로세로 반지름, center_y: 발밑에서 도형 가운데까지 (위가 음수)
static func _make(half: Vector2, center_y: float, is_diamond: bool) -> PlaceholderArt:
	var width: int = ceili(half.x * 2.0)
	var height: int = ceili(half.y * 2.0)
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in width:
			var from_center: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(width, height) * 0.5) / half
			var inside: bool = absf(from_center.x) + absf(from_center.y) <= 1.0 if is_diamond else from_center.length_squared() <= 1.0
			if inside:
				image.set_pixel(x, y, Color.WHITE)
	var art: PlaceholderArt = PlaceholderArt.new()
	art.texture = ImageTexture.create_from_image(image)
	art.offset = Vector2(-half.x, center_y - half.y).floor()
	return art
