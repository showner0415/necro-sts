extends TestCase
## 카메라가 조준 방향으로 앞서 가는 양 (AimLead)

const CENTER: Vector2 = Vector2(320, 180)

var lead: AimLead


func before_each() -> void:
	lead = AimLead.new()
	lead.ratio = 0.3
	lead.max_distance = 1000.0
	lead.dead_zone = 0.0
	lead.follow_speed = 6.0
	lead.strength = 1.0


func test_moves_by_ratio_of_player_to_mouse_distance() -> void:
	var offset: Vector2 = lead.target_offset(CENTER + Vector2(200, 0), CENTER)
	# 플레이어는 화면 가운데에서 offset만큼 반대로 밀려난다.
	var player_to_mouse: float = 200.0 + offset.x
	assert_almost_eq(offset.x, player_to_mouse * 0.3, 0.001, "플레이어-마우스 거리의 30%")
	assert_eq(offset.y, 0.0, "세로로는 움직이지 않음")


func test_inside_dead_zone_does_not_move() -> void:
	lead.dead_zone = 32.0
	assert_eq(lead.target_offset(CENTER + Vector2(20, -20), CENTER), Vector2.ZERO, "구역 안")
	assert_eq(lead.target_offset(CENTER, CENTER), Vector2.ZERO, "가운데")


func test_dead_zone_edge_does_not_jump() -> void:
	lead.dead_zone = 32.0
	var just_outside: Vector2 = lead.target_offset(CENTER + Vector2(32.5, 0), CENTER)
	assert_true(just_outside.length() < 1.0, "경계 바로 밖에서 튀지 않음: %s" % just_outside)


func test_limited_by_max_distance() -> void:
	lead.max_distance = 90.0
	assert_almost_eq(lead.target_offset(CENTER + Vector2(5000, 3000), CENTER).length(), 90.0, 0.001, "최대 거리")


func test_strength_zero_turns_it_off() -> void:
	lead.strength = 0.0
	assert_eq(lead.target_offset(CENTER + Vector2(300, 100), CENTER), Vector2.ZERO, "세기 0")


func test_strength_scales_the_offset() -> void:
	var full: Vector2 = lead.target_offset(CENTER + Vector2(100, 0), CENTER)
	lead.strength = 0.5
	assert_almost_eq(lead.target_offset(CENTER + Vector2(100, 0), CENTER).x, full.x * 0.5, 0.001, "세기 절반")


func test_depends_only_on_the_mouse() -> void:
	var first: Vector2 = lead.target_offset(CENTER + Vector2(120, 40), CENTER)
	var second: Vector2 = lead.target_offset(CENTER + Vector2(120, 40), CENTER)
	assert_eq(first, second, "같은 마우스 위치면 같은 값")


func test_follow_reaches_target_without_overshoot() -> void:
	var current: Vector2 = Vector2.ZERO
	var target: Vector2 = Vector2(100, 0)
	for i: int in 600:
		current = lead.follow(current, target, 1.0 / 60.0)
		assert_true(current.x <= target.x + 0.001, "넘어가지 않음")
	assert_almost_eq(current.x, 100.0, 0.01, "목표에 닿음")


func test_follow_is_independent_of_frame_rate() -> void:
	var at_60: Vector2 = Vector2.ZERO
	for i: int in 60:
		at_60 = lead.follow(at_60, Vector2(100, 0), 1.0 / 60.0)
	var at_30: Vector2 = Vector2.ZERO
	for i: int in 30:
		at_30 = lead.follow(at_30, Vector2(100, 0), 1.0 / 30.0)
	assert_almost_eq(at_60.x, at_30.x, 0.01, "60프레임과 30프레임이 같음")
