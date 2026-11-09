extends ScenarioTest
## 시나리오: 싸울 때의 움직임 (몬스터 AI 1단계). 네크로맨서는 가만히 서 있고 체력을 크게 해서 죽지 않게 한다.
## 쥐: 물고 물러남 → 멈춤 → 다시 들어와 또 묾, 기다리는 동안 제자리에 서 있지 않음 → 쥐끼리 한 점에 겹치지 않음 → 쥐 언데드는 물러나지 않고 붙어 있음.
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
	finish(true)


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
		elif rat.velocity.length() < 0.01:
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
	return _check("멈춤 말고는 서 있지 않음", standing <= 2, "멈춤 단계 밖에서 속도 0인 프레임 %d" % standing)


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
