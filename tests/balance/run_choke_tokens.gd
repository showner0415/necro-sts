extends ScenarioTest
## 길목 안 공격권 측정: 길목 시험 동굴(tests/choke_test_cave.tscn)의 아래 구역(돌아갈 길 없는 26칸 길목)에서
## 실제 속도의 쥐 N마리가 길목 너머 오른쪽 굴의 네크로맨서를 쫓는 동안, 길목 안에 공격권 없는 쥐가 몇 마리 있는지,
## 길목 안에서 공격권을 잃은 횟수(시간 제한·물고 반납), 네크로맨서가 물린 횟수를 잰다. 판정이 없어 run_all.sh에는 넣지 않는다.
## 쥐는 데이터 복사로 배회 0·체력 크게·추격 포기 없음 (속도는 그대로). 네크로맨서는 체력을 크게 하고 움직이지 않는다.
##   bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_choke_tokens.gd
## 쥐 수와 재는 시간: -- --rats=8 --seconds=60

const CHOKE_SCENE: String = "res://tests/choke_test_cave.tscn"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const TOUGH_HEALTH: float = 100000.0
const NECRO_SPOT: Vector2 = Vector2(1200, 480)
## 쥐를 놓는 왼쪽 굴의 자리들 (앞에서부터 쓴다)
const RAT_SPOTS: Array[Vector2] = [Vector2(80, 420), Vector2(80, 560), Vector2(140, 420), Vector2(140, 560), Vector2(110, 490), Vector2(170, 490), Vector2(60, 490), Vector2(200, 430)]
const DEFAULT_RATS: int = 4
const DEFAULT_SECONDS: float = 60.0


func get_start_scene() -> String:
	return CHOKE_SCENE


func _on_scene_ready() -> void:
	var count: int = mini(_arg(&"rats", DEFAULT_RATS), RAT_SPOTS.size())
	var seconds: float = _arg(&"seconds", DEFAULT_SECONDS)
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
	var frames: int = roundi(seconds * Engine.physics_ticks_per_second)
	var held_before: Dictionary = {}
	var tokenless_sum: int = 0
	var tokenless_max: int = 0
	var lost_inside: int = 0
	var health_before: float = necromancer.health
	for frame: int in frames:
		await wait_frames(1)
		var tokenless: int = 0
		for rat: Monster in rats:
			var inside: bool = index.choke_at(rat.global_position) >= 0
			var holding: bool = board.tokens.held_target(rat) == necromancer
			if inside and not holding:
				tokenless += 1
				if held_before.get(rat, false):
					lost_inside += 1
			held_before[rat] = holding
		tokenless_sum += tokenless
		tokenless_max = maxi(tokenless_max, tokenless)
	print("[측정] 실제 속도(%.0fpx/s) 쥐 %d마리, %.0f초, 26칸 길목 (돌아갈 길 없음)" % [data.move_speed, count, seconds])
	print("[측정] 길목 안 공격권 없는 쥐: 평균 %.2f마리, 가장 많을 때 %d마리. 길목 안에서 공격권을 잃은 횟수 %d (시간 제한 또는 물고 반납)" % [float(tokenless_sum) / frames, tokenless_max, lost_inside])
	print("[측정] 네크로맨서가 받은 피해 %.1f (쥐 한 번에 %.1f → 약 %d번 물림)" % [health_before - necromancer.health, data.contact_damage, roundi((health_before - necromancer.health) / data.contact_damage)])
	finish(true)


func _arg(name: StringName, fallback: float) -> float:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.split("=")[1].to_float()
	return fallback
