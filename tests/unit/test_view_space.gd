extends TestCase
## 2D 규칙 세계와 3D 화면 층 사이의 좌표 규칙 (ViewSpace)

const AIM_HEIGHT: float = 6.0
const FALLBACK: Vector2 = Vector2(1, 2)


func test_one_tile_is_one_unit() -> void:
	var point: Vector3 = ViewSpace.to_3d(Vector2(64, -32), 16.0)
	assert_almost_eq(point.x, 2.0, 0.001, "x")
	assert_almost_eq(point.y, 0.5, 0.001, "높이")
	assert_almost_eq(point.z, -1.0, 0.001, "2D y는 3D z")


func test_aim_point_moves_back_to_ground_and_up_to_height() -> void:
	var point: Vector3 = ViewSpace.aim_to_3d(Vector2(32, 26), AIM_HEIGHT)
	assert_almost_eq(point.x, 1.0, 0.001, "x")
	assert_almost_eq(point.y, AIM_HEIGHT / ViewSpace.TILE, 0.001, "탄 높이")
	assert_almost_eq(point.z, 1.0, 0.001, "몸 높이만큼 y를 되돌림")


func test_straight_down_ray_hits_aim_under_it() -> void:
	var aim: Vector2 = ViewSpace.aim_from_ray(Vector3(2, 10, 3), Vector3.DOWN, AIM_HEIGHT, FALLBACK)
	assert_almost_eq(aim.x, 64.0, 0.001, "x")
	assert_almost_eq(aim.y, 96.0 - AIM_HEIGHT, 0.001, "y는 몸 높이만큼 위쪽")


func test_slanted_ray_stops_at_aim_height_not_ground() -> void:
	var target: Vector3 = ViewSpace.aim_to_3d(Vector2(100, 50), AIM_HEIGHT)
	var direction: Vector3 = Vector3(0.3, -1.0, -0.5).normalized()
	var aim: Vector2 = ViewSpace.aim_from_ray(target - direction * 20.0, direction, AIM_HEIGHT, FALLBACK)
	assert_almost_eq(aim.x, 100.0, 0.001, "x")
	assert_almost_eq(aim.y, 50.0, 0.001, "y")


func test_screen_offset_of_feet_is_zero() -> void:
	var offset: Vector2 = ViewSpace.screen_offset(Vector2(100, 50), Vector2(100, 50), 0.0, 70.0, 45.0, 30.0, 360.0)
	assert_almost_eq(offset.length(), 0.0, 0.001, "발밑은 화면 가운데")


func test_screen_offset_one_tile_east_is_one_tile_on_screen() -> void:
	var offset: Vector2 = ViewSpace.screen_offset(Vector2.ZERO, Vector2(32, 0), 0.0, 60.0, 0.0, 30.0, 360.0)
	assert_almost_eq(offset.x, 32.0, 0.5, "발밑 평면에서 1픽셀 = 화면 1픽셀")
	assert_almost_eq(offset.y, 0.0, 0.5, "세로로는 안 움직임")


func test_screen_offset_north_goes_up_and_height_goes_up() -> void:
	var north: Vector2 = ViewSpace.screen_offset(Vector2.ZERO, Vector2(0, -64), 0.0, 60.0, 0.0, 30.0, 360.0)
	var raised: Vector2 = ViewSpace.screen_offset(Vector2.ZERO, Vector2.ZERO, 32.0, 60.0, 0.0, 30.0, 360.0)
	assert_true(north.y < 0.0, "북쪽은 화면 위")
	assert_true(raised.y < 0.0, "높은 점은 화면 위")


func test_ray_along_plane_uses_fallback() -> void:
	assert_eq(ViewSpace.aim_from_ray(Vector3(0, 5, 0), Vector3.RIGHT, AIM_HEIGHT, FALLBACK), FALLBACK, "평면과 나란한 광선")
