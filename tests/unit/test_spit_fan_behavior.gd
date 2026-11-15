extends TestCase
## SpitFanBehavior(행동 조각 "부채꼴 뱉기", 동굴 두꺼비 제안) 단위 테스트.
## 조각은 body.velocity만 정하므로 이동은 확인하지 않고 속도만 본다. 침(Stone)은 트리에 붙여서 만든 뒤 방향·값을 본다.
## 침이 맞는 규칙(적에게 피해, 다른 몸에 막힘, 던진 몸·지나가는 그룹은 지나감)은 Stone 규칙이라 test_throw_behavior.gd가 본다.

const DT: float = 1.0 / 60.0
const SPEED: float = 30.0
const RANGE: float = 150.0
const DAMAGE: float = 3.0
const COOLDOWN: float = 2.0


class FakeBody:
	extends CharacterBody2D
	var groups: Array[StringName] = [&"necromancer", &"undead"]
	var passes: Array[StringName] = []

	func get_stone_pass_groups() -> Array[StringName]:
		return passes

	func get_hostile_groups() -> Array[StringName]:
		return groups

	## 공격권 (Monster.request_attack 흉내). 기본은 언제나 준다
	var allowed: bool = true
	var finished: int = 0

	func request_attack(_target: Node2D) -> bool:
		return allowed

	func finish_attack() -> void:
		finished += 1


class FakeTarget:
	extends CharacterBody2D
	var damage: Array[float] = []

	func take_damage(amount: float, _source: Node2D = null) -> void:
		damage.append(amount)


var world: Node2D
var body: FakeBody
var target: FakeTarget
var stats: CombatStats
var spit: SpitFanBehavior


func before_each() -> void:
	world = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	body = FakeBody.new()
	target = FakeTarget.new()
	target.add_to_group(&"necromancer")
	world.add_child(body)
	world.add_child(target)
	stats = CombatStats.create(SPEED, RANGE, DAMAGE, COOLDOWN)
	spit = (load("res://data/behaviors/cave_toad_spit_fan.tres") as SpitFanBehavior).make_instance()


func after_each() -> void:
	world.free()


func _spits() -> Array[Stone]:
	var result: Array[Stone] = []
	for child: Node in world.get_children():
		if child is Stone and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _step(with_target: bool = true) -> void:
	spit.update(DT)
	spit.act(body, stats, target if with_target else null, DT)


## 예고가 끝날 때까지 돌린다 (예고 중인 프레임 수만큼)
func _finish_windup() -> void:
	for frame: int in roundi(spit.windup_time / DT) + 2:
		if not spit.is_telegraphing():
			return
		_step()


# --- 다가가기와 서기 ---

func test_far_target_is_approached_without_spitting() -> void:
	target.position = Vector2(RANGE + 30.0, 0)
	_step()
	assert_almost_eq(body.velocity.x, SPEED, 0.01, "뱉는 거리 밖이면 다가간다")
	assert_false(spit.is_telegraphing(), "밖에서는 예고하지 않는다")
	assert_eq(_spits().size(), 0, "밖에서는 뱉지 않는다")


func test_close_target_does_not_make_it_retreat() -> void:
	target.position = Vector2(30, 0)
	_step()
	assert_eq(body.velocity, Vector2.ZERO, "가까워도 물러나지 않고 선다 (투석병과 다른 점)")
	assert_true(spit.is_telegraphing(), "가까워도 예고를 시작한다")


# --- 예고 ---

func test_windup_stands_still_blinks_and_draws_lines() -> void:
	target.position = Vector2(100, 0)
	_step()
	assert_true(spit.is_telegraphing(), "거리 안이면 예고를 시작한다")
	assert_true(spit.is_busy(), "예고 중에는 대상이 없어도 이어 간다")
	assert_true(spit.keeps_token_on_target_change(), "예고 중에는 대상이 바뀌어도 공격권을 든다")
	assert_false(spit.allows_spacing(), "예고 중에는 밀지 않는다")
	assert_eq(body.velocity, Vector2.ZERO, "예고 중에는 멈춰 있다")
	assert_eq(spit.get_body_color(Color("181425")), spit.blink_color, "예고를 시작하면 깜빡인다")
	assert_eq(spit.get_warning_segment(Vector2.ZERO).size(), 2, "예고 중에는 가운데 줄이 있다")
	assert_eq(_spits().size(), 0, "예고 중에는 아직 뱉지 않는다")


