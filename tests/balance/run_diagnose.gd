extends "res://tests/balance/run_balance.gd"
## 밸런스 측정 결과의 원인을 재는 진단 (run_balance.gd와 같은 싸움터·봇). 판정이 없어서 run_all.sh에는 넣지 않는다.
##
## 돌진과 시야: 멧돼지가 돌진을 시작할 때 봇이 그 멧돼지를 보고 있었는지, 그 돌진에 맞았는지
##   bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_diagnose.gd -- --mode=charge_sight --runs=10
## 고블린과 언데드: 살아 있는 고블린이 있는 동안 봇이 무엇을 했는지 (쏨 / 사거리 밖 / 안 보임 / 도망), 누가 때렸는지
##   bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_diagnose.gd -- --mode=goblin_time --runs=50
## 고블린이 물러나지 않으면 어떻게 되는지 비교: -- --mode=goblin_time --no_retreat=1, 물러나는 속도를 바꿔 비교: --retreat_speed=30
## 박쥐·고블린의 겨누기와 시야: 봇이 겨눈 몬스터와 화면 방향의 차이, 시야가 튀는 정도, 공격이 시작될 때 봤는지와 그 공격에 맞았는지
##   bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_diagnose.gd -- --mode=aim_sight --runs=50
## 시야를 끄고 같은 싸움을 재서 비교: -- --mode=aim_sight --runs=50 --no_vision=1
## 시야를 따르기 전의 봇(커밋 f29cc34)으로도 돌도록 봇 내부는 Variant로 읽는다. 그 봇은 늘 모두 본다.

var _mode: String = "charge_sight"
var _no_retreat: bool = false
## 0 이상이면 테스트 안에서만 고블린이 물러나는 속도를 이 값으로 바꾼다 (--retreat_speed=30)
var _retreat_speed: float = -1.0
var _trace: bool = false
var _spawned: Array[Monster] = []
var _necromancer_ref: Variant = null
## 돌진: 행동 조각 → 추적 상태, 이번 판의 돌진 기록, 멧돼지를 놓친 프레임·구간
var _tracks: Dictionary = {}
var _charges: Array[Dictionary] = []
var _frames: int = 0
var _lost_frames: int = 0
var _lost_spells: int = 0
var _was_lost: bool = false
## 고블린: 이번 판의 프레임 집계
var _goblin: Dictionary = {}
## 겨누기와 시야: 대상 → 함께 싸우는 언데드 수 (설명되지 않은 차이가 나온 조건)
const AIM_SIGHT_CASES: Dictionary = {&"bat_pack": 0, &"goblin_pair": 2}
## 화면 방향과 겨눈 몬스터의 각도가 이보다 크면 완전히 밝은 곳 밖 / 부채꼴 밖이다 (도, 지금 시야 값)
const AIM_BRIGHT_ANGLE: float = 23.0
const AIM_CONE_ANGLE: float = 35.0
## 한 프레임에 화면 방향이 이보다 크게 돌면 "튐"으로 센다 (도)
const AIM_JUMP_ANGLE: float = 30.0
## 돌이나 박쥐가 사라질 때 네크로맨서에게서 이 거리 안이고 체력이 줄었으면 맞은 것으로 센다 (픽셀)
const AIM_HIT_DISTANCE: float = 24.0
var _no_vision: bool = false
var _aim: Dictionary = {}
var _attacks: Array[Dictionary] = []
var _dive_tracks: Dictionary = {}
var _stone_tracks: Dictionary = {}
var _last_facing: Vector2 = Vector2.ZERO
var _last_aimed_id: int = 0
var _last_health: float = 0.0


