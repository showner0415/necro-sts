extends ScenarioTest
## 시나리오: 공격권 (쥐, 멧돼지, 투석병). 무리 시험 지역(regions/test_pack.tscn)에서 몬스터를 코드로 새로 놓는다.
## 1. 두 무리(쥐 3, 쥐 2)가 함께 네크로맨서를 노려도, 네크로맨서를 동시에 노리는 공격권은 쥐 2 + 추가 1을 넘지 않음 (두 무리가 나눠 씀),
##    공격권이 없는 쥐는 들어와 물지 않고 맴도는 거리(64)쯤에서 맴돌며, 추가 공격권은 1초 박자에만 생기고(8초에 2개 이상), 물면 반납해서 여러 쥐가 돌아가며 문다
## 2. 반납: 공격권을 든 쥐가 죽으면, 다른 대상(언데드)을 노리게 되면, 멀리 밀려나면 반납
## 3. 시간 제한: 맴도는 거리 안에서 대상에게 닿지 못하는 쥐(속도 0)는 공격권을 6초 들고 있다가 반납하고, 그 뒤 1초 동안 그 대상의 공격권을 다시 받지 못함
## 4. 멧돼지 1 + 쥐 2가 섞인 무리: 멧돼지 공격권(1)과 쥐 공격권(2)을 따로 셈 (둘이 함께 들 수 있음)
## 5. 멧돼지 둘·투석병 둘이 한 대상을 노려도 종마다 보통 1을, 추가 공격권은 대상 하나에 하나를 넘지 않고, 공격권이 없는 멧돼지·투석병은 맴도는 거리(96·170)쯤에서 기다림
## 6. 박쥐는 공격권을 쓰지 않음 (늘 공격해도 됨)
## 몬스터는 데이터 복사로 배회 0·체력 크게 한다. 네크로맨서는 체력을 크게 한다. 실제 .tres는 바꾸지 않는다.

const PACK_SCENE: String = "res://regions/test_pack.tscn"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const BAT_PATH: String = "res://data/monsters/bat.tres"
const BOAR_PATH: String = "res://data/monsters/boar.tres"
const GOBLIN_PATH: String = "res://data/monsters/goblin_slinger.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 30
const TOUGH_HEALTH: float = 1000.0
const NECRO_SPOT: Vector2 = Vector2(0, 100)
## 두 무리의 자리 (네크로맨서에게서, 쥐 감지 80 밖)
const PACK_A_OFFSETS: Array[Vector2] = [Vector2(-20, -150), Vector2(0, -160), Vector2(20, -150)]
const PACK_B_OFFSETS: Array[Vector2] = [Vector2(150, -10), Vector2(160, 10)]
const TIMEOUT_FRAMES: int = 120
## 1. 지켜보는 시간, 맴도는 거리를 재기 전에 기다리는 시간 (프레임)
const WATCH_FRAMES: int = 480
const SETTLE_FRAMES: int = 90
## 1. 공격권 없이 공격 거리 안에 들어와도 되는 프레임 수 (반납된 프레임에 아직 붙어 있는 경우), 맴도는 거리의 허용 차이 (픽셀)
const CLOSE_SLACK_FRAMES: int = 6
const WAIT_TOLERANCE: float = 12.0
## 1. 지켜보는 동안 적어도 이만큼 추가 공격권이 생기고(1초 넘게 띄어서), 이만큼 다른 쥐가 공격권을 들어야 한다
const MIN_EXTRA: int = 2
const MIN_DISTINCT_HOLDERS: int = 4
## 2. 밀어내는 거리 (반납 기준 48 넘게)
const KNOCK: Vector2 = Vector2(60, 0)
## 3. 반납 시각이 시간 제한에서 벗어나도 되는 시간 (초)
const LIMIT_TOLERANCE: float = 0.05
## 3. 닿지 못하는 쥐의 자리: 맴도는 거리 안(공격권을 묻는다), 공격 거리 밖(물지 못한다)
const STUCK_OFFSET: Vector2 = Vector2(0, -40)
## 4. 섞인 무리의 자리 (멧돼지, 쥐, 쥐), 5. 멧돼지 둘·투석병 둘의 자리 (네크로맨서에게서, 감지 밖. 무리 경보로 함께 온다)
const MIXED_OFFSETS: Array[Vector2] = [Vector2(0, -230), Vector2(-20, -215), Vector2(20, -215)]
const BOAR_GOBLIN_OFFSETS: Array[Vector2] = [Vector2(-30, -240), Vector2(30, -240), Vector2(-220, -60), Vector2(220, -60)]
## 5. 공격을 끝내고 맴도는 거리로 돌아가는 시간을 빼려고, 이 프레임 수 넘게 공격권 없이 기다린 몸의 거리만 잰다
const WAIT_SETTLE_FRAMES: int = 120

