extends TestCase
## 임시 도형의 3D용 흰 형판 그림 (PlaceholderArt)

const TOLERANCE: float = 0.001


func _data(shape: MonsterData.PlaceholderShape, radius: float) -> MonsterData:
	var data: MonsterData = MonsterData.new()
	data.placeholder_shape = shape
	data.placeholder_radius = radius
	return data


func test_body_sits_on_feet() -> void:
	var data: MonsterData = _data(MonsterData.PlaceholderShape.CIRCLE, 8.0)
	var art: PlaceholderArt = PlaceholderArt.for_body(data, 1.0, false)
	var half: Vector2 = data.get_placeholder_half_size()
	assert_almost_eq(art.offset.x, floorf(-half.x), TOLERANCE, "가로 가운데")
	assert_almost_eq(art.offset.y, floorf(-2.0 * half.y), TOLERANCE, "도형 아래가 발밑")


func test_circle_center_filled_corner_empty() -> void:
	var image: Image = PlaceholderArt.for_body(_data(MonsterData.PlaceholderShape.CIRCLE, 8.0), 1.0, false).texture.get_image()
	assert_eq(image.get_pixel(image.get_width() / 2, image.get_height() / 2).a, 1.0, "가운데는 채움")
	assert_eq(image.get_pixel(0, 0).a, 0.0, "모서리는 빔")


func test_corpse_is_centered_on_feet_and_flatter() -> void:
	var data: MonsterData = _data(MonsterData.PlaceholderShape.CIRCLE, 8.0)
	var standing: PlaceholderArt = PlaceholderArt.for_body(data, 1.0, false)
	var corpse: PlaceholderArt = PlaceholderArt.for_body(data, 0.5, true)
	var half: Vector2 = data.get_placeholder_half_size()
	assert_almost_eq(corpse.offset.y, floorf(-half.y * 0.5), TOLERANCE, "가운데가 발밑")
	assert_true(corpse.texture.get_height() < standing.texture.get_height(), "누운 모양은 세로가 짧음")


func test_diamond_corner_empty_but_tip_filled() -> void:
	var image: Image = PlaceholderArt.for_body(_data(MonsterData.PlaceholderShape.DIAMOND, 8.0), 1.0, false).texture.get_image()
	assert_eq(image.get_pixel(0, 0).a, 0.0, "모서리는 빔")
	assert_eq(image.get_pixel(image.get_width() / 2, 1).a, 1.0, "위 꼭짓점 근처는 채움")


func test_box_sits_on_feet() -> void:
	var art: PlaceholderArt = PlaceholderArt.for_box(Vector2(6, 4))
	assert_eq(art.offset, Vector2(-3, -4), "아래 가운데가 발밑")
	assert_eq(art.texture.get_size(), Vector2(6, 4), "크기")


func test_same_shape_reuses_art() -> void:
	var data: MonsterData = _data(MonsterData.PlaceholderShape.CIRCLE, 5.0)
	assert_true(PlaceholderArt.for_body(data, 1.0, false) == PlaceholderArt.for_body(data, 1.0, false), "같은 모양은 같은 그림")
