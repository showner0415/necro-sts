extends ScenarioTest
## 시나리오: 투사체 (고블린 돌). 포물선은 그림만이고 예측 지점에 그림자 원이 그려진다.
## 던지기 전에 멈춤 → 그림자는 돌마다 하나, 시야에 숨지 않음, 돌과 함께 사라짐 → 한 방향으로 계속 걷는 대상은 맞음 → 던진 뒤 방향을 바꾸면 피함 →
## 고블린 투석병 vs 고블린 언데드 1마리와 2마리 싸움이 30초 안에 끝남.
## 고블린은 데이터 복사로 움직이지 않게 고정하고, 예측은 "정확"(비율 1, 오차 0)으로 시험한 뒤 실제 값도 출력한다. 실제 .tres는 바꾸지 않는다.

const GOBLIN_PATH: String = "res://data/monsters/goblin_slinger.tres"
const GOBLIN_SKULL_PATH: String = "res://data/skulls/goblin_slinger_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const BONES: int = 60
const STAGE: Vector2 = Vector2(0, 300)
const THROW_DISTANCE: float = 110.0
const WALK_DIRECTION: Vector2 = Vector2.DOWN
const THROWS: int = 5
const TIMEOUT_FRAMES: int = 300
## 싸움이 끝나야 하는 시간 (프레임, 30초)
const DUEL_FRAMES: int = 1800

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


func _stones() -> Array[Stone]:
	var result: Array[Stone] = []
	for child: Node in _necromancer.get_parent().get_children():
		if child is Stone and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _shadows() -> Array[StoneShadow]:
	var result: Array[StoneShadow] = []
	for child: Node in _necromancer.get_parent().get_children():
		if child is StoneShadow and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _spawn_still_goblin(lead: float, error: float) -> Monster:
	var data: MonsterData = (load(GOBLIN_PATH) as MonsterData).duplicate()
	data.move_speed = 0.0
	data.wander_speed = 0.0
	var ratios: Array[float] = [lead]
	var errors: Array[float] = [error]
	data.throw_lead_ratios = ratios
	data.throw_aim_errors = errors
	var goblin: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	goblin.data = data
	goblin.position = STAGE + Vector2(THROW_DISTANCE, 0)
	_necromancer.get_parent().add_child(goblin)
	var behavior: ThrowBehavior = goblin.get_behavior() as ThrowBehavior
	behavior.strafe_speed = 0.0
	behavior.retreat_distance = 0.0
	return goblin


func _run() -> void:
	_necromancer = find_necromancer()
	_necromancer.max_health = 100000.0
	_necromancer.health = _necromancer.max_health
	if not await _shadow_step():
		return
	if not await _walker(1.0, 0.0, false, "정확한 예측"):
		return
	if not await _walker(1.0, 0.0, true, "정확한 예측"):
		return
	await _walker_report()
	if not await _duel(1):
		return
	if not await _duel(2):
		return
	finish(true)


func _shadow_step() -> bool:
	_clear_monsters()
	_necromancer.global_position = STAGE
	var goblin: Monster = _spawn_still_goblin(1.0, 0.0)
	var behavior: ThrowBehavior = goblin.get_behavior() as ThrowBehavior
	var wound_up: bool = false
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if behavior.is_winding_up():
			wound_up = true
		if not _stones().is_empty():
			break
	if not _check("던지기 전에 멈춤", wound_up and goblin.velocity == Vector2.ZERO, "멈춤 단계 %s" % wound_up):
		return false
	await wait_frames(1)
	var shadows: Array[StoneShadow] = _shadows()
	if not _check("그림자가 돌 하나에 하나", shadows.size() == 1 and _stones().size() == 1, "돌 %d, 그림자 %d" % [_stones().size(), shadows.size()]):
		return false
	if not _check("그림자는 시야에 숨지 않음", not shadows[0].is_in_group(&"sight_hidden") and shadows[0].visible, "sight_hidden %s, visible %s" % [shadows[0].is_in_group(&"sight_hidden"), shadows[0].visible]):
		return false
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if _stones().is_empty():
			break
	await wait_frames(2)
	return _check("돌과 함께 그림자가 사라짐", _shadows().is_empty(), "그림자 %d" % _shadows().size())


