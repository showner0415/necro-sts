extends TestCase
## EscapeTimer(탈출 게이지) 단위 테스트.

const DURATION: float = 3.0


func test_fills_while_inside_and_escapes_after_duration() -> void:
	var timer: EscapeTimer = EscapeTimer.new(DURATION)
	assert_false(timer.update(1.5, true))
	assert_almost_eq(timer.get_progress(), 0.5, 0.0001, "1.5초면 절반")
	assert_false(timer.update(1.4, true), "2.9초는 아직")
	assert_true(timer.update(0.1, true), "3초가 되면 탈출")
	assert_eq(timer.get_progress(), 1.0)
	assert_true(timer.is_done())


func test_leaving_resets_to_zero() -> void:
	var timer: EscapeTimer = EscapeTimer.new(DURATION)
	timer.update(2.5, true)
	timer.update(0.016, false)
	assert_eq(timer.get_progress(), 0.0, "벗어나면 처음으로")
	assert_false(timer.update(2.5, true), "다시 처음부터 3초가 필요하다")


func test_escapes_only_once() -> void:
	var timer: EscapeTimer = EscapeTimer.new(DURATION)
	assert_true(timer.update(5.0, true))
	assert_false(timer.update(1.0, true), "이미 탈출했으면 다시 알리지 않는다")
	assert_false(timer.update(1.0, false))
	assert_eq(timer.get_progress(), 1.0, "탈출한 뒤에는 벗어나도 그대로")


func test_starts_empty() -> void:
	assert_eq(EscapeTimer.new(DURATION).get_progress(), 0.0)


func test_design_duration_is_three_seconds() -> void:
	var scene: PackedScene = load("res://regions/escape_point.tscn")
	var point: Node = scene.instantiate()
	assert_eq(point.get("duration"), 3.0, "설계: 탈출 지점에 3초")
	point.free()
