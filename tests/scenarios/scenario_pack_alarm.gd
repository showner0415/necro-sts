extends ScenarioTest
## 시나리오: 무리 경보 (박쥐가 아닌 무리). 무리 시험 지역(regions/test_pack.tscn)에서 무리를 코드로 새로 만든다.
## 1. 처음에는 두 무리(쥐 4, 쥐 3) 모두 평소 → 2. 한 마리만 맞으면 그 쥐가 신호(멈춤·깜빡임, 신호 시간) 뒤 무리 전체가 경보, 모두 네크로맨서를 노림
## → 3. 언데드가 나타나면 무리원마다 네크로맨서 편 전체 중 가장 가까운 대상을 노림 → 4. 다른 무리는 돕지 않음(평소 그대로)
## → 5. 모두가 추격 포기 조건(350px)을 넘으면 함께 포기하고 그 자리에 머묾 → 5-1. 평소인 다른 무리는 맞지 않고 한 마리가 감지만 해도
## 그 쥐가 신호 뒤 무리 전체가 경보 → 6. 섞인 무리(멧돼지 + 쥐)는 무리원 모두가 넘어야 포기
## (쥐는 350px를 넘어도 멧돼지의 추격 6초까지 함께 쫓음). 몬스터는 데이터 복사로 배회 0·체력 크게 한다. 실제 .tres는 바꾸지 않는다.

const PACK_SCENE: String = "res://regions/test_pack.tscn"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const BOAR_PATH: String = "res://data/monsters/boar.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 30
const TOUGH_HEALTH: float = 1000.0
## 네크로맨서와 두 무리의 자리 (네크로맨서는 쥐 감지 80 밖, 추격 포기 350 안)
const NECRO_START: Vector2 = Vector2(0, 200)
const PACK_A: Vector2 = Vector2(0, -40)
const PACK_B: Vector2 = Vector2(420, -40)
const A_OFFSETS: Array[Vector2] = [Vector2(-20, 0), Vector2(20, 0), Vector2(-10, 20), Vector2(10, -20)]
const B_OFFSETS: Array[Vector2] = [Vector2(-15, 0), Vector2(15, 0), Vector2(0, 20)]
## 신호 시간과 실제로 잰 시간의 허용 차이 (프레임). 무리는 몬스터 다음에 판단해서 한두 프레임 늦을 수 있다
const SIGNAL_TOLERANCE_FRAMES: int = 3
const TIMEOUT_FRAMES: int = 120
## 신호 중인 쥐가 멈춰 있다고 보는 속도 (픽셀/초)
const STILL_SPEED: float = 0.5
## 맞은 번쩍임(hit_flash_duration 0.1초)이 가실 때까지 밝기를 보지 않는 신호 프레임 수
const BLINK_SKIP_FRAMES: int = 8
## 3. 네크로맨서와 언데드를 무리 가운데에서 서로 반대쪽으로 이만큼 둔다 (쥐 감지 80 안)
const SPLIT_OFFSET: Vector2 = Vector2(0, 60)
const NEAREST_FRAMES: int = 30
## 가장 가까운 대상이 아닌 것을 노려도 되는 프레임 수 (거리가 거의 같을 때)
const NEAREST_SLACK: int = 2
## 5. 포기시키려고 네크로맨서를 무리 가운데에서 이만큼 옮긴다 (350 밖)
const FAR_OFFSET: Vector2 = Vector2(0, 600)
const STAY_FRAMES: int = 90
const STAY_TOLERANCE: float = 1.0
## 5-1. 무리 B의 첫 쥐에게서 이만큼 떨어진 곳에 네크로맨서를 둔다 (첫 쥐만 감지 80 안)
const DETECT_OFFSET: Vector2 = Vector2(-60, -20)
## 6. 섞인 무리: 네크로맨서를 무리 가운데에서 늘 이만큼 떨어뜨린다 (쥐의 350 밖, 멧돼지 감지 150 밖)
const MIXED_DISTANCE: float = 400.0
## 6. 포기 시각이 멧돼지 추격 시간에서 벗어나도 되는 시간 (초), 중간에 보는 시각 (초)
const MIXED_TOLERANCE: float = 0.25
const MIXED_CHECK_SECONDS: float = 3.0

