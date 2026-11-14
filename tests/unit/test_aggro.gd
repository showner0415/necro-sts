extends TestCase
## Aggro(감지 범위 밖에서 맞거나 보던 대상을 놓치면 쫓는 규칙) 단위 테스트. 위치만으로 확인한다.
## 포기 조건의 시계 자체는 test_chase_clock.gd가 본다.

const ATTACKER_LIMIT: float = 350.0
const LOST_TIME: float = 5.0
const CHASE_TIME: float = 6.0
const START: Vector2 = Vector2(100, 0)

var aggro: Aggro
var attacker: RefCounted
var other: RefCounted


func before_each() -> void:
	aggro = Aggro.new(ATTACKER_LIMIT, LOST_TIME)
	attacker = RefCounted.new()
	other = RefCounted.new()


func test_hit_with_no_one_in_detect_chases_attacker() -> void:
	aggro.on_hit(attacker, false)
	assert_eq(aggro.state, Aggro.State.CHASING)
	assert_eq(aggro.attacker, attacker)


func test_hit_with_someone_in_detect_keeps_nearest_rule() -> void:
	aggro.on_hit(attacker, true)
	assert_eq(aggro.state, Aggro.State.IDLE, "감지 범위에 누가 있으면 가장 가까운 대상 규칙 그대로")


func test_someone_entering_detect_switches_to_nearest() -> void:
	aggro.on_hit(attacker, false)
	aggro.update(START + Vector2(-30, 0), true, true, Vector2.ZERO)
	assert_eq(aggro.state, Aggro.State.IDLE, "쫓다가 감지 범위에 누가 들어오면 가장 가까운 대상")
	assert_eq(aggro.attacker, null)


func test_gives_up_when_attacker_too_far() -> void:
	aggro.on_hit(attacker, false)
	aggro.update(START, false, true, START + Vector2(ATTACKER_LIMIT - 1.0, 0))
	assert_eq(aggro.state, Aggro.State.CHASING, "한계 안이면 계속 쫓는다")
	aggro.update(START, false, true, START + Vector2(ATTACKER_LIMIT + 1.0, 0))
	assert_eq(aggro.state, Aggro.State.IDLE, "공격자와 350 넘으면 포기하고 그 자리에서 평소로 (돌아가지 않는다)")
	assert_eq(aggro.attacker, null)


func test_no_limit_from_where_the_chase_started() -> void:
	aggro.on_hit(attacker, false)
	var here: Vector2 = START + Vector2(-2000.0, 0)
	aggro.update(here, false, true, here + Vector2(-50, 0))
	assert_eq(aggro.state, Aggro.State.CHASING, "쫓기 시작한 자리에서 멀어져도 대상이 가깝고 보이면 계속 쫓는다")


func test_gives_up_when_attacker_gone() -> void:
	aggro.on_hit(attacker, false)
	aggro.update(START, false, false, Vector2.ZERO)
	assert_eq(aggro.state, Aggro.State.IDLE)


func test_after_giving_up_hits_and_detect_work_right_away() -> void:
	aggro.on_hit(attacker, false)
	aggro.update(START, false, true, START + Vector2(ATTACKER_LIMIT + 10.0, 0))
	assert_eq(aggro.state, Aggro.State.IDLE)
	aggro.on_hit(other, false)
	assert_eq(aggro.state, Aggro.State.CHASING, "포기한 뒤 다시 맞으면 바로 쫓는다 (돌아가는 동안 무시하던 규칙은 없다)")
	assert_eq(aggro.attacker, other)


func test_hit_again_while_chasing_switches_attacker() -> void:
	aggro.on_hit(attacker, false)
	aggro.on_hit(other, false)
	assert_eq(aggro.attacker, other, "새 공격자를 쫓는다")


func test_give_up_from_outside() -> void:
	aggro.on_hit(attacker, false)
	aggro.give_up()
	assert_eq(aggro.state, Aggro.State.IDLE, "무리가 함께 포기하면 스스로 쫓던 것도 그만둔다")
	assert_eq(aggro.attacker, null)


func test_start_chase_follows_lost_target() -> void:
	aggro.start_chase(attacker)
	assert_eq(aggro.state, Aggro.State.CHASING, "보던 대상을 놓치면 쫓는다")
	assert_eq(aggro.attacker, attacker)


func test_start_chase_only_when_idle() -> void:
	aggro.on_hit(attacker, false)
	aggro.start_chase(other)
	assert_eq(aggro.attacker, attacker, "이미 쫓는 중이면 바꾸지 않는다")


func test_hidden_target_chased_for_lost_time() -> void:
	aggro.start_chase(attacker)
	aggro.update(START, false, true, START + Vector2(50, 0), false, LOST_TIME - 0.1)
	assert_eq(aggro.state, Aggro.State.CHASING, "안 보여도 시간 안이면 쫓는다 (꺾인 길 돌아오기)")
	aggro.update(START, false, true, START + Vector2(50, 0), false, 0.2)
	assert_eq(aggro.state, Aggro.State.IDLE, "못 본 지 5초가 지나면 포기")


func test_seeing_again_resets_lost_time() -> void:
	aggro.start_chase(attacker)
	aggro.update(START, false, true, START + Vector2(50, 0), false, LOST_TIME - 0.5)
	aggro.update(START, false, true, START + Vector2(50, 0), true, 0.1)
	aggro.update(START, false, true, START + Vector2(50, 0), false, LOST_TIME - 0.5)
	assert_eq(aggro.state, Aggro.State.CHASING, "다시 보면 처음부터 잰다")


func test_attacker_limit_applies_even_when_hidden() -> void:
	aggro.start_chase(attacker)
	aggro.update(START, false, true, START + Vector2(ATTACKER_LIMIT + 1.0, 0), false, 0.1)
	assert_eq(aggro.state, Aggro.State.IDLE, "대상과 350 넘으면 보이든 안 보이든 포기 (걸어서 도망칠 수 있게)")


func test_chase_time_limit_gives_up_and_hit_restarts_it() -> void:
	# 멧돼지: 거리 한계 없음, 못 본 지 3초, 추격 6초.
	var boar: Aggro = Aggro.new(0.0, 3.0, CHASE_TIME)
	boar.on_hit(attacker, false)
	boar.update(START, false, true, START + Vector2(1000, 0), true, CHASE_TIME - 0.5)
	assert_eq(boar.state, Aggro.State.CHASING, "거리 한계가 0이면 멀어도 쫓는다")
	boar.on_hit(attacker, false)
	boar.update(START, false, true, START + Vector2(1000, 0), true, CHASE_TIME - 0.5)
	assert_eq(boar.state, Aggro.State.CHASING, "맞으면 추격 시간을 처음부터 다시 잰다")
	boar.update(START, false, true, START + Vector2(1000, 0), true, 1.0)
	assert_eq(boar.state, Aggro.State.IDLE, "감지 범위 밖의 대상을 6초 넘게 쫓으면 포기")


func test_new_chase_starts_clock_over() -> void:
	aggro.start_chase(attacker)
	aggro.update(START, false, true, START + Vector2(50, 0), false, LOST_TIME - 0.5)
	aggro.give_up()
	aggro.start_chase(other)
	aggro.update(START, false, true, START + Vector2(50, 0), false, LOST_TIME - 0.5)
	assert_eq(aggro.state, Aggro.State.CHASING, "새로 쫓기 시작하면 못 본 시간을 처음부터 잰다")