var _necromancer: Necromancer
var _board: AttackTokenBoard
var _rats: Array[Monster] = []
var _pack_a: Array[Monster] = []
var _pack_b: Array[Monster] = []


func get_start_scene() -> String:
	return PACK_SCENE


func _on_scene_ready() -> void:
	_run()


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
	return ok


func _tough(path: String) -> MonsterData:
	var data: MonsterData = (load(path) as MonsterData).duplicate()
	data.wander_speed = 0.0
	data.max_health = TOUGH_HEALTH
	return data


func _spawn(data: MonsterData, at: Vector2) -> Monster:
	var monster: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	monster.data = data
	monster.position = at
	_necromancer.get_parent().add_child(monster)
	return monster


func _make_pack(monsters: Array[Monster]) -> void:
	var pack: MonsterPack = MonsterPack.new()
	pack.set_members(monsters)
	current_scene.add_child(pack)


func _clear() -> void:
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	for node: Node in current_scene.get_children():
		if node is MonsterPack:
			node.free()


func _run() -> void:
	_necromancer = find_necromancer()
	_necromancer.max_health = 1000000.0
	_necromancer.health = _necromancer.max_health
	_board = get_first_node_in_group(&"attack_tokens") as AttackTokenBoard
	if _board == null:
		fail_step("준비", "지역에 공격권(attack_tokens)이 없음")
		return
	_clear()
	_necromancer.global_position = NECRO_SPOT
	var rat_data: MonsterData = _tough(RAT_PATH)
	for offset: Vector2 in PACK_A_OFFSETS:
		_pack_a.append(_spawn(rat_data, NECRO_SPOT + offset))
	for offset: Vector2 in PACK_B_OFFSETS:
		_pack_b.append(_spawn(rat_data, NECRO_SPOT + offset))
	_rats = _pack_a + _pack_b
	_make_pack(_pack_a)
	_make_pack(_pack_b)
	await wait_frames(3)
	if not await _limit_wait_and_extra():
		return
	if not await _released():
		return
	if not await _time_limit():
		return
	if not await _mixed_pack():
		return
	if not await _boars_and_goblins():
		return
	_bats_unlimited()


