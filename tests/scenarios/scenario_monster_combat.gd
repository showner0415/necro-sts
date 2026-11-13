extends ScenarioTest
## 시나리오: 싸울 때의 움직임 (몬스터 AI 1단계). 네크로맨서는 가만히 서 있고 체력을 크게 해서 죽지 않게 한다.
## 쥐: 물고 물러남 → 멈춤 → 다시 들어와 또 묾, 멈춤 말고는 제자리에 서 있지 않음 → 쥐끼리 한 점에 겹치지 않음 → 쥐 언데드는 물러나지 않고 붙어 있음.
## 멧돼지: 돌진·멈칫 뒤 방향을 틀어 거리를 벌리고 다시 예고. 고블린: 던지고 잠깐 멈춤, 던지는 사이 옆으로 걸음, 물러나다 벽에 막히면 벽을 따라 미끄러지지 않음.
## 박쥐: 도는 동안 서 있지 않음.
## 몬스터는 단계마다 새로 놓는다. 언데드 단계의 적은 데이터 복사로 움직이지 않고 피해를 주지 않게 고정한다 (실제 .tres는 바꾸지 않는다).

const RAT_PATH: String = "res://data/monsters/rat.tres"
const APPROACH_PATH: String = "res://data/behaviors/approach.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const STAGE: Vector2 = Vector2(0, 300)
const TIMEOUT_FRAMES: int = 300
## 물러났다고 볼 최소 거리 (물린 자리에서 대상까지, 픽셀)
const BACK_OFF_MIN_DISTANCE: float = 40.0
## 쥐 두 마리가 이보다 가까우면 한 점에 겹친 것으로 본다 (픽셀)
const MIN_RAT_GAP: float = 12.0
const WATCH_FRAMES: int = 240
const UNDEAD_WATCH_FRAMES: int = 150
## 언데드가 대상에게 붙어 있다고 볼 거리 (쥐 언데드 공격 거리 24 + 여유)
const UNDEAD_STICK_DISTANCE: float = 30.0
const TOUGH_HEALTH: float = 500.0
const BOAR_PATH: String = "res://data/monsters/boar.tres"
const BAT_PATH: String = "res://data/monsters/bat.tres"
const GOBLIN_PATH: String = "res://data/monsters/goblin_slinger.tres"
## 돌진 뒤 이만큼 벌어져야 거리를 벌린 것으로 본다 (픽셀, back_off_distance 96에 조금 못 미치는 값)
const BOAR_MIN_GAP: float = 90.0
## 벽 시험: 네크로맨서에서 벽까지 거리 (고블린이 물러나는 거리 90보다 가깝게)
const GOBLIN_WALL_OFFSET: float = 70.0
const BONES: int = 30

var _necromancer: Necromancer


func get_start_scene() -> String:
	return TEST_REGION_SCENE


func _on_scene_ready() -> void:
	_run()


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
	return ok


func _clear_monsters() -> void:
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()


func _spawn(data: MonsterData, position: Vector2) -> Monster:
	var monster: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	monster.data = data
	monster.position = position
	_necromancer.get_parent().add_child(monster)
	return monster


func _run() -> void:
	_necromancer = find_necromancer()
	_necromancer.max_health = 100000.0
	_necromancer.health = _necromancer.max_health
	if not await _rat_hit_and_run():
		return
	if not await _rats_do_not_overlap():
		return
	if not await _undead_rat_sticks():
		return
	if not await _boar_turns_away():
		return
	if not await _goblin_pauses_and_strafes():
		return
	if not await _goblin_stops_at_wall():
		return
	if not await _bat_keeps_moving():
		return
	finish(true)


## 박쥐는 고치지 않았다: 도는 동안 제자리에 서 있지 않는지만 확인한다.
func _bat_keeps_moving() -> bool:
	_clear_monsters()
	_necromancer.global_position = STAGE
	var bat: Monster = _spawn(load(BAT_PATH), STAGE + Vector2(50, 0))
	var behavior: DiveBehavior = bat.get_behavior() as DiveBehavior
	var orbit_frames: int = 0
	var orbit_still: int = 0
	var orbit_starts: int = 0
	var was_orbit: bool = false
	for frame: int in WATCH_FRAMES * 2:
		await wait_frames(1)
		var orbiting: bool = behavior.get_state() == DiveBehavior.State.ORBIT
		if orbiting:
			orbit_frames += 1
			orbit_still += 1 if bat.velocity.length() < 0.01 else 0
			orbit_starts += 1 if not was_orbit else 0
		was_orbit = orbiting
	# 돌기를 시작하는 프레임은 물러나기를 끝내며 속도가 0이다.
	return _check("박쥐는 도는 동안 서 있지 않음", orbit_frames > 0 and orbit_still <= orbit_starts, "도는 프레임 %d, 돌기 시작 %d번, 속도 0인 프레임 %d" % [orbit_frames, orbit_starts, orbit_still])


