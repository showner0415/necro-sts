extends TestCase
## Aggro(감지 범위 밖에서 맞으면 공격자를 쫓는 규칙) 단위 테스트. 위치만으로 확인한다.

const ATTACKER_LIMIT: float = 250.0
const HOME_LIMIT: float = 150.0
const ARRIVE: float = 4.0
const START: Vector2 = Vector2(100, 0)

var aggro: Aggro
var attacker: RefCounted
var other: RefCounted


func before_each() -> void:
	aggro = Aggro.new(ATTACKER_LIMIT, HOME_LIMIT, ARRIVE)
	attacker = RefCounted.new()
	other = RefCounted.new()


func test_hit_with_no_one_in_detect_chases_attacker() -> void:
	aggro.on_hit(attacker, START, false)
	assert_eq(aggro.state, Aggro.State.CHASING)
	assert_eq(aggro.attacker, attacker)
	assert_eq(aggro.origin, START, "맞기 시작한 자리를 기억한다")


func test_hit_with_someone_in_detect_keeps_nearest_rule() -> void:
	aggro.on_hit(attacker, START, true)
	assert_eq(aggro.state, Aggro.State.IDLE, "감지 범위에 누가 있으면 가장 가까운 대상 규칙 그대로")


func test_someone_entering_detect_switches_to_nearest() -> void:
	aggro.on_hit(attacker, START, false)
	aggro.update(START + Vector2(-30, 0), true, true, Vector2.ZERO)
	assert_eq(aggro.state, Aggro.State.IDLE, "쫓다가 감지 범위에 누가 들어오면 가장 가까운 대상")
	assert_eq(aggro.attacker, null)


func test_gives_up_when_attacker_too_far() -> void:
	aggro.on_hit(attacker, START, false)
	aggro.update(START, false, true, START + Vector2(ATTACKER_LIMIT - 1.0, 0))
	assert_eq(aggro.state, Aggro.State.CHASING, "한계 안이면 계속 쫓는다")
	aggro.update(START, false, true, START + Vector2(ATTACKER_LIMIT + 1.0, 0))
	assert_eq(aggro.state, Aggro.State.RETURNING, "공격자와 250 넘으면 포기")


func test_gives_up_when_too_far_from_origin() -> void:
	aggro.on_hit(attacker, START, false)
	var here: Vector2 = START + Vector2(-(HOME_LIMIT + 1.0), 0)
	aggro.update(here, false, true, here + Vector2(-50, 0))
	assert_eq(aggro.state, Aggro.State.RETURNING, "공격자가 가까워도 맞기 시작한 자리에서 150 넘으면 포기")


func test_gives_up_when_attacker_gone() -> void:
	aggro.on_hit(attacker, START, false)
	aggro.update(START, false, false, Vector2.ZERO)
	assert_eq(aggro.state, Aggro.State.RETURNING)


func test_returning_ignores_hits_and_detect_until_home() -> void:
	aggro.on_hit(attacker, START, false)
	aggro.update(START + Vector2(-HOME_LIMIT - 10.0, 0), false, true, Vector2.ZERO)
	aggro.on_hit(other, START + Vector2(-100, 0), false)
	assert_eq(aggro.state, Aggro.State.RETURNING, "돌아가는 중에 맞아도 무시")
	aggro.update(START + Vector2(-50, 0), true, true, Vector2.ZERO)
	assert_eq(aggro.state, Aggro.State.RETURNING, "돌아가는 중에 감지 범위에 들어와도 무시")
	aggro.update(START + Vector2(ARRIVE - 1.0, 0), false, false, Vector2.ZERO)
	assert_eq(aggro.state, Aggro.State.IDLE, "다 돌아오면 평소로")


func test_hit_again_while_chasing_keeps_origin() -> void:
	aggro.on_hit(attacker, START, false)
	aggro.on_hit(other, START + Vector2(-40, 0), false)
	assert_eq(aggro.attacker, other, "새 공격자를 쫓는다")
	assert_eq(aggro.origin, START, "맞기 시작한 자리는 처음 맞은 곳 그대로")


func test_start_return_goes_home_and_ignores_hits() -> void:
	aggro.on_hit(attacker, START, false)
	var home: Vector2 = Vector2(-50, 20)
	aggro.start_return(home)
	assert_eq(aggro.state, Aggro.State.RETURNING, "무리가 포기하면 돌아간다")
	assert_eq(aggro.origin, home, "무리 싸움을 시작한 자리로")
	assert_eq(aggro.attacker, null)
	aggro.on_hit(other, home + Vector2(30, 0), false)
	assert_eq(aggro.state, Aggro.State.RETURNING, "돌아가는 중에는 맞아도 대상을 바꾸지 않는다")
	aggro.update(home + Vector2(1, 0), false, false, Vector2.ZERO)
	assert_eq(aggro.state, Aggro.State.IDLE, "다 돌아오면 평소로")


func test_start_chase_follows_lost_target_from_first_seen_spot() -> void:
	var first_seen: Vector2 = Vector2(-20, 0)
	aggro.start_chase(attacker, first_seen)
	assert_eq(aggro.state, Aggro.State.CHASING, "보던 대상을 놓치면 쫓는다")
	assert_eq(aggro.attacker, attacker)
	assert_eq(aggro.origin, first_seen, "쫓는 한계의 시작 자리는 처음 대상을 본 자리")
	aggro.update(first_seen + Vector2(aggro.home_limit + 1.0, 0), false, true, first_seen)
	assert_eq(aggro.state, Aggro.State.RETURNING, "시작 자리에서 너무 멀어지면 포기하고 돌아간다")


func test_start_chase_only_when_idle() -> void:
	aggro.on_hit(attacker, START, false)
	aggro.start_chase(other, START + Vector2(30, 0))
	assert_eq(aggro.attacker, attacker, "이미 쫓는 중이면 바꾸지 않는다")
	assert_eq(aggro.origin, START)
	aggro.start_return(START)
	aggro.start_chase(other, START)
	assert_eq(aggro.state, Aggro.State.RETURNING, "돌아가는 중에는 쫓지 않는다")
