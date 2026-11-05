extends TestCase
## Knockback(밀쳐내기 규칙) 단위 테스트.

const DT: float = 1.0 / 60.0


func test_moves_offset_over_duration() -> void:
	var knockback: Knockback = Knockback.new()
	knockback.start(Vector2(24, 0), 0.15)
	var moved: Vector2 = Vector2.ZERO
	var frames: int = 0
	while knockback.is_active() and frames < 100:
		moved += knockback.get_velocity() * DT
		knockback.update(DT)
		frames += 1
	assert_almost_eq(moved.x, 24.0, 0.5, "밀려난 거리")
	assert_eq(frames, 9, "0.15초 = 9프레임")
	assert_eq(knockback.get_velocity(), Vector2.ZERO, "끝나면 멈춘다")


func test_not_active_by_default_and_ignores_zero() -> void:
	var knockback: Knockback = Knockback.new()
	assert_false(knockback.is_active())
	knockback.start(Vector2.ZERO, 0.15)
	assert_false(knockback.is_active(), "밀 거리가 0이면 시작하지 않는다")
	knockback.start(Vector2(10, 0), 0.0)
	assert_false(knockback.is_active(), "시간이 0이면 시작하지 않는다")


func test_new_knockback_replaces_old() -> void:
	var knockback: Knockback = Knockback.new()
	knockback.start(Vector2(24, 0), 0.15)
	knockback.update(0.1)
	knockback.start(Vector2(0, 30), 0.3)
	assert_almost_eq(knockback.get_velocity().x, 0.0, 0.001, "새로 맞으면 새 방향")
	assert_almost_eq(knockback.get_velocity().y, 100.0, 0.001, "새로 맞으면 새 속도 (30px / 0.3초)")
	knockback.update(0.2)
	assert_true(knockback.is_active(), "새 시간만큼 이어진다")
