extends ScenarioTest
## 길목 안 공격권 측정: 길목 시험 동굴(tests/choke_test_cave.tscn)의 아래 구역(돌아갈 길 없는 26칸 길목)에서
## 실제 속도의 쥐 N마리가 길목 너머 오른쪽 굴의 네크로맨서를 쫓는 동안, 길목 안에 공격권 없는 쥐가 몇 마리 있는지,
## 길목 안에서 공격권을 잃은 횟수(시간 제한·물고 반납), 네크로맨서가 물린 횟수를 잰다. 판정이 없어 run_all.sh에는 넣지 않는다.
## 쥐는 데이터 복사로 배회 0·체력 크게·추격 포기 없음 (속도는 그대로). 네크로맨서는 체력을 크게 하고 움직이지 않는다.
##   bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_choke_tokens.gd
## 쥐 수와 재는 시간: -- --rats=8 --seconds=60
## 여러 판 (봇 측정 5b): --seeds=10이면 판마다 씬을 다시 불러 던전 상태·공격권 난수·전역 난수를 BASE_SEED + 판 번호로 맞추고,
##   판마다 [판] 줄과 마지막에 [요약] 줄(물린 횟수 평균·최소~최대)을 찍는다. 없으면 지금 씬에서 한 판이고 출력은 [측정] 세 줄 그대로다.
## 진단 (봇 측정 5b): --diagnose=1이면 판마다 [진단] 줄을 더 찍는다 (여러 판이면 [요약]에 평균도).
##   - 공격권을 든 쥐가 어디에 있었는지: 길목 입구 쪽(길목 왼쪽)·길목 안·길목 너머(길목 오른쪽 끝보다 오른쪽) 프레임 평균 마리 수
##   - 공격권을 새로 받은 때 그 쥐가 어디 있었는지 (보통·추가 공격권을 따로 센다)
##   - 길목 너머에 닿은 쥐 수와 처음 닿은 시각, 길목 너머에 있던 쥐의 프레임 평균 마리 수, 통행 자리(ChokePasses)를 든 쥐의 프레임 평균 마리 수
## 길목 통행 자리(봇 측정 5b) 뒤로는 길목을 지나는 쥐가 공격권 대신 통행 자리를 들어서, [측정]의 "길목 안 공격권 없는 쥐"는 길목을 지나는 쥐 수에 가깝다
## 길목은 그 씬에서 돌아갈 길이 없는 길목(우회 비율이 모두 0 이하)이고, 없으면 칸이 가장 많은 길목이다.

const CHOKE_SCENE: String = "res://tests/choke_test_cave.tscn"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const TOUGH_HEALTH: float = 100000.0
const NECRO_SPOT: Vector2 = Vector2(1200, 480)
## 쥐를 놓는 왼쪽 굴의 자리들 (앞에서부터 쓴다)
const RAT_SPOTS: Array[Vector2] = [Vector2(80, 420), Vector2(80, 560), Vector2(140, 420), Vector2(140, 560), Vector2(110, 490), Vector2(170, 490), Vector2(60, 490), Vector2(200, 430)]
const DEFAULT_RATS: int = 4
const DEFAULT_SECONDS: float = 60.0
## 여러 판일 때 판 번호에 더하는 시드
const BASE_SEED: int = 4000
## 진단에서 쥐가 있는 곳
const ZONES: Array[StringName] = [&"입구 쪽", &"길목 안", &"길목 너머"]


func get_start_scene() -> String:
	return CHOKE_SCENE


func _on_scene_ready() -> void:
	var count: int = mini(_arg(&"rats", DEFAULT_RATS), RAT_SPOTS.size())
	var seconds: float = _arg(&"seconds", DEFAULT_SECONDS)
	var seeds: int = int(_arg(&"seeds", 0.0))
	var diagnose: bool = _arg(&"diagnose", 0.0) > 0.0
	if seeds <= 0:
		var result: Dictionary = await _measure(count, seconds)
		print("[측정] 실제 속도(%.0fpx/s) 쥐 %d마리, %.0f초, 26칸 길목 (돌아갈 길 없음)" % [result["speed"], count, seconds])
		print("[측정] 길목 안 공격권 없는 쥐: 평균 %.2f마리, 가장 많을 때 %d마리. 길목 안에서 공격권을 잃은 횟수 %d (시간 제한 또는 물고 반납)" % [result["tokenless_avg"], result["tokenless_max"], result["lost_inside"]])
		print("[측정] 네크로맨서가 받은 피해 %.1f (쥐 한 번에 %.1f → 약 %d번 물림)" % [result["damage"], result["contact"], result["bites"]])
		if diagnose:
			_print_diagnosis("한 판", result)
		finish(true)
		return
	print("[측정] 실제 속도 쥐 %d마리, %.0f초, 26칸 길목 (돌아갈 길 없음), 시드 %d개 (%d~%d)" % [count, seconds, seeds, BASE_SEED, BASE_SEED + seeds - 1])
	var results: Array[Dictionary] = []
	for run: int in seeds:
		await reload_fight_scene(CHOKE_SCENE, BASE_SEED + run)
		seed(BASE_SEED + run)
		var result: Dictionary = await _measure(count, seconds)
		print("[판] %d (시드 %d): 물림 %d번, 길목 안 공격권 없는 쥐 평균 %.2f·최대 %d, 길목 안에서 잃은 공격권 %d" % [run, BASE_SEED + run, result["bites"], result["tokenless_avg"], result["tokenless_max"], result["lost_inside"]])
		if diagnose:
			_print_diagnosis("판 %d" % run, result)
		results.append(result)
	_print_summary(count, results, diagnose)
	finish(true)