var _necromancer: Necromancer
var _pack_a: MonsterPack
var _pack_b: MonsterPack
var _rats_a: Array[Monster] = []
var _rats_b: Array[Monster] = []


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


func _make_pack(monsters: Array[Monster]) -> MonsterPack:
	var pack: MonsterPack = MonsterPack.new()
	pack.set_members(monsters)
	current_scene.add_child(pack)
	return pack


func _clear() -> void:
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	for node: Node in current_scene.get_children():
		if node is MonsterPack:
			node.free()


func _target_name(monster: Monster) -> String:
	var target: Node2D = monster.get_target()
	if target == null:
		return "없음"
	return "네크로맨서" if target == _necromancer else "언데드"


func _describe(rats: Array[Monster]) -> String:
	return ", ".join(rats.map(func(rat: Monster) -> String: return _target_name(rat)))


func _center(monsters: Array[Monster]) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for monster: Monster in monsters:
		sum += monster.global_position
	return sum / monsters.size()


func _run() -> void:
	_necromancer = find_necromancer()
	_necromancer.max_health = 100000.0
	_necromancer.health = _necromancer.max_health
	_clear()
	_necromancer.global_position = NECRO_START
	var rat_data: MonsterData = _tough(RAT_PATH)
	for offset: Vector2 in A_OFFSETS:
		_rats_a.append(_spawn(rat_data, PACK_A + offset))
	for offset: Vector2 in B_OFFSETS:
		_rats_b.append(_spawn(rat_data, PACK_B + offset))
	_pack_a = _make_pack(_rats_a)
	_pack_b = _make_pack(_rats_b)
	await wait_frames(3)

	# 1. 처음: 모두 평소
	var calm: bool = _pack_a.uses_alarm() and _pack_a.get_alarm_state() == PackAlarm.State.CALM and _pack_b.get_alarm_state() == PackAlarm.State.CALM \
			and (_rats_a + _rats_b).all(func(rat: Monster) -> bool: return rat.get_target() == null)
	if not _check("처음에는 두 무리 모두 평소", calm, "무리 A 경보 %s (경보를 쓰는 무리 %s), 무리 B 경보 %s, A 대상 [%s], B 대상 [%s], 네크로맨서와 A 가운데 %.0f (쥐 감지 %.0f)" % [
			PackAlarm.State.keys()[_pack_a.get_alarm_state()], _pack_a.uses_alarm(), PackAlarm.State.keys()[_pack_b.get_alarm_state()],
			_describe(_rats_a), _describe(_rats_b), _center(_rats_a).distance_to(_necromancer.global_position), rat_data.detect_range]):
		finish(false)
		return
	if not await _signal_then_alert():
		return
	if not await _each_picks_nearest():
		return
	if not _other_pack_stays():
		return
	if not await _give_up_and_stay():
		return
	if not await _detect_signals_then_alert():
		return
	await _mixed_pack_gives_up_together()


