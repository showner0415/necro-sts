extends TestCase
## ThrowBehavior(행동 조각 "거리 두고 던지기", 고블린 투석병)와 돌(Stone) 단위 테스트.
## 조각은 body.velocity만 정하므로 이동은 확인하지 않고 속도만 본다. 돌은 트리에 붙여서 만든 뒤 맞는 쪽을 직접 넣어 본다.

const DT: float = 1.0 / 60.0
const SPEED: float = 45.0
const RANGE: float = 140.0
const DAMAGE: float = 2.0
const COOLDOWN: float = 2.0


class FakeBody:
	extends CharacterBody2D
	var groups: Array[StringName] = [&"necromancer", &"undead"]

	var passes: Array[StringName] = []

	func get_stone_pass_groups() -> Array[StringName]:
		return passes

	func get_hostile_groups() -> Array[StringName]:
		return groups


class FakeTarget:
	extends CharacterBody2D
	var damage: Array[float] = []
	var sources: Array[Node2D] = []

	func take_damage(amount: float, source: Node2D = null) -> void:
		damage.append(amount)
		sources.append(source)


var world: Node2D
var body: FakeBody
var target: FakeTarget
var stats: CombatStats
var throw: ThrowBehavior


func before_each() -> void:
	world = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	body = FakeBody.new()
	target = FakeTarget.new()
	target.add_to_group(&"necromancer")
	world.add_child(body)
	world.add_child(target)
	stats = CombatStats.create(SPEED, RANGE, DAMAGE, COOLDOWN)
	throw = (load("res://data/behaviors/throw.tres") as ThrowBehavior).make_instance()
	# 거리 두기·던지기 규칙만 보는 테스트는 멈춤과 옆걸음을 끈다. 아래 "싸울 때 움직임"에서 따로 켠다.
	throw.throw_pause_time = 0.0
	throw.strafe_speed = 0.0


func after_each() -> void:
	world.free()


func _stones() -> Array[Stone]:
	var result: Array[Stone] = []
	for child: Node in world.get_children():
		if child is Stone and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _step() -> void:
	throw.update(DT)
	throw.act(body, stats, target, DT)


# --- 거리 두기 ---

func test_far_target_is_approached() -> void:
	target.position = Vector2(RANGE + 30.0, 0)
	_step()
	assert_almost_eq(body.velocity.x, SPEED, 0.01, "던지는 거리 밖이면 다가간다")
	assert_eq(_stones().size(), 0, "밖에서는 던지지 않는다")


func test_stands_between_retreat_and_range() -> void:
	target.position = Vector2((throw.retreat_distance + RANGE) / 2.0, 0)
	_step()
	assert_eq(body.velocity, Vector2.ZERO, "알맞은 거리면 멈춰 선다")


func test_close_target_makes_it_retreat_slowly() -> void:
	target.position = Vector2(throw.retreat_distance - 20.0, 0)
	_step()
	assert_almost_eq(body.velocity.x, -throw.retreat_speed, 0.01, "가까우면 반대쪽으로 느리게 물러난다")
	assert_eq(_stones().size(), 1, "물러나면서도 던진다")


# --- 싸울 때 움직임 ---

func test_pauses_after_throw_then_moves_again() -> void:
	throw.throw_pause_time = 0.4
	throw.strafe_speed = 30.0
	target.position = Vector2(throw.retreat_distance - 20.0, 0)
	_step()
	assert_eq(_stones().size(), 1, "던진다")
	assert_eq(body.velocity, Vector2.ZERO, "던지면 멈춘다")
	assert_true(throw.is_paused_after_throw(), "멈춤 중")
	assert_false(throw.allows_spacing(), "멈춤 중에는 밀지 않는다")
	for frame: int in roundi(0.4 / DT) + 2:
		_step()
	assert_false(throw.is_paused_after_throw(), "멈춤이 끝남")
	assert_true(body.velocity.x < 0.0, "멈춤이 끝나면 다시 물러난다")


