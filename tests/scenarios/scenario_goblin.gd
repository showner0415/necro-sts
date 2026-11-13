extends ScenarioTest
## 시나리오: 고블린 투석병(행동 조각 "거리 두고 던지기").
## 시험 지역 동쪽, 멧돼지 뒤에 2마리 → 던지는 거리 밖이면 다가옴 → 예고 없이 돌을 던져 네크로맨서에게 피해(데이터의 contact_damage, 지금 2)
## → 던지자마자 옆으로 걸으면 돌이 빗나감 → 가까이 가면 느리게 물러나며 계속 던짐 → 다른 몬스터(쥐)가 사이에 있으면 돌이 막힘(둘 다 피해 없음)
## → 언데드 투석병은 몬스터에게 돌을 던져 피해를 줌.
## 투석병 한 마리와 쥐 한 마리만 남긴다. 쥐는 데이터를 복사해 움직이지 않고 피해를 주지 않게 바꾼다 (실제 데이터 파일은 바꾸지 않는다).
## 네크로맨서는 체력을 크게 해서 죽지 않게 한다.

const TIMEOUT_FRAMES: int = 300
const RANGE_MARGIN: float = 30.0
const SIDESTEP: Vector2 = Vector2.DOWN
const PARKED_POSITION: Vector2 = Vector2(-420, 420)
const GOBLIN_SKULL_PATH: String = "res://data/skulls/goblin_slinger_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 30
const UNDEAD_STAGE: Vector2 = Vector2(0, 300)
## 언데드 단계에서 쥐를 둘 자리 (네크로맨서 기준, 언데드 투석병의 감지·던지는 거리 안)
const UNDEAD_RAT_OFFSET: Vector2 = Vector2(110, 0)

var _necromancer: Necromancer
var _goblin: Monster
var _rat: Monster


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


func _stones() -> Array[Stone]:
	var result: Array[Stone] = []
	for child: Node in current_scene.get_node("Actors").get_children():
		if child is Stone and not child.is_queued_for_deletion():
			result.append(child)
	return result


## 새 돌이 나올 때까지 기다린다. 나온 돌, 없으면 null.
func _wait_new_stone() -> Stone:
	var before: Array[Stone] = _stones()
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		for stone: Stone in _stones():
			if not before.has(stone):
				return stone
	return null


## 돌이 사라질 때까지 기다린다. 걸린 프레임 수.
func _wait_stone_gone(stone: Stone) -> int:
	for frame: int in TIMEOUT_FRAMES:
		if not is_instance_valid(stone) or stone.is_queued_for_deletion():
			return frame
		await wait_frames(1)
	return -1


