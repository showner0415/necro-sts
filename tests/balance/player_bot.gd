class_name PlayerBot
extends RefCounted
## 밸런스 측정용 플레이어 봇. 실제 입력(이동, 뛰기, 구르기, 조준, 공격, 핫바·소환 키)만 흉내 내서 싸우므로
## 스태미나·마나·공격 간격 같은 제약을 그대로 받는다. 판단에는 몬스터 위치와 예고 상태를 읽는다.
## - 겨누기: 가장 가까운 몬스터의 이동 방향을 감안해 탄이 닿을 자리를 겨눈다. 조준 오차(도)만큼 흔들린다
## - 피하기: 몬스터가 예고를 시작하면 반응 시간 뒤, 공격 방향이 고정되었으면 그 옆으로 구른다. 회피 성공률만큼만 시도한다
## - 돌 피하기: 예고 없이 날아오는 돌(Stone)은 처음 본 뒤 반응 시간이 지나면, 맞을 줄 위에 있는 동안 줄에서 벗어나는 옆쪽으로 걷는다 (쏘기는 계속).
##   회피 성공률만큼만 시도한다
##   (방향이 고정되기 전에 구르면 멧돼지가 다시 겨누므로 고정을 기다린다)
## - 거리 두기: 근접 몬스터와 keep_distance를 유지하며 쏜다. 다가오는 몬스터가 아주 가까우면 쏘기를 멈추고 뛴다 (쏘는 동안은 느리고 뛸 수 없다)
##   예고 중인 공격(돌진 등)은 뛰어서 피하지 않는다. 피하기는 구르기 판단(반응 시간, 회피 성공률) 하나로만 한다.
##   그래야 실력 단계의 회피 성공률이 결과에 그대로 드러난다
## - 줄 피하기: 몬스터가 예고 중일 때, 그 몬스터와 언데드를 잇는 줄 위(언데드 뒤쪽)에 있으면 옆으로 비킨다 (물러나지는 않는다).
##   언데드를 노린 공격이 뒤로 이어지지 않게. 사람도 예고 선이 보일 때 비키므로 예고 중에만 한다
## - 언데드: 핫바의 머리뼈가 소환 중이 아니고 마나가 넉넉하면 숫자키 → G로 다시 소환한다
## - 물러나기(retreat_to): 쏘지 않고 탈출 지점으로 길찾기로 가며, 뛸 수 있으면 뛰고 예고된 공격만 구르기로 피한다
## - 시야 (--sight, 기본 full): full이면 모든 몬스터·돌의 위치를 안다. cone이면 지역에 시야(Vision)가 있을 때 플레이어나 언데드 시야에 보이는 몬스터·돌만 안다. 처음 보인 뒤 반응 시간이 지나야 겨눈다.
##   예고·돌은 보이기 시작한 때부터 반응 시간을 센다
## - 둘러보기 (사용자 확정): 겨눌 몬스터가 없으면 걷는 방향을 본다. scan_interval초마다 좌우 scan_angle도를 한 번씩 scan_look_time초 동안 본다.
##   안 보이는 몬스터에게 맞으면 hit_turn_delay초 뒤 맞은 쪽을 hit_look_time초 동안 본다 (맵을 걸을 때는 look_around를 부른다)
## - 놓친 몬스터 (사용자 결정): 살아 있는 몬스터가 시야에서 사라지면 반응 시간 동안 마우스를 그대로 두고, 그 뒤 last_seen_look_time초 동안 마지막으로 본 자리를 본다.
##   실제 위치가 아니라 마지막으로 본 자리만 쓴다. 싸우는 중이면 그다음 둘러보기도 그쪽을 기준으로 한다
## 실력은 반응 시간, 조준 오차, 회피 성공률(, 둘러보는 간격) 값으로 정한다 (SKILLS, 임시값).

## 실력 단계: [이름, 반응 시간(초), 조준 오차(도, 표준편차), 회피 성공률, 둘러보는 간격(초, 사용자 확정)]
const SKILLS: Dictionary = {
	&"skilled": {"name": "숙련", "reaction": 0.18, "aim_error": 0.0, "dodge": 0.9, "scan_interval": 1.2},
	&"normal": {"name": "보통", "reaction": 0.30, "aim_error": 3.5, "dodge": 0.6, "scan_interval": 2.0},
	&"novice": {"name": "초보", "reaction": 0.45, "aim_error": 7.0, "dodge": 0.25, "scan_interval": 3.0},
}