func test_strafes_sideways_between_throws() -> void:
	throw.throw_pause_time = 0.0
	throw.strafe_speed = 30.0
	target.position = Vector2((throw.retreat_distance + RANGE) / 2.0, 0)
	_step()
	_step()
	assert_almost_eq(absf(body.velocity.y), 30.0, 0.01, "알맞은 거리면 옆으로 걷는다")
	assert_almost_eq(body.velocity.x, 0.0, 0.01, "앞뒤로는 움직이지 않는다")


# --- 던지기 ---

func test_throws_every_cooldown() -> void:
	target.position = Vector2(110, 0)
	var thrown_frames: Array[int] = []
	for frame: int in roundi(COOLDOWN * 2.5 / DT):
		var before: int = _stones().size()
		_step()
		if _stones().size() > before:
			thrown_frames.append(frame)
	assert_eq(thrown_frames.size(), 3, "바로 한 번, 그 뒤 2초마다 (5초 동안 3번)")
	if thrown_frames.size() >= 2:
		assert_almost_eq((thrown_frames[1] - thrown_frames[0]) * DT, COOLDOWN, DT * 1.5, "간격 2초")


func test_stone_flies_at_target_position_with_stats() -> void:
	target.position = Vector2(60, 80)
	var stone: Stone = throw.throw_stone(body, stats, target)
	var expected: Vector2 = Vector2(60, 80).normalized()
	assert_almost_eq(stone.direction.angle_to(expected), 0.0, 0.001, "던지는 순간 대상이 있던 쪽")
	assert_eq(stone.speed, throw.stone_speed)
	assert_eq(stone.damage, DAMAGE, "피해는 능력치의 피해")
	assert_eq(stone.max_distance, RANGE, "던지는 거리만큼 날아간다")
	assert_eq(stone.hostile_groups, [&"necromancer", &"undead"] as Array[StringName], "던진 쪽의 적 그룹")


# --- 돌 ---

func test_stone_damages_hostile_and_stops() -> void:
	var stone: Stone = throw.throw_stone(body, stats, target)
	stone._on_body_entered(target)
	assert_eq(target.damage, [DAMAGE] as Array[float], "적에게 피해")
	assert_eq(target.sources[0], body, "던진 쪽이 때린 쪽")
	assert_true(stone.is_queued_for_deletion(), "맞으면 멈춘다")


func test_stone_blocked_by_other_body_without_damage() -> void:
	var other_monster: FakeTarget = FakeTarget.new()
	other_monster.add_to_group(&"monsters")
	world.add_child(other_monster)
	var stone: Stone = throw.throw_stone(body, stats, target)
	stone._on_body_entered(other_monster)
	assert_eq(other_monster.damage.size(), 0, "다른 몬스터는 피해 없음")
	assert_true(stone.is_queued_for_deletion(), "다른 몬스터 몸에 막힌다")


func test_stone_passes_its_thrower() -> void:
	var stone: Stone = throw.throw_stone(body, stats, target)
	stone._on_body_entered(body)
	assert_false(stone.is_queued_for_deletion(), "던진 몸은 지나간다")


func test_stone_disappears_after_range() -> void:
	var stone: Stone = throw.throw_stone(body, stats, target)
	stone._physics_process(RANGE / stone.speed + DT)
	assert_true(stone.is_queued_for_deletion(), "던지는 거리를 다 날면 사라진다")


func test_undead_thrower_passes_allies_and_hits_monsters() -> void:
	body.groups = [&"monsters"]
	body.passes = [&"necromancer", &"undead"]
	var stone: Stone = throw.throw_stone(body, stats, target)
	stone._on_body_entered(target)
	assert_eq(target.damage.size(), 0, "언데드의 돌은 네크로맨서에게 피해를 주지 않는다")
	assert_false(stone.is_queued_for_deletion(), "네크로맨서·언데드는 지나간다")
	var monster: FakeTarget = FakeTarget.new()
	monster.add_to_group(&"monsters")
	world.add_child(monster)
	stone._on_body_entered(monster)
	assert_eq(monster.damage, [DAMAGE] as Array[float], "몬스터에게 피해")
	assert_true(stone.is_queued_for_deletion())