## 1. 동시에 노리는 수, 맴돌기, 추가 공격권, 돌아가며 물기
func _limit_wait_and_extra() -> bool:
	var tokens: AttackTokens = _board.tokens
	_pack_a[0].take_damage(0.1, _necromancer)
	_pack_b[0].take_damage(0.1, _necromancer)
	var extra_before: int = tokens.extra_granted
	var health_before: float = _necromancer.health
	var max_normal: int = 0
	var max_extra: int = 0
	var close_without: int = 0
	var wait_sum: float = 0.0
	var wait_count: int = 0
	var holders: Dictionary = {}
	var packs_holding: Dictionary = {}
	var extra_frames: Array[int] = []
	var last_granted: int = tokens.extra_granted
	for frame: int in WATCH_FRAMES:
		await wait_frames(1)
		max_normal = maxi(max_normal, tokens.count_normal(_necromancer, &"rat"))
		max_extra = maxi(max_extra, 1 if tokens.extra_holder(_necromancer) != null else 0)
		if tokens.extra_granted != last_granted:
			last_granted = tokens.extra_granted
			extra_frames.append(frame)
		for rat: Monster in _rats:
			var holding: bool = tokens.held_target(rat) == _necromancer
			if holding:
				holders[rat] = true
				packs_holding["A" if _pack_a.has(rat) else "B"] = true
				continue
			var behavior: ApproachBehavior = rat.get_behavior() as ApproachBehavior
			if rat.get_target() != _necromancer or behavior.get_phase() != ApproachBehavior.Phase.CLOSE_IN or behavior.is_winding_up():
				continue
			var distance: float = rat.global_position.distance_to(_necromancer.global_position)
			if distance <= rat.data.attack_range + 2.0:
				close_without += 1
			# 맴도는 거리는 공격권을 묻는 거리(맴도는 거리 + 띠 × 2) 안에서 공격권을 못 받은 쥐로만 잰다 (아직 다가오는 쥐는 빼고).
			if frame >= SETTLE_FRAMES and distance <= rat.data.token_wait_distance + behavior.wait_band * 2.0:
				wait_sum += distance
				wait_count += 1
	var wait_mean: float = wait_sum / maxi(wait_count, 1)
	var wait_distance: float = _rats[0].data.token_wait_distance
	var extras: int = tokens.extra_granted - extra_before
	var bites: float = health_before - _necromancer.health
	# 추가 공격권은 1초 박자에 맞춰서만 생긴다 (두 번 사이가 1초보다 짧지 않다).
	var beat: int = roundi(_board.extra_interval * Engine.physics_ticks_per_second)
	var min_gap: int = WATCH_FRAMES
	for i: int in range(1, extra_frames.size()):
		min_gap = mini(min_gap, extra_frames[i] - extra_frames[i - 1])
	var ok: bool = max_normal <= _rats[0].data.attack_tokens_per_target and max_extra <= 1 and close_without <= CLOSE_SLACK_FRAMES \
			and wait_count > 0 and absf(wait_mean - wait_distance) <= WAIT_TOLERANCE and extras >= MIN_EXTRA and min_gap >= beat - 1 \
			and holders.size() >= MIN_DISTINCT_HOLDERS and packs_holding.size() == 2 and bites > 0.0
	return _check("두 무리가 함께여도 공격권을 나눠 쓰고, 없는 쥐는 맴돌며 기다림", ok,
			"%.0f초 동안 쥐 5마리(무리 둘): 보통 공격권 가장 많을 때 %d (쥐 %d), 추가 공격권 가장 많을 때 %d, 생긴 추가 공격권 %d개 (적어도 %d, 생긴 프레임 %s, 가장 짧은 간격 %d프레임 ≥ %d), 공격권을 든 쥐 %d마리 (무리 %s), 공격권 없이 공격 거리 안 %d프레임 (허용 %d), 기다리는 쥐의 평균 거리 %.1f (맴도는 거리 %.0f ± %.0f, %d번 잼), 네크로맨서가 받은 피해 %.1f" % [
				WATCH_FRAMES / float(Engine.physics_ticks_per_second), max_normal, _rats[0].data.attack_tokens_per_target, max_extra, extras, MIN_EXTRA,
				extra_frames, min_gap, beat - 1, holders.size(), packs_holding.keys(), close_without, CLOSE_SLACK_FRAMES, wait_mean, wait_distance, WAIT_TOLERANCE, wait_count, bites])


## 공격권을 든 쥐 하나 (보통 공격권을 먼저, 없으면 추가 공격권). 없으면 생길 때까지 기다린다.
func _wait_holder(extra_ok: bool = true) -> Monster:
	for frame: int in TIMEOUT_FRAMES:
		for rat: Monster in _rats:
			if is_instance_valid(rat) and _board.tokens.held_target(rat) == _necromancer and (extra_ok or not _board.tokens.holds_extra(rat)):
				return rat
		await wait_frames(1)
	return null