## 2. 한 마리만 맞으면 신호 뒤 무리 전체가 경보
func _signal_then_alert() -> bool:
	var shot: Monster = _rats_a[0]
	var signal_frames: int = roundi(shot.data.alarm_signal_time * Engine.physics_ticks_per_second)
	shot.take_damage(0.1, _necromancer)
	var signalling_frames: int = 0
	var fastest: float = 0.0
	var brightest: float = 0.0
	var dimmest: float = INF
	var early_targets: int = 0
	var alert_frame: int = -1
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if shot.is_alarm_signalling():
			signalling_frames += 1
			# 무리는 몬스터 다음에 판단하므로, 신호가 정해진 첫 프레임에는 몬스터가 이미 움직였다.
			if signalling_frames > 1:
				fastest = maxf(fastest, shot.velocity.length())
			# 맞은 번쩍임(0.1초)이 가신 뒤의 깜빡임만 본다.
			if signalling_frames > BLINK_SKIP_FRAMES:
				brightest = maxf(brightest, shot.modulate.r)
				dimmest = minf(dimmest, shot.modulate.r)
		if _pack_a.get_alarm_state() != PackAlarm.State.ALERT:
			for rat: Monster in _rats_a.slice(1):
				if rat.get_target() != null:
					early_targets += 1
			continue
		if _rats_a.all(func(rat: Monster) -> bool: return rat.get_target() == _necromancer):
			alert_frame = frame + 1
			break
	var ok: bool = absi(signalling_frames - signal_frames) <= SIGNAL_TOLERANCE_FRAMES and fastest <= STILL_SPEED \
			and absf(brightest - shot.alarm_blink_brightness) < 0.01 and absf(dimmest - 1.0) < 0.01 and early_targets == 0 and alert_frame >= 0 and alert_frame <= signal_frames + SIGNAL_TOLERANCE_FRAMES * 2
	return _check("한 마리만 맞아도 신호 뒤 무리 전체가 경보", ok,
			"맞은 쥐의 신호 %d프레임 (신호 시간 %.2f초 = %d프레임), 신호 중 가장 빠른 속도 %.1f (첫 프레임 뺌), 번쩍임이 가신 뒤 밝기 %.1f배 ↔ %.1f배 (깜빡임 %.1f배), 경보 전에 대상을 정한 다른 쥐 %d번, %d프레임 만에 4마리 모두 %s" % [
				signalling_frames, shot.data.alarm_signal_time, signal_frames, fastest, dimmest, brightest, shot.alarm_blink_brightness, early_targets, alert_frame, _describe(_rats_a)])


## 3. 언데드가 나타나면 무리원마다 네크로맨서 편 전체 중 가장 가까운 대상
func _each_picks_nearest() -> bool:
	var undead: Node2D = await _summon_undead()
	if undead == null:
		return _check("언데드 소환", false, "언데드가 나오지 않음")
	# 네크로맨서와 언데드를 무리의 양쪽에 두어, 무리원마다 가까운 쪽이 갈리게 한다.
	var center: Vector2 = _center(_rats_a)
	_necromancer.global_position = center + SPLIT_OFFSET
	undead.global_position = center - SPLIT_OFFSET
	var wrong: int = 0
	var on_undead: int = 0
	var on_necro: int = 0
	for frame: int in NEAREST_FRAMES:
		await wait_frames(1)
		for rat: Monster in _rats_a:
			var to_necro: float = rat.global_position.distance_to(_necromancer.global_position)
			var to_undead: float = rat.global_position.distance_to(undead.global_position)
			var nearest: Node2D = undead if to_undead < to_necro else _necromancer
			if rat.get_target() != nearest:
				wrong += 1
			if rat.get_target() == undead:
				on_undead += 1
			elif rat.get_target() == _necromancer:
				on_necro += 1
	var ok: bool = wrong <= NEAREST_SLACK and on_undead > 0 and on_necro > 0
	return _check("무리원마다 가장 가까운 대상", ok,
			"%d프레임 동안 가장 가까운 대상이 아닌 것을 노린 횟수 %d (허용 %d), 언데드를 노린 횟수 %d, 네크로맨서를 노린 횟수 %d, 지금 [%s]" % [
				NEAREST_FRAMES, wrong, NEAREST_SLACK, on_undead, on_necro, _describe(_rats_a)])


## 4. 다른 무리는 돕지 않는다
func _other_pack_stays() -> bool:
	var ok: bool = _pack_b.get_alarm_state() == PackAlarm.State.CALM and _rats_b.all(func(rat: Monster) -> bool: return rat.get_target() == null)
	return _check("다른 무리는 돕지 않음", ok, "무리 A가 싸우는 동안 무리 B 경보 %s, B 대상 [%s], A 가운데에서 B 가운데까지 %.0f" % [
		PackAlarm.State.keys()[_pack_b.get_alarm_state()], _describe(_rats_b), _center(_rats_a).distance_to(_center(_rats_b))])


