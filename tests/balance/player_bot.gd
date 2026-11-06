class_name PlayerBot
extends RefCounted
## 밸런스 측정용 플레이어 봇. 실제 입력(이동, 뛰기, 구르기, 조준, 공격, 핫바·소환 키)만 흉내 내서 싸우므로
## 스태미나·마나·공격 간격 같은 제약을 그대로 받는다. 판단에는 몬스터 위치와 예고 상태를 읽는다.
## - 겨누기: 가장 가까운 몬스터의 이동 방향을 감안해 탄이 닿을 자리를 겨눈다. 조준 오차(도)만큼 흔들린다
## - 피하기: 몬스터가 예고를 시작하면 반응 시간 뒤, 공격 방향이 고정되었으면 그 옆으로 구른다. 회피 성공률만큼만 시도한다
##   (방향이 고정되기 전에 구르면 멧돼지가 다시 겨누므로 고정을 기다린다)
## - 거리 두기: 근접 몬스터와 keep_distance를 유지하며 쏜다. 다가오는 몬스터가 아주 가까우면 쏘기를 멈추고 뛴다 (쏘는 동안은 느리고 뛸 수 없다)
##   예고 중인 공격(돌진 등)은 뛰어서 피하지 않는다. 피하기는 구르기 판단(반응 시간, 회피 성공률) 하나로만 한다.
##   그래야 실력 단계의 회피 성공률이 결과에 그대로 드러난다
## - 언데드: 핫바의 머리뼈가 소환 중이 아니고 마나가 넉넉하면 숫자키 → G로 다시 소환한다
## 실력은 반응 시간, 조준 오차, 회피 성공률 세 값으로 정한다 (SKILLS, 임시값).

## 실력 단계: [이름, 반응 시간(초), 조준 오차(도, 표준편차), 회피 성공률]
const SKILLS: Dictionary = {
	&"skilled": {"name": "숙련", "reaction": 0.18, "aim_error": 0.0, "dodge": 0.9},
	&"normal": {"name": "보통", "reaction": 0.30, "aim_error": 3.5, "dodge": 0.6},
	&"novice": {"name": "초보", "reaction": 0.45, "aim_error": 7.0, "dodge": 0.25},
}

## 핫바 칸을 고르는 숫자키 (칸 순서대로)
const HOTBAR_KEYS: Array[Key] = [KEY_1, KEY_2]

## 근접 몬스터와 유지하려는 거리 (픽셀)
var keep_distance: float = 100.0
## 이보다 가까우면 뛴다 (픽셀)
var run_distance: float = 55.0
## 사거리의 이 비율 안에 들어오면 쏜다
var fire_range_ratio: float = 0.95
## 싸우는 곳의 가운데와 반지름. 밖으로 나가면 가운데 쪽으로 돌아온다 (시험 지역 바닥 안)
var arena_center: Vector2 = Vector2.ZERO
var arena_radius: float = 360.0
## 조준 오차를 다시 뽑는 간격 (초). 한 발마다 다른 오차가 되도록 _init에서 공격 간격과 맞춘다.
var aim_resample_interval: float = 0.4
## 처음 이 횟수만큼의 무리 동시 공격은 일부러 피하지 않는다 (실수했을 때를 재기 위해)
var miss_group_attacks: int = 0
## 무리 동시 공격 하나가 끝났다고 보기까지 기다리는 시간 (초). 예고가 끝난 뒤 물린 피해까지 센다.
var group_attack_settle_time: float = 0.3
## 다시 소환할 때 소환 마나에 더해 남겨 둘 마나
var summon_mana_margin: float = 2.0

var skill: Dictionary
var _test: ScenarioTest
var _necromancer: Necromancer
var _aim_offset_deg: float = 0.0
var _aim_timer: float = 0.0
var _last_positions: Dictionary = {}
## 지금 보고 있는 예고: 행동 조각 → {"seen": 처음 본 시각, "try": 피하기를 시도할지, "done": 굴렀는지}
var _telegraphs: Dictionary = {}
var _time: float = 0.0
var _running: bool = false
var _summon_cooldown: float = 0.0
var _undead_skulls: Array[Skull] = []
var _key_queue: Array[Key] = []
## 측정: 쏜 탄 수, 맞힌 탄 수, 구른 횟수
var shots: int = 0
var hits: int = 0
var rolls: int = 0
## 측정: 본 예고 수, 소환 키를 누른 횟수, 몬스터가 가장 가까이 온 거리
var telegraphs_seen: int = 0
var summons: int = 0
var closest: float = INF
## 측정: 본 무리 동시 공격 수, 일부러 놓친 동시 공격에서 받은 피해 합,
## 놓친 동시 공격이 끝난 직후의 마나 (놓친 것이 없으면 -1), 싸우는 동안 가장 낮았던 마나
var group_attacks_seen: int = 0
var missed_group_damage: float = 0.0
var mana_after_miss: float = -1.0
var mana_min: float = INF
## 측정: 언데드가 죽은 판정으로 사라진 수, 그 밖의 이유(마나 0 등)로 해제된 수
var undead_died: int = 0
var undead_released: int = 0