## 돌진 → 멈칫 → 방향을 틀어 거리를 벌림 → 다시 예고. 대상 옆에 서 있지 않는다.
func _boar_turns_away() -> bool:
	_clear_monsters()
	for node: Node in get_nodes_in_group(&"undead"):
		node.free()
	_necromancer.global_position = STAGE
	var boar: Monster = _spawn(load(BOAR_PATH), STAGE + Vector2(100, 0))
	var behavior: ChargeBehavior = boar.get_behavior() as ChargeBehavior
	var recovered: bool = false
	for frame: int in TIMEOUT_FRAMES * 2:
		await wait_frames(1)
		if behavior.get_state() == ChargeBehavior.State.RECOVER:
			recovered = true
			break
	if not _check("멧돼지가 돌진하고 멈칫함", recovered, "상태 %s" % behavior.get_state()):
		return false
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if behavior.get_state() != ChargeBehavior.State.RECOVER:
			break
	var at_end: float = boar.global_position.distance_to(_necromancer.global_position)
	var moved_frames: int = 0
	var farthest: float = at_end
	var next_windup: bool = false
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		farthest = maxf(farthest, boar.global_position.distance_to(_necromancer.global_position))
		moved_frames += 1 if boar.velocity.length() > 0.01 else 0
		if behavior.get_state() == ChargeBehavior.State.WINDUP:
			next_windup = true
			break
	return _check("돌진 뒤 거리를 벌리고 다시 예고", next_windup and farthest >= BOAR_MIN_GAP and moved_frames > 0,
			"멈칫이 끝난 거리 %.0f → 가장 멀리 %.0f (기준 %.0f), 움직인 프레임 %d, 다시 예고 %s" % [at_end, farthest, BOAR_MIN_GAP, moved_frames, next_windup])


func _goblin_stones() -> Array[Stone]:
	var result: Array[Stone] = []
	for child: Node in _necromancer.get_parent().get_children():
		if child is Stone and not child.is_queued_for_deletion():
			result.append(child)
	return result


## 던지면 멈춘다 → 던지는 사이 옆으로 걷는다
func _goblin_pauses_and_strafes() -> bool:
	_clear_monsters()
	_necromancer.global_position = STAGE
	var goblin: Monster = _spawn(load(GOBLIN_PATH), STAGE + Vector2(120, 0))
	var behavior: ThrowBehavior = goblin.get_behavior() as ThrowBehavior
	var thrown: bool = false
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if behavior.is_paused_after_throw():
			thrown = true
			break
	if not _check("고블린이 돌을 던짐", thrown and not _goblin_stones().is_empty(), "돌 %d개" % _goblin_stones().size()):
		return false
	var start: Vector2 = goblin.global_position
	var pause_frames: int = 0
	while behavior.is_paused_after_throw() and pause_frames < TIMEOUT_FRAMES:
		await wait_frames(1)
		pause_frames += 1
	var pause_moved: float = goblin.global_position.distance_to(start)
	if not _check("던지고 잠깐 멈춤", pause_frames >= 20 and pause_moved <= 1.0, "멈춘 프레임 %d (%.2f초), 그동안 움직인 거리 %.1f" % [pause_frames, pause_frames / 60.0, pause_moved]):
		return false
	var before: Vector2 = goblin.global_position
	await wait_frames(30)
	var moved: Vector2 = goblin.global_position - before
	var to_target: Vector2 = _necromancer.global_position - before
	var sideways: float = absf(moved.dot(to_target.normalized().orthogonal()))
	return _check("던지는 사이 옆으로 걸음", sideways >= 8.0, "30프레임 동안 옆으로 %.1f 이동 (앞뒤 %.1f)" % [sideways, absf(moved.dot(to_target.normalized()))])


## 물러나다 벽에 막히면 벽을 따라 미끄러지지 않고 멈춘다
func _goblin_stops_at_wall() -> bool:
	_clear_monsters()
	_necromancer.global_position = STAGE
	var wall_x: float = STAGE.x + GOBLIN_WALL_OFFSET
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(32, 400)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector2(wall_x + 16.0, STAGE.y)
	_necromancer.get_parent().add_child(wall)
	var goblin: Monster = _spawn(load(GOBLIN_PATH), Vector2(wall_x - 8.0, STAGE.y))
	var behavior: ThrowBehavior = goblin.get_behavior() as ThrowBehavior
	await wait_frames(30)
	var start: Vector2 = goblin.global_position
	var along_wall: float = 0.0
	var walking_frames: int = 0
	for frame: int in WATCH_FRAMES:
		await wait_frames(1)
		along_wall = maxf(along_wall, absf(goblin.global_position.y - start.y))
		walking_frames += 1 if not behavior.is_paused_after_throw() and goblin.velocity.length() > 0.01 else 0
	wall.queue_free()
	return _check("물러나다 벽에 막히면 미끄러지지 않음", along_wall <= 2.0, "벽을 등진 고블린, %d프레임 동안 벽을 따라 움직인 거리 %.1f, 걸은 프레임 %d, 체력 그대로 %s" % [WATCH_FRAMES, along_wall, walking_frames, goblin.health == goblin.data.max_health])


## 쥐가 물 때까지 기다린다. 물었으면 true.
func _wait_bite(health_before: float) -> bool:
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if _necromancer.health < health_before:
			return true
	return false