## 핫바 칸을 고르는 숫자키 (칸 순서대로)
const HOTBAR_KEYS: Array[Key] = [KEY_1, KEY_2]
## 물러날 때 탈출 지점에서 이 거리 안이면 멈춰 선다 (탈출 지점 반지름보다 작게, 픽셀)
const RETREAT_ARRIVE: float = 6.0

## 근접 몬스터와 유지하려는 거리 (픽셀)
var keep_distance: float = 100.0
## 이보다 가까우면 뛴다 (픽셀)
var run_distance: float = 55.0
## 몬스터 → 언데드 방향과 몬스터 → 네크로맨서 방향의 각도가 이보다 작으면 줄 위에 있다고 보고 비킨다 (도)
var line_avoid_angle: float = 25.0
## 이 거리 안의 몬스터에 대해서만 줄 피하기를 한다 (픽셀)
var line_avoid_range: float = 220.0
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
## 봇이 상대할 몬스터를 고르는 거름 (Monster -> bool). 비어 있으면 살아 있는 몬스터 모두. 실제 맵에서 걸려 온 몬스터만 상대할 때 쓴다
var monster_filter: Callable = Callable()
## 둘러보기 (사용자 확정): 걷는 방향에서 좌우 이 각도 (도), 한쪽을 보는 시간 (초)
var scan_angle: float = 60.0
var scan_look_time: float = 0.4
## 안 보이는 쪽에서 맞으면 이만큼 뒤에 맞은 쪽을 본다 (초, 사용자 확정)
var hit_turn_delay: float = 0.3
## 맞은 쪽을 보는 시간 (초, 제안)
var hit_look_time: float = 0.8
## 놓친 몬스터의 마지막 자리를 보는 시간 (초, 제안)
var last_seen_look_time: float = 1.0
## 몬스터를 앞서 겨눌 때 실제 몸에서 벗어나도 되는 각도 (도, 제안). 시야가 완전히 밝은 각도(좌우 23도) 안쪽
var max_lead_angle: float = 20.0
## 둘러볼 때 마우스를 몸에서 이만큼 떨어진 곳에 둔다 (픽셀)
var look_distance: float = 100.0

var skill: Dictionary
## 봇이 몬스터를 아는 방식 (명령줄 --sight=full / --sight=cone). full: 시야와 상관없이 모든 몬스터와 돌의 위치를 안다 (기본값, 사용자 결정 2026-11-09).
## cone: 플레이어·언데드 시야에 보이는 것만 안다. 실력 차이는 full이면 반응 시간·조준 오차·회피 성공률로만 나뉜다.
var sight: StringName = &"full"
var _test: ScenarioTest
var _necromancer: Necromancer
var _aim_offset_deg: float = 0.0
var _aim_timer: float = 0.0
var _last_positions: Dictionary = {}
## 지금 보고 있는 예고: 행동 조각 → {"seen": 처음 본 시각, "try": 피하기를 시도할지, "done": 굴렀는지}
var _telegraphs: Dictionary = {}
## 지금 날아오는 돌: Stone → {"seen": 처음 본 시각, "try": 피하기를 시도할지}
var _stones: Dictionary = {}
## 돌 줄에서 몸 가운데가 이 거리 안이면 맞을 것으로 보고 옆으로 걷는다 (몸 반지름 + 돌 반지름 + 여유)
var stone_danger_width: float = 12.0
## 그림자 원 가장자리에서 이만큼 더 벗어난다 (몸 반지름과 여유)
var shadow_margin: float = 8.0
var _time: float = 0.0
var _running: bool = false
var _summon_cooldown: float = 0.0
var _undead_skulls: Array[Skull] = []
var _key_queue: Array[Key] = []
## 측정: 앞서 겨누기를 계산한 프레임 수, 그중 max_lead_angle 제한에 걸린 프레임 수 (측정용, 동작을 바꾸지 않는다)
var lead_checks: int = 0
var lead_clamped: int = 0
## 측정: 쏜 탄 수, 맞힌 탄 수, 구른 횟수
var shots: int = 0
var hits: int = 0
var rolls: int = 0
## 측정: 본 예고 수(날아오는 돌 포함), 소환 키를 누른 횟수, 몬스터가 가장 가까이 온 거리
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
## 측정: 언데드가 죽은 판정으로 사라진 물리 프레임 번호들 (같은 프레임에 함께 죽었는지 본다)
var undead_death_frames: Array[int] = []
## 물러나는 중이면 이 자리(탈출 지점)로 간다. 쏘지 않고, 뛸 수 있으면 뛰고, 예고된 공격은 구르기로 피한다 (retreat_to로 켠다)
var retreating: bool = false
var _retreat_point: Vector2 = Vector2.ZERO
var _retreat_follower: PathFollower

