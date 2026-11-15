extends ScenarioTest
## 시나리오: 동굴 두꺼비(행동 조각 "부채꼴 뱉기", 제안 2026-11-15, 사용자 확인 전).
## 뱉는 거리 밖이면 느리게 다가옴 → 거리 안이면 멈춰 예고(깜빡임, 바닥에 부채꼴 줄 셋, 줄이 대상을 따라 돌다 고정)
## → 가만히 서 있으면 가운데 침에 맞음(피해 한 번, 데이터의 contact_damage) → 뱉은 뒤 멈춤
## → 고정된 뒤 줄 사이 틈에 서면 세 침이 모두 빗나감 → 옆 줄 위에 서면 옆 침에 맞음 → 다른 몬스터(쥐)가 줄 위에 있으면 침이 막힘(둘 다 피해 없음)
## → 언데드 두꺼비는 몬스터에게 침을 뱉고, 침은 네크로맨서를 지나간다.
## 시험 지역의 몬스터를 모두 치우고 두꺼비와 쥐를 직접 놓는다. 쥐는 데이터를 복사해 움직이지 않고 피해를 주지 않게 바꾼다 (실제 데이터 파일은 바꾸지 않는다).
## 네크로맨서는 체력을 크게 해서 죽지 않게 한다. 틈·옆 줄 단계는 줄이 고정된 뒤 네크로맨서를 그 자리로 옮겨 놓는다 (걷기 입력 대신, 자리가 판마다 같게).

const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const TOAD_PATH: String = "res://data/monsters/cave_toad.tres"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const TOAD_SKULL_PATH: String = "res://data/skulls/cave_toad_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 30
const TIMEOUT_FRAMES: int = 600
## 두꺼비를 놓는 자리 (시험 지역 가운데의 빈 바닥, 밸런스 측정의 몬스터 자리와 같다)
const TOAD_POSITION: Vector2 = Vector2(150, 0)
## 감지 범위 안, 뱉는 거리보다 이만큼 밖에 선다
const APPROACH_MARGIN: float = 10.0
## 예고·맞기 단계에서 두꺼비와 떨어진 거리 (뱉는 거리 안)
const FIGHT_DISTANCE: float = 110.0
## 고정 전에 대상을 따라 도는지 보려고 옆으로 옮기는 거리
const FOLLOW_OFFSET: float = 30.0
const PARKED_POSITION: Vector2 = Vector2(-420, 420)
const UNDEAD_STAGE: Vector2 = Vector2(0, 300)
## 언데드 단계에서 쥐를 둘 자리 (네크로맨서 기준, 언데드 두꺼비의 뱉는 거리 안)
const UNDEAD_RAT_OFFSET: Vector2 = Vector2(110, 0)

var _necromancer: Necromancer
var _toad: Monster
var _rat: Monster
var _spit: SpitFanBehavior


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


## cond가 참이 될 때까지 기다린다. 걸린 프레임 수, 시간이 넘으면 -1.
func _wait_until(cond: Callable, max_frames: int = TIMEOUT_FRAMES) -> int:
	for frame: int in max_frames:
		if cond.call():
			return frame
		await wait_frames(1)
	return -1


func _spits() -> Array[Stone]:
	var result: Array[Stone] = []
	for child: Node in _necromancer.get_parent().get_children():
		if child is Stone and not child.is_queued_for_deletion():
			result.append(child)
	return result


## 지금 날고 있는 침이 모두 사라질 때까지 기다린다. 걸린 프레임 수, 시간이 넘으면 -1.
func _wait_spits_gone() -> int:
	return await _wait_until(func() -> bool: return _spits().is_empty())


func _spawn(path: String, at: Vector2) -> Monster:
	var monster: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	monster.data = load(path)
	monster.position = at
	_necromancer.get_parent().add_child(monster)
	return monster


## 두꺼비 둘레 distance 거리, 가운데 줄에서 degrees만큼 돌린 자리 (발밑)
func _on_line(direction: Vector2, degrees: float, distance: float) -> Vector2:
	return _toad.global_position + direction.rotated(deg_to_rad(degrees)) * distance


## 다음 예고가 고정될 때까지 기다린다. 고정된 가운데 줄 방향, 시간이 넘으면 ZERO.
func _wait_locked() -> Vector2:
	var frames: int = await _wait_until(func() -> bool: return _spit.is_attack_locked())
	return _spit.get_direction() if frames >= 0 else Vector2.ZERO


