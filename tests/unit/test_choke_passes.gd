extends TestCase
## ChokePasses(대상마다·종마다 길목 통행 자리, 반납, 시간 제한과 멈춤) 단위 테스트. 봇 측정 5b.

const RAT: StringName = &"rat"
const BOAR: StringName = &"boar"
const HOLD_LIMIT: float = 6.0

var passes: ChokePasses
var target: RefCounted
var other_target: RefCounted
var rats: Array[RefCounted] = []


func before_each() -> void:
	passes = ChokePasses.new(HOLD_LIMIT)
	target = RefCounted.new()
	other_target = RefCounted.new()
	rats.clear()
	for i: int in 4:
		rats.append(RefCounted.new())


func test_limit_per_target_and_kind() -> void:
	assert_true(passes.request(rats[0], target, RAT, 2), "첫 번째는 통행 자리를 받는다")
	assert_true(passes.request(rats[1], target, RAT, 2), "두 번째도 받는다 (쥐 2)")
	assert_false(passes.request(rats[2], target, RAT, 2), "세 번째는 못 받는다")
	assert_true(passes.request(rats[0], target, RAT, 2), "이미 든 몸은 계속 true")
	assert_eq(passes.count(target, RAT), 2)


func test_kinds_and_targets_count_separately() -> void:
	passes.request(rats[0], target, RAT, 1)
	assert_true(passes.request(rats[1], target, BOAR, 1), "종이 다르면 따로 센다")
	assert_true(passes.request(rats[2], other_target, RAT, 1), "대상이 다르면 따로 센다")
	assert_false(passes.request(rats[3], target, RAT, 1), "같은 대상·같은 종은 한도 안에서만")


func test_zero_limit_never_gives() -> void:
	assert_false(passes.request(rats[0], target, RAT, 0), "자리 수가 0이면 받지 못한다")


func test_release_frees_a_spot() -> void:
	passes.request(rats[0], target, RAT, 1)
	assert_false(passes.request(rats[1], target, RAT, 1))
	passes.release(rats[0])
	assert_false(passes.is_holding(rats[0]), "반납하면 들고 있지 않다")
	assert_true(passes.request(rats[1], target, RAT, 1), "반납한 자리를 다른 몸이 받는다")


func test_requesting_other_target_releases_first() -> void:
	passes.request(rats[0], target, RAT, 1)
	assert_true(passes.request(rats[0], other_target, RAT, 1), "다른 대상의 자리를 받는다")
	assert_eq(passes.held_target(rats[0]), other_target, "든 대상이 바뀐다")
	assert_eq(passes.count(target, RAT), 0, "처음 대상의 자리는 반납했다")


func test_time_limit_releases_without_block() -> void:
	passes.request(rats[0], target, RAT, 1)
	passes.update(HOLD_LIMIT - 0.1)
	assert_true(passes.is_holding(rats[0]), "시간 제한 전에는 든다")
	passes.update(0.2)
	assert_false(passes.is_holding(rats[0]), "시간 제한을 넘으면 반납한다")
	assert_true(passes.request(rats[0], target, RAT, 1), "시간 제한 뒤 막기가 없어 곧 다시 받는다")


func test_pause_hold_stops_the_clock_for_that_frame() -> void:
	passes.request(rats[0], target, RAT, 1)
	for i: int in 10:
		passes.pause_hold(rats[0])
		passes.update(1.0)
	assert_true(passes.is_holding(rats[0]), "멈춘 프레임에는 시간 제한이 흐르지 않는다")
	passes.update(HOLD_LIMIT - 0.5)
	assert_true(passes.is_holding(rats[0]), "멈춘 곳부터 이어서 센다")
	passes.update(1.0)
	assert_false(passes.is_holding(rats[0]), "멈추지 않으면 다시 흘러 반납한다")


func test_no_extra_spot() -> void:
	passes.request(rats[0], target, RAT, 1)
	for i: int in 5:
		assert_false(passes.request(rats[1], target, RAT, 1), "기다려도 추가 자리를 받지 못한다")
		passes.pause_hold(rats[0])
		passes.update(1.0)
	assert_eq(passes.count(target, RAT), 1)