## 시야: 몬스터마다 처음 보인 시각, 마지막으로 걸은 방향, 둘러보기 시계, 맞은 쪽 보기 (-1이면 안 함)
var _seen_at: Dictionary = {}
var _walk_direction: Vector2 = Vector2.RIGHT
var _scan_timer: float = 0.0
var _hit_timer: float = -1.0
var _hit_direction: Vector2 = Vector2.ZERO
var _last_health: float = -1.0
## 보이는 몬스터마다 지금 자리, 가장 최근에 놓친 몬스터의 마지막 자리와 놓친 시각 (-1이면 없음)
var _last_seen: Dictionary = {}
var _lost_position: Vector2 = Vector2.ZERO
var _lost_at: float = -1.0

## 진행 중인 무리 동시 공격: 일부러 놓치는지, 시작할 때 체력, 예고가 안 보인 지 얼마나 됐는지
var _group_active: bool = false
var _group_missed: bool = false
var _group_health_before: float = 0.0
var _group_quiet_time: float = 0.0


func _init(test: ScenarioTest, necromancer: Necromancer, skill_id: StringName) -> void:
	_test = test
	_necromancer = necromancer
	skill = SKILLS[skill_id]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sight="):
			sight = StringName(arg.trim_prefix("--sight="))
	aim_resample_interval = necromancer.attack.windup + necromancer.attack.cooldown
	_necromancer.get_parent().child_entered_tree.connect(_on_actor_added)
	_necromancer.summoner.roster.unsummoned.connect(func(_skull: Skull, died: bool) -> void:
		if died:
			undead_died += 1
			undead_death_frames.append(Engine.get_physics_frames())
		else:
			undead_released += 1)


## 핫바 칸 순서대로 소환할 머리뼈 (언데드와 함께 싸울 때)
func set_undead_skulls(skulls: Array[Skull]) -> void:
	_undead_skulls = skulls


## 언데드를 모두 잃었는지: 소환할 머리뼈가 있었고, 모두 소환 중이 아니며 다시 소환할 수도 없다 (체력 0 또는 내구도 0)
func lost_all_undead() -> bool:
	if _undead_skulls.is_empty():
		return false
	var roster: UndeadRoster = _necromancer.summoner.roster
	for skull: Skull in _undead_skulls:
		if roster.is_summoned(skull) or not ((skull.awakened and skull.health <= 0.0) or skull.is_broken()):
			return false
	return true


## 지금부터 point(탈출 지점)로 물러난다. 몬스터가 있어도 싸우지 않고 그쪽으로 간다 (벽은 길찾기로 돌아간다).
func retreat_to(point: Vector2) -> void:
	retreating = true
	_retreat_point = point
	_retreat_follower = PathFollower.new(Vector2(_necromancer.body_radius, _necromancer.body_radius), Vector2(0, -_necromancer.body_radius))


## 물러나는 중 한 프레임: 쏘지 않고 탈출 지점으로 가며, 예고된 공격은 구르기로 피한다 (다가오는 몬스터를 피해 뛰기도 한다).
func _retreat_tick(monsters: Array[Monster], delta: float) -> void:
	_test.press_mouse(false)
	if not monsters.is_empty() and _try_dodge(monsters):
		return
	if _necromancer.is_rolling():
		return
	var direction: Vector2 = Vector2.ZERO
	if _necromancer.global_position.distance_to(_retreat_point) > RETREAT_ARRIVE:
		direction = _retreat_follower.get_direction(_necromancer, _retreat_point)
	_test.press_moves(direction)
	_set_running(direction != Vector2.ZERO and _necromancer.stamina.can_run())
	look_around(delta, direction)


