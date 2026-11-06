extends ScenarioTest
## 밸런스 측정: 플레이어 봇(PlayerBot)이 시험 지역에서 몬스터와 싸운 결과를 잰다.
## 대상 × 조건(혼자 / 쥐 언데드 2마리와 함께) × 실력 단계마다 runs번 싸워서
## 잡는 시간과 받은 피해의 평균·가장 나쁜 경우, 죽은 비율, 시간 초과 비율, 명중률을 표로 출력한다.
## 판정(통과/실패)을 내지 않으므로 run_all.sh에는 넣지 않는다. 몬스터를 추가하면 TARGETS에 넣고 다시 잰다.
##
## 전부 측정 (헤드리스, 빠르게):
##   bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_balance.gd
## 일부만: -- --targets=boar,bat_pack --skills=normal --undead=0 --runs=5
## 봇이 몬스터와 유지하는 거리 바꾸기: -- --keep=0 (0이면 거리를 두지 않고 제자리에서 쏘며 예고만 피한다)
## 무리 동시 공격(박쥐 동시 돌진)을 처음 N번 일부러 못 피하게: -- --miss_pack=1
##   놓친 동시 공격에서 받은 피해, 그 직후 마나, 언데드가 죽거나 해제된 수, 죽은 비율로 "실수 한 번의 값"을 본다
## 봇이 싸우는 모습을 창으로 보기 (실제 속도, 한 판):
##   bash tools/godot.sh --path . -s tests/balance/run_balance.gd -- --targets=boar --skills=normal --undead=0 --runs=1
##
## 싸움터: 시험 지역에서 몬스터와 탈출 지점을 모두 치우고, 네크로맨서는 가운데, 대상은 SPAWN_OFFSET에 둔다
## (감지 범위 밖이라 봇이 먼저 쏴서 싸움을 건다). 판마다 난수 시드를 바꾼다.

const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const UNDEAD_BONES: int = 40
## 대상 id → [몬스터 데이터, 놓을 자리들 (SPAWN_OFFSET 기준)]
const TARGETS: Dictionary = {
	&"rat": {"name": "쥐 1마리", "data": "res://data/monsters/rat.tres", "offsets": [Vector2.ZERO]},
	&"boar": {"name": "멧돼지 1마리", "data": "res://data/monsters/boar.tres", "offsets": [Vector2.ZERO]},
	&"bat_pack": {"name": "박쥐 무리(3)", "data": "res://data/monsters/bat.tres", "offsets": [Vector2(0, -12), Vector2(12, 0), Vector2(0, 12)], "pack": true},
}
const SPAWN_OFFSET: Vector2 = Vector2(150, 0)
const DEFAULT_RUNS: int = 20
## 한 판의 시간 한계 (초). 넘으면 "시간 초과"로 센다.
const DEFAULT_TIMEOUT: float = 60.0
## 판마다 시드 = BASE_SEED + 판 번호
const BASE_SEED: int = 1000

var _targets: Array[StringName] = [&"rat", &"boar", &"bat_pack"]
var _skills: Array[StringName] = [&"skilled", &"normal", &"novice"]
var _undead_counts: Array[int] = [0, 2]
var _runs: int = DEFAULT_RUNS
var _timeout: float = DEFAULT_TIMEOUT
## 봇이 근접 몬스터와 유지하는 거리. 음수면 봇의 기본값.
var _keep: float = -1.0
## 처음 이 횟수만큼의 무리 동시 공격은 봇이 일부러 피하지 않는다
var _miss_pack: int = 0


func get_start_scene() -> String:
	return TEST_REGION_SCENE


func _on_scene_ready() -> void:
	_parse_args()
	_run_all()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		if parts.size() != 2:
			continue
		var values: PackedStringArray = parts[1].split(",")
		match parts[0]:
			"targets":
				_targets.assign(Array(values).map(func(v: String) -> StringName: return StringName(v)))
			"skills":
				_skills.assign(Array(values).map(func(v: String) -> StringName: return StringName(v)))
			"undead":
				_undead_counts.assign(Array(values).map(func(v: String) -> int: return int(v)))
			"runs":
				_runs = int(parts[1])
			"timeout":
				_timeout = float(parts[1])
			"miss_pack":
				_miss_pack = int(parts[1])
			"keep":
				_keep = float(parts[1])