## 2. 죽음, 대상이 바뀜, 멀리 밀려남으로 반납
func _released() -> bool:
	var tokens: AttackTokens = _board.tokens
	var dying: Monster = await _wait_holder()
	if dying == null:
		return _check("반납: 죽음", false, "공격권을 든 쥐가 없음")
	dying.take_damage(TOUGH_HEALTH * 10.0, _necromancer)
	var died_ok: bool = not tokens.holders_of(_necromancer).has(dying)
	_rats.erase(dying)
	_pack_a.erase(dying)
	_pack_b.erase(dying)
	if not _check("반납: 죽음", died_ok, "공격권을 든 쥐가 죽은 바로 뒤 네크로맨서의 공격권을 든 몸 %d (죽은 쥐 없음 %s)" % [tokens.holders_of(_necromancer).size(), died_ok]):
		return false

	var switching: Monster = await _wait_holder()
	var undead: Node2D = await _summon_undead()
	if switching == null or undead == null:
		return _check("반납: 대상이 바뀜", false, "공격권을 든 쥐 %s, 언데드 %s" % [switching, undead])
	# 언데드를 그 쥐 바로 옆에 두어, 그 쥐가 네크로맨서보다 가까운 언데드를 노리게 한다.
	undead.global_position = switching.global_position + Vector2(0, 10)
	var switched: int = -1
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if switching.get_target() == undead:
			switched = frame + 1
			break
	var switch_ok: bool = switched >= 0 and tokens.held_target(switching) != _necromancer
	if not _check("반납: 대상이 바뀜", switch_ok, "%d프레임 만에 그 쥐가 언데드를 노림, 네크로맨서의 공격권 %s" % [
			switched, "반납함" if tokens.held_target(switching) != _necromancer else "아직 듦"]):
		return false
	_necromancer.summoner.toggle_selected()
	await wait_frames(2)

	var pushed: Monster = await _wait_holder()
	if pushed == null:
		return _check("반납: 멀리 밀려남", false, "공격권을 든 쥐가 없음")
	var before: bool = tokens.is_holding(pushed)
	pushed.knock_back(KNOCK, 0.2)
	var push_ok: bool = before and not tokens.is_holding(pushed)
	return _check("반납: 멀리 밀려남", push_ok, "%.0f 밀어내기 전 공격권 %s, 바로 뒤 %s (반납 기준 %.0f)" % [
		KNOCK.length(), before, tokens.is_holding(pushed), _board.knockback_release_distance])


## 3. 닿지 못하는 쥐는 시간 제한이 지나면 반납하고, 그 뒤 retry_block_time초 동안 그 대상의 공격권을 다시 받지 못한다
func _time_limit() -> bool:
	_clear()
	_rats.clear()
	var still: MonsterData = _tough(RAT_PATH)
	still.move_speed = 0.0
	var rat: Monster = _spawn(still, NECRO_SPOT + STUCK_OFFSET)
	await wait_frames(3)
	rat.take_damage(0.1, _necromancer)
	var held_from: int = -1
	var released_at: int = -1
	var held_again: int = -1
	var frames: int = roundi((_board.hold_time_limit + _board.retry_block_time + 1.0) * Engine.physics_ticks_per_second)
	for frame: int in frames:
		await wait_frames(1)
		var holding: bool = _board.tokens.is_holding(rat)
		if held_from < 0 and holding:
			held_from = frame
		elif held_from >= 0 and released_at < 0 and not holding:
			released_at = frame
		elif released_at >= 0 and holding:
			held_again = frame
			break
	var ticks: float = float(Engine.physics_ticks_per_second)
	var seconds: float = (released_at - held_from) / ticks if released_at >= 0 else -1.0
	var ok: bool = held_from >= 0 and absf(seconds - _board.hold_time_limit) <= LIMIT_TOLERANCE
	if not _check("반납: 시간 제한", ok, "닿지 못하는 쥐(속도 0)가 공격권을 %.2f초 들고 있다가 반납 (시간 제한 %.1f초), 대상까지 %.0f" % [
			seconds, _board.hold_time_limit, rat.global_position.distance_to(_necromancer.global_position)]):
		return false
	# 그 쥐는 그동안에도 프레임마다 묻는다 (맴도는 거리 안). 다른 쥐가 없으니 막는 시간이 지나면 곧 다시 받는다.
	var blocked: float = (held_again - released_at) / ticks if held_again >= 0 else -1.0
	var block_ok: bool = held_again >= 0 and absf(blocked - _board.retry_block_time) <= LIMIT_TOLERANCE
	return _check("시간 제한 뒤 잠깐 다시 못 받음", block_ok, "시간 제한으로 반납하고 %.2f초 뒤 다시 받음 (막는 시간 %.1f초)" % [blocked, _board.retry_block_time])


