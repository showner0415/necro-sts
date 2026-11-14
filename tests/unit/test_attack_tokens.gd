extends TestCase
## AttackTokens(대상마다·종마다 공격권, 추가 공격권, 반납) 단위 테스트.

const RAT: StringName = &"rat"
const BOAR: StringName = &"boar"
const EXTRA_INTERVAL: float = 1.0
const HOLD_LIMIT: float = 6.0
const RETRY_BLOCK: float = 1.0

var tokens: AttackTokens
var target: RefCounted
var other_target: RefCounted
var rats: Array[RefCounted] = []


func before_each() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	tokens = AttackTokens.new(EXTRA_INTERVAL, HOLD_LIMIT, rng, RETRY_BLOCK)
	target = RefCounted.new()
	other_target = RefCounted.new()
	rats.clear()
	for i: int in 4:
		rats.append(RefCounted.new())


func test_limit_per_target_and_kind() -> void:
	assert_true(tokens.request(rats[0], target, RAT, 2), "첫 번째는 공격권을 받는다")
	assert_true(tokens.request(rats[1], target, RAT, 2), "두 번째도 받는다 (쥐 2)")
	assert_false(tokens.request(rats[2], target, RAT, 2), "세 번째는 기다린다")
	assert_true(tokens.request(rats[0], target, RAT, 2), "이미 든 몸은 계속 true")
	assert_eq(tokens.count_normal(target, RAT), 2)


func test_kinds_count_separately() -> void:
	tokens.request(rats[0], target, RAT, 1)
	assert_true(tokens.request(rats[1], target, BOAR, 1), "종이 다르면 따로 센다")
	assert_false(tokens.request(rats[2], target, RAT, 1), "같은 종은 한도 안에서만")


func test_targets_count_separately() -> void:
	tokens.request(rats[0], target, RAT, 1)
	assert_true(tokens.request(rats[1], other_target, RAT, 1), "대상이 다르면 따로 센다")


func test_finish_attack_frees_slot() -> void:
	tokens.request(rats[0], target, RAT, 1)
	assert_false(tokens.request(rats[1], target, RAT, 1))
	tokens.finish_attack(rats[0])
	assert_false(tokens.is_holding(rats[0]), "공격이 끝나면 반납")
	assert_true(tokens.request(rats[1], target, RAT, 1), "반납된 자리를 다른 몸이 받는다")


func test_release_and_switch_target() -> void:
	tokens.request(rats[0], target, RAT, 1)
	assert_true(tokens.request(rats[0], other_target, RAT, 1), "다른 대상을 노리면 그 대상의 공격권을 받는다")
	assert_eq(tokens.held_target(rats[0]), other_target)
	assert_eq(tokens.count_normal(target, RAT), 0, "앞 대상의 공격권은 반납된다")
	tokens.release(rats[0])
	assert_false(tokens.is_holding(rats[0]), "죽음·밀려남 등으로 반납")


func test_hold_time_limit() -> void:
	tokens.request(rats[0], target, RAT, 1)
	tokens.update(HOLD_LIMIT - 0.1)
	assert_true(tokens.is_holding(rats[0]), "시간 제한 전에는 들고 있다")
	tokens.update(0.2)
	assert_false(tokens.is_holding(rats[0]), "시간 제한이 지나면 반납 (묶이는 버그 방지)")


func test_retry_block_after_hold_time_limit() -> void:
	tokens.request(rats[0], target, RAT, 1)
	tokens.update(HOLD_LIMIT + 0.1)
	assert_false(tokens.request(rats[0], target, RAT, 1), "시간 제한으로 반납한 몸은 곧바로 다시 받지 못한다")
	assert_true(tokens.request(rats[1], target, RAT, 1), "그 자리는 다른 몸이 받는다")
	tokens.release(rats[1])
	assert_true(tokens.request(rats[0], other_target, RAT, 1), "다른 대상의 공격권은 받는다")
	tokens.release(rats[0])
	tokens.update(RETRY_BLOCK - 0.2)
	assert_false(tokens.request(rats[0], target, RAT, 1), "막는 시간이 안 지났으면 계속 못 받는다")
	tokens.update(0.3)
	assert_true(tokens.request(rats[0], target, RAT, 1), "막는 시간이 지나면 다시 받는다")