func _run_all() -> void:
	var rows: Array[String] = []
	for target_id: StringName in _targets:
		for undead_count: int in _undead_counts:
			for skill_id: StringName in _skills:
				var results: Array[Dictionary] = []
				for run: int in _runs:
					results.append(await _fight(target_id, undead_count, skill_id, run))
				var row: String = _summary_row(target_id, undead_count, skill_id, results)
				print(row)
				rows.append(row)
	print("")
	print("| 대상 | 조건 | 실력 | 잡은 시간 평균 | 가장 늦게 | 받은 피해 평균 | 가장 많이 | 죽음 | 시간 초과 | 명중률 | 본 예고 | 구름 | 소환 | 가장 가까이 온 거리 | 동시 공격 | 놓친 동시 공격 피해 | 놓친 직후 마나 | 최저 마나 | 언데드 죽음 | 언데드 해제 |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	if _miss_pack > 0:
		print("(무리 동시 공격 처음 %d번은 일부러 피하지 않음)" % _miss_pack)
	for row: String in rows:
		print(row)
	finish(true)


## 한 판 싸운다. 결과: time(초), damage, died, timeout, shots, hits
func _fight(target_id: StringName, undead_count: int, skill_id: StringName, run: int) -> Dictionary:
	await _reload_scene()
	seed(BASE_SEED + run)
	var region: Node = current_scene
	var necromancer: Necromancer = find_necromancer()
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	for node: Node in region.find_children("*", "EscapePoint", true, false):
		node.free()
	necromancer.global_position = Vector2.ZERO

	var target: Dictionary = TARGETS[target_id]
	var data: MonsterData = load(target["data"])
	var spawned: Array[Monster] = []
	for offset: Vector2 in target["offsets"]:
		var monster: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		monster.data = data
		monster.position = SPAWN_OFFSET + offset
		necromancer.get_parent().add_child(monster)
		spawned.append(monster)
	# 무리면 동시 공격 시각을 맞추는 MonsterPack으로 묶는다 (시험 지역의 BatPack과 같다).
	if target.get("pack", false):
		var pack: MonsterPack = MonsterPack.new()
		pack.set_members(spawned)
		region.add_child(pack)

	var bot: PlayerBot = PlayerBot.new(self, necromancer, skill_id)
	bot.miss_group_attacks = _miss_pack
	if _keep >= 0.0:
		bot.keep_distance = _keep
	if undead_count > 0:
		bot.set_undead_skulls(_give_undead(necromancer, undead_count))

	var time: float = 0.0
	var delta: float = 1.0 / Engine.physics_ticks_per_second
	var result: Dictionary = {"died": false, "timeout": false}
	var max_health: float = necromancer.max_health
	# 죽으면 지역 씬이 곧바로 거점으로 넘어가 네크로맨서 노드가 사라지므로, 시그널로 기록한다.
	necromancer.died.connect(func() -> void: result["died"] = true)
	while true:
		await physics_frame
		time += delta
		if result["died"] or not is_instance_valid(necromancer):
			result["died"] = true
			break
		if bot_monsters_left() == 0:
			break
		if time >= _timeout:
			result["timeout"] = true
			break
		bot.tick(delta)
	bot.release_all()
	bot.finish_tracking(result["died"])
	result["time"] = time
	result["damage"] = max_health if result["died"] else max_health - necromancer.health
	result["shots"] = bot.shots
	result["hits"] = bot.hits
	result["rolls"] = bot.rolls
	result["telegraphs"] = bot.telegraphs_seen
	result["summons"] = bot.summons
	result["closest"] = bot.closest
	result["group_attacks"] = bot.group_attacks_seen
	result["missed_damage"] = bot.missed_group_damage
	result["mana_after_miss"] = bot.mana_after_miss
	result["mana_min"] = bot.mana_min
	result["undead_died"] = bot.undead_died
	result["undead_released"] = bot.undead_released
	return result


func bot_monsters_left() -> int:
	var count: int = 0
	for node: Node in get_nodes_in_group(&"monsters"):
		if not node.is_queued_for_deletion() and (node as Monster).health > 0.0:
			count += 1
	return count


## 쥐의 머리뼈를 count개 인벤토리에 넣고 핫바 칸에 차례로 놓는다. 봇이 숫자키와 G로 소환한다.
func _give_undead(necromancer: Necromancer, count: int) -> Array[Skull]:
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	var skulls: Array[Skull] = []
	for i: int in count:
		var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
		necromancer.inventory.try_add(ItemStack.of_skull(skull))
		hotbar.assign(i, skull)
		skulls.append(skull)
	necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), UNDEAD_BONES))
	return skulls


