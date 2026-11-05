extends TestCase
## ApproachBehavior(행동 조각 "다가가기")와 MonsterData의 행동 조각 고르기 단위 테스트.
## 조각은 body.velocity만 정하므로, 트리에 넣지 않은 노드로 확인한다.

const SPEED: float = 40.0
const ATTACK_RANGE: float = 16.0
const DAMAGE: float = 2.0
const COOLDOWN: float = 1.0


## take_damage만 있는 가짜 대상
class FakeTarget:
	extends Node2D
	var received: Array[float] = []

	func take_damage(amount: float) -> void:
		received.append(amount)


var body: CharacterBody2D
var target: FakeTarget
var stats: CombatStats
var behavior: ApproachBehavior


func before_each() -> void:
	body = CharacterBody2D.new()
	target = FakeTarget.new()
	stats = CombatStats.create(SPEED, ATTACK_RANGE, DAMAGE, COOLDOWN)
	behavior = ApproachBehavior.new()


func after_each() -> void:
	body.free()
	target.free()


func test_far_target_is_approached_at_move_speed() -> void:
	target.position = Vector2(100, 0)
	behavior.act(body, stats, target, 0.0)
	assert_eq(body.velocity, Vector2(SPEED, 0), "대상 쪽으로 이동 속도만큼")
	assert_true(target.received.is_empty(), "멀면 때리지 않는다")


func test_target_in_range_stops_and_hits() -> void:
	target.position = Vector2(ATTACK_RANGE - 1.0, 0)
	behavior.act(body, stats, target, 0.0)
	assert_eq(body.velocity, Vector2.ZERO, "공격 거리 안이면 멈춘다")
	assert_eq(target.received, [DAMAGE] as Array[float], "몸으로 부딪혀 피해")


func test_cooldown_between_hits() -> void:
	target.position = Vector2(ATTACK_RANGE - 1.0, 0)
	behavior.act(body, stats, target, 0.0)
	behavior.update(COOLDOWN * 0.5)
	behavior.act(body, stats, target, 0.0)
	assert_eq(target.received.size(), 1, "간격이 지나기 전에는 다시 때리지 않는다")
	behavior.update(COOLDOWN * 0.5)
	behavior.act(body, stats, target, 0.0)
	assert_eq(target.received.size(), 2, "간격이 지나면 다시 때린다")


func test_each_instance_has_its_own_cooldown() -> void:
	var data: MonsterData = MonsterData.new()
	data.behavior = behavior
	var first: MonsterBehavior = data.make_enemy_behavior()
	var second: MonsterBehavior = data.make_enemy_behavior()
	assert_ne(first, second, "한 마리에 하나씩 복사한다")
	target.position = Vector2(ATTACK_RANGE - 1.0, 0)
	first.act(body, stats, target, 0.0)
	second.act(body, stats, target, 0.0)
	assert_eq(target.received.size(), 2, "한 마리가 때린 간격이 다른 마리에 옮지 않는다")


func test_undead_uses_enemy_behavior_when_not_set() -> void:
	var data: MonsterData = MonsterData.new()
	data.behavior = behavior
	assert_true(data.make_undead_behavior() is ApproachBehavior, "언데드 조각을 비워 두면 적일 때와 같은 조각")
	var other: MonsterBehavior = MonsterBehavior.new()
	data.undead_behavior = other
	assert_false(data.make_undead_behavior() is ApproachBehavior, "언데드 조각을 정하면 그것을 쓴다")


func test_enemy_and_undead_stats_come_from_their_own_values() -> void:
	var data: MonsterData = MonsterData.new()
	data.move_speed = 10.0
	data.undead_move_speed = 20.0
	data.contact_damage = 1.0
	data.undead_contact_damage = 3.0
	assert_eq(data.get_enemy_stats().move_speed, 10.0)
	assert_eq(data.get_undead_stats().move_speed, 20.0)
	assert_eq(data.get_enemy_stats().contact_damage, 1.0)
	assert_eq(data.get_undead_stats().contact_damage, 3.0)
