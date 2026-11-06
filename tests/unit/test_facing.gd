extends TestCase
## 방향 → 8방향 그림 번호 규칙 (Facing)


func test_cardinal_directions() -> void:
	assert_eq(Facing.index_for(Vector2.RIGHT, 8), 0, "동")
	assert_eq(Facing.index_for(Vector2.DOWN, 8), 2, "남 (화면 아래)")
	assert_eq(Facing.index_for(Vector2.LEFT, 8), 4, "서")
	assert_eq(Facing.index_for(Vector2.UP, 8), 6, "북 (화면 위)")


func test_diagonal_directions() -> void:
	assert_eq(Facing.index_for(Vector2(1, 1), 8), 1, "남동")
	assert_eq(Facing.index_for(Vector2(-1, 1), 8), 3, "남서")
	assert_eq(Facing.index_for(Vector2(-1, -1), 8), 5, "북서")
	assert_eq(Facing.index_for(Vector2(1, -1), 8), 7, "북동")


func test_rounds_to_nearest_direction() -> void:
	assert_eq(Facing.index_for(Vector2.from_angle(deg_to_rad(20.0)), 8), 0, "20도는 동")
	assert_eq(Facing.index_for(Vector2.from_angle(deg_to_rad(25.0)), 8), 1, "25도는 남동")
	assert_eq(Facing.index_for(Vector2.from_angle(deg_to_rad(-20.0)), 8), 0, "-20도(북동 쪽)도 동")
	assert_eq(Facing.index_for(Vector2.from_angle(deg_to_rad(170.0)), 8), 4, "170도는 서")
	assert_eq(Facing.index_for(Vector2.from_angle(deg_to_rad(-170.0)), 8), 4, "-170도도 서 (음수 각도를 감싸 돈다)")


func test_works_for_other_counts() -> void:
	assert_eq(Facing.index_for(Vector2.UP, 4), 3, "4방향에서 북은 3번")
	assert_eq(Facing.index_for(Vector2.DOWN, 4), 1, "4방향에서 남은 1번")
