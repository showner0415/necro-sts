extends ScenarioTest
## 시나리오: 몬스터 타게팅.
## 감지 범위 밖에서 쥐를 쏘면 다가옴 → 공격자와 너무 멀어지면 포기하고 맞기 시작한 자리로 돌아감
## (돌아가는 중에는 감지 범위에 들어와도 무시, 체력 그대로) → 다시 쏘면 쫓아오다 감지 범위에 들어오면 가장 가까운 대상
## → 감지 범위 안에서 언데드와 싸우는 중에는 네크로맨서가 쏴도 가장 가까운 대상(언데드)을 계속 노림.
##
## 쥐 두 마리만 남기고 다른 몬스터는 치운다. 쥐 데이터는 복사해서 바꾼다 (실제 데이터 파일은 바꾸지 않는다).
## - 처음 쥐: 배회 속도 0 (멀리서 쏜 탄이 날아가는 동안 비켜나지 않게. 쫓는 속도는 그대로)
## - 마지막 단계의 쥐: 체력을 크게 (싸우는 동안 죽지 않게)

const WAIT_FRAMES: int = 3
const TIMEOUT_FRAMES: int = 600
## 쥐가 다가오는지 볼 프레임
const APPROACH_FRAMES: int = 20
## 포기시키려고 네크로맨서를 쥐에게서 이만큼 떨어뜨린다 (공격자 한계 250보다 멀게)
const FAR_OFFSET: Vector2 = Vector2(-300, 0)
## 돌아가는 중에 네크로맨서를 쥐 옆(감지 범위 안)에 둔다
const NEAR_OFFSET: Vector2 = Vector2(-30, 0)
const IGNORE_FRAMES: int = 10
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 10
## 마지막 단계: 쥐, 그 바로 옆에 언데드, 감지 범위 안 조금 떨어진 곳에 네크로맨서
const FIGHT_STAGE: Vector2 = Vector2(0, 300)
const UNDEAD_OFFSET: Vector2 = Vector2(12, 0)
const NECROMANCER_OFFSET: Vector2 = Vector2(-60, 0)
const TOUGH_RAT_HEALTH: float = 50.0
const FIGHT_FRAMES: int = 90

var _necromancer: Necromancer
var _rat: Monster
var _fight_rat: Monster


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


func _state_name(rat: Monster) -> String:
	return Aggro.State.keys()[rat.get_aggro().state]


func _target_name(rat: Monster) -> String:
	var target: Node2D = rat.get_target()
	return target.name if target != null else "없음"


func _run() -> void:
	_necromancer = find_necromancer()
	_rat = current_scene.get_node_or_null("Actors/Rat1")
	_fight_rat = current_scene.get_node_or_null("Actors/Rat2")
	if _necromancer == null or _rat == null or _fight_rat == null:
		fail_step("준비", "네크로맨서 %s, Rat1 %s, Rat2 %s" % [_necromancer, _rat, _fight_rat])
		return
	for node: Node in get_nodes_in_group(&"monsters"):
		if node != _rat and node != _fight_rat:
			node.queue_free()
	var still_rat: MonsterData = _rat.data.duplicate()
	still_rat.wander_speed = 0.0
	_rat.data = still_rat
	# 마지막 단계까지 끼어들지 않게 멀리 둔다.
	_fight_rat.global_position = FIGHT_STAGE + Vector2(0, 150)
	await wait_frames(WAIT_FRAMES)

	if not await _shoot_from_outside():
		return
	if not await _give_up_and_return():
		return
	if not await _chase_then_nearest():
		return
	await _fight_keeps_nearest()


## 쥐를 한 발 쏜다. 맞을 때까지 기다린 프레임 수, 못 맞히면 -1.
func _shoot_once(rat: Monster) -> int:
	var health_before: float = rat.health
	# 흉내 낸 마우스 이동은 몇 프레임 뒤에 반영되므로, 조준을 유지하다가 쏜다.
	for i: int in WAIT_FRAMES:
		aim_mouse_at(rat.global_position + Vector2(0, -rat.data.placeholder_radius))
		await wait_frames(1)
	press_mouse(true)
	await wait_frames(1)
	press_mouse(false)
	for frame: int in TIMEOUT_FRAMES:
		if rat.health < health_before:
			return frame
		await wait_frames(1)
	return -1