## 물리 프레임마다 부른다.
func tick(delta: float) -> void:
	_time += delta
	_summon_cooldown = maxf(_summon_cooldown - delta, 0.0)
	_press_queued_key()
	var monsters: Array[Monster] = _alive_monsters()
	_update_seen(monsters)
	_check_hit()
	if retreating:
		_retreat_tick(monsters, delta)
		return
	if monsters.is_empty():
		release_all()
		look_around(delta, Vector2.ZERO)
		return
	_track_group_attack(monsters, delta)
	# 겨누고 거리를 두는 것은 보인 뒤 반응 시간이 지난 몬스터만. 예고 피하기는 보이는 몬스터 모두 (예고를 본 때부터 반응 시간을 센다).
	var known: Array[Monster] = monsters.filter(func(m: Monster) -> bool: return _time - _seen_at[m] >= skill["reaction"])
	if known.is_empty():
		_test.press_mouse(false)
		look_around(delta, Vector2.ZERO)
	else:
		_aim_and_fire(_nearest(known), delta, _should_flee(known))
	if not _try_dodge(monsters) and not _try_sidestep_stones():
		if known.is_empty():
			_test.press_moves(Vector2.ZERO)
			_set_running(false)
		else:
			_move(known)
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


## 살아 있고 지금 보이는 몬스터 (monster_filter가 있으면 그것도 통과한 것)
func _alive_monsters() -> Array[Monster]:
	var result: Array[Monster] = []
	for monster: Monster in _all_alive_monsters():
		if (not monster_filter.is_valid() or monster_filter.call(monster)) and _can_see(monster.global_position):
			result.append(monster)
	return result


func _all_alive_monsters() -> Array[Monster]:
	var result: Array[Monster] = []
	for node: Node in _test.get_nodes_in_group(&"monsters"):
		var monster: Monster = node as Monster
		if monster != null and not monster.is_queued_for_deletion() and monster.health > 0.0:
			result.append(monster)
	return result


## 지역의 시야 (없으면 null: 모두 보인다)
func _vision() -> Vision:
	var scene: Node = _test.current_scene
	if scene == null or not scene.has_method(&"get_vision"):
		return null
	return scene.call(&"get_vision")


func _can_see(world: Vector2) -> bool:
	if sight == &"full":
		return true
	var vision: Vision = _vision()
	return vision == null or vision.is_visible_at(world)


## 보이는 몬스터마다 처음 보인 시각을 적고, 안 보이게 된 몬스터는 지운다 (다시 보이면 반응 시간을 처음부터 센다).
func _update_seen(visible: Array[Monster]) -> void:
	var now: Dictionary = {}
	for monster: Monster in visible:
		now[monster] = true
		_last_seen[monster] = monster.global_position
		if not _seen_at.has(monster):
			_seen_at[monster] = _time
	for monster: Variant in _seen_at.keys():
		if not now.has(monster):
			_seen_at.erase(monster)
			# 다시 보일 때 안 보이던 동안의 이동이 한 프레임 속도로 계산되지 않게 지운다.
			_last_positions.erase(monster)
			# 죽어서 사라진 몬스터는 찾지 않는다.
			if is_instance_valid(monster) and not monster.is_queued_for_deletion() and monster.health > 0.0:
				_lost_position = _last_seen[monster]
				_lost_at = _time
			_last_seen.erase(monster)


## 체력이 줄었는데 때린 몬스터(네크로맨서를 노리는 가장 가까운 몬스터)가 안 보이면, 맞은 쪽 보기를 시작한다.
func _check_hit() -> void:
	var health: float = _necromancer.health
	if _last_health >= 0.0 and health < _last_health:
		var attacker: Monster = null
		for monster: Monster in _all_alive_monsters():
			if monster.get_target() == _necromancer and (attacker == null or monster.global_position.distance_to(_necromancer.global_position) < attacker.global_position.distance_to(_necromancer.global_position)):
				attacker = monster
		if attacker != null and not _can_see(attacker.global_position):
			_hit_timer = 0.0
			_hit_direction = _necromancer.get_body_center().direction_to(attacker.global_position)
	_last_health = health


