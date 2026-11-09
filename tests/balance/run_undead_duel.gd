extends ScenarioTest
## 밸런스 측정: 같은 몬스터끼리 언데드와 적이 싸운 결과를 잰다 (언데드 능력치 배율이 목표에 맞는지).
## 몬스터마다 세 경우를 runs번씩 싸운다.
##   1. 언데드 1 vs 적 1          → 목표: 언데드가 진다 (언데드는 원래 몬스터보다 약하다)
##   2. 언데드 1 + 네크로맨서 vs 적 1 → 목표: 이긴다 (네크로맨서는 측정 봇 PlayerBot, 실력 --skill)
##   3. 언데드 2 vs 적 1          → 목표: 이긴다
## 1·3에서는 네크로맨서를 "necromancer" 그룹에서 빼서 몬스터가 노리지 않게 하고(체력도 크게), 공격하지 않고 가만히 둔다.
## 1·3에서는 마나도 바닥나지 않게 한다 (능력치 배율만 보려고). 2번은 실제 마나 그대로라 유지비로 해제될 수 있다.
## 언데드는 감지 범위가 없으므로, 적이 언데드를 노리면 그때 싸운다 (적을 언데드의 감지 범위 밖이 아니라 적의 감지 범위 안에 둔다).
## 판정이 없으므로 run_all.sh에는 넣지 않는다.
##
## bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_undead_duel.gd
## 일부만: -- --monsters=rat,boar --cases=1,3 --runs=10 --skill=normal

const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 60
## 몬스터 id → 이름. 데이터는 data/monsters/<id>.tres, 머리뼈는 data/skulls/<id>_skull.tres
const MONSTERS: Dictionary = {&"rat": "쥐", &"boar": "멧돼지", &"bat": "박쥐", &"goblin_slinger": "고블린 투석병"}
const CASE_NAMES: Dictionary = {1: "언데드 1 vs 적 1", 2: "언데드 1 + 네크로맨서 vs 적 1", 3: "언데드 2 vs 적 1"}
## 적을 놓는 자리 (네크로맨서 기준). 소환된 언데드는 네크로맨서 옆에 있다.
const ENEMY_OFFSET: Vector2 = Vector2(70, 0)
const DEFAULT_RUNS: int = 20
const TIMEOUT: float = 60.0
const BASE_SEED: int = 3000

var _monsters: Array[StringName] = [&"rat", &"boar", &"bat", &"goblin_slinger"]
var _cases: Array[int] = [1, 2, 3]
var _runs: int = DEFAULT_RUNS
var _skill: StringName = &"normal"
## 원인 추적: "rat"(시간 초과 판의 거리 변화), "boar"(돌진 뒤 누구를 노리는지). 비어 있으면 하지 않는다
var _trace: String = ""
## 테스트 안에서만 멧돼지의 돌진 뒤 거리 벌리기를 끈다: --no_turn_away=1 적만, 2 적과 언데드 모두, 3 언데드만
var _no_turn_away: int = 0
var _tr: Dictionary = {}
var _tr_fights: Array[Dictionary] = []
var _boar_prev: Dictionary = {}
## 시간 초과 판의 거리 기록 간격(프레임)과, 그렇게 출력할 판 수
const RAT_SERIES_FRAMES: int = 300
const RAT_SERIES_FIGHTS: int = 3
## 시간 초과일 때 적과 언데드가 서로 노리지 않은 채 이만큼(프레임) 이어졌으면 시간 초과가 아니라 교착으로 센다 (5초)
const STALEMATE_FRAMES: int = 300


func get_start_scene() -> String:
	return TEST_REGION_SCENE