func _shoot_from_outside() -> bool:
	var distance: float = _rat.global_position.distance_to(_necromancer.global_position)
	if not _check("감지 범위 밖", distance > _rat.data.detect_range and distance < _necromancer.attack.projectile_range and _rat.get_target() == null,
			"쥐까지 %.0f (감지 %.0f, 사거리 %.0f), 노리는 대상 %s" % [distance, _rat.data.detect_range, _necromancer.attack.projectile_range, _target_name(_rat)]):
		return false
	var frames: int = await _shoot_once(_rat)
	var hit_position: Vector2 = _rat.global_position
	await wait_frames(1)
	var aggro: Aggro = _rat.get_aggro()
	if not _check("맞으면 공격자를 노림", frames >= 0 and aggro.state == Aggro.State.CHASING and _rat.get_target() == _necromancer and aggro.origin.distance_to(hit_position) < 2.0,
			"%d프레임 만에 맞음 (체력 %.0f/%.0f), 상태 %s, 노리는 대상 %s, 맞기 시작한 자리 %s" % [
				frames, _rat.health, _rat.data.max_health, _state_name(_rat), _target_name(_rat), aggro.origin.round()]):
		return false
	var before: float = _rat.global_position.distance_to(_necromancer.global_position)
	await wait_frames(APPROACH_FRAMES)
	var after: float = _rat.global_position.distance_to(_necromancer.global_position)
	return _check("감지 범위 밖에서 쏘면 다가옴", after < before - 5.0 and _rat.get_aggro().state == Aggro.State.CHASING,
			"%d프레임 동안 거리 %.0f → %.0f, 상태 %s" % [APPROACH_FRAMES, before, after, _state_name(_rat)])


func _give_up_and_return() -> bool:
	var origin: Vector2 = _rat.get_aggro().origin
	var health: float = _rat.health
	_necromancer.global_position = _rat.global_position + FAR_OFFSET
	await wait_frames(WAIT_FRAMES)
	if not _check("공격자와 멀어지면 포기", _rat.get_aggro().state == Aggro.State.RETURNING and _rat.get_target() == null,
			"공격자까지 %.0f (한계 %.0f), 상태 %s, 노리는 대상 %s" % [
				_rat.global_position.distance_to(_necromancer.global_position), _rat.data.chase_attacker_limit, _state_name(_rat), _target_name(_rat)]):
		return false

	# 돌아가는 중에는 바로 옆(감지 범위 안)에 있어도 노리지 않는다.
	_necromancer.global_position = _rat.global_position + NEAR_OFFSET
	var ignored: bool = true
	for i: int in IGNORE_FRAMES:
		await wait_frames(1)
		ignored = ignored and _rat.get_aggro().state == Aggro.State.RETURNING and _rat.get_target() == null
	if not _check("돌아가는 중에는 감지 무시", ignored,
			"감지 범위 안(%.0f)에서 %d프레임 동안 상태 %s, 노리는 대상 %s" % [
				_rat.global_position.distance_to(_necromancer.global_position), IGNORE_FRAMES, _state_name(_rat), _target_name(_rat)]):
		return false
	# 끼어들지 않게 다시 멀리 둔다.
	_necromancer.global_position = origin + FAR_OFFSET
	var frames: int = 0
	while _rat.get_aggro().state == Aggro.State.RETURNING and frames < TIMEOUT_FRAMES:
		await wait_frames(1)
		frames += 1
	return _check("맞기 시작한 자리로 돌아감", _rat.get_aggro().state == Aggro.State.IDLE and _rat.global_position.distance_to(origin) <= _rat.return_arrive_distance + 1.0 and _rat.health == health,
			"%d프레임 만에 도착, 맞기 시작한 자리까지 %.1f, 체력 %.0f (돌아가기 전 %.0f, 회복 안 함)" % [
				frames, _rat.global_position.distance_to(origin), _rat.health, health])