## 진행 중인 무리 동시 공격: 일부러 놓치는지, 시작할 때 체력, 예고가 안 보인 지 얼마나 됐는지
var _group_active: bool = false
var _group_missed: bool = false
var _group_health_before: float = 0.0
var _group_quiet_time: float = 0.0


func _init(test: ScenarioTest, necromancer: Necromancer, skill_id: StringName) -> void:
	_test = test
	_necromancer = necromancer
	skill = SKILLS[skill_id]
	aim_resample_interval = necromancer.attack.cooldown
	_necromancer.get_parent().child_entered_tree.connect(_on_actor_added)
	_necromancer.summoner.roster.unsummoned.connect(func(_skull: Skull, died: bool) -> void:
		if died:
			undead_died += 1
		else:
			undead_released += 1)


## 핫바 칸 순서대로 소환할 머리뼈 (언데드와 함께 싸울 때)
func set_undead_skulls(skulls: Array[Skull]) -> void:
	_undead_skulls = skulls


## 물리 프레임마다 부른다.
func tick(delta: float) -> void:
	_time += delta
	_summon_cooldown = maxf(_summon_cooldown - delta, 0.0)
	_press_queued_key()
	var monsters: Array[Monster] = _alive_monsters()
	if monsters.is_empty():
		release_all()
		return
	_track_group_attack(monsters, delta)
	var target: Monster = _nearest(monsters)
	_aim_and_fire(target, delta, _should_flee(monsters))
	if not _try_dodge(monsters):
		_move(monsters)
	_manage_undead()
	mana_min = minf(mana_min, _necromancer.mana.current)
	for monster: Monster in monsters:
		_last_positions[monster] = monster.global_position
		closest = minf(closest, monster.global_position.distance_to(_necromancer.global_position))


## 판이 끝났을 때 부른다. 놓친 동시 공격 도중에 죽었으면 남아 있던 체력을 모두 그 피해로 센다.
func finish_tracking(died: bool) -> void:
	if _group_active and _group_missed:
		missed_group_damage += _group_health_before if died else _group_health_before - _necromancer.health
		_group_active = false


func release_all() -> void:
	_test.press_moves(Vector2.ZERO)
	_test.press_mouse(false)
	_set_running(false)


func _alive_monsters() -> Array[Monster]:
	var result: Array[Monster] = []
	for node: Node in _test.get_nodes_in_group(&"monsters"):
		var monster: Monster = node as Monster
		if monster != null and not monster.is_queued_for_deletion() and monster.health > 0.0:
			result.append(monster)
	return result


func _nearest(monsters: Array[Monster]) -> Monster:
	var nearest: Monster = monsters[0]
	for monster: Monster in monsters:
		if monster.global_position.distance_to(_necromancer.global_position) < nearest.global_position.distance_to(_necromancer.global_position):
			nearest = monster
	return nearest


## 예고 없이 다가오는 몬스터가 아주 가까우면, 쏘기를 멈추고 뛰어서 벗어난다.
func _should_flee(monsters: Array[Monster]) -> bool:
	if keep_distance <= 0.0 or not _necromancer.stamina.can_run():
		return false
	for monster: Monster in monsters:
		var behavior: MonsterBehavior = monster.get_behavior()
		if behavior != null and behavior.is_telegraphing():
			continue
		if monster.global_position.distance_to(_necromancer.global_position) < run_distance:
			return true
	return false


func _aim_and_fire(target: Monster, delta: float, fleeing: bool) -> void:
	_aim_timer -= delta
	if _aim_timer <= 0.0:
		_aim_timer = aim_resample_interval
		_aim_offset_deg = randfn(0.0, skill["aim_error"]) if skill["aim_error"] > 0.0 else 0.0
	var origin: Vector2 = _necromancer.global_position + Vector2(0, -_necromancer.placeholder_radius)
	var center: Vector2 = target.global_position + PlaceholderBody.center(target.data)
	# 이동 방향 감안: 탄이 닿는 시간만큼 앞을 겨눈다.
	var velocity: Vector2 = Vector2.ZERO
	if _last_positions.has(target) and delta > 0.0:
		velocity = (target.global_position - _last_positions[target]) / delta
	var flight_time: float = origin.distance_to(center) / _necromancer.attack.projectile_speed
	var aim: Vector2 = center + velocity * flight_time
	aim = origin + (aim - origin).rotated(deg_to_rad(_aim_offset_deg))
	_test.aim_mouse_at(aim)
	var in_range: bool = origin.distance_to(center) <= _necromancer.attack.projectile_range * fire_range_ratio
	_test.press_mouse(in_range and not fleeing)


