extends TestCase
## 스태미나(Stamina) 규칙 단위 테스트: 소모·회복, 뛰는 중 회복 안 됨, 부족하면 뛰기·구르기 불가,
## 연속 구르기 비용 증가·초기화, 구른 뒤 회복 지연.

const MAX: float = 100.0
const REGEN: float = 30.0
const RUN_COST: float = 25.0
const ROLL_COSTS: Array[float] = [25.0, 40.0, 60.0]
const ROLL_COST: float = 25.0
const CHAIN_WINDOW: float = 1.0
const REGEN_DELAY: float = 0.6
## 구르는 시간 (네크로맨서의 roll_duration과 같은 값)
const ROLL_DURATION: float = 0.3

var stamina: Stamina


func before_each() -> void:
	stamina = Stamina.new(MAX, REGEN, RUN_COST, ROLL_COSTS.duplicate(), CHAIN_WINDOW, REGEN_DELAY)


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


# --- 연속 구르기 ---

## 구르고, 구르는 시간만큼 굴러서 끝내고, rest초 쉰다.
func _roll_and_rest(rest: float) -> void:
	assert_true(stamina.try_roll(), "구를 수 있어야 한다 (스태미나 %.1f, 비용 %.1f)" % [stamina.current, stamina.get_roll_cost()])
	stamina.process(ROLL_DURATION, false, true)
	if rest > 0.0:
		stamina.process(rest, false, false)


func test_chained_roll_cost_grows() -> void:
	stamina.maximum = 1000.0
	stamina.current = 1000.0
	var spent: Array[float] = []
	for i: int in 4:
		var before: float = stamina.current
		_roll_and_rest(0.5)
		spent.append(before - stamina.current)
	assert_eq(spent, [25.0, 40.0, 60.0, 60.0] as Array[float], "1초 안에 다시 구르면 25 → 40 → 60, 그 뒤로는 마지막 값")


func test_roll_cost_resets_after_window() -> void:
	_roll_and_rest(0.5)
	assert_eq(stamina.get_roll_cost(), 40.0, "0.5초 쉬면 아직 연속")
	_roll_and_rest(CHAIN_WINDOW + 0.1)
	assert_eq(stamina.get_roll_chain(), 0, "1초보다 오래 쉬면 연속이 끊긴다")
	assert_eq(stamina.get_roll_cost(), ROLL_COST, "비용이 처음 값으로 돌아온다")


func test_chain_window_counts_from_roll_end() -> void:
	assert_true(stamina.try_roll())
	stamina.process(CHAIN_WINDOW + 0.5, false, true)
	stamina.process(CHAIN_WINDOW * 0.5, false, false)
	assert_eq(stamina.get_roll_cost(), 40.0, "시작에서 1초가 넘었어도 끝난 뒤 1초 안이면 연속")


func test_chained_cost_blocks_roll() -> void:
	_roll_and_rest(0.0)
	_roll_and_rest(0.0)
	assert_almost_eq(stamina.current, MAX - 25.0 - 40.0, 0.0001)
	assert_false(stamina.can_roll(), "35 남았는데 세 번째 비용은 60이라 못 구른다")
	stamina.process(CHAIN_WINDOW + 0.1, false, false)
	assert_true(stamina.can_roll(), "쉬어서 비용이 25로 돌아오면 다시 구를 수 있다")


# --- 구른 뒤 회복 지연 ---

func test_no_regen_right_after_roll() -> void:
	assert_true(stamina.try_roll())
	stamina.process(ROLL_DURATION, false, true)
	var after_roll: float = stamina.current
	stamina.process(REGEN_DELAY - 0.1, false, false)
	assert_eq(stamina.current, after_roll, "끝나고 0.6초 동안은 회복하지 않는다")
	stamina.process(0.2, false, false)
	assert_almost_eq(stamina.current, after_roll + REGEN * 0.2, 0.0001, "0.6초가 지나면 다시 찬다")


func test_regen_delay_restarts_on_new_roll() -> void:
	_roll_and_rest(REGEN_DELAY + 0.1)
	assert_true(stamina.try_roll())
	stamina.process(ROLL_DURATION, false, true)
	var after_roll: float = stamina.current
	stamina.process(REGEN_DELAY - 0.1, false, false)
	assert_eq(stamina.current, after_roll, "다시 구르면 지연도 처음부터")


func test_no_regen_delay_after_running() -> void:
	stamina.process(1.0, true, false)
	var before: float = stamina.current
	stamina.process(0.1, false, false)
	assert_almost_eq(stamina.current, before + REGEN * 0.1, 0.0001, "뛰기가 끝나면 지연 없이 바로 찬다")