func test_no_retry_block_after_normal_release() -> void:
	tokens.request(rats[0], target, RAT, 1)
	tokens.finish_attack(rats[0])
	tokens.update(0.1)
	assert_true(tokens.request(rats[0], target, RAT, 1), "공격을 끝내 반납했으면 막지 않는다")


func test_extra_token_every_interval_to_a_waiting_member() -> void:
	tokens.request(rats[0], target, RAT, 1)
	tokens.request(rats[1], target, RAT, 1)
	tokens.request(rats[2], target, RAT, 1)
	tokens.update(EXTRA_INTERVAL - 0.1)
	assert_eq(tokens.extra_holder(target), null, "1초가 안 됐으면 추가 공격권이 없다")
	tokens.request(rats[1], target, RAT, 1)
	tokens.request(rats[2], target, RAT, 1)
	tokens.update(0.2)
	var extra: Object = tokens.extra_holder(target)
	assert_true(extra == rats[1] or extra == rats[2], "기다리던 몸 중 하나가 추가 공격권을 받는다")
	assert_true(tokens.holds_extra(extra))
	assert_true(tokens.request(extra, target, RAT, 1), "추가 공격권을 든 몸은 공격해도 된다")
	assert_eq(tokens.extra_granted, 1)


func test_only_one_extra_per_target() -> void:
	tokens.request(rats[0], target, RAT, 1)
	for i: int in 3:
		for rat: RefCounted in rats.slice(1):
			tokens.request(rat, target, RAT, 1)
		tokens.update(EXTRA_INTERVAL)
	var extras: int = rats.filter(func(rat: RefCounted) -> bool: return tokens.holds_extra(rat)).size()
	assert_eq(extras, 1, "추가 공격권은 한 대상에 동시에 하나뿐")
	assert_eq(tokens.extra_granted, 1, "쓰고 반납하기 전에는 더 주지 않는다")


func test_extra_used_once_then_returned() -> void:
	tokens.request(rats[0], target, RAT, 1)
	tokens.request(rats[1], target, RAT, 1)
	tokens.update(EXTRA_INTERVAL)
	assert_true(tokens.holds_extra(rats[1]))
	tokens.finish_attack(rats[1])
	assert_false(tokens.is_holding(rats[1]), "추가 공격권은 공격 한 번에 쓰고 반납")
	assert_false(tokens.request(rats[1], target, RAT, 1), "다시 기다린다")


func test_no_extra_without_waiting() -> void:
	tokens.request(rats[0], target, RAT, 2)
	tokens.update(EXTRA_INTERVAL * 3.0)
	assert_eq(tokens.extra_granted, 0, "기다리는 몸이 없으면 추가 공격권을 주지 않는다")


func test_waiting_list_cleared_each_update() -> void:
	tokens.request(rats[0], target, RAT, 1)
	tokens.request(rats[1], target, RAT, 1)
	tokens.update(0.1)
	tokens.update(EXTRA_INTERVAL)
	assert_eq(tokens.extra_holder(target), null, "그 프레임에 다시 묻지 않은 몸은 기다리는 것이 아니다")


func test_holders_of_lists_normal_and_extra() -> void:
	tokens.request(rats[0], target, RAT, 1)
	tokens.request(rats[1], target, RAT, 1)
	tokens.update(EXTRA_INTERVAL)
	var holders: Array = tokens.holders_of(target)
	assert_eq(holders.size(), 2, "보통 공격권 하나와 추가 공격권 하나")
	assert_true(holders.has(rats[0]) and holders.has(rats[1]))
	assert_true(tokens.holders_of(other_target).is_empty())