## 예고를 보고 반응 시간 뒤 공격 방향의 옆으로 구른다. 이번 프레임에 굴렀으면 true.
func _try_dodge(monsters: Array[Monster]) -> bool:
	var seen_now: Dictionary = {}
	var rolled: bool = false
	for monster: Monster in monsters:
		var behavior: MonsterBehavior = monster.get_behavior()
		if behavior == null or not behavior.is_telegraphing():
			continue
		seen_now[behavior] = true
		if not _telegraphs.has(behavior):
			telegraphs_seen += 1
			# 일부러 놓치는 무리 동시 공격에는 피하기를 시도하지 않는다.
			var skip: bool = behavior.is_group_attack() and _group_missed
			_telegraphs[behavior] = {"seen": _time, "try": not skip and randf() < skill["dodge"], "done": false}
		var info: Dictionary = _telegraphs[behavior]
		if rolled or info["done"] or not info["try"]:
			continue
		if _time - info["seen"] < skill["reaction"] or not behavior.is_attack_locked():
			continue
		var direction: Vector2 = behavior.get_attack_direction()
		if direction == Vector2.ZERO:
			continue
		# 공격 줄에서 벗어나는 옆쪽을 고른다.
		var side: Vector2 = direction.orthogonal()
		if side.dot(_necromancer.global_position - monster.global_position) < 0.0:
			side = -side
		side = _keep_in_arena(side)
		_test.press_moves(side)
		_test.press_key(KEY_SPACE, true)
		_test.press_key(KEY_SPACE, false)
		info["done"] = true
		rolled = true
		rolls += 1
	for behavior: Variant in _telegraphs.keys():
		if not seen_now.has(behavior):
			_telegraphs.erase(behavior)
	return rolled


## 무리 동시 공격의 시작과 끝을 본다. 처음 miss_group_attacks번은 놓치기로 하고, 그동안 받은 피해와 끝난 직후 마나를 잰다.
## _try_dodge보다 먼저 시작을 알아야 하므로, 새 예고가 보이는 프레임에 _try_dodge 안에서 쓰는 _group_missed를 여기서 정한다.
func _track_group_attack(monsters: Array[Monster], delta: float) -> void:
	var group_now: bool = false
	for monster: Monster in monsters:
		var behavior: MonsterBehavior = monster.get_behavior()
		if behavior != null and behavior.is_group_attack():
			group_now = true
	if group_now and not _group_active:
		_group_active = true
		group_attacks_seen += 1
		_group_missed = group_attacks_seen <= miss_group_attacks
		_group_health_before = _necromancer.health
	if not _group_active:
		return
	_group_quiet_time = 0.0 if group_now else _group_quiet_time + delta
	if _group_quiet_time < group_attack_settle_time:
		return
	_group_active = false
	if _group_missed:
		missed_group_damage += _group_health_before - _necromancer.health
		mana_after_miss = _necromancer.mana.current
	_group_missed = false


func _move(monsters: Array[Monster]) -> void:
	if _necromancer.is_rolling():
		return
	var position: Vector2 = _necromancer.global_position
	var away: Vector2 = Vector2.ZERO
	for monster: Monster in monsters:
		var distance: float = position.distance_to(monster.global_position)
		if distance < keep_distance and distance > 0.0:
			away += monster.global_position.direction_to(position) * (keep_distance - distance) / keep_distance
	var direction: Vector2 = Vector2.ZERO
	var target: Monster = _nearest(monsters)
	var to_target: Vector2 = target.global_position - position
	if away != Vector2.ZERO:
		# 물러나되 옆으로도 돌아서 한 방향으로만 밀리지 않게 한다.
		direction = (away.normalized() + away.normalized().orthogonal() * 0.5).normalized()
	elif to_target.length() > _necromancer.attack.projectile_range * 0.85:
		direction = to_target.normalized()
	direction = _keep_in_arena(direction)
	_test.press_moves(direction)
	_set_running(_should_flee(monsters) and direction != Vector2.ZERO)


func _keep_in_arena(direction: Vector2) -> Vector2:
	var from_center: Vector2 = _necromancer.global_position - arena_center
	if from_center.length() > arena_radius:
		return (direction - from_center.normalized()).normalized()
	return direction


func _set_running(running: bool) -> void:
	if running == _running:
		return
	_running = running
	_test.press_key(KEY_SHIFT, running)


func _manage_undead() -> void:
	if _summon_cooldown > 0.0 or not _key_queue.is_empty():
		return
	var roster: UndeadRoster = _necromancer.summoner.roster
	for i: int in _undead_skulls.size():
		var skull: Skull = _undead_skulls[i]
		# 소환 중이거나, 깨운 뒤 체력이 0이거나, 내구도가 0이면 소환할 수 없다.
		if roster.is_summoned(skull) or (skull.awakened and skull.health <= 0.0) or skull.is_broken():
			continue
		var cost: float = roster.get_monster(skull).summon_mana_cost
		if _necromancer.mana.current < cost + summon_mana_margin:
			continue
		# 숫자키로 칸을 고르고 G로 소환한다 (한 프레임에 키 하나씩).
		_key_queue = [HOTBAR_KEYS[i], KEY_G]
		summons += 1
		_summon_cooldown = 0.2
		return


func _press_queued_key() -> void:
	if _key_queue.is_empty():
		return
	var key: Key = _key_queue.pop_front()
	_test.press_key(key, true)
	_test.press_key(key, false)


func _on_actor_added(node: Node) -> void:
	var bolt: Bolt = node as Bolt
	if bolt == null:
		return
	shots += 1
	bolt.hit_target.connect(func(_body: Node2D) -> void: hits += 1)