## 4. 멧돼지 + 쥐가 섞인 무리: 쥐 공격권과 멧돼지 공격권을 따로 센다 (둘이 함께 들 수 있다)
func _mixed_pack() -> bool:
	_clear()
	var tokens: AttackTokens = _board.tokens
	var boar: Monster = _spawn(_tough(BOAR_PATH), NECRO_SPOT + MIXED_OFFSETS[0])
	var mixed: Array[Monster] = [boar]
	for i: int in range(1, MIXED_OFFSETS.size()):
		mixed.append(_spawn(_tough(RAT_PATH), NECRO_SPOT + MIXED_OFFSETS[i]))
	_make_pack(mixed)
	await wait_frames(3)
	boar.take_damage(0.1, _necromancer)
	var max_boar: int = 0
	var max_rat: int = 0
	var together: int = 0
	for frame: int in WATCH_FRAMES:
		await wait_frames(1)
		var boars: int = tokens.count_normal(_necromancer, &"boar")
		var rats: int = tokens.count_normal(_necromancer, &"rat")
		max_boar = maxi(max_boar, boars)
		max_rat = maxi(max_rat, rats)
		if boars > 0 and rats > 0:
			together += 1
	var ok: bool = max_boar <= boar.data.attack_tokens_per_target and max_rat <= mixed[1].data.attack_tokens_per_target and together > 0
	return _check("섞인 무리는 종마다 따로 셈", ok, "%.0f초 동안 멧돼지 1 + 쥐 %d: 멧돼지 공격권 가장 많을 때 %d (멧돼지 %d), 쥐 공격권 가장 많을 때 %d (쥐 %d), 멧돼지와 쥐가 함께 든 프레임 %d" % [
			WATCH_FRAMES / float(Engine.physics_ticks_per_second), mixed.size() - 1, max_boar, boar.data.attack_tokens_per_target,
			max_rat, mixed[1].data.attack_tokens_per_target, together])