## 걷는 네크로맨서에게 돌을 THROWS번 던지게 하고 맞은 수를 돌려준다. turn이면 돌을 던진 뒤 반대쪽으로 걷는다.
func _throw_at_walker(lead: float, error: float, turn: bool) -> int:
	_clear_monsters()
	var goblin: Monster = _spawn_still_goblin(lead, error)
	var behavior: ThrowBehavior = goblin.get_behavior() as ThrowBehavior
	var hits: int = 0
	for i: int in THROWS:
		for frame: int in TIMEOUT_FRAMES:
			await wait_frames(1)
			if behavior.is_winding_up():
				break
		_necromancer.global_position = STAGE
		press_moves(WALK_DIRECTION)
		var thrown: bool = false
		for frame: int in TIMEOUT_FRAMES:
			await wait_frames(1)
			if not _stones().is_empty():
				thrown = true
				break
		if not thrown:
			break
		if turn:
			press_moves(-WALK_DIRECTION)
		var health: float = _necromancer.health
		for frame: int in TIMEOUT_FRAMES:
			await wait_frames(1)
			if _stones().is_empty():
				break
		hits += 1 if _necromancer.health < health else 0
	press_moves(Vector2.ZERO)
	return hits


func _walker(lead: float, error: float, turn: bool, label: String) -> bool:
	var hits: int = await _throw_at_walker(lead, error, turn)
	if turn:
		return _check("던진 뒤 방향을 바꾸면 피함 (%s)" % label, hits <= 1, "%d번 중 %d번 맞음" % [THROWS, hits])
	return _check("한 방향으로 걷는 대상이 맞음 (%s)" % label, hits >= THROWS - 1, "%d번 중 %d번 맞음" % [THROWS, hits])


## 실제 예측 값으로 걸었을 때 맞은 수를 출력한다 (판정 없음)
func _walker_report() -> void:
	var data: MonsterData = load(GOBLIN_PATH)
	var straight: int = await _throw_at_walker(data.throw_lead_ratios[0], data.throw_aim_errors[0], false)
	var turned: int = await _throw_at_walker(data.throw_lead_ratios[0], data.throw_aim_errors[0], true)
	pass_step("실제 값 (예측 %.1f, 오차 ±%.0f도)" % [data.throw_lead_ratios[0], data.throw_aim_errors[0]], "곧게 걸으면 %d/%d, 방향을 바꾸면 %d/%d 맞음" % [straight, THROWS, turned, THROWS])


## 고블린 1마리 vs 고블린 언데드 count마리: 네크로맨서는 구경만 한다.
func _duel(count: int) -> bool:
	_clear_monsters()
	for node: Node in get_nodes_in_group(&"undead"):
		node.free()
	_necromancer.global_position = STAGE
	_necromancer.remove_from_group(&"necromancer")
	_necromancer.mana.maximum = 100000.0
	_necromancer.mana.current = _necromancer.mana.maximum
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	for i: int in count:
		var skull: Skull = Skull.create(load(GOBLIN_SKULL_PATH))
		_necromancer.inventory.try_add(ItemStack.of_skull(skull))
		hotbar.assign(i, skull)
		hotbar.select(i)
		_necromancer.summoner.toggle_selected()
	await wait_frames(3)
	var goblin: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	goblin.data = load(GOBLIN_PATH)
	goblin.position = STAGE + Vector2(70, 0)
	_necromancer.get_parent().add_child(goblin)
	var frames: int = DUEL_FRAMES
	for frame: int in DUEL_FRAMES:
		await wait_frames(1)
		if not is_instance_valid(goblin) or goblin.is_queued_for_deletion() or get_nodes_in_group(&"undead").is_empty():
			frames = frame + 1
			break
	var goblin_alive: bool = is_instance_valid(goblin) and not goblin.is_queued_for_deletion()
	var undead_left: int = get_nodes_in_group(&"undead").size()
	for node: Node in get_nodes_in_group(&"undead"):
		node.free()
	_necromancer.add_to_group(&"necromancer")
	return _check("고블린 vs 언데드 %d마리가 30초 안에 끝남" % count, frames < DUEL_FRAMES, "%.1f초, 고블린 살아 있음 %s, 남은 언데드 %d" % [frames / 60.0, goblin_alive, undead_left])
