extends TestCase
## ManaPool(마나 계산 규칙) 단위 테스트.

const MAX_MANA: float = 10.0
const REGEN: float = 2.0

var pool: ManaPool


func before_each() -> void:
	pool = ManaPool.new(MAX_MANA, REGEN)


func test_starts_full() -> void:
	assert_eq(pool.current, MAX_MANA, "처음에는 가득 차 있다")
	assert_eq(pool.maximum, MAX_MANA)


func test_regenerate_adds_rate_times_seconds() -> void:
	pool.try_spend(6.0)
	pool.regenerate(0.5)
	assert_almost_eq(pool.current, 5.0, 0.0001, "4 + 초당 2 × 0.5초")


func test_regenerate_stops_at_maximum() -> void:
	pool.try_spend(1.0)
	pool.regenerate(10.0)
	assert_eq(pool.current, MAX_MANA, "최대치를 넘지 않는다")


func test_spend_reduces_mana() -> void:
	assert_true(pool.try_spend(3.0), "충분하면 성공")
	assert_eq(pool.current, 7.0)


func test_spend_exact_remaining_amount() -> void:
	assert_true(pool.try_spend(MAX_MANA), "남은 양과 같으면 성공")
	assert_eq(pool.current, 0.0)


func test_spend_fails_when_not_enough_and_keeps_mana() -> void:
	pool.try_spend(8.0)
	assert_false(pool.try_spend(3.0), "2밖에 없으면 3은 실패")
	assert_eq(pool.current, 2.0, "실패하면 마나가 줄지 않는다")


func test_zero_cost_always_succeeds() -> void:
	pool.try_spend(MAX_MANA)
	assert_true(pool.try_spend(0.0), "마나 0이어도 비용 0은 성공")
	assert_eq(pool.current, 0.0)


func test_changed_signal_reports_new_values() -> void:
	var reports: Array = []
	pool.changed.connect(func(current: float, maximum: float) -> void: reports.append([current, maximum]))
	pool.try_spend(4.0)
	pool.regenerate(1.0)
	assert_eq(reports, [[6.0, MAX_MANA], [8.0, MAX_MANA]], "소모와 회복마다 한 번씩")


func test_no_signal_when_nothing_changes() -> void:
	var count: Array[int] = [0]
	pool.changed.connect(func(_current: float, _maximum: float) -> void: count[0] += 1)
	pool.regenerate(1.0)
	pool.try_spend(0.0)
	pool.try_spend(MAX_MANA + 1.0)
	assert_eq(count[0], 0, "가득 찬 상태의 회복, 비용 0, 실패한 소모는 알리지 않는다")


func test_drain_stops_at_zero() -> void:
	pool.drain(3.0)
	assert_eq(pool.current, MAX_MANA - 3.0)
	pool.drain(100.0)
	assert_eq(pool.current, 0.0, "0 밑으로 내려가지 않는다")
	assert_true(pool.is_empty())
