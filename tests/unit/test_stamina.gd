extends TestCase
## 스태미나(Stamina) 규칙 단위 테스트: 소모·회복, 뛰는 중 회복 안 됨, 부족하면 뛰기·구르기 불가.

const MAX: float = 100.0
const REGEN: float = 30.0
const RUN_COST: float = 25.0
const ROLL_COST: float = 25.0

var stamina: Stamina


func before_each() -> void:
	stamina = Stamina.new(MAX, REGEN, RUN_COST, ROLL_COST)


func test_starts_full() -> void:
	assert_eq(stamina.current, MAX)
	assert_true(stamina.is_full())


# --- 소모 ---

func test_running_drains_per_second() -> void:
	stamina.process(1.0, true, false)
	assert_almost_eq(stamina.current, MAX - RUN_COST, 0.0001, "1초 뛰면 초당 소모량만큼")
	stamina.process(0.5, true, false)
	assert_almost_eq(stamina.current, MAX - RUN_COST * 1.5, 0.0001)


func test_roll_spends_cost_at_once() -> void:
	assert_true(stamina.try_roll())
	assert_almost_eq(stamina.current, MAX - ROLL_COST, 0.0001)


func test_running_stops_at_zero() -> void:
	stamina.process(100.0, true, false)
	assert_eq(stamina.current, 0.0, "0 밑으로 내려가지 않는다")


# --- 회복 ---

func test_regenerates_when_idle() -> void:
	stamina.process(2.0, true, false)
	var before: float = stamina.current
	stamina.process(1.0, false, false)
	assert_almost_eq(stamina.current, before + REGEN, 0.0001, "끝나면 초당 회복량만큼 찬다")


func test_regen_stops_at_maximum() -> void:
	stamina.try_roll()
	stamina.process(100.0, false, false)
	assert_eq(stamina.current, MAX)


func test_no_regen_while_running() -> void:
	stamina.process(1.0, true, false)
	var before: float = stamina.current
	stamina.process(1.0, true, false)
	assert_true(stamina.current < before, "뛰는 동안은 계속 줄기만 한다")
	assert_almost_eq(stamina.current, before - RUN_COST, 0.0001, "회복이 섞이지 않는다")


func test_no_regen_while_rolling() -> void:
	stamina.try_roll()
	var before: float = stamina.current
	stamina.process(0.3, false, true)
	assert_eq(stamina.current, before, "구르는 동안은 회복되지 않는다")


# --- 부족할 때 ---

func test_cannot_roll_without_enough_stamina() -> void:
	stamina.process((MAX - ROLL_COST + 1.0) / RUN_COST, true, false)
	assert_true(stamina.current < ROLL_COST)
	var before: float = stamina.current
	assert_false(stamina.can_roll())
	assert_false(stamina.try_roll(), "구르기 비용보다 적으면 못 구른다")
	assert_eq(stamina.current, before, "못 구르면 스태미나도 그대로")


func test_can_roll_with_exact_cost() -> void:
	stamina.process((MAX - ROLL_COST) / RUN_COST, true, false)
	stamina.release_run()
	assert_almost_eq(stamina.current, ROLL_COST, 0.0001)
	assert_true(stamina.try_roll(), "딱 비용만큼 있으면 구를 수 있다")


func test_cannot_run_at_zero() -> void:
	stamina.process(100.0, true, false)
	assert_false(stamina.can_run(), "0이면 뛸 수 없다")


func test_exhausted_until_run_released() -> void:
	stamina.process(100.0, true, false)
	stamina.process(0.5, false, false)
	assert_true(stamina.current > 0.0, "조금 회복됐다")
	assert_false(stamina.can_run(), "뛰기 키를 떼기 전에는 여전히 못 뛴다 (지침)")
	stamina.release_run()
	assert_true(stamina.can_run(), "떼었다 누르면 다시 뛸 수 있다")


func test_changed_signal() -> void:
	var values: Array[float] = []
	stamina.changed.connect(func(current: float, _maximum: float) -> void: values.append(current))
	stamina.try_roll()
	stamina.process(1.0, false, false)
	stamina.process(1.0, false, false)
	assert_eq(values, [MAX - ROLL_COST, MAX] as Array[float], "가득 차면 더 알리지 않는다")