func _on_scene_ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg == "--no_retreat=1":
			_no_retreat = true
		elif arg == "--trace=1":
			_trace = true
		elif arg.begins_with("--retreat_speed="):
			_retreat_speed = arg.trim_prefix("--retreat_speed=").to_float()
		elif arg == "--no_vision=1":
			_no_vision = true
	if _mode == "charge_sight":
		_targets = [&"boar"]
		_undead_counts = [2]
	elif _mode == "aim_sight":
		_targets.assign(AIM_SIGHT_CASES.keys())
	else:
		_targets = [&"goblin_pair"]
		_undead_counts = [0, 2]
	_parse_args()
	if _mode == "charge_sight":
		_run_charge_sight()
	elif _mode == "aim_sight":
		_run_aim_sight()
	else:
		_run_goblin_time()


func _on_fight_start(necromancer: Necromancer, _bot: PlayerBot, spawned: Array[Monster]) -> void:
	_necromancer_ref = necromancer
	_spawned = spawned
	_tracks = {}
	_charges = []
	_frames = 0
	_lost_frames = 0
	_lost_spells = 0
	_was_lost = false
	_goblin = {"frames": 0, "firing": 0, "out_of_range": 0, "not_known": 0, "fleeing": 0, "distance": 0.0, "target_necromancer": 0, "target_undead": 0, "target_none": 0,
		"goblin_frames": 0, "moving": 0, "bolt_hits": 0, "undead_hits": 0, "first_kill": -1.0}
	_aim = {"frames": 0, "alive": 0, "seen": 0, "not_known": 0, "aim_frames": 0, "off_sum": 0.0, "off_bright": 0, "off_cone": 0, "jumps": 0, "switches": 0}
	_attacks = []
	_dive_tracks = {}
	_stone_tracks = {}
	_last_facing = Vector2.ZERO
	_last_aimed_id = 0
	_last_health = necromancer.health
	if _mode == "aim_sight":
		if _no_vision:
			(current_scene.call(&"get_vision") as Vision).set_active(false)
		return
	if _mode != "charge_sight":
		for monster: Monster in spawned:
			var behavior: ThrowBehavior = monster.get_behavior() as ThrowBehavior
			if _no_retreat:
				behavior.retreat_distance = 0.0
			if _retreat_speed >= 0.0:
				behavior.retreat_speed = _retreat_speed
			monster.hit_by.connect(func(source: Node2D) -> void:
				_goblin["bolt_hits" if source == necromancer else "undead_hits"] += 1)


func _on_fight_frame(necromancer: Necromancer, bot: PlayerBot, time: float) -> void:
	if _mode == "charge_sight":
		_track_charges(necromancer, bot, time)
	elif _mode == "aim_sight":
		_track_aim_sight(necromancer, bot)
	else:
		_track_goblin(necromancer, bot, time)


func _on_fight_end(result: Dictionary, _bot: PlayerBot) -> void:
	if _mode == "charge_sight":
		# 돌진에 맞아 죽으면 지역 씬이 사라지므로, 진행 중이던 돌진을 맞은 것으로 끝낸다.
		for track: Dictionary in _tracks.values():
			if track["state"] == ChargeBehavior.State.CHARGE and result["died"]:
				track["entry"]["damage"] = track["entry"]["health"]
		result["charges"] = _charges
		result["frames"] = _frames
		result["lost_frames"] = _lost_frames
		result["lost_spells"] = _lost_spells
	elif _mode == "aim_sight":
		# 공격을 맞고 죽으면 지역 씬이 사라지므로, 진행 중이던 돌진·날아오던 돌을 맞은 것으로 끝낸다.
		if result["died"]:
			for track: Dictionary in _dive_tracks.values():
				if track["state"] == DiveBehavior.State.DIVE and track.has("entry"):
					track["entry"]["hit"] = true
			for entry: Dictionary in _stone_tracks.values():
				entry["hit"] = true
		result["aim"] = _aim
		result["attacks"] = _attacks
	else:
		result["goblin"] = _goblin


## 살아 있는 대상
func _alive() -> Array[Monster]:
	# 죽어서 사라진 몸은 형이 있는 인자로 넘기면 오류이므로 filter 대신 여기서 확인한다.
	var result: Array[Monster] = []
	for monster: Variant in _spawned:
		if is_instance_valid(monster) and not monster.is_queued_for_deletion() and monster.health > 0.0:
			result.append(monster)
	return result