## 5. 모두가 포기 조건을 넘으면 함께 포기하고 그 자리에 머문다
func _give_up_and_stay() -> bool:
	_necromancer.summoner.toggle_selected()
	await wait_frames(2)
	_necromancer.global_position = _center(_rats_a) + FAR_OFFSET
	var gave_up: int = -1
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if _pack_a.get_alarm_state() == PackAlarm.State.CALM and _rats_a.all(func(rat: Monster) -> bool: return rat.get_target() == null):
			gave_up = frame + 1
			break
	if not _check("함께 포기", gave_up >= 0, "네크로맨서를 무리 가운데에서 %.0f 옮기고 %d프레임 만에 경보 %s, 대상 [%s]" % [
			FAR_OFFSET.length(), gave_up, PackAlarm.State.keys()[_pack_a.get_alarm_state()], _describe(_rats_a)]):
		return false
	var at: Array[Vector2] = []
	var chased: float = INF
	for i: int in _rats_a.size():
		at.append(_rats_a[i].global_position)
		chased = minf(chased, _rats_a[i].global_position.distance_to(PACK_A + A_OFFSETS[i]))
	await wait_frames(STAY_FRAMES)
	var moved: float = 0.0
	for i: int in _rats_a.size():
		moved = maxf(moved, _rats_a[i].global_position.distance_to(at[i]))
	var ok: bool = moved <= STAY_TOLERANCE and _pack_a.get_alarm_state() == PackAlarm.State.CALM
	return _check("포기한 자리에 머묾 (돌아가지 않음)", ok, "%d프레임 동안 가장 많이 움직인 쥐 %.1f (배회 0), 처음 자리에서 가장 덜 쫓아온 쥐 %.0f, 경보 %s" % [
		STAY_FRAMES, moved, chased, PackAlarm.State.keys()[_pack_a.get_alarm_state()]])


## 5-1. 맞지 않고 감지만 해도 그 무리원이 신호를 낸 뒤 무리 전체가 경보 (무리 B, 아직 평소)
func _detect_signals_then_alert() -> bool:
	var spotter: Monster = _rats_b[0]
	if _pack_b.get_alarm_state() != PackAlarm.State.CALM:
		return _check("감지로도 신호 뒤 경보", false, "시작할 때 무리 B가 평소가 아님: %s" % PackAlarm.State.keys()[_pack_b.get_alarm_state()])
	_necromancer.global_position = spotter.global_position + DETECT_OFFSET
	var in_range: Array[float] = []
	for rat: Monster in _rats_b:
		in_range.append(rat.global_position.distance_to(_necromancer.global_position))
	var signal_frames: int = roundi(spotter.data.alarm_signal_time * Engine.physics_ticks_per_second)
	var signalling_frames: int = 0
	var early_targets: int = 0
	var alert_frame: int = -1
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if spotter.is_alarm_signalling():
			signalling_frames += 1
		if _pack_b.get_alarm_state() != PackAlarm.State.ALERT:
			for rat: Monster in _rats_b.slice(1):
				if rat.get_target() != null:
					early_targets += 1
			continue
		if _rats_b.all(func(rat: Monster) -> bool: return rat.get_target() == _necromancer):
			alert_frame = frame + 1
			break
	var ok: bool = in_range[0] <= spotter.data.detect_range and in_range.slice(1).all(func(d: float) -> bool: return d > spotter.data.detect_range) \
			and absi(signalling_frames - signal_frames) <= SIGNAL_TOLERANCE_FRAMES and early_targets == 0 and alert_frame >= 0
	return _check("감지로도 신호 뒤 경보", ok,
			"네크로맨서까지 거리 %s (감지 %.0f, 첫 쥐만 안), 감지한 쥐의 신호 %d프레임 (신호 시간 %d프레임), 경보 전에 대상을 정한 다른 쥐 %d번, %d프레임 만에 3마리 모두 %s" % [
				in_range.map(func(d: float) -> String: return "%.0f" % d), spotter.data.detect_range, signalling_frames, signal_frames, early_targets, alert_frame, _describe(_rats_b)])