## 한 판을 잰다 (지금 씬에서). 결과 사전의 키는 아래 return 참고
func _measure(count: int, seconds: float) -> Dictionary:
	var necromancer: Necromancer = find_necromancer()
	necromancer.max_health = TOUGH_HEALTH
	necromancer.health = TOUGH_HEALTH
	necromancer.global_position = NECRO_SPOT
	var grid: NavigationGrid = get_first_node_in_group(&"navigation_grid") as NavigationGrid
	var board: AttackTokenBoard = get_first_node_in_group(&"attack_tokens") as AttackTokenBoard
	var data: MonsterData = (load(RAT_PATH) as MonsterData).duplicate()
	data.wander_speed = 0.0
	data.max_health = TOUGH_HEALTH
	data.chase_attacker_limit = 0.0
	data.chase_lost_time = 0.0
	data.chase_time_limit = 0.0
	var rats: Array[Monster] = []
	for i: int in count:
		var rat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		rat.data = data
		rat.position = RAT_SPOTS[i]
		necromancer.get_parent().add_child(rat)
		rats.append(rat)
	await wait_frames(3)
	for rat: Monster in rats:
		rat.take_damage(0.01, necromancer)
	var index: ChokeIndex = grid.get_choke_index()
	var bounds: Rect2 = _choke_bounds(index)
	var frames: int = roundi(seconds * Engine.physics_ticks_per_second)
	var held_before: Dictionary = {}
	var tokenless_sum: int = 0
	var tokenless_max: int = 0
	var lost_inside: int = 0
	var health_before: float = necromancer.health
	# 진단: 구역마다 공격권을 든 쥐의 프레임 합, 새로 받은 공격권(보통·추가)의 구역, 너머에 닿은 쥐
	var holder_frames: Dictionary = {}
	var normal_grants: Dictionary = {}
	var extra_grants: Dictionary = {}
	for zone: StringName in ZONES:
		holder_frames[zone] = 0
		normal_grants[zone] = 0
		extra_grants[zone] = 0
	var reached: Dictionary = {}
	var first_reach: float = -1.0
	var beyond_frames: int = 0
	var pass_frames: int = 0
	for frame: int in frames:
		await wait_frames(1)
		var tokenless: int = 0
		var extra: Object = board.tokens.extra_holder(necromancer)
		for rat: Monster in rats:
			var inside: bool = index.choke_at(rat.global_position) >= 0
			var holding: bool = board.tokens.held_target(rat) == necromancer
			if inside and not holding:
				tokenless += 1
				if held_before.get(rat, false):
					lost_inside += 1
			var zone: StringName = _zone_of(rat.global_position, inside, bounds)
			if holding:
				holder_frames[zone] += 1
				if not held_before.get(rat, false):
					if rat == extra:
						extra_grants[zone] += 1
					else:
						normal_grants[zone] += 1
			if board.passes.is_holding(rat):
				pass_frames += 1
			if zone == &"길목 너머":
				beyond_frames += 1
				if not reached.has(rat):
					reached[rat] = true
					if first_reach < 0.0:
						first_reach = float(frame + 1) / Engine.physics_ticks_per_second
			held_before[rat] = holding
		tokenless_sum += tokenless
		tokenless_max = maxi(tokenless_max, tokenless)
	var damage: float = health_before - necromancer.health
	var holder_avg: Dictionary = {}
	for zone: StringName in ZONES:
		holder_avg[zone] = float(holder_frames[zone]) / frames
	return {
		"speed": data.move_speed, "contact": data.contact_damage, "damage": damage, "bites": roundi(damage / data.contact_damage),
		"tokenless_avg": float(tokenless_sum) / frames, "tokenless_max": tokenless_max, "lost_inside": lost_inside,
		"holder_avg": holder_avg, "normal_grants": normal_grants, "extra_grants": extra_grants,
		"reached": reached.size(), "first_reach": first_reach, "beyond_avg": float(beyond_frames) / frames, "pass_avg": float(pass_frames) / frames,
	}


