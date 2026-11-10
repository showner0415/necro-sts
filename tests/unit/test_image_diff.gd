extends TestCase
## 두 이미지의 차이 찾기 (ImageDiff)


func _image() -> Image:
	return Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)


func test_same_images_have_no_changes() -> void:
	assert_eq(ImageDiff.changed_pixels(_image(), _image()).size(), 0, "차이 없음")


func test_finds_changed_pixels_and_bounds() -> void:
	var a: Image = _image()
	var b: Image = _image()
	b.set_pixel(1, 1, Color.WHITE)
	b.set_pixel(3, 2, Color.WHITE)
	var changed: Array[Vector2i] = ImageDiff.changed_pixels(a, b)
	assert_eq(changed.size(), 2, "두 픽셀")
	assert_eq(ImageDiff.bounds(changed), Rect2i(1, 1, 3, 2), "두 점을 감싼 사각형")


func test_rect_limits_the_search() -> void:
	var a: Image = _image()
	var b: Image = _image()
	b.set_pixel(0, 0, Color.WHITE)
	b.set_pixel(3, 3, Color.WHITE)
	assert_eq(ImageDiff.changed_pixels(a, b, Rect2i(2, 2, 2, 2)), [Vector2i(3, 3)] as Array[Vector2i], "사각형 안만 봄")


func test_bounds_of_nothing_is_empty() -> void:
	assert_eq(ImageDiff.bounds([] as Array[Vector2i]), Rect2i(), "빈 사각형")
