extends TestCase
## UndeadRules(체력 회복 뼈 계산) 단위 테스트.

const MAX_HEALTH: float = 4.0
const BONE_COST: int = 5


func test_full_health_needs_no_bones() -> void:
	assert_eq(UndeadRules.heal_bone_cost(MAX_HEALTH, MAX_HEALTH, BONE_COST), 0, "가득 차 있으면 0")


func test_half_health_rounds_up() -> void:
	# 5 × (2 / 4) = 2.5 → 3
	assert_eq(UndeadRules.heal_bone_cost(2.0, MAX_HEALTH, BONE_COST), 3, "절반이면 2.5를 올림해서 3")


func test_zero_health_equals_first_cost() -> void:
	assert_eq(UndeadRules.heal_bone_cost(0.0, MAX_HEALTH, BONE_COST), BONE_COST, "체력 0이면 처음 소환 비용과 같다")


func test_exact_ratio_is_not_rounded_up_by_float_error() -> void:
	# 4 × (1 - 0.6/... ) 같은 값이 2.0000001이 되어 3으로 올라가지 않아야 한다.
	assert_eq(UndeadRules.heal_bone_cost(3.0, 4.0, 4), 1, "4 × (1/4) = 1")
	assert_eq(UndeadRules.heal_bone_cost(0.1 + 0.2, 0.3 * 10.0, 10), 9, "10 × (2.7/3) = 9")


func test_enough_bones_fill_exactly_to_max() -> void:
	assert_eq(UndeadRules.health_after_heal(2.0, MAX_HEALTH, BONE_COST, 3), MAX_HEALTH, "필요한 만큼 쓰면 최대 체력")
	assert_eq(UndeadRules.health_after_heal(2.0, MAX_HEALTH, BONE_COST, 10), MAX_HEALTH, "많아도 최대를 넘지 않는다")


func test_not_enough_bones_heal_partially() -> void:
	# 뼈 하나당 4 / 5 = 0.8
	assert_almost_eq(UndeadRules.health_per_bone(MAX_HEALTH, BONE_COST), 0.8, 0.0001)
	assert_almost_eq(UndeadRules.health_after_heal(0.0, MAX_HEALTH, BONE_COST, 2), 1.6, 0.0001, "뼈 2개면 1.6만큼")


func test_zero_bone_cost_heals_fully_for_free() -> void:
	assert_eq(UndeadRules.heal_bone_cost(0.0, MAX_HEALTH, 0), 0)
	assert_eq(UndeadRules.health_after_heal(0.0, MAX_HEALTH, 0, 0), MAX_HEALTH)


func test_stored_bones_is_health_in_bones_rounded_down() -> void:
	assert_eq(UndeadRules.stored_bones(4.0, 4.0, 4), 4, "가득 차면 처음 소환 비용만큼")
	assert_eq(UndeadRules.stored_bones(2.5, 4.0, 4), 2, "소수는 버림")
	assert_eq(UndeadRules.stored_bones(0.9, 4.0, 4), 0, "뼈 하나에 못 미치면 0")
	assert_eq(UndeadRules.stored_bones(0.0, 4.0, 4), 0, "체력 0이면 0")
	assert_eq(UndeadRules.stored_bones(6.8, 6.8, 5), 5, "뼈 하나당 체력이 소수여도 가득이면 비용만큼")
	assert_eq(UndeadRules.stored_bones(1.99999, 4.0, 4), 2, "정수에 살짝 못 미치는 값은 맞춘 뒤 버림")
	assert_eq(UndeadRules.stored_bones(4.0, 4.0, 0), 0, "처음 소환 비용이 0이면 돌려받을 뼈 없음")