## 5. 멧돼지 둘·투석병 둘: 종마다 보통 1 + 추가 1(대상 하나에 하나)을 넘지 않고, 공격권이 없는 몸은 맴도는 거리(96·170)쯤에서 기다린다
func _boars_and_goblins() -> bool:
	_clear()
	var tokens: AttackTokens = _board.tokens
	var group: Array[Monster] = []
	for i: int in BOAR_GOBLIN_OFFSETS.size():
		group.append(_spawn(_tough(BOAR_PATH if i < 2 else GOBLIN_PATH), NECRO_SPOT + BOAR_GOBLIN_OFFSETS[i]))
	_make_pack(group)
	await wait_frames(3)
	group[0].take_damage(0.1, _necromancer)
	var max_normal: Dictionary = {&"boar": 0, &"goblin_slinger": 0}
	var max_kind_total: Dictionary = {&"boar": 0, &"goblin_slinger": 0}
	var max_extra: int = 0
	var wait_sum: Dictionary = {&"boar": 0.0, &"goblin_slinger": 0.0}
	var wait_count: Dictionary = {&"boar": 0, &"goblin_slinger": 0}
	# 몸마다 공격권 없이 공격하지 않고 있은 프레임 수. 공격을 끝내고 맴도는 거리로 돌아가는 중인 몸은 빼려고 센다.
	var idle_frames: Dictionary = {}
	for frame: int in WATCH_FRAMES:
		await wait_frames(1)
		max_extra = maxi(max_extra, 1 if tokens.extra_holder(_necromancer) != null else 0)
		var holding_kind: Dictionary = {&"boar": 0, &"goblin_slinger": 0}
		for monster: Monster in group:
			var kind: StringName = monster.data.id
			var behavior: MonsterBehavior = monster.get_behavior()
			if tokens.held_target(monster) == _necromancer or behavior.is_busy() or monster.get_target() != _necromancer:
				idle_frames[monster] = 0
			else:
				idle_frames[monster] = idle_frames.get(monster, 0) + 1
			if tokens.held_target(monster) == _necromancer:
				holding_kind[kind] += 1
				continue
			# 자리 잡고 기다리는 몸만 잰다: WAIT_SETTLE_FRAMES 넘게 공격권도 없고 공격 중(예고·돌진·멈칫, 던지기)도 아니며, 공격권을 묻는 띠(맴도는 거리 + 띠 × 2) 안.
			if idle_frames[monster] < WAIT_SETTLE_FRAMES:
				continue
			var distance: float = monster.global_position.distance_to(_necromancer.global_position)
			if distance <= monster.data.token_wait_distance + behavior.wait_band * 2.0:
				wait_sum[kind] += distance
				wait_count[kind] += 1
		for kind: StringName in holding_kind:
			max_normal[kind] = maxi(max_normal[kind], tokens.count_normal(_necromancer, kind))
			max_kind_total[kind] = maxi(max_kind_total[kind], holding_kind[kind])
	var ok: bool = max_extra <= 1
	var text: PackedStringArray = []
	for kind: StringName in max_normal:
		var data: MonsterData = group[0].data if kind == &"boar" else group[2].data
		var mean: float = wait_sum[kind] / maxi(wait_count[kind], 1)
		ok = ok and max_normal[kind] <= data.attack_tokens_per_target and max_kind_total[kind] <= data.attack_tokens_per_target + 1 \
				and wait_count[kind] > 0 and absf(mean - data.token_wait_distance) <= WAIT_TOLERANCE
		text.append("%s: 보통 공격권 가장 많을 때 %d (%d), 보통+추가 가장 많을 때 %d, 기다리는 평균 거리 %.1f (맴도는 거리 %.0f ± %.0f, %d번 잼)" % [
				kind, max_normal[kind], data.attack_tokens_per_target, max_kind_total[kind], mean, data.token_wait_distance, WAIT_TOLERANCE, wait_count[kind]])
	return _check("멧돼지·투석병도 공격권을 기다림", ok, "%.0f초 동안 멧돼지 2 + 투석병 2, 추가 공격권 가장 많을 때 %d. %s" % [
			WATCH_FRAMES / float(Engine.physics_ticks_per_second), max_extra, " / ".join(text)])


## 6. 박쥐는 공격권을 쓰지 않는다
func _bats_unlimited() -> void:
	var bat: Monster = _spawn(load(BAT_PATH), NECRO_SPOT + Vector2(-200, 0))
	await wait_frames(2)
	var allowed: bool = true
	for i: int in 5:
		allowed = allowed and bat.request_attack(_necromancer)
	var ok: bool = allowed and not bat.is_holding_token() and bat.data.attack_tokens_per_target == 0
	_check("박쥐는 공격권을 쓰지 않음", ok, "박쥐 공격권 수 %d, 다섯 번 물어 모두 공격해도 됨 %s, 공격권을 듦 %s" % [
		bat.data.attack_tokens_per_target, allowed, bat.is_holding_token()])
	finish(ok)


## 쥐 언데드를 소환해 돌려준다 (네크로맨서 옆에 나온다).
func _summon_undead() -> Node2D:
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	hotbar.assign(0, skull)
	hotbar.select(0)
	_necromancer.summoner.toggle_selected()
	await wait_frames(2)
	var undead: Array[Node] = get_nodes_in_group(&"undead")
	return undead[0] as Node2D if not undead.is_empty() else null