## 시험 지역을 새로 불러오고, 전역 상태(인벤토리·핫바)를 비운다.
func _reload_scene() -> void:
	# 지난 판에서 죽었으면 지역 씬이 거점으로 보내는 중일 수 있다. 그 뒤에 다시 부른다.
	await physics_frame
	await physics_frame
	var game_state: Node = root.get_node("GameState")
	game_state.call(&"reset_after_death")
	var old_scene: Node = current_scene
	change_scene_to_file(TEST_REGION_SCENE)
	while current_scene == old_scene or current_scene == null or not current_scene.is_node_ready():
		await physics_frame


func _summary_row(target_id: StringName, undead_count: int, skill_id: StringName, results: Array[Dictionary]) -> String:
	var finished: Array[Dictionary] = results.filter(func(r: Dictionary) -> bool: return not r["died"] and not r["timeout"])
	var times: Array = finished.map(func(r: Dictionary) -> float: return r["time"])
	var damages: Array = results.map(func(r: Dictionary) -> float: return r["damage"])
	var deaths: int = results.filter(func(r: Dictionary) -> bool: return r["died"]).size()
	var timeouts: int = results.filter(func(r: Dictionary) -> bool: return r["timeout"]).size()
	var shots: int = 0
	var hits: int = 0
	for r: Dictionary in results:
		shots += r["shots"]
		hits += r["hits"]
	var time_mean: String = "%.1f초" % _mean(times) if not times.is_empty() else "-"
	var time_worst: String = "%.1f초" % times.max() if not times.is_empty() else "-"
	var condition: String = "혼자" if undead_count == 0 else "쥐 언데드 %d" % undead_count
	# 놓친 동시 공격 열은 실제로 놓친 판(놓친 직후 마나를 잰 판, 또는 놓친 중에 죽은 판)만 평균한다.
	var missed: Array[Dictionary] = results.filter(func(r: Dictionary) -> bool: return r["mana_after_miss"] >= 0.0 or r["missed_damage"] > 0.0)
	var missed_damage: String = "%.1f (%d판)" % [_mean(missed.map(func(r: Dictionary) -> float: return r["missed_damage"])), missed.size()] if not missed.is_empty() else "-"
	var after_miss: Array = results.filter(func(r: Dictionary) -> bool: return r["mana_after_miss"] >= 0.0).map(func(r: Dictionary) -> float: return r["mana_after_miss"])
	var mana_after: String = "%.1f" % _mean(after_miss) if not after_miss.is_empty() else "-"
	return "| %s | %s | %s | %s | %s | %.1f | %.0f | %d%% | %d%% | %d%% | %.1f | %.1f | %.1f | %.0f | %.1f | %s | %s | %.1f | %.1f | %.1f |" % [
		TARGETS[target_id]["name"], condition, PlayerBot.SKILLS[skill_id]["name"], time_mean, time_worst,
		_mean(damages), damages.max(), 100 * deaths / results.size(), 100 * timeouts / results.size(),
		100 * hits / maxi(shots, 1),
		_mean(results.map(func(r: Dictionary) -> float: return r["telegraphs"])),
		_mean(results.map(func(r: Dictionary) -> float: return r["rolls"])),
		_mean(results.map(func(r: Dictionary) -> float: return r["summons"])),
		_mean(results.map(func(r: Dictionary) -> float: return r["closest"])),
		_mean(results.map(func(r: Dictionary) -> float: return r["group_attacks"])),
		missed_damage, mana_after,
		_mean(results.map(func(r: Dictionary) -> float: return r["mana_min"])),
		_mean(results.map(func(r: Dictionary) -> float: return r["undead_died"])),
		_mean(results.map(func(r: Dictionary) -> float: return r["undead_released"]))]


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / values.size()