func _print_diagnosis(label: String, result: Dictionary) -> void:
	var holder_avg: Dictionary = result["holder_avg"]
	var normal: Dictionary = result["normal_grants"]
	var extra: Dictionary = result["extra_grants"]
	print("[진단] %s: 공격권을 든 쥐 (프레임 평균) 입구 쪽 %.2f · 길목 안 %.2f · 너머 %.2f. 새로 받은 공격권 보통 입구 쪽 %d · 길목 안 %d · 너머 %d, 추가 입구 쪽 %d · 길목 안 %d · 너머 %d. 너머에 닿은 쥐 %d마리 (처음 %.1f초), 너머에 있던 쥐 평균 %.2f마리, 통행 자리를 든 쥐 평균 %.2f마리" % [
		label, holder_avg[&"입구 쪽"], holder_avg[&"길목 안"], holder_avg[&"길목 너머"],
		normal[&"입구 쪽"], normal[&"길목 안"], normal[&"길목 너머"], extra[&"입구 쪽"], extra[&"길목 안"], extra[&"길목 너머"],
		result["reached"], result["first_reach"], result["beyond_avg"], result["pass_avg"]])


func _print_summary(count: int, results: Array[Dictionary], diagnose: bool) -> void:
	var bites: Array[int] = []
	var bites_sum: int = 0
	var tokenless_sum: float = 0.0
	var lost_sum: int = 0
	for result: Dictionary in results:
		bites.append(result["bites"])
		bites_sum += result["bites"]
		tokenless_sum += result["tokenless_avg"]
		lost_sum += result["lost_inside"]
	var runs: int = results.size()
	print("[요약] 쥐 %d마리 × %d판: 물린 횟수 평균 %.1f (최소 %d ~ 최대 %d), 길목 안 공격권 없는 쥐 평균 %.2f, 길목 안에서 잃은 공격권 합 %d" % [
		count, runs, float(bites_sum) / runs, bites.min(), bites.max(), tokenless_sum / runs, lost_sum])
	if not diagnose:
		return
	var holder: Dictionary = {}
	var normal: Dictionary = {}
	var extra: Dictionary = {}
	for zone: StringName in ZONES:
		holder[zone] = 0.0
		normal[zone] = 0.0
		extra[zone] = 0.0
	var reached_sum: int = 0
	var first_sum: float = 0.0
	var first_runs: int = 0
	var beyond_sum: float = 0.0
	var pass_sum: float = 0.0
	for result: Dictionary in results:
		for zone: StringName in ZONES:
			holder[zone] += result["holder_avg"][zone]
			normal[zone] += result["normal_grants"][zone]
			extra[zone] += result["extra_grants"][zone]
		reached_sum += result["reached"]
		beyond_sum += result["beyond_avg"]
		pass_sum += result["pass_avg"]
		if result["first_reach"] >= 0.0:
			first_sum += result["first_reach"]
			first_runs += 1
	print("[요약] 진단 (판 평균): 공격권을 든 쥐 입구 쪽 %.2f · 길목 안 %.2f · 너머 %.2f. 새로 받은 공격권 보통 입구 쪽 %.1f · 길목 안 %.1f · 너머 %.1f, 추가 입구 쪽 %.1f · 길목 안 %.1f · 너머 %.1f. 너머에 닿은 쥐 %.1f마리 (처음 %.1f초), 너머에 있던 쥐 평균 %.2f마리, 통행 자리를 든 쥐 평균 %.2f마리" % [
		holder[&"입구 쪽"] / runs, holder[&"길목 안"] / runs, holder[&"길목 너머"] / runs,
		normal[&"입구 쪽"] / runs, normal[&"길목 안"] / runs, normal[&"길목 너머"] / runs,
		extra[&"입구 쪽"] / runs, extra[&"길목 안"] / runs, extra[&"길목 너머"] / runs,
		float(reached_sum) / runs, first_sum / maxi(first_runs, 1), beyond_sum / runs, pass_sum / runs])


## 쥐가 있는 곳: 길목 안이면 "길목 안", 길목 오른쪽 끝보다 오른쪽이면 "길목 너머", 아니면 "입구 쪽"
func _zone_of(point: Vector2, inside: bool, bounds: Rect2) -> StringName:
	if inside:
		return &"길목 안"
	if point.x > bounds.end.x:
		return &"길목 너머"
	return &"입구 쪽"


## 쥐가 지나는 길목(돌아갈 길이 없는 길목, 없으면 칸이 가장 많은 길목)의 월드 사각형
func _choke_bounds(index: ChokeIndex) -> Rect2:
	var chosen: int = -1
	var most_cells: int = -1
	for i: int in index.chokes.size():
		var ratios: PackedFloat32Array = index.chokes[i].detour_ratios
		var no_detour: bool = true
		for ratio: float in ratios:
			if ratio > 0.0:
				no_detour = false
		if no_detour:
			chosen = i
			break
		if index.chokes[i].cells.size() > most_cells:
			most_cells = index.chokes[i].cells.size()
			chosen = i
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for rect: Rect2 in index.cell_rects(chosen):
		bounds = rect if first else bounds.merge(rect)
		first = false
	return bounds


func _arg(name: StringName, fallback: float) -> float:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.split("=")[1].to_float()
	return fallback
