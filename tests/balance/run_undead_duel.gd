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
	var rows: Array[String] = []
	for monster_id: StringName in _monsters:
		for case_id: int in _cases:
			var results: Array[Dictionary] = []
			for run: int in _runs:
				results.append(await _fight(monster_id, case_id, run))
			var row: String = _row(monster_id, case_id, results)
			print(row)
			rows.append(row)
	print("")
	print("| 몬스터 | 경우 | 언데드 쪽 승리 | 패배 | 해제(마나 0) | 시간 초과 | 이겼을 때 남은 언데드 체력 | 졌을 때 남은 적 체력 | 평균 시간 | 네크로맨서 사망 |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for row: String in rows:
		print(row)
	finish(true)


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
		if bot != null:
			bot.tick(delta)
	if bot != null:
		bot.release_all()
	result["time"] = time
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
	return "| %s | %s | %d%% | %d%% | %d%% | %d%% | %s | %s | %.1f초 | %s |" % [
		MONSTERS[monster_id], CASE_NAMES[case_id], 100 * count.call("win") / n, 100 * count.call("lose") / n,
		100 * count.call("released") / n, 100 * count.call("timeout") / n, undead_left, enemy_left,
		_mean(results.map(func(r: Dictionary) -> float: return r["time"])), necro_deaths]


## 시험 지역을 새로 불러오고, 전역 상태(인벤토리·핫바)를 비운다.
func _reload_scene() -> void:
	await physics_frame
	await physics_frame
	root.get_node("GameState").call(&"reset_after_death")
	var old_scene: Node = current_scene
	change_scene_to_file(TEST_REGION_SCENE)
	while current_scene == old_scene or current_scene == null or not current_scene.is_node_ready():
		await physics_frame


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / values.size()