## 봇이 world를 볼 수 있는지 (시야를 따르기 전의 봇은 늘 true)
func _bot_sees(bot: Variant, world: Vector2) -> bool:
	return not bot.has_method(&"_can_see") or bot.call(&"_can_see", world)


## 봇이 monster를 겨눌 수 있는지 (보인 뒤 반응 시간이 지남)
func _bot_knows(bot: Variant, monster: Monster) -> bool:
	if not bot.has_method(&"_can_see"):
		return true
	return bot.get(&"_seen_at").has(monster) and bot.get(&"_time") - bot.get(&"_seen_at")[monster] >= bot.get(&"skill")["reaction"]


## 12프레임(0.2초)마다 한 줄: 멧돼지 상태, 노리는 쪽, 거리, 바라보는 방향과의 각도, 봇이 보는지·겨눌 수 있는지, 놓친 뒤 지난 시간, 체력 (--trace=1)
func _print_trace(necromancer: Necromancer, bot: Variant, monster: Monster, behavior: ChargeBehavior, time: float) -> void:
	if _frames % 12 != 0:
		return
	var to_boar: Vector2 = monster.global_position - necromancer.get_body_center()
	var vision: Vision = current_scene.call(&"get_vision")
	var lost_at: float = bot.get(&"_lost_at") if bot.get(&"_lost_at") != null else -1.0
	var target: Node2D = monster.get_target()
	print("t=%.1f %s 노림=%s 거리=%.0f 각도=%.0f 보임=%s 겨눔=%s 놓친뒤=%s 뒤로=%s 구름=%s 체력=%.0f" % [time, ChargeBehavior.State.keys()[behavior.get_state()],
		"없음" if target == null else ("네크로" if target == necromancer else "언데드"), to_boar.length(), rad_to_deg(absf(vision._facing.angle_to(to_boar))),
		_bot_sees(bot, monster.global_position), _bot_knows(bot, monster), "%.2f" % (bot.get(&"_time") - lost_at) if lost_at >= 0.0 else "-", behavior.is_busy(), necromancer.is_rolling(), necromancer.health])


func _track_charges(necromancer: Necromancer, bot: Variant, time: float) -> void:
	var alive: Array[Monster] = _alive()
	if alive.is_empty():
		return
	_frames += 1
	if _trace:
		_print_trace(necromancer, bot, alive[0], alive[0].get_behavior() as ChargeBehavior, time)
	var lost: bool = not _bot_sees(bot, alive[0].global_position)
	if lost:
		_lost_frames += 1
		if not _was_lost:
			_lost_spells += 1
	_was_lost = lost
	for monster: Monster in alive:
		var behavior: ChargeBehavior = monster.get_behavior() as ChargeBehavior
		if behavior == null:
			continue
		var state: ChargeBehavior.State = behavior.get_state()
		if not _tracks.has(behavior):
			_tracks[behavior] = {"state": ChargeBehavior.State.APPROACH}
		var track: Dictionary = _tracks[behavior]
		var seen: bool = _bot_sees(bot, monster.global_position)
		if state == ChargeBehavior.State.WINDUP:
			if track["state"] != state:
				track["windup_frames"] = 0
				track["seen_frames"] = 0
				track["first_seen"] = -1.0
			track["windup_frames"] += 1
			if seen:
				track["seen_frames"] += 1
				if track["first_seen"] < 0.0:
					track["first_seen"] = time
		elif state == ChargeBehavior.State.CHARGE:
			if track["state"] == ChargeBehavior.State.WINDUP:
				var entry: Dictionary = {
					"seen_at_start": seen,
					"seen_ratio": float(track["seen_frames"]) / maxi(track["windup_frames"], 1),
					"seen_lead": time - track["first_seen"] if track["first_seen"] >= 0.0 else -1.0,
					"on_necromancer": behavior._locked_target == necromancer,
					"rolled": false,
					"health": necromancer.health,
					"damage": 0.0,
				}
				_charges.append(entry)
				track["entry"] = entry
			if track.has("entry") and bot.get(&"_telegraphs").has(behavior) and bot.get(&"_telegraphs")[behavior]["done"]:
				track["entry"]["rolled"] = true
			if track.has("entry"):
				track["entry"]["damage"] = maxf(track["entry"]["health"] - necromancer.health, 0.0)
		track["state"] = state