func _chase_then_nearest() -> bool:
	# 감지 범위 밖, 사거리 안에서 다시 쏜다.
	_necromancer.global_position = _rat.global_position + Vector2(-130, 0)
	await wait_frames(WAIT_FRAMES)
	if await _shoot_once(_rat) < 0 or _rat.get_aggro().state != Aggro.State.CHASING:
		fail_step("다시 쫓음", "맞지 않았거나 상태가 %s" % _state_name(_rat))
		return false
	var frames: int = 0
	while _rat.global_position.distance_to(_necromancer.global_position) > _rat.data.detect_range and frames < TIMEOUT_FRAMES:
		await wait_frames(1)
		frames += 1
	await wait_frames(1)
	return _check("쫓다가 감지 범위에 들어오면 가장 가까운 대상", _rat.get_aggro().state == Aggro.State.IDLE and _rat.get_target() == _necromancer,
			"%d프레임 만에 감지 범위(%.0f) 안, 상태 %s, 노리는 대상 %s" % [frames, _rat.data.detect_range, _state_name(_rat), _target_name(_rat)])


func _fight_keeps_nearest() -> void:
	_rat.queue_free()
	var tough: MonsterData = _fight_rat.data.duplicate()
	tough.max_health = TOUGH_RAT_HEALTH
	_fight_rat.data = tough
	_fight_rat.health = TOUGH_RAT_HEALTH
	# 대상 고르기만 보는 단계다: 물고 물러나면 쥐가 움직여 "가장 가까운 대상"이 프레임마다 바뀌므로 붙어 싸우게 고정한다.
	(_fight_rat.get_behavior() as ApproachBehavior).hit_and_run = false
	_fight_rat.global_position = FIGHT_STAGE
	_necromancer.global_position = FIGHT_STAGE + NECROMANCER_OFFSET

	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	hotbar.assign(0, skull)
	hotbar.select(0)
	_necromancer.summoner.toggle_selected()
	await wait_frames(1)
	var undead: Undead = get_first_node_in_group(&"undead") as Undead
	if undead == null:
		fail_step("언데드 소환", "언데드가 없음")
		return
	undead.global_position = FIGHT_STAGE + UNDEAD_OFFSET
	await wait_frames(WAIT_FRAMES)

	# 네크로맨서가 계속 쏘는 동안, 매 프레임 쥐가 노리는 대상이 가장 가까운 대상인지 본다.
	var health_before: float = _fight_rat.health
	var wrong_frames: int = 0
	var undead_frames: int = 0
	press_mouse(true)
	for i: int in FIGHT_FRAMES:
		aim_mouse_at(_fight_rat.global_position + Vector2(0, -_fight_rat.data.placeholder_radius))
		await wait_frames(1)
		if not is_instance_valid(undead):
			break
		var to_necromancer: float = _fight_rat.global_position.distance_to(_necromancer.global_position)
		var to_undead: float = _fight_rat.global_position.distance_to(undead.global_position)
		var nearest: Node2D = undead if to_undead <= to_necromancer else _necromancer
		if _fight_rat.get_target() != nearest:
			wrong_frames += 1
		if _fight_rat.get_target() == undead:
			undead_frames += 1
	press_mouse(false)
	var damage: float = health_before - _fight_rat.health
	# 그동안 언데드 혼자 줄 수 있는 최대 피해. 이보다 많이 받았으면 네크로맨서의 탄도 맞은 것이다.
	var cooldown_frames: float = undead.data.attack_cooldown * Engine.physics_ticks_per_second
	var undead_max: float = ceilf(FIGHT_FRAMES / cooldown_frames) * undead.data.undead_contact_damage
	var ok: bool = wrong_frames == 0 and undead_frames > 0 and damage > undead_max and _fight_rat.get_aggro().state == Aggro.State.IDLE
	_check("싸우는 중에 맞아도 가장 가까운 대상", ok,
			"%d프레임 중 가장 가까운 대상이 아닌 것을 노린 프레임 %d, 언데드를 노린 프레임 %d, 쥐가 받은 피해 %.0f (언데드 혼자 최대 %.0f → 네크로맨서 탄도 맞음), 상태 %s" % [
				FIGHT_FRAMES, wrong_frames, undead_frames, damage, undead_max, _state_name(_fight_rat)])
	finish(ok)