## 겨눌 몬스터가 없을 때 마우스를 둔다: 걷는 방향(walk_direction이 ZERO면 마지막으로 걸은 방향), scan_interval초마다 좌우를 한 번씩 둘러봄,
## 안 보이는 쪽에서 맞았으면 맞은 쪽, 방금 몬스터를 놓쳤으면 마지막으로 본 자리. 맵을 걸을 때(싸우지 않을 때)는 밖에서 매 물리 프레임 부른다.
func look_around(delta: float, walk_direction: Vector2) -> void:
	if walk_direction != Vector2.ZERO:
		_walk_direction = walk_direction.normalized()
	var look: Vector2 = _walk_direction
	if _hit_timer >= 0.0:
		_hit_timer += delta
		if _hit_timer >= hit_turn_delay:
			look = _hit_direction
		if _hit_timer >= hit_turn_delay + hit_look_time:
			_hit_timer = -1.0
	elif _lost_at >= 0.0 and _time - _lost_at < skill["reaction"]:
		# 놓친 것을 알아차리기 전이다. 마우스를 그대로 둔다.
		return
	elif _lost_at >= 0.0 and _time - _lost_at < skill["reaction"] + last_seen_look_time:
		look = _necromancer.get_body_center().direction_to(_lost_position)
		if walk_direction == Vector2.ZERO and look != Vector2.ZERO:
			_walk_direction = look
	else:
		_scan_timer += delta
		var since: float = _scan_timer - skill["scan_interval"]
		if since >= 0.0 and since < scan_look_time:
			look = _walk_direction.rotated(deg_to_rad(-scan_angle))
		elif since >= scan_look_time and since < scan_look_time * 2.0:
			look = _walk_direction.rotated(deg_to_rad(scan_angle))
		elif since >= scan_look_time * 2.0:
			_scan_timer = 0.0
	_test.aim_mouse_at(_necromancer.get_body_center() + look * look_distance)


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
		# 한 발마다 다른 오차가 되도록 aim_resample_interval(_init에서 공격 간격과 맞춤)마다 다시 뽑는다.
		_aim_timer = aim_resample_interval
		_aim_offset_deg = randfn(0.0, skill["aim_error"]) if skill["aim_error"] > 0.0 else 0.0
	var origin: Vector2 = _necromancer.get_shot_origin()
	var center: Vector2 = target.global_position + PlaceholderBody.center(target.data)
	# 이동 방향 감안: 탄이 닿는 시간만큼 앞을 겨눈다.
	var velocity: Vector2 = Vector2.ZERO
	if _last_positions.has(target) and delta > 0.0:
		velocity = (target.global_position - _last_positions[target]) / delta
	var flight_time: float = origin.distance_to(center) / _necromancer.attack.projectile_speed
	var aim: Vector2 = _limit_lead(origin, center, center + velocity * flight_time)
	aim = origin + (aim - origin).rotated(deg_to_rad(_aim_offset_deg))
	_test.aim_mouse_at(aim)
	var in_range: bool = origin.distance_to(center) <= _necromancer.attack.projectile_range * fire_range_ratio
	_test.press_mouse(in_range and not fleeing)


## 앞서 겨눈 자리(lead)를 실제 몸(center)에서 max_lead_angle도 안쪽으로 줄인다. 빠르게 달려오는 몬스터를 앞서 겨누면 겨눌 자리가
## 봇의 몸 근처나 뒤쪽이 되어 마우스 방향이 튀고, 시야 부채꼴이 그 몬스터를 벗어난다.
func _limit_lead(origin: Vector2, center: Vector2, lead: Vector2) -> Vector2:
	var to_center: Vector2 = center - origin
	var angle: float = to_center.angle_to(lead - origin)
	var limit: float = deg_to_rad(max_lead_angle)
	lead_checks += 1
	if absf(angle) <= limit and origin.distance_to(lead) >= to_center.length() * 0.5:
		return lead
	lead_clamped += 1
	return origin + to_center.rotated(clampf(angle, -limit, limit))


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