func _rat_hit_and_run() -> bool:
	_clear_monsters()
	_necromancer.global_position = STAGE
	var data: MonsterData = load(RAT_PATH)
	var rat: Monster = _spawn(data, STAGE + Vector2(40, 0))
	var behavior: ApproachBehavior = rat.get_behavior() as ApproachBehavior
	if not _check("살아 있는 쥐는 치고 빠지기 켜짐", behavior.hit_and_run, "hit_and_run %s" % behavior.hit_and_run):
		return false
	var health: float = _necromancer.health
	if not _check("쥐가 묾", await _wait_bite(health), "체력 %.0f → %.0f" % [health, _necromancer.health]):
		return false
	var bitten_at: float = rat.global_position.distance_to(_necromancer.global_position)
	var farthest: float = bitten_at
	var paused_frames: int = 0
	var paused_moving: int = 0
	health = _necromancer.health
	var second_bite: bool = false
	var standing: int = 0
	var phases: Array[ApproachBehavior.Phase] = []
	for frame: int in WATCH_FRAMES:
		await wait_frames(1)
		farthest = maxf(farthest, rat.global_position.distance_to(_necromancer.global_position))
		var phase: ApproachBehavior.Phase = behavior.get_phase()
		if phases.is_empty() or phases[-1] != phase:
			phases.append(phase)
		if phase == ApproachBehavior.Phase.PAUSE:
			paused_frames += 1
			paused_moving += 1 if rat.velocity.length() > 0.01 else 0
		elif rat.velocity.length() < 0.01 and not behavior.is_winding_up():
			standing += 1
		if _necromancer.health < health:
			second_bite = true
			break
	if not _check("물고 물러남", farthest >= BACK_OFF_MIN_DISTANCE, "물린 거리 %.0f → 가장 멀리 %.0f" % [bitten_at, farthest]):
		return false
	if not _check("물러난 뒤 잠깐 멈춤", paused_frames > 0 and paused_moving == 0, "멈춘 프레임 %d (%.2f초), 그동안 움직인 프레임 %d, 단계 순서 %s" % [paused_frames, paused_frames / 60.0, paused_moving, phases]):
		return false
	if not _check("다시 들어와 또 묾", second_bite, "두 번째 물기 %s" % second_bite):
		return false
	return _check("멈춤 말고는 서 있지 않음", standing <= 2, "멈춤·물기 직전 밖에서 속도 0인 프레임 %d" % standing)


func _rats_do_not_overlap() -> bool:
	_clear_monsters()
	_necromancer.global_position = STAGE
	var data: MonsterData = load(RAT_PATH)
	var first: Monster = _spawn(data, STAGE + Vector2(60, 0))
	var second: Monster = _spawn(data, STAGE + Vector2(60, 6))
	await wait_frames(60)
	var closest: float = INF
	for frame: int in WATCH_FRAMES:
		await wait_frames(1)
		closest = minf(closest, first.global_position.distance_to(second.global_position))
	return _check("쥐끼리 한 점에 겹치지 않음", closest >= MIN_RAT_GAP, "거의 같은 자리에서 시작, 1초 뒤부터 가장 가까운 거리 %.1f (기준 %.0f)" % [closest, MIN_RAT_GAP])


func _undead_rat_sticks() -> bool:
	_clear_monsters()
	_necromancer.global_position = STAGE
	var data: MonsterData = load(RAT_PATH)
	if not _check("쥐 언데드는 치고 빠지기 꺼짐", not (data.make_undead_behavior() as ApproachBehavior).hit_and_run, "언데드 행동 %s" % data.undead_behavior.resource_path):
		return false
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	hotbar.assign(0, skull)
	hotbar.select(0)
	_necromancer.summoner.toggle_selected()
	await wait_frames(3)
	var undead: Undead = get_first_node_in_group(&"undead") as Undead
	# 움직이지 않고 피해를 주지 않는 적을 언데드 바로 옆에 두어 싸움을 건다.
	var enemy_data: MonsterData = data.duplicate()
	enemy_data.behavior = load(APPROACH_PATH)
	enemy_data.move_speed = 0.0
	enemy_data.wander_speed = 0.0
	enemy_data.contact_damage = 0.0
	enemy_data.max_health = TOUGH_HEALTH
	var enemy: Monster = _spawn(enemy_data, undead.global_position + Vector2(20, 0))
	var contact: bool = false
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if enemy.health < TOUGH_HEALTH:
			contact = true
			break
	if not _check("쥐 언데드가 적을 때림", contact, "적 체력 %.1f" % enemy.health):
		return false
	var farthest: float = 0.0
	for frame: int in UNDEAD_WATCH_FRAMES:
		await wait_frames(1)
		farthest = maxf(farthest, undead.global_position.distance_to(enemy.global_position))
	return _check("쥐 언데드는 물러나지 않고 붙어 있음", farthest <= UNDEAD_STICK_DISTANCE, "%d프레임 동안 적과 가장 먼 거리 %.1f (기준 %.0f), 적 체력 %.1f" % [UNDEAD_WATCH_FRAMES, farthest, UNDEAD_STICK_DISTANCE, enemy.health])
