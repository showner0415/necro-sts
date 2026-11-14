extends TestCase
## ChaseClock(종별 추격 포기 조건을 재는 시계) 단위 테스트.

const DISTANCE_LIMIT: float = 350.0
const LOST_TIME: float = 5.0
const CHASE_TIME: float = 6.0

var clock: ChaseClock


func before_each() -> void:
	clock = ChaseClock.new()


func test_distance_limit() -> void:
	assert_false(clock.gives_up(DISTANCE_LIMIT - 1.0, DISTANCE_LIMIT, LOST_TIME, 0.0), "한계 안이면 계속 쫓는다")
	assert_true(clock.gives_up(DISTANCE_LIMIT + 1.0, DISTANCE_LIMIT, LOST_TIME, 0.0), "대상과 한계보다 멀어지면 포기")


func test_unseen_time_counts_only_while_hidden() -> void:
	clock.update(LOST_TIME - 0.1, false, false)
	assert_false(clock.gives_up(0.0, DISTANCE_LIMIT, LOST_TIME, 0.0), "못 본 시간이 한계 안이면 계속 쫓는다")
	clock.update(0.2, false, false)
	assert_true(clock.gives_up(0.0, DISTANCE_LIMIT, LOST_TIME, 0.0), "못 본 지 5초가 넘으면 포기")


func test_seeing_again_restarts_unseen_time() -> void:
	clock.update(LOST_TIME - 0.5, false, false)
	clock.update(0.1, true, false)
	assert_eq(clock.unseen_elapsed, 0.0, "다시 보면 처음부터 잰다")
	clock.update(LOST_TIME - 0.5, false, false)
	assert_false(clock.gives_up(0.0, DISTANCE_LIMIT, LOST_TIME, 0.0))


func test_chase_time_counts_while_not_detected() -> void:
	# 멧돼지: 보이지만 감지 범위 밖인 대상을 쫓는다.
	clock.update(CHASE_TIME - 0.1, true, false)
	assert_false(clock.gives_up(200.0, 0.0, 3.0, CHASE_TIME), "추격 6초 전에는 계속 쫓는다")
	clock.update(0.2, true, false)
	assert_true(clock.gives_up(200.0, 0.0, 3.0, CHASE_TIME), "감지 범위 밖의 대상을 6초 넘게 쫓으면 포기")


func test_chase_time_restarts_when_detected() -> void:
	clock.update(CHASE_TIME - 0.5, true, false)
	clock.update(0.1, true, true)
	assert_eq(clock.chase_elapsed, 0.0, "감지 범위 안에서 보이면(싸우는 중) 처음부터 잰다")
	clock.update(100.0, true, true)
	assert_false(clock.gives_up(50.0, 0.0, 3.0, CHASE_TIME), "싸우는 동안은 시간이 흘러도 포기하지 않는다")


func test_chase_time_restarts_when_hit() -> void:
	clock.update(CHASE_TIME - 0.5, true, false)
	clock.on_hit()
	clock.update(CHASE_TIME - 0.5, true, false)
	assert_false(clock.gives_up(200.0, 0.0, 3.0, CHASE_TIME), "맞으면 추격 시간을 처음부터 다시 잰다")


func test_hit_does_not_restart_unseen_time() -> void:
	clock.update(2.0, false, false)
	clock.on_hit()
	assert_eq(clock.unseen_elapsed, 2.0, "맞아도 못 본 시간은 그대로다")


func test_zero_turns_condition_off() -> void:
	clock.update(1000.0, false, false)
	assert_false(clock.gives_up(100000.0, 0.0, 0.0, 0.0), "값이 0인 조건은 쓰지 않는다")


func test_reset_starts_over() -> void:
	clock.update(10.0, false, false)
	clock.reset()
	assert_eq(clock.unseen_elapsed, 0.0)
	assert_eq(clock.chase_elapsed, 0.0)