## 날아오는 돌을 반응 시간 뒤 옆으로 걸어 피한다. 이번 프레임에 피하는 중이면 true (그동안 _move 대신).
func _try_sidestep_stones() -> bool:
	var center: Vector2 = _necromancer.get_body_center()
	var step: Vector2 = Vector2.ZERO
	var seen_now: Dictionary = {}
	for node: Node in _necromancer.get_parent().get_children():
		var stone: Stone = node as Stone
		# 그림자 원은 시야와 상관없이 보이므로 돌도 던진 순간부터 안다. 돌이 안 보여도 그림자로 알 수 있다.
		if stone == null or stone.is_queued_for_deletion() or not stone.hostile_groups.has(&"necromancer") or not (_can_see(stone.global_position) or stone.landing_radius > 0.0):
			continue
		seen_now[stone] = true
		if not _stones.has(stone):
			telegraphs_seen += 1
			_stones[stone] = {"seen": _time, "try": randf() < skill["dodge"]}
		var info: Dictionary = _stones[stone]
		if not info["try"] or _time - info["seen"] < skill["reaction"]:
			continue
		# 그림자 원 안이면 원 밖으로 걷는다 (돌이 도착하면 맞는 범위다).
		var ground: Vector2 = stone.global_position + stone.direction * (stone.max_distance - stone.get_traveled())
		var from_landing: Vector2 = center - ground
		if stone.landing_radius > 0.0 and from_landing.length() <= stone.landing_radius + shadow_margin:
			step = from_landing.normalized() if from_landing != Vector2.ZERO else stone.direction.orthogonal()
			continue
		var to_me: Vector2 = center - stone.global_position
		var along: float = to_me.dot(stone.direction)
		if along < 0.0:
			continue
		var off: Vector2 = to_me - stone.direction * along
		if off.length() > stone_danger_width:
			continue
		var side: Vector2 = stone.direction.orthogonal()
		if side.dot(off) < 0.0:
			side = -side
		step = side
	for stone: Variant in _stones.keys():
		if not seen_now.has(stone):
			_stones.erase(stone)
	if step == Vector2.ZERO:
		return false
	_test.press_moves(_keep_in_arena(step))
	_set_running(false)
	return true


func _move(monsters: Array[Monster]) -> void:
	if _necromancer.is_rolling():
		return
	var position: Vector2 = _necromancer.global_position
	var away: Vector2 = Vector2.ZERO
	for monster: Monster in monsters:
		var distance: float = position.distance_to(monster.global_position)
		if distance < keep_distance and distance > 0.0:
			away += monster.global_position.direction_to(position) * (keep_distance - distance) / keep_distance
	var sidestep: Vector2 = _line_avoidance(monsters)
	var direction: Vector2 = Vector2.ZERO
	var target: Monster = _nearest(monsters)
	var to_target: Vector2 = target.global_position - position
	if away != Vector2.ZERO:
		# 물러나되 옆으로도 돌아서 한 방향으로만 밀리지 않게 한다.
		direction = (away.normalized() + away.normalized().orthogonal() * 0.5).normalized()
	elif to_target.length() > _necromancer.attack.projectile_range * 0.85:
		direction = to_target.normalized()
	if sidestep != Vector2.ZERO:
		direction = (direction + sidestep.normalized() * 2.0).normalized()
	direction = _keep_in_arena(direction)
	_test.press_moves(direction)
	_set_running(_should_flee(monsters) and direction != Vector2.ZERO)


## 몬스터와 언데드를 잇는 줄 위(언데드 뒤쪽)에 있으면 그 줄에서 옆으로 비키는 방향. 없으면 ZERO.
func _line_avoidance(monsters: Array[Monster]) -> Vector2:
	var position: Vector2 = _necromancer.global_position
	var push: Vector2 = Vector2.ZERO
	for monster: Monster in monsters:
		var behavior: MonsterBehavior = monster.get_behavior()
		if behavior == null or not behavior.is_telegraphing():
			continue
		var to_me: Vector2 = position - monster.global_position
		if to_me.length() > line_avoid_range:
			continue
		for node: Node in _test.get_nodes_in_group(&"undead"):
			var undead: Node2D = node as Node2D
			if undead == null or undead.is_queued_for_deletion():
				continue
			var to_undead: Vector2 = undead.global_position - monster.global_position
			if to_undead.length() >= to_me.length() or to_undead == Vector2.ZERO:
				continue
			if rad_to_deg(absf(to_undead.angle_to(to_me))) < line_avoid_angle:
				var side: Vector2 = to_undead.normalized().orthogonal()
				push += side if side.dot(to_me) >= 0.0 else -side
	return push


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