func _run() -> void:
	_necromancer = find_necromancer()
	_necromancer.max_health = 10000.0
	_necromancer.health = 10000.0
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	_necromancer.global_position = Vector2.ZERO
	_toad = _spawn(TOAD_PATH, TOAD_POSITION)
	_rat = _spawn(RAT_PATH, PARKED_POSITION)
	var harmless_rat: MonsterData = _rat.data.duplicate()
	harmless_rat.contact_damage = 0.0
	harmless_rat.move_speed = 0.0
	harmless_rat.wander_speed = 0.0
	harmless_rat.max_health = 1000.0
	_rat.data = harmless_rat
	_rat.health = harmless_rat.max_health
	await wait_frames(1)
	_spit = _toad.get_behavior() as SpitFanBehavior
	if not _check("두꺼비가 부채꼴 뱉기 조각을 씀", _spit != null and _spit.spit_count == 3,
			"조각 %s, 줄 %d" % [_toad.get_behavior(), _spit.spit_count if _spit != null else -1]):
		finish(false)
		return
	var range: float = _toad.data.attack_range
	var damage: float = _toad.data.contact_damage

	# 1. 뱉는 거리 밖에서 감지하면 느리게 다가온다
	_necromancer.global_position = _toad.global_position + Vector2(-(range + APPROACH_MARGIN), 0)
	await wait_frames(3)
	var approach: Vector2 = _toad.velocity
	if not _check("거리 밖이면 다가옴", _toad.get_target() == _necromancer and approach.x < 0.0 and is_equal_approx(approach.length(), _toad.data.move_speed) and not _spit.is_telegraphing(),
			"거리 %.0f (뱉는 거리 %.0f, 감지 %.0f), 대상 %s, 속도 %s (이동 속도 %.0f)" % [range + APPROACH_MARGIN, range, _toad.data.detect_range, _toad.get_target(), approach.round(), _toad.data.move_speed]):
		finish(false)
		return

	# 2. 거리 안이면 멈춰 예고한다: 깜빡임, 바닥 줄 셋. 고정 전에는 대상을 따라 돌고, 고정된 뒤에는 그대로다
	_necromancer.global_position = _toad.global_position + Vector2(-FIGHT_DISTANCE, 0)
	var seen: Dictionary = {"blink": false}
	var started: int = await _wait_until(func() -> bool:
		if _spit.is_telegraphing() and _toad.get_placeholder_tint() == _spit.blink_color:
			seen["blink"] = true
		return _spit.is_telegraphing())
	var still: bool = _toad.velocity == Vector2.ZERO
	var first_direction: Vector2 = _spit.get_direction()
	_necromancer.global_position += Vector2(0, FOLLOW_OFFSET)
	await wait_frames(2)
	var followed: Vector2 = _spit.get_direction()
	var to_necro: Vector2 = _toad.global_position.direction_to(_necromancer.global_position)
	var locked: Vector2 = await _wait_locked()
	_necromancer.global_position += Vector2(0, -FOLLOW_OFFSET * 2.0)
	await wait_frames(2)
	var after_lock: Vector2 = _spit.get_direction()
	if not _check("예고: 멈춰 깜빡이고 줄 셋이 대상을 따라 돌다 고정", started >= 0 and still and seen["blink"] and _spit.get_spit_directions().size() == 3
			and followed.dot(to_necro) > 0.999 and not first_direction.is_equal_approx(followed) and locked != Vector2.ZERO and after_lock.is_equal_approx(locked),
			"%d프레임 뒤 예고, 멈춤 %s, 깜빡임 %s, 줄 %d, 옆으로 옮기자 방향 %s → %s (네크로맨서 쪽 %s), 고정 뒤 옮겨도 %s → %s" % [
				started, still, seen["blink"], _spit.get_spit_directions().size(), first_direction, followed, to_necro, locked, after_lock]):
		finish(false)
		return

	# 3. 가만히 서 있으면 가운데 침에 맞는다 (옆 침 둘은 빗나간다). 뱉은 뒤 잠깐 멈춘다
	# 고정된 줄 위(가운데)에 선다: 고정 뒤 옮겨 놓은 자리에서 가운데 줄로 되돌린다.
	_necromancer.global_position = _on_line(locked, 0.0, FIGHT_DISTANCE)
	var health_before: float = _necromancer.health
	var spat: int = await _wait_until(func() -> bool: return _spits().size() == _spit.spit_count)
	await wait_frames(2)
	var recovering: bool = _spit.get_state() == SpitFanBehavior.State.RECOVER and _toad.velocity == Vector2.ZERO
	var frames: int = await _wait_spits_gone()
	if not _check("가만히 서 있으면 가운데 침에 맞음, 뱉은 뒤 멈춤", spat >= 0 and frames >= 0 and recovering and is_equal_approx(_necromancer.health, health_before - damage),
			"침 %d개, 뱉은 뒤 멈춤 %s, %d프레임 뒤 모두 사라짐, 체력 %.0f → %.0f (침 피해 %.0f)" % [_spit.spit_count, recovering, frames, health_before, _necromancer.health, damage]):
		finish(false)
		return

	# 4. 줄이 고정된 뒤 줄 사이 틈에 서면 세 침이 모두 빗나간다
	_necromancer.global_position = _toad.global_position + Vector2(-FIGHT_DISTANCE, 0)
	locked = await _wait_locked()
	_necromancer.global_position = _on_line(locked, _spit.spread_degrees / 2.0, FIGHT_DISTANCE)
	health_before = _necromancer.health
	spat = await _wait_until(func() -> bool: return _spits().size() == _spit.spit_count)
	frames = await _wait_spits_gone()
	if not _check("줄 사이 틈에 서면 빗나감", locked != Vector2.ZERO and spat >= 0 and frames >= 0 and _necromancer.health == health_before,
			"고정 뒤 가운데 줄에서 %.0f도 돌린 자리(거리 %.0f)로 옮김, %d프레임 뒤 침 사라짐, 체력 %.0f → %.0f" % [_spit.spread_degrees / 2.0, FIGHT_DISTANCE, frames, health_before, _necromancer.health]):
		finish(false)
		return

	# 5. 옆 줄 위에 서면 옆 침에 맞는다 (줄이 셋이다)
	_necromancer.global_position = _toad.global_position + Vector2(-FIGHT_DISTANCE, 0)
	locked = await _wait_locked()
	_necromancer.global_position = _on_line(locked, _spit.spread_degrees, FIGHT_DISTANCE)
	health_before = _necromancer.health
	spat = await _wait_until(func() -> bool: return _spits().size() == _spit.spit_count)
	frames = await _wait_spits_gone()
	if not _check("옆 줄 위에 서면 맞음", locked != Vector2.ZERO and spat >= 0 and frames >= 0 and is_equal_approx(_necromancer.health, health_before - damage),
			"고정 뒤 옆 줄(%.0f도) 위로 옮김, %d프레임 뒤 침 사라짐, 체력 %.0f → %.0f" % [_spit.spread_degrees, frames, health_before, _necromancer.health]):
		finish(false)
		return

	# 6. 다른 몬스터가 가운데 줄 위에 있으면 침이 막힌다 (피해 없음). 옆 침은 가운데 줄 위의 네크로맨서를 빗나간다
	_necromancer.global_position = _toad.global_position + Vector2(-FIGHT_DISTANCE, 0)
	_rat.global_position = _toad.global_position + Vector2(-FIGHT_DISTANCE / 2.0, 0)
	health_before = _necromancer.health
	var rat_before: float = _rat.health
	locked = await _wait_locked()
	spat = await _wait_until(func() -> bool: return _spits().size() == _spit.spit_count)
	frames = await _wait_spits_gone()
	if not _check("다른 몬스터에 막힘", locked != Vector2.ZERO and spat >= 0 and frames >= 0 and _necromancer.health == health_before and _rat.health == rat_before,
			"쥐가 가운데 줄 위 (두꺼비와 네크로맨서 사이), 네크로맨서 체력 %.0f → %.0f, 쥐 체력 %.0f → %.0f" % [health_before, _necromancer.health, rat_before, _rat.health]):
		finish(false)
		return

	# 7. 언데드 두꺼비는 몬스터에게 뱉고, 침은 네크로맨서를 지나간다
	_toad.free()
	_necromancer.global_position = UNDEAD_STAGE
	_rat.global_position = UNDEAD_STAGE + UNDEAD_RAT_OFFSET
	# 언데드는 감지 범위가 없다. 네크로맨서가 때린 몬스터를 노리므로 먼저 쥐를 때려 둔다.
	_rat.take_damage(0.0, _necromancer)
	await wait_frames(2)
	var skull: Skull = Skull.create(load(TOAD_SKULL_PATH))
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	hotbar.assign(0, skull)
	hotbar.select(0)
	_necromancer.summoner.toggle_selected()
	await wait_frames(2)
	rat_before = _rat.health
	health_before = _necromancer.health
	var groups: Dictionary = {"value": []}
	spat = await _wait_until(func() -> bool:
		var spits: Array[Stone] = _spits()
		if not spits.is_empty():
			groups["value"] = spits[0].hostile_groups.duplicate()
		return not spits.is_empty())
	frames = await _wait_spits_gone()
	var undead_damage: float = (load(TOAD_PATH) as MonsterData).undead_contact_damage
	var hits: float = (rat_before - _rat.health) / undead_damage
	_check("언데드 두꺼비는 몬스터에게 뱉음", not get_nodes_in_group(&"undead").is_empty() and spat >= 0 and groups["value"].size() == 1 and groups["value"][0] == &"monsters" and roundi(hits) >= 1 and absf(hits - roundf(hits)) < 0.01 and _necromancer.health == health_before,
		"언데드 %d, 침 적 그룹 %s, %d프레임 뒤 사라짐, 쥐 체력 %.2f → %.2f (침 %.0f개, 언데드 침 피해 %.2f), 네크로맨서 체력 %.0f → %.0f" % [
			get_nodes_in_group(&"undead").size(), groups["value"], frames, rat_before, _rat.health, hits, undead_damage, health_before, _necromancer.health])
	finish(true)
