extends TestCase
## LeaderCrown(무리 대장 왕관의 자리와 그림) 단위 테스트.


func test_crown_sits_one_pixel_above_art_center() -> void:
	# 20×20 그림에서 불투명 영역이 (6, 4)부터 8×10
	var image: Image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(6, 4, 8, 10), Color.WHITE)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	var offset: Vector2 = Vector2(-10, -18)
	var top_left: Vector2 = LeaderCrown.top_left_for_art(texture, offset)
	# 가운데 x = -10 + 6 + 4 = 0 → 왕관 폭 5의 왼쪽은 -2 (반올림), 위쪽 = -18 + 4 - 1 - 2
	assert_eq(top_left, Vector2(roundf(0.0 - 2.5), -17.0), "불투명 영역 위쪽 가운데, 1px 위")


func test_crown_follows_head_rows() -> void:
	# 몸은 (4, 8)부터 12×6, 머리는 오른쪽 위 (12, 4)부터 4×4. 위 세 줄에는 머리만 있다
	var image: Image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(4, 8, 12, 6), Color.WHITE)
	image.fill_rect(Rect2i(12, 4, 4, 4), Color.WHITE)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	var top_left: Vector2 = LeaderCrown.top_left_for_art(texture, Vector2(-10, -18))
	# 머리 가운데 x = -10 + 14 = 4 → 왼쪽은 4 - 2.5 반올림, 위쪽 = -18 + 4 - 1 - 2
	assert_eq(top_left, Vector2(roundf(4.0 - 2.5), -17.0), "몸 가운데가 아니라 머리 쪽 위")


func test_crown_above_placeholder_top() -> void:
	assert_eq(LeaderCrown.top_left_for_top(-16.0), Vector2(roundf(-2.5), -16.0 - 1 - 2), "도형 위쪽 끝 1px 위")


func test_texture_matches_rows() -> void:
	var image: Image = LeaderCrown.texture().get_image()
	assert_eq(Vector2i(image.get_size()), LeaderCrown.size())
	assert_eq(image.get_pixel(0, 0), LeaderCrown.COLOR, "1.1.1의 첫 칸은 칠함")
	assert_eq(image.get_pixel(1, 0).a, 0.0, "1.1.1의 둘째 칸은 비움")
	assert_eq(image.get_pixel(4, 1), LeaderCrown.COLOR, "아랫줄은 모두 칠함")