func test_lines_follow_target_until_locked() -> void:
	target.position = Vector2(100, 0)
	_step()
	target.position = Vector2(100, 40)
	_step()
	assert_almost_eq(spit.get_direction().angle_to(Vector2(100, 40)), 0.0, 0.001, "고정 전에는 대상을 따라 돈다")
	assert_false(spit.is_attack_locked(), "아직 고정 전")
	for frame: int in roundi((spit.windup_time - spit.lock_time) / DT) + 1:
		_step()
	assert_true(spit.is_attack_locked(), "끝나기 lock_time 전에 고정된다")
	var locked: Vector2 = spit.get_direction()
	assert_eq(spit.get_attack_direction(), locked, "봇이 읽는 공격 방향은 가운데 줄")
	target.position = Vector2(100, -60)
	_step()
	assert_eq(spit.get_direction(), locked, "고정된 뒤에는 대상이 움직여도 그대로다")


func test_spits_fan_at_locked_direction_with_stats() -> void:
	target.position = Vector2(100, 0)
	_step()
	_finish_windup()
	var spits: Array[Stone] = _spits()
	assert_eq(spits.size(), spit.spit_count, "줄 수만큼 한꺼번에 뱉는다")
	var angles: Array[float] = []
	for stone: Stone in spits:
		angles.append(roundf(rad_to_deg(Vector2.RIGHT.angle_to(stone.direction))))
		assert_eq(stone.speed, spit.spit_speed)
		assert_eq(stone.damage, DAMAGE, "피해는 능력치의 피해")
		assert_eq(stone.max_distance, spit.spit_range, "spit_range까지 곧게 날아간다")
		assert_eq(stone.landing_radius, 0.0, "떨어질 곳(그림자 원)이 없다")
		assert_eq(stone.hostile_groups, [&"necromancer", &"undead"] as Array[StringName], "뱉은 쪽의 적 그룹")
	angles.sort()
	assert_eq(angles, [-spit.spread_degrees, 0.0, spit.spread_degrees] as Array[float], "가운데 줄은 대상 쪽, 양옆은 spread_degrees씩")
	assert_eq(body.finished, 1, "뱉으면 공격 한 번이 끝난다 (공격권 반납)")


func test_commits_even_if_target_leaves_or_disappears() -> void:
	target.position = Vector2(100, 0)
	_step()
	target.position = Vector2(RANGE + 100.0, 0)
	_step()
	assert_true(spit.is_telegraphing(), "대상이 거리 밖으로 나가도 예고를 이어 간다")
	for frame: int in roundi(spit.windup_time / DT) + 2:
		if not spit.is_telegraphing():
			break
		_step(false)
	assert_eq(_spits().size(), spit.spit_count, "대상이 사라져도 끝까지 뱉는다")


func test_recovers_then_waits_for_cooldown() -> void:
	target.position = Vector2(100, 0)
	_step()
	_finish_windup()
	assert_eq(spit.get_state(), SpitFanBehavior.State.RECOVER, "뱉은 뒤 멈춘다")
	assert_eq(body.velocity, Vector2.ZERO)
	assert_false(spit.is_telegraphing(), "멈춤은 예고가 아니다")
	var spit_count: int = _spits().size()
	var next_windup_frame: int = -1
	for frame: int in roundi(COOLDOWN * 1.5 / DT):
		_step()
		if spit.is_telegraphing():
			next_windup_frame = frame
			break
	assert_eq(_spits().size(), spit_count, "그사이 더 뱉지 않는다")
	assert_almost_eq(next_windup_frame * DT, COOLDOWN, DT * 2.0, "공격 간격이 지나야 다음 예고를 시작한다")


# --- 공격권 ---

func test_waits_around_without_token_instead_of_spitting() -> void:
	body.allowed = false
	stats.wait_distance = 170.0
	target.position = Vector2(100, 0)
	_step()
	assert_false(spit.is_telegraphing(), "공격권이 없으면 예고하지 않는다")
	assert_true(body.velocity.x < 0.0, "맴도는 거리(170)까지 물러나 기다린다")
	body.allowed = true
	_step()
	assert_true(spit.is_telegraphing(), "공격권을 받으면 예고를 시작한다")


# --- 언데드 ---

func test_undead_spits_hit_monsters_and_pass_allies() -> void:
	body.groups = [&"monsters"]
	body.passes = [&"necromancer", &"undead"]
	target.position = Vector2(100, 0)
	_step()
	_finish_windup()
	var center: Stone = null
	for stone: Stone in _spits():
		if absf(stone.direction.angle_to(Vector2.RIGHT)) < 0.01:
			center = stone
	assert_ne(center, null, "가운데 침이 있다")
	if center == null:
		return
	assert_eq(center.hostile_groups, [&"monsters"] as Array[StringName], "언데드의 침은 몬스터만 맞힌다")
	center._on_body_entered(target)
	assert_eq(target.damage.size(), 0, "네크로맨서에게는 피해가 없다")
	assert_false(center.is_queued_for_deletion(), "네크로맨서·언데드는 지나간다")
