extends TestCase
## PackAlarm(무리 경보: 평소 → 신호 → 경보 → 포기하면 평소) 단위 테스트.

const SIGNAL_TIME: float = 0.3

var alarm: PackAlarm
var member: RefCounted
var other_member: RefCounted


func before_each() -> void:
	alarm = PackAlarm.new()
	member = RefCounted.new()
	other_member = RefCounted.new()


func test_starts_calm() -> void:
	assert_eq(alarm.state, PackAlarm.State.CALM)
	assert_false(alarm.is_alert())


func test_trigger_signals_then_alerts() -> void:
	alarm.trigger(member, SIGNAL_TIME)
	assert_eq(alarm.state, PackAlarm.State.SIGNAL, "맞거나 감지하면 먼저 신호")
	assert_true(alarm.is_signalling(member), "계기가 된 무리원이 신호를 낸다")
	assert_false(alarm.is_signalling(other_member), "다른 무리원은 신호를 내지 않는다")
	assert_false(alarm.update(SIGNAL_TIME - 0.05), "신호 시간 전에는 아직 경보가 아니다")
	assert_true(alarm.update(0.1), "신호 시간이 지나면 경보가 된다 (이번에 됐다고 알린다)")
	assert_true(alarm.is_alert())
	assert_false(alarm.is_signalling(member), "경보가 되면 신호를 그만둔다")
	assert_false(alarm.update(1.0), "이미 경보면 다시 알리지 않는다")


func test_zero_signal_time_alerts_at_once() -> void:
	alarm.trigger(member, 0.0)
	assert_true(alarm.is_alert(), "신호 시간이 0이면 바로 경보")


func test_trigger_during_signal_does_not_restart_it() -> void:
	alarm.trigger(member, SIGNAL_TIME)
	alarm.update(0.2)
	alarm.trigger(other_member, SIGNAL_TIME)
	assert_true(alarm.is_signalling(member), "신호 중에 다른 계기가 생겨도 처음 무리원이 계속 신호")
	assert_true(alarm.update(0.15), "신호를 처음부터 다시 재지 않는다")


func test_trigger_while_alert_changes_nothing() -> void:
	alarm.trigger(member, 0.0)
	alarm.trigger(other_member, SIGNAL_TIME)
	assert_true(alarm.is_alert(), "경보 중에 다시 맞거나 감지해도 경보 그대로")
	assert_false(alarm.is_signalling(other_member))


func test_end_signal_goes_alert() -> void:
	alarm.trigger(member, SIGNAL_TIME)
	alarm.end_signal()
	assert_true(alarm.is_alert(), "신호를 내던 무리원이 죽으면 바로 경보")


func test_give_up_goes_calm() -> void:
	alarm.trigger(member, 0.0)
	alarm.give_up()
	assert_eq(alarm.state, PackAlarm.State.CALM, "포기하면 평소")
	alarm.trigger(other_member, SIGNAL_TIME)
	assert_true(alarm.is_signalling(other_member), "포기한 뒤 다시 맞거나 감지하면 다시 신호")