## 6. 섞인 무리는 무리원 모두가 자기 종의 조건을 넘어야 함께 포기한다
func _mixed_pack_gives_up_together() -> void:
	_clear()
	_rats_a.clear()
	_rats_b.clear()
	var boar: Monster = _spawn(_tough(BOAR_PATH), PACK_A)
	var rat: Monster = _spawn(_tough(RAT_PATH), PACK_A + Vector2(30, 0))
	var members: Array[Monster] = [boar, rat]
	var pack: MonsterPack = _make_pack(members)
	_necromancer.global_position = PACK_A + Vector2(0, MIXED_DISTANCE)
	await wait_frames(3)
	rat.take_damage(0.1, _necromancer)
	var alert: int = -1
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		_necromancer.global_position = _center(members) + Vector2(0, MIXED_DISTANCE)
		if pack.get_alarm_state() == PackAlarm.State.ALERT:
			alert = frame + 1
			break
	if alert < 0:
		_check("섞인 무리 경보", false, "%d프레임 안에 경보가 나지 않음" % TIMEOUT_FRAMES)
		finish(false)
		return
	var limit: float = boar.data.chase_time_limit
	var mid_ok: bool = false
	var mid_text: String = ""
	var gave_up_seconds: float = -1.0
	var rat_distance: float = 0.0
	var frames: int = roundi((limit + 2.0) * Engine.physics_ticks_per_second)
	for frame: int in frames:
		await wait_frames(1)
		# 무리가 다가오는 만큼 네크로맨서도 물러난다 (쥐의 거리 한계 밖, 멧돼지 감지 범위 밖).
		_necromancer.global_position = _center(members) + Vector2(0, MIXED_DISTANCE)
		var seconds: float = (frame + 1) / float(Engine.physics_ticks_per_second)
		rat_distance = rat.global_position.distance_to(_necromancer.global_position)
		if is_equal_approx(snappedf(seconds, 1.0 / Engine.physics_ticks_per_second), MIXED_CHECK_SECONDS) or (mid_text.is_empty() and seconds >= MIXED_CHECK_SECONDS):
			mid_ok = pack.get_alarm_state() == PackAlarm.State.ALERT and rat.get_target() == _necromancer and boar.get_target() == _necromancer \
					and rat_distance > rat.data.chase_attacker_limit
			mid_text = "%.1f초에 경보 %s, 쥐까지 %.0f (쥐 한계 %.0f), 쥐 대상 %s, 멧돼지 대상 %s" % [
				seconds, PackAlarm.State.keys()[pack.get_alarm_state()], rat_distance, rat.data.chase_attacker_limit, _target_name(rat), _target_name(boar)]
		if pack.get_alarm_state() == PackAlarm.State.CALM:
			gave_up_seconds = seconds
			break
	# 몬스터는 무리 다음 프레임에 대상을 다시 고른다.
	await wait_frames(1)
	var together: bool = gave_up_seconds > 0.0 and absf(gave_up_seconds - limit) <= MIXED_TOLERANCE \
			and rat.get_target() == null and boar.get_target() == null
	var ok: bool = mid_ok and together
	_check("섞인 무리는 무리원 모두가 넘어야 함께 포기", ok,
			"%s → 경보 뒤 %.2f초에 함께 포기 (멧돼지 추격 시간 %.1f초), 그때 쥐 대상 %s, 멧돼지 대상 %s" % [
				mid_text, gave_up_seconds, limit, _target_name(rat), _target_name(boar)])
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