func _run() -> void:
	_necromancer = find_necromancer()
	_necromancer.max_health = 10000.0
	_necromancer.health = 10000.0
	var goblins: Array[Monster] = []
	for node: Node in get_nodes_in_group(&"monsters"):
		if (node as Monster).data.id == &"goblin_slinger":
			goblins.append(node)
	_rat = current_scene.get_node("Actors/Rat1")
	if not _check("동쪽 멧돼지 뒤에 2마리", goblins.size() == 2 and goblins.all(func(g: Monster) -> bool: return g.global_position.x > 400.0),
			"투석병 %d마리, 자리 %s" % [goblins.size(), goblins.map(func(g: Monster) -> Vector2: return g.global_position)]):
		finish(false)
		return
	_goblin = goblins[0]
	for node: Node in get_nodes_in_group(&"monsters"):
		if node != _goblin and node != _rat:
			node.free()
	var harmless_rat: MonsterData = _rat.data.duplicate()
	harmless_rat.contact_damage = 0.0
	harmless_rat.move_speed = 0.0
	harmless_rat.wander_speed = 0.0
	harmless_rat.max_health = 1000.0
	_rat.data = harmless_rat
	_rat.health = harmless_rat.max_health
	_rat.global_position = PARKED_POSITION
	var range: float = _goblin.data.attack_range

	# 1. 던지는 거리 밖에서 감지하면 다가온다
	_necromancer.global_position = _goblin.global_position + Vector2(-(range + RANGE_MARGIN * 0.3), 0)
	await wait_frames(3)
	var approach_speed: float = _goblin.velocity.length()
	if not _check("거리 밖이면 다가옴", _goblin.get_target() == _necromancer and _goblin.velocity.x < 0.0 and is_equal_approx(approach_speed, _goblin.data.move_speed),
			"거리 %.0f (던지는 거리 %.0f, 감지 %.0f), 대상 %s, 속도 %s (이동 속도 %.0f)" % [_goblin.global_position.distance_to(_necromancer.global_position), range, _goblin.data.detect_range, _goblin.get_target(), _goblin.velocity.round(), _goblin.data.move_speed]):
		finish(false)
		return

	# 2. 예고 없이 던져서 맞힌다 (네크로맨서는 가만히)
	var health_before: float = _necromancer.health
	var stone: Stone = await _wait_new_stone()
	var thrown: bool = stone != null
	var stone_dir: Vector2 = stone.direction if stone != null else Vector2.ZERO
	var to_necro: Vector2 = _goblin.global_position.direction_to(_necromancer.global_position)
	var frames: int = await _wait_stone_gone(stone)
	if not _check("돌에 맞음", thrown and stone_dir.dot(to_necro) > 0.99 and _necromancer.health == health_before - _goblin.data.contact_damage,
			"돌 방향 %s (네크로맨서 쪽 %s), %d프레임 뒤 사라짐, 체력 %.0f → %.0f (피해 %.0f)" % [stone_dir, to_necro, frames, health_before, _necromancer.health, _goblin.data.contact_damage]):
		finish(false)
		return

	# 3. 던지자마자 옆으로 걸으면 빗나간다
	health_before = _necromancer.health
	stone = await _wait_new_stone()
	thrown = stone != null
	press_moves(SIDESTEP)
	frames = await _wait_stone_gone(stone)
	press_moves(Vector2.ZERO)
	if not _check("옆으로 걸으면 빗나감", thrown and frames >= 0 and _necromancer.health == health_before,
			"돌이 나오자 아래로 걸음, %d프레임 뒤 돌 사라짐, 체력 %.0f → %.0f" % [frames, health_before, _necromancer.health]):
		finish(false)
		return

	# 4. 가까이 가면 느리게 물러나며 계속 던진다
	var throw: ThrowBehavior = _goblin.get_behavior() as ThrowBehavior
	_necromancer.global_position = _goblin.global_position + Vector2(-(throw.retreat_distance - 30.0), 0)
	await wait_frames(2)
	var retreat_velocity: Vector2 = _goblin.velocity
	stone = await _wait_new_stone()
	thrown = stone != null
	var still_close: bool = _goblin.global_position.distance_to(_necromancer.global_position) < throw.retreat_distance + 10.0
	if not _check("가까우면 물러나며 던짐", retreat_velocity.x > 0.0 and is_equal_approx(retreat_velocity.length(), throw.retreat_speed) and thrown,
			"거리 %.0f (물러나는 거리 %.0f), 속도 %s (물러나는 속도 %.0f, 네크로맨서 반대쪽), 물러나는 중 던짐 %s (아직 가까움 %s)" % [
				throw.retreat_distance - 30.0, throw.retreat_distance, retreat_velocity.round(), throw.retreat_speed, thrown, still_close]):
		finish(false)
		return
	await _wait_stone_gone(stone)

	# 5. 다른 몬스터가 사이에 있으면 돌이 막힌다
	# 돌과 쥐가 일직선인지만 보는 단계라 옆으로 걷지 않게 고정한다.
	throw.strafe_speed = 0.0
	_necromancer.global_position = _goblin.global_position + Vector2(-120, 0)
	_rat.global_position = _goblin.global_position + Vector2(-60, 0)
	health_before = _necromancer.health
	var rat_before: float = _rat.health
	stone = await _wait_new_stone()
	thrown = stone != null
	frames = await _wait_stone_gone(stone)
	if not _check("다른 몬스터에 막힘", thrown and _necromancer.health == health_before and _rat.health == rat_before and frames < roundi(110.0 / throw.stone_speed * 60.0),
			"쥐가 가운데, %d프레임 만에 사라짐 (네크로맨서까지 %d프레임), 네크로맨서 체력 %.0f → %.0f, 쥐 체력 %.0f → %.0f" % [
				frames, roundi(110.0 / throw.stone_speed * 60.0), health_before, _necromancer.health, rat_before, _rat.health]):
		finish(false)
		return

	# 6. 언데드 투석병은 몬스터에게 던진다
	_goblin.free()
	_necromancer.global_position = UNDEAD_STAGE
	_rat.global_position = UNDEAD_STAGE + UNDEAD_RAT_OFFSET
	# 언데드는 감지 범위가 없다. 네크로맨서가 때린 몬스터(또는 아군을 노리는 몬스터)를 노리므로 먼저 쥐를 때려 둔다.
	_rat.take_damage(0.0, _necromancer)
	await wait_frames(2)
	var skull: Skull = Skull.create(load(GOBLIN_SKULL_PATH))
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	hotbar.assign(0, skull)
	hotbar.select(0)
	_necromancer.summoner.toggle_selected()
	await wait_frames(2)
	rat_before = _rat.health
	stone = await _wait_new_stone()
	thrown = stone != null
	var groups: Array = stone.hostile_groups.duplicate() if thrown else []
	frames = await _wait_stone_gone(stone)
	var undead: Array[Node] = get_nodes_in_group(&"undead")
	_check("언데드 투석병은 몬스터에게 던짐", not undead.is_empty() and thrown and _stone_hits(rat_before - _rat.health) >= 1,
		"언데드 %d, 돌 적 그룹 %s, %d프레임 뒤 사라짐, 쥐 체력 %.0f → %.0f (돌 %d개 맞음, 소환 직후 이미 던진 돌 포함)" % [undead.size(), groups, frames, rat_before, _rat.health, _stone_hits(rat_before - _rat.health)])
	finish(true)


func _goblin_damage() -> float:
	return (load("res://data/monsters/goblin_slinger.tres") as MonsterData).undead_contact_damage


## 받은 피해가 돌 몇 개만큼인지 (돌 피해의 정수배가 아니면 -1)
func _stone_hits(damage: float) -> int:
	var hits: float = damage / _goblin_damage()
	return roundi(hits) if absf(hits - roundf(hits)) < 0.01 else -1