func _run_charge_sight() -> void:
	print("| 판 | 실력 | 돌진 | 네크로맨서 노림 | 시작 순간 보임 | 맞음 | 죽음 | 잡은 시간 |")
	print("|---|---|---|---|---|---|---|---|")
	var summaries: Array[String] = []
	for skill_id: StringName in _skills:
		var all: Array[Dictionary] = []
		var frames: int = 0
		var lost_frames: int = 0
		var lost_spells: int = 0
		var deaths: int = 0
		for run: int in _runs:
			var result: Dictionary = await _fight(&"boar", _undead_counts[0], skill_id, run)
			if result.has("invalid"):
				continue
			var charges: Array[Dictionary] = []
			charges.assign(result["charges"])
			all.append_array(charges)
			frames += result["frames"]
			lost_frames += result["lost_frames"]
			lost_spells += result["lost_spells"]
			deaths += 1 if result["died"] else 0
			print("| %d | %s | %d | %d | %d | %d | %s | %.1f초 |" % [run, PlayerBot.SKILLS[skill_id]["name"], charges.size(), _count(charges, "on_necromancer"), _count(charges, "seen_at_start"),
				charges.filter(func(c: Dictionary) -> bool: return c["damage"] > 0.0).size(), "예" if result["died"] else "아니오", result["time"]])
		summaries.append(_charge_summary(skill_id, all, frames, lost_frames, lost_spells, deaths))
	print("")
	print("| 실력 | 판 | 돌진 수 | 시작 순간 보임 | 네크로맨서를 노린 돌진 | 그중 시작 순간 보임 | 보인 돌진에 맞음 | 안 보인 돌진에 맞음 | 예고 중 본 시간 비율 | 돌진 전에 처음 본 시각 (평균) | 굴러서 피하려 함 | 멧돼지가 안 보인 시간 | 놓친 횟수 (판당) | 죽음 |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for row: String in summaries:
		print(row)
	finish(start_failures == 0)


func _charge_summary(skill_id: StringName, all: Array[Dictionary], frames: int, lost_frames: int, lost_spells: int, deaths: int) -> String:
	var on_necromancer: Array[Dictionary] = all.filter(func(c: Dictionary) -> bool: return c["on_necromancer"])
	var seen: Array[Dictionary] = on_necromancer.filter(func(c: Dictionary) -> bool: return c["seen_at_start"])
	var unseen: Array[Dictionary] = on_necromancer.filter(func(c: Dictionary) -> bool: return not c["seen_at_start"])
	var leads: Array = all.filter(func(c: Dictionary) -> bool: return c["seen_lead"] >= 0.0).map(func(c: Dictionary) -> float: return c["seen_lead"])
	return "| %s | %d | %d | %s | %d | %s | %s | %s | %.0f%% | %.2f초 전 | %s | %.0f%% | %.1f | %d |" % [
		PlayerBot.SKILLS[skill_id]["name"], _runs, all.size(), _share(_count(all, "seen_at_start"), all.size()),
		on_necromancer.size(), _share(seen.size(), on_necromancer.size()), _hit_share(seen), _hit_share(unseen),
		100.0 * _mean(all.map(func(c: Dictionary) -> float: return c["seen_ratio"])),
		_mean(leads), _share(_count(on_necromancer, "rolled"), on_necromancer.size()),
		100.0 * lost_frames / maxi(frames, 1), float(lost_spells) / _runs, deaths]


func _count(entries: Array[Dictionary], key: String) -> int:
	return entries.filter(func(c: Dictionary) -> bool: return c[key]).size()


func _share(count: int, total: int) -> String:
	return "%d/%d (%.0f%%)" % [count, total, 100.0 * count / maxi(total, 1)]


func _hit_share(entries: Array[Dictionary]) -> String:
	return _share(entries.filter(func(c: Dictionary) -> bool: return c["damage"] > 0.0).size(), entries.size())


func _track_goblin(necromancer: Necromancer, bot: Variant, time: float) -> void:
	var alive: Array[Monster] = _alive()
	if alive.is_empty():
		return
	if alive.size() < _spawned.size() and _goblin["first_kill"] < 0.0:
		_goblin["first_kill"] = time
	_goblin["frames"] += 1
	var known: Array[Monster] = alive.filter(func(m: Monster) -> bool: return _bot_knows(bot, m))
	var origin: Vector2 = necromancer.get_shot_origin()
	var nearest: float = INF
	for monster: Monster in alive:
		nearest = minf(nearest, origin.distance_to(monster.global_position))
		var target: Node2D = monster.get_target()
		_goblin["goblin_frames"] += 1
		_goblin["target_none" if target == null else ("target_necromancer" if target == necromancer else "target_undead")] += 1
		if monster.velocity.length() > 1.0:
			_goblin["moving"] += 1
	_goblin["distance"] += nearest
	if known.is_empty():
		_goblin["not_known"] += 1
		return
	if bot.call(&"_should_flee", known):
		_goblin["fleeing"] += 1
		return
	var aimed: Monster = bot.call(&"_nearest", known)
	var center: Vector2 = aimed.global_position + PlaceholderBody.center(aimed.data)
	_goblin["firing" if origin.distance_to(center) <= necromancer.attack.projectile_range * bot.get(&"fire_range_ratio") else "out_of_range"] += 1


func _run_goblin_time() -> void:
	print("(고블린이 물러나지 않게 고침: %s)" % ("예" if _no_retreat else "아니오"))
	print("| 조건 | 실력 | 잡은 시간 (95% 오차) | 첫 고블린까지 | 쏘는 중 | 사거리 밖 | 안 보임 | 도망 | 봇과 가장 가까운 고블린 거리 | 고블린이 노림: 네크로맨서 / 언데드 / 없음 | 고블린 움직임 | 탄 명중 | 언데드 명중 | 초당 발사 | 명중률 |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for undead_count: int in _undead_counts:
		for skill_id: StringName in _skills:
			var results: Array[Dictionary] = []
			for run: int in _runs:
				var result: Dictionary = await _fight(&"goblin_pair", undead_count, skill_id, run)
				if not result.has("invalid"):
					results.append(result)
			print(_goblin_row(undead_count, skill_id, results))
	finish(start_failures == 0)


func _goblin_row(undead_count: int, skill_id: StringName, results: Array[Dictionary]) -> String:
	var finished: Array[Dictionary] = results.filter(func(r: Dictionary) -> bool: return not r["died"] and not r["timeout"])
	var total: Dictionary = {}
	var shots: int = 0
	var hits: int = 0
	var time: float = 0.0
	var first_kills: Array = []
	for result: Dictionary in finished:
		var goblin: Dictionary = result["goblin"]
		for key: String in goblin.keys():
			total[key] = total.get(key, 0.0) + goblin[key]
		shots += result["shots"]
		hits += result["hits"]
		time += result["time"]
		if goblin["first_kill"] >= 0.0:
			first_kills.append(goblin["first_kill"])
	var frames: float = maxf(total.get("frames", 0.0), 1.0)
	var goblin_frames: float = maxf(total.get("goblin_frames", 0.0), 1.0)
	var count: int = maxi(finished.size(), 1)
	return "| %s | %s | %s | %.1f초 | %.0f%% | %.0f%% | %.0f%% | %.0f%% | %.0f | %.0f / %.0f / %.0f%% | %.0f%% | %.1f | %.1f | %.2f | %.0f%% |" % [
		"혼자" if undead_count == 0 else "쥐 언데드 %d" % undead_count, PlayerBot.SKILLS[skill_id]["name"],
		_mean_error(finished.map(func(r: Dictionary) -> float: return r["time"]), "초"), _mean(first_kills),
		100.0 * total.get("firing", 0.0) / frames, 100.0 * total.get("out_of_range", 0.0) / frames, 100.0 * total.get("not_known", 0.0) / frames, 100.0 * total.get("fleeing", 0.0) / frames,
		total.get("distance", 0.0) / frames,
		100.0 * total.get("target_necromancer", 0.0) / goblin_frames, 100.0 * total.get("target_undead", 0.0) / goblin_frames, 100.0 * total.get("target_none", 0.0) / goblin_frames,
		100.0 * total.get("moving", 0.0) / goblin_frames,
		total.get("bolt_hits", 0.0) / count, total.get("undead_hits", 0.0) / count,
		shots / maxf(time, 0.01), 100.0 * hits / maxi(shots, 1)]


func _track_aim_sight(necromancer: Necromancer, bot: PlayerBot) -> void:
	var alive: Array[Monster] = _alive()
	if alive.is_empty():
		return
	var lost_health: bool = necromancer.health < _last_health
	_last_health = necromancer.health
	_aim["frames"] += 1
	_aim["alive"] += alive.size()
	var known: Array[Monster] = []
	for monster: Monster in alive:
		if _bot_sees(bot, monster.global_position):
			_aim["seen"] += 1
		if _bot_knows(bot, monster):
			known.append(monster)
	var vision: Vision = current_scene.call(&"get_vision")
	if vision == null:
		# 시야가 없는 씬에서 싸우는 판 (봇도 모두 본다). 겨누기는 재지 않고, 판이 끝나면 표 위에 알린다.
		if not _aim.has("no_vision_scene"):
			_aim["no_vision_scene"] = 1
			print("시야 없는 씬에서 싸움: %s, 네크로맨서 체력 %.1f" % [current_scene.scene_file_path, necromancer.health])
		_aim["frames"] -= 1
		return
	var facing: Vector2 = vision._facing
	if _last_facing != Vector2.ZERO and facing != Vector2.ZERO and rad_to_deg(absf(_last_facing.angle_to(facing))) > AIM_JUMP_ANGLE:
		_aim["jumps"] += 1
	_last_facing = facing
	if known.is_empty():
		_aim["not_known"] += 1
	elif facing != Vector2.ZERO:
		var aimed: Monster = bot.call(&"_nearest", known)
		if _last_aimed_id != 0 and _last_aimed_id != aimed.get_instance_id():
			_aim["switches"] += 1
		_last_aimed_id = aimed.get_instance_id()
		var off: float = rad_to_deg(absf(facing.angle_to(aimed.global_position + PlaceholderBody.center(aimed.data) - necromancer.get_body_center())))
		_aim["aim_frames"] += 1
		_aim["off_sum"] += off
		_aim["off_bright"] += 1 if off > AIM_BRIGHT_ANGLE else 0
		_aim["off_cone"] += 1 if off > AIM_CONE_ANGLE else 0
	for monster: Monster in alive:
		var behavior: DiveBehavior = monster.get_behavior() as DiveBehavior
		if behavior != null:
			_track_dive(necromancer, bot, monster, behavior, lost_health)
	_track_stones(necromancer, bot, lost_health)


## 박쥐 돌진 하나: 예고 중 봤는지, 시작 순간 보였는지, 구르려 했는지, 물렸는지
func _track_dive(necromancer: Necromancer, bot: PlayerBot, monster: Monster, behavior: DiveBehavior, lost_health: bool) -> void:
	var state: DiveBehavior.State = behavior.get_state()
	if not _dive_tracks.has(behavior):
		_dive_tracks[behavior] = {"state": DiveBehavior.State.APPROACH, "windup_seen": false}
	var track: Dictionary = _dive_tracks[behavior]
	var seen: bool = _bot_sees(bot, monster.global_position)
	if state == DiveBehavior.State.WINDUP or state == DiveBehavior.State.PACK_WINDUP:
		if track["state"] != state:
			track["windup_seen"] = false
		track["windup_seen"] = track["windup_seen"] or seen
	elif state == DiveBehavior.State.DIVE:
		if track["state"] != state:
			var entry: Dictionary = {"kind": "group" if behavior.is_group_attack() else "dive", "on_necromancer": monster.get_target() == necromancer,
				"seen_at_start": seen, "windup_seen": track["windup_seen"], "rolled": false, "hit": false}
			_attacks.append(entry)
			track["entry"] = entry
		if bot.get(&"_telegraphs").has(behavior) and bot.get(&"_telegraphs")[behavior]["done"]:
			track["entry"]["rolled"] = true
	elif track["state"] == DiveBehavior.State.DIVE and lost_health and monster.global_position.distance_to(necromancer.global_position) <= AIM_HIT_DISTANCE:
		track["entry"]["hit"] = true
	track["state"] = state


## 네크로맨서에게도 맞을 수 있는 돌 하나: 던진 고블린이 보였는지, 돌이 보였는지, 맞았는지
func _track_stones(necromancer: Necromancer, bot: PlayerBot, lost_health: bool) -> void:
	for stone: Variant in _stone_tracks.keys():
		var entry: Dictionary = _stone_tracks[stone]
		if not is_instance_valid(stone) or stone.is_queued_for_deletion():
			entry["hit"] = lost_health and entry["last"].distance_to(necromancer.get_body_center()) <= AIM_HIT_DISTANCE
			_stone_tracks.erase(stone)
		else:
			entry["last"] = stone.global_position
			entry["windup_seen"] = entry["windup_seen"] or _bot_sees(bot, stone.global_position)
			entry["rolled"] = entry["rolled"] or (bot.get(&"_stones").has(stone) and bot.get(&"_stones")[stone]["try"])
	for node: Node in necromancer.get_parent().get_children():
		var stone: Stone = node as Stone
		if stone == null or stone.is_queued_for_deletion() or _stone_tracks.has(stone) or not stone.hostile_groups.has(&"necromancer"):
			continue
		var thrower: Monster = stone.thrower as Monster if is_instance_valid(stone.thrower) else null
		var entry: Dictionary = {"kind": "stone", "on_necromancer": thrower != null and thrower.get_target() == necromancer,
			"seen_at_start": thrower != null and _bot_sees(bot, thrower.global_position),
			"windup_seen": _bot_sees(bot, stone.global_position), "rolled": false, "hit": false, "last": stone.global_position}
		_stone_tracks[stone] = entry
		_attacks.append(entry)


func _run_aim_sight() -> void:
	print("(시야 끔: %s)" % ("예" if _no_vision else "아니오"))
	var rows: Array[String] = []
	var attack_rows: Array[String] = []
	for target_id: StringName in _targets:
		var undead_count: int = AIM_SIGHT_CASES[target_id]
		for skill_id: StringName in _skills:
			var results: Array[Dictionary] = []
			for run: int in _runs:
				var result: Dictionary = await _fight(target_id, undead_count, skill_id, run)
				if not result.has("invalid"):
					results.append(result)
			rows.append(_aim_row(target_id, undead_count, skill_id, results))
			attack_rows.append_array(_attack_rows(target_id, undead_count, skill_id, results))
			print(rows[-1])
	print("")
	print("| 대상 | 조건 | 실력 | 판 | 죽음 (95% 범위) | 받은 피해 (95% 오차) | 살아 있는 몬스터가 보인 비율 | 겨눌 몬스터 없음 | 겨눈 몬스터와 화면 방향 차이 평균 | 23도 넘음 | 35도 넘음(부채꼴 밖) | 시야가 튄 횟수(30도 넘게, 초당) | 겨눔 대상 바뀜(초당) | 명중률 |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for row: String in rows:
		print(row)
	print("")
	print("| 대상 | 조건 | 실력 | 공격 종류 | 네크로맨서를 노린 수 | 시작 순간 보임 | 예고·비행 중 한 번이라도 봄 | 보인 공격에 맞음 | 안 보인 공격에 맞음 | 피하려 함 |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for row: String in attack_rows:
		print(row)
	finish(start_failures == 0)


func _aim_row(target_id: StringName, undead_count: int, skill_id: StringName, results: Array[Dictionary]) -> String:
	var total: Dictionary = {}
	var shots: int = 0
	var hits: int = 0
	for result: Dictionary in results:
		var aim: Dictionary = result["aim"]
		for key: String in aim.keys():
			total[key] = total.get(key, 0.0) + aim[key]
		shots += result["shots"]
		hits += result["hits"]
	var deaths: int = results.filter(func(r: Dictionary) -> bool: return r["died"]).size()
	var seconds: float = maxf(total["frames"] / float(Engine.physics_ticks_per_second), 0.01)
	var aim_frames: float = maxf(total["aim_frames"], 1.0)
	return "| %s | %s | %s | %d | %s | %s | %.0f%% | %.0f%% | %.1f도 | %.0f%% | %.0f%% | %.2f | %.2f | %.0f%% |" % [
		TARGETS[target_id]["name"], "혼자" if undead_count == 0 else "쥐 언데드 %d" % undead_count, PlayerBot.SKILLS[skill_id]["name"], results.size(),
		_rate_range(deaths, results.size()), _mean_error(results.map(func(r: Dictionary) -> float: return r["damage"]), ""),
		100.0 * total["seen"] / maxf(total["alive"], 1.0), 100.0 * total["not_known"] / maxf(total["frames"], 1.0),
		total["off_sum"] / aim_frames, 100.0 * total["off_bright"] / aim_frames, 100.0 * total["off_cone"] / aim_frames,
		total["jumps"] / seconds, total["switches"] / seconds, 100.0 * hits / maxi(shots, 1)]


func _attack_rows(target_id: StringName, undead_count: int, skill_id: StringName, results: Array[Dictionary]) -> Array[String]:
	var all: Array[Dictionary] = []
	for result: Dictionary in results:
		var attacks: Array[Dictionary] = []
		attacks.assign(result["attacks"])
		all.append_array(attacks)
	var rows: Array[String] = []
	for kind: String in ["dive", "group", "stone"]:
		var attacks: Array[Dictionary] = all.filter(func(a: Dictionary) -> bool: return a["kind"] == kind and a["on_necromancer"])
		if attacks.is_empty():
			continue
		var seen: Array[Dictionary] = attacks.filter(func(a: Dictionary) -> bool: return a["seen_at_start"])
		var unseen: Array[Dictionary] = attacks.filter(func(a: Dictionary) -> bool: return not a["seen_at_start"])
		var hit: Callable = func(a: Dictionary) -> bool: return a["hit"]
		rows.append("| %s | %s | %s | %s | %d | %s | %s | %s | %s | %s |" % [
			TARGETS[target_id]["name"], "혼자" if undead_count == 0 else "쥐 언데드 %d" % undead_count, PlayerBot.SKILLS[skill_id]["name"],
			{"dive": "혼자 돌진", "group": "동시 돌진", "stone": "돌"}[kind], attacks.size(), _share(seen.size(), attacks.size()), _share(_count(attacks, "windup_seen"), attacks.size()),
			_share(seen.filter(hit).size(), seen.size()), _share(unseen.filter(hit).size(), unseen.size()), _share(_count(attacks, "rolled"), attacks.size())])
	return rows