func _on_scene_ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		if parts.size() != 2:
			continue
		var values: Array = Array(parts[1].split(","))
		match parts[0]:
			"monsters":
				_monsters.assign(values.map(func(v: String) -> StringName: return StringName(v)))
			"cases":
				_cases.assign(values.map(func(v: String) -> int: return int(v)))
			"runs":
				_runs = int(parts[1])
			"skill":
				_skill = StringName(parts[1])
			"trace":
				_trace = parts[1]
			"no_turn_away":
				_no_turn_away = int(parts[1])
	var rows: Array[String] = []
	for monster_id: StringName in _monsters:
		for case_id: int in _cases:
			var results: Array[Dictionary] = []
			for run: int in _runs:
				var result: Dictionary = await _fight(monster_id, case_id, run)
				if not result.has("invalid"):
					results.append(result)
			var row: String = _row(monster_id, case_id, results)
			print(row)
			rows.append(row)
	print("")
	print("| 몬스터 | 경우 | 언데드 쪽 승리 | 패배 | 해제(마나 0) | 시간 초과 | 교착 (서로 노리지 않음) | 이겼을 때 남은 언데드 체력 | 졌을 때 남은 적 체력 | 평균 시간 | 네크로맨서 사망 | 내구도 소모 합계 (판당) | 초당 소모 (합계) |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for row: String in rows:
		print(row)
	if _trace == "rat":
		_print_rat_trace()
	elif _trace == "boar":
		_print_boar_trace()
	finish(start_failures == 0)


## 적이 대상을 노리고 있거나, 언데드 중 하나가 적을 노리고 있는지
func _is_engaged(enemy: Monster) -> bool:
	if enemy.get_target() != null:
		return true
	for node: Node in get_nodes_in_group(&"undead"):
		if (node as Undead).get_target() == enemy:
			return true
	return false


# --- 원인 추적 (--trace=rat, --trace=boar). 판정을 내지 않는다 ---

## 판을 시작할 때 적과 언데드를 기억하고 집계를 비운다.
func _start_trace(enemy: Monster) -> void:
	_tr = {"frames": 0, "near_sum": 0.0, "in_range": 0, "target_frames": [0, 0], "enemy_on": [0, 0, 0], "phases": [0, 0, 0], "undead_hits": 0, "series": []}
	_tr["undeads"] = get_nodes_in_group(&"undead")
	enemy.hit_by.connect(func(_source: Node2D) -> void: _tr["undead_hits"] += 1)
	_boar_prev = {"state": ChargeBehavior.State.APPROACH, "locked": "", "health": 0.0, "turned": false}
	_tr["windups"] = []
	if enemy.get_behavior() is ChargeBehavior:
		if _no_turn_away == 1 or _no_turn_away == 2:
			(enemy.get_behavior() as ChargeBehavior).back_off_after_charge = false


func _trace_frame(enemy: Monster, necromancer: Necromancer, time: float) -> void:
	if _trace == "rat":
		_trace_rat(enemy, time)
	elif _trace == "boar":
		_trace_boar(enemy, necromancer, time)


func _trace_rat(enemy: Monster, time: float) -> void:
	var undeads: Array = _tr["undeads"]
	var near: float = INF
	var distances: Array[String] = []
	var targets: Array[String] = []
	for i: int in undeads.size():
		if not is_instance_valid(undeads[i]) or undeads[i].is_queued_for_deletion():
			distances.append("-")
			targets.append("-")
			continue
		var undead: Undead = undeads[i]
		var distance: float = undead.global_position.distance_to(enemy.global_position)
		near = minf(near, distance)
		distances.append("%.0f" % distance)
		targets.append("쥐" if undead.get_target() == enemy else "없음")
		if undead.get_target() == enemy:
			_tr["target_frames"][i] += 1
	_tr["frames"] += 1
	_tr["near_sum"] += near
	_tr["in_range"] += 1 if near <= enemy.data.get_undead_stats().attack_range else 0
	var target: Node2D = enemy.get_target()
	var on: int = undeads.find(target) if target != null else 2
	_tr["enemy_on"][on if on >= 0 else 2] += 1
	var phase: int = (enemy.get_behavior() as ApproachBehavior).get_phase()
	_tr["phases"][phase] += 1
	if _tr["frames"] % RAT_SERIES_FRAMES == 1:
		_tr["series"].append("%2.0f초 | %s | %s | %s | %s | %.1f" % [time, " / ".join(distances), " / ".join(targets), "언데드 %d" % (on + 1) if on >= 0 and on < 2 else "없음", ["다가감", "물러남", "멈춤"][phase], enemy.health])


func _print_rat_trace() -> void:
	print("")
	print("| 결과 | 판 | 평균 시간 | 가까운 언데드까지 평균 | 공격 거리(24) 안 프레임 | 언데드 1 대상 있음 | 언데드 2 대상 있음 | 쥐가 노림: 1 / 2 / 없음 | 쥐 단계: 다가감 / 물러남 / 멈춤 | 언데드 명중 (판당) | 남은 쥐 체력 |")
	print("|---|---|---|---|---|---|---|---|---|---|---|")
	for outcome: String in ["win", "timeout", "stalemate"]:
		var fights: Array[Dictionary] = _tr_fights.filter(func(f: Dictionary) -> bool: return f["outcome"] == outcome)
		if fights.is_empty():
			continue
		var frames: float = 0.0
		var sums: Dictionary = {"near": 0.0, "in": 0.0, "hits": 0.0, "t0": 0.0, "t1": 0.0, "e0": 0.0, "e1": 0.0, "e2": 0.0, "p0": 0.0, "p1": 0.0, "p2": 0.0, "hp": 0.0, "time": 0.0}
		for fight: Dictionary in fights:
			var tr: Dictionary = fight["tr"]
			frames += tr["frames"]
			sums["near"] += tr["near_sum"]
			sums["in"] += tr["in_range"]
			sums["hits"] += tr["undead_hits"]
			sums["time"] += fight["time"]
			sums["hp"] += fight["enemy_health"]
			for i: int in 2:
				sums["t%d" % i] += tr["target_frames"][i]
			for i: int in 3:
				sums["e%d" % i] += tr["enemy_on"][i]
				sums["p%d" % i] += tr["phases"][i]
		var n: float = fights.size()
		print("| %s | %d | %.1f초 | %.0f | %.0f%% | %.0f%% | %.0f%% | %.0f / %.0f / %.0f%% | %.0f / %.0f / %.0f%% | %.1f | %.1f |" % [outcome, fights.size(), sums["time"] / n, sums["near"] / frames, 100.0 * sums["in"] / frames,
			100.0 * sums["t0"] / frames, 100.0 * sums["t1"] / frames, 100.0 * sums["e0"] / frames, 100.0 * sums["e1"] / frames, 100.0 * sums["e2"] / frames,
			100.0 * sums["p0"] / frames, 100.0 * sums["p1"] / frames, 100.0 * sums["p2"] / frames, sums["hits"] / n, sums["hp"] / n])
	var timeouts: Array[Dictionary] = _tr_fights.filter(func(f: Dictionary) -> bool: return f["outcome"] == "timeout" or f["outcome"] == "stalemate")
	for i: int in mini(timeouts.size(), RAT_SERIES_FIGHTS):
		print("")
		print("시간 초과 판 %d (시각 | 언데드 1 / 2와 쥐의 거리 | 언데드 대상 | 쥐가 노림 | 쥐 단계 | 쥐 체력)" % (i + 1))
		for line: String in timeouts[i]["tr"]["series"]:
			print(line)


func _trace_boar(enemy: Monster, necromancer: Necromancer, _time: float) -> void:
	var behavior: ChargeBehavior = enemy.get_behavior() as ChargeBehavior
	# 봇이 소환한 언데드는 판 시작 때 아직 그룹에 없을 수 있어서 프레임마다 끈다.
	if _no_turn_away == 2 or _no_turn_away == 3:
		for undead_node: Node in get_nodes_in_group(&"undead"):
			((undead_node as Undead)._behavior as ChargeBehavior).back_off_after_charge = false
	var state: ChargeBehavior.State = behavior.get_state()
	var locked: Node2D = behavior._locked_target if is_instance_valid(behavior._locked_target) else null
	var label: String = "" if locked == null else ("네크로맨서" if locked == necromancer else "언데드")
	if _boar_prev["state"] != ChargeBehavior.State.WINDUP and state == ChargeBehavior.State.WINDUP:
		var undead: Node2D = get_first_node_in_group(&"undead") as Node2D
		_tr["windups"].append({"target": label, "prev": _boar_prev["locked"], "turned": _boar_prev["turned"],
			"to_necro": enemy.global_position.distance_to(necromancer.global_position),
			"to_undead": enemy.global_position.distance_to(undead.global_position) if undead != null else -1.0,
			"undead_alive": undead != null, "hit": false})
		_boar_prev["turned"] = false
	if state == ChargeBehavior.State.CHARGE and necromancer.health < _boar_prev["health"] and not _tr["windups"].is_empty():
		_tr["windups"][-1]["hit"] = true
	if _boar_prev["state"] == ChargeBehavior.State.RECOVER and state != ChargeBehavior.State.RECOVER:
		_boar_prev["turned"] = behavior._turn_away_left > 0.0
	if label != "":
		_boar_prev["locked"] = label
	_boar_prev["state"] = state
	_boar_prev["health"] = necromancer.health


func _print_boar_trace() -> void:
	var all: Array[Dictionary] = []
	for fight: Dictionary in _tr_fights:
		var windups: Array[Dictionary] = []
		windups.assign(fight["tr"]["windups"])
		for windup: Dictionary in windups:
			windup["died"] = fight["necro_died"]
		all.append_array(windups)
	var deaths: int = _tr_fights.filter(func(f: Dictionary) -> bool: return f["necro_died"]).size()
	print("")
	print("(돌진 뒤 거리 벌리기 끔: %s) 판 %d, 네크로맨서 사망 %d" % [["안 끔", "적만", "적과 언데드 모두", "언데드만"][_no_turn_away], _tr_fights.size(), deaths])
	print("| 다음 돌진을 시작할 때 | 돌진 수 | 네크로맨서를 노림 | 언데드를 노림 | 네크로맨서를 노린 돌진에 맞음 | 시작 때 네크로맨서까지 평균 | 언데드까지 평균 |")
	print("|---|---|---|---|---|---|---|")
	for row: Array in [["언데드가 살아 있음", func(w: Dictionary) -> bool: return w["undead_alive"]], ["언데드가 죽은 뒤", func(w: Dictionary) -> bool: return not w["undead_alive"]],
			["바로 전 돌진이 언데드를 노림 + 거리를 벌림", func(w: Dictionary) -> bool: return w["prev"] == "언데드" and w["turned"]],
			["바로 전 돌진이 네크로맨서를 노림 + 거리를 벌림", func(w: Dictionary) -> bool: return w["prev"] == "네크로맨서" and w["turned"]]]:
		var windups: Array[Dictionary] = all.filter(row[1])
		var on_necro: Array[Dictionary] = windups.filter(func(w: Dictionary) -> bool: return w["target"] == "네크로맨서")
		var hit: int = on_necro.filter(func(w: Dictionary) -> bool: return w["hit"]).size()
		print("| %s | %d | %d | %d | %d/%d | %.0f | %.0f |" % [row[0], windups.size(), on_necro.size(), windups.size() - on_necro.size(), hit, on_necro.size(),
			_mean(windups.map(func(w: Dictionary) -> float: return w["to_necro"])), _mean(windups.filter(func(w: Dictionary) -> bool: return w["to_undead"] >= 0.0).map(func(w: Dictionary) -> float: return w["to_undead"]))])


## 한 판. 결과: outcome("win"/"lose"/"released"/"timeout"), time, undead_ratio(남은 언데드 체력 비율 평균), enemy_ratio, necro_died
func _fight(monster_id: StringName, case_id: int, run: int) -> Dictionary:
	await _reload_scene()
	seed(BASE_SEED + run)
	var region: Node = current_scene
	var necromancer: Necromancer = find_necromancer()
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	for node: Node in region.find_children("*", "EscapePoint", true, false):
		node.free()
	necromancer.global_position = Vector2.ZERO
	var data: MonsterData = load("res://data/monsters/%s.tres" % monster_id)
	var skull_data: SkullData = load("res://data/skulls/%s_skull.tres" % monster_id)
	var undead_count: int = 2 if case_id == 3 else 1

	var skulls: Array[Skull] = []
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	for i: int in undead_count:
		var skull: Skull = Skull.create(skull_data)
		necromancer.inventory.try_add(ItemStack.of_skull(skull))
		hotbar.assign(i, skull)
		skulls.append(skull)
	necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var roster: UndeadRoster = necromancer.summoner.roster
	var result: Dictionary = {"outcome": "timeout", "necro_died": false}
	var lost: Array[int] = [0, 0]
	roster.unsummoned.connect(func(_skull: Skull, died: bool) -> void:
		lost[0 if died else 1] += 1)
	necromancer.died.connect(func() -> void: result["necro_died"] = true)

	var bot: PlayerBot = null
	if case_id == 2:
		bot = PlayerBot.new(self, necromancer, _skill)
		bot.set_undead_skulls(skulls)
	else:
		# 네크로맨서는 구경만 한다: 몬스터가 노리지 않고, 죽지 않는다.
		necromancer.remove_from_group(&"necromancer")
		necromancer.max_health = 100000.0
		necromancer.health = necromancer.max_health
		# 능력치 배율만 보려고 마나는 바닥나지 않게 한다 (유지비로 해제되는 문제는 2번에서 실제 마나로 본다).
		necromancer.mana.maximum = 100000.0
		necromancer.mana.current = necromancer.mana.maximum
		for i: int in undead_count:
			hotbar.select(i)
			necromancer.summoner.toggle_selected()
	# 언데드가 나올 때까지 기다린 뒤(봇은 숫자키·G로 소환) 적을 놓는다.
	for frame: int in 60:
		if bot != null:
			bot.tick(1.0 / Engine.physics_ticks_per_second)
		await physics_frame
		if roster.get_summoned().size() >= undead_count:
			break
	var enemy: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	enemy.data = data
	enemy.position = necromancer.global_position + ENEMY_OFFSET
	necromancer.get_parent().add_child(enemy)
	if not check_fight_start(TEST_REGION_SCENE, 1):
		return {"invalid": true}
	var durability_start: float = _total_durability(skulls)
	## 적과 언데드가 서로 노리지 않은 채 이어진 프레임 수
	var stale_frames: int = 0
	if _trace != "":
		_start_trace(enemy)

	var time: float = 0.0
	var delta: float = 1.0 / Engine.physics_ticks_per_second
	# 네크로맨서가 죽으면 씬이 바뀌어 적이 사라지므로, 적 체력은 프레임마다 적어 둔다.
	var enemy_health: float = data.max_health
	while time < TIMEOUT:
		await physics_frame
		time += delta
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy_health = enemy.health
		if result["necro_died"] or not is_instance_valid(necromancer):
			result["outcome"] = "lose"
			break
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.health <= 0.0:
			result["outcome"] = "win"
			break
		if lost[0] + lost[1] >= undead_count and case_id != 2:
			result["outcome"] = "lose" if lost[0] > 0 else "released"
			break
		if _trace != "":
			_trace_frame(enemy, necromancer, time)
		stale_frames = 0 if _is_engaged(enemy) else stale_frames + 1
		if bot != null:
			bot.tick(delta)
	if result["outcome"] == "timeout" and stale_frames >= STALEMATE_FRAMES:
		result["outcome"] = "stalemate"
	if bot != null:
		bot.release_all()
	result["time"] = time
	result["durability_lost"] = durability_start - _total_durability(skulls)
	if _trace != "":
		result["tr"] = _tr
		result["enemy_health"] = enemy_health
		_tr_fights.append(result)
	var max_health: float = data.undead_max_health
	result["undead_ratio"] = skulls.map(func(s: Skull) -> float: return s.health / max_health).reduce(func(a: float, b: float) -> float: return a + b, 0.0) / skulls.size()
	result["enemy_ratio"] = maxf(enemy_health, 0.0) / data.max_health
	# 2번에서 언데드가 모두 죽었어도 네크로맨서가 혼자 이길 수 있다. 그때는 언데드 쪽 승리로 센다 (남은 언데드 체력 0).
	return result


func _row(monster_id: StringName, case_id: int, results: Array[Dictionary]) -> String:
	var count: Callable = func(outcome: String) -> int: return results.filter(func(r: Dictionary) -> bool: return r["outcome"] == outcome).size()
	var wins: Array = results.filter(func(r: Dictionary) -> bool: return r["outcome"] == "win")
	var losses: Array = results.filter(func(r: Dictionary) -> bool: return r["outcome"] == "lose")
	var n: int = results.size()
	var undead_left: String = "%d%%" % roundi(100.0 * _mean(wins.map(func(r: Dictionary) -> float: return r["undead_ratio"]))) if not wins.is_empty() else "-"
	var enemy_left: String = "%d%%" % roundi(100.0 * _mean(losses.map(func(r: Dictionary) -> float: return r["enemy_ratio"]))) if not losses.is_empty() else "-"
	var necro_deaths: String = "%d%%" % (100 * results.filter(func(r: Dictionary) -> bool: return r["necro_died"]).size() / n) if case_id == 2 else "-"
	var total_time: float = 0.0
	var total_lost: float = 0.0
	for result: Dictionary in results:
		total_time += result["time"]
		total_lost += result["durability_lost"]
	return "| %s | %s | %d%% | %d%% | %d%% | %d%% | %d%% | %s | %s | %.1f초 | %s | %.1f | %.2f |" % [
		MONSTERS[monster_id], CASE_NAMES[case_id], 100 * count.call("win") / n, 100 * count.call("lose") / n,
		100 * count.call("released") / n, 100 * count.call("timeout") / n, 100 * count.call("stalemate") / n, undead_left, enemy_left,
		_mean(results.map(func(r: Dictionary) -> float: return r["time"])), necro_deaths, total_lost / n, total_lost / maxf(total_time, 0.01)]


func _total_durability(skulls: Array[Skull]) -> float:
	var total: float = 0.0
	for skull: Skull in skulls:
		total += skull.durability
	return total


## 시험 지역을 새로 불러오고, 전역 상태(인벤토리·핫바)를 비운다.
func _reload_scene() -> void:
	await reload_fight_scene(TEST_REGION_SCENE)


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / values.size()
