extends ScenarioTest
## 길찾기 부하 측정: 벽 막대가 많은 시험 굴(tests/balance/stress_cave.tscn)에서 몬스터 40마리(쥐 32, 멧돼지 8)가
## 굴을 한 바퀴 도는 네크로맨서를 쫓는 동안 프레임 시간(물리 프레임 사이의 실제 시간. 헤드리스는 그리기가 거의 없어 처리 시간과 같다)과 길찾기 횟수를 잰다. 길찾기를 바꾸기 전과 뒤를 견줄 때 쓴다.
## 몬스터는 데이터 복사로 배회 0·체력 크게·추격 포기 없음으로 하고, 처음에 한 대씩 맞혀 모두 쫓게 한다. 네크로맨서는 체력을 크게 하고 정해진 고리를 걷게 옮긴다.
## 판정(통과/실패)을 내지 않으므로 run_all.sh에는 넣지 않는다. 결과는 tests/balance/results/에 적는다.
##   bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_path_load.gd

const STRESS_SCENE: String = "res://tests/balance/stress_cave.tscn"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const BOAR_PATH: String = "res://data/monsters/boar.tres"
const RAT_COUNT: int = 32
## 멧돼지는 다섯 마리마다 한 마리 (RAT_COUNT + BOAR_COUNT의 1/5)
const BOAR_COUNT: int = 8
const TOUGH_HEALTH: float = 100000.0
## 몬스터를 놓을 빈 칸: 이 타일 간격으로 고르고, 네크로맨서 출발 자리에서 이 거리(픽셀)보다 먼 곳만
const SPAWN_STEP: int = 3
const SPAWN_MIN_DISTANCE: float = 320.0
## 네크로맨서가 걷는 고리 (타일, 모두 빈 줄·빈 열)와 속도 (픽셀/초)
const LOOP_TILES: Array[Vector2] = [Vector2(7, 7), Vector2(39, 7), Vector2(39, 23), Vector2(7, 23)]
const WALK_SPEED: float = 50.0
## 재기 전에 기다리는 시간과 재는 시간 (초)
const WARMUP_SECONDS: float = 3.0
const MEASURE_SECONDS: float = 30.0

var _necromancer: Necromancer
var _grid: NavigationGrid
var _monsters: Array[Monster] = []


func get_start_scene() -> String:
	return STRESS_SCENE


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	_necromancer.max_health = TOUGH_HEALTH
	_necromancer.health = TOUGH_HEALTH
	_grid = get_first_node_in_group(&"navigation_grid") as NavigationGrid
	var walls: PlaceholderWalls = current_scene.get_node("Walls") as PlaceholderWalls
	var spots: Array[Vector2] = _spawn_spots(walls)
	var rat: MonsterData = _tough(RAT_PATH)
	var boar: MonsterData = _tough(BOAR_PATH)
	var count: int = mini(RAT_COUNT + BOAR_COUNT, spots.size())
	for i: int in count:
		var monster: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		# 다섯 마리마다 한 마리가 멧돼지 (40마리면 8)
		monster.data = boar if i % 5 == 4 else rat
		# 빈 칸을 고르게 건너뛰어 굴 전체에 흩어 놓는다.
		monster.position = spots[i * spots.size() / count]
		_necromancer.get_parent().add_child(monster)
		_monsters.append(monster)
	await wait_frames(3)
	for monster: Monster in _monsters:
		monster.take_damage(0.01, _necromancer)
	var tile: float = walls.tile_size
	var loop: Array[Vector2] = []
	for point: Vector2 in LOOP_TILES:
		loop.append((point + Vector2(0.5, 0.5)) * tile)
	_necromancer.global_position = loop[0]
	var ticks: int = Engine.physics_ticks_per_second
	var warmup: int = roundi(WARMUP_SECONDS * ticks)
	var total: int = warmup + roundi(MEASURE_SECONDS * ticks)
	var times: PackedFloat32Array = PackedFloat32Array()
	var chasing_sum: int = 0
	var searches_before: int = 0
	var usec_before: int = 0
	var leg: int = 0
	for frame: int in total:
		_walk(loop, leg)
		if _necromancer.global_position.distance_to(loop[(leg + 1) % loop.size()]) < 1.0:
			leg = (leg + 1) % loop.size()
		var started: int = Time.get_ticks_usec()
		await wait_frames(1)
		var spent: float = (Time.get_ticks_usec() - started) / 1000.0
		if frame == warmup:
			searches_before = _grid.path_searches
			usec_before = _grid.path_search_usec
		if frame > warmup:
			times.append(spent)
			for monster: Monster in _monsters:
				if monster.get_target() != null:
					chasing_sum += 1
	times.sort()
	var mean: float = 0.0
	for value: float in times:
		mean += value
	mean /= maxi(times.size(), 1)
	var frames: int = times.size()
	print("[측정] 몬스터 %d마리 (쥐 %d, 멧돼지 %d), %.0f초" % [_monsters.size(), _count(&"rat"), _count(&"boar"), MEASURE_SECONDS])
	print("[측정] 프레임 시간(ms, 물리 프레임 사이의 실제 시간): 평균 %.2f, 중앙 %.2f, 95%% %.2f, 최대 %.2f" % [mean, times[frames / 2], times[mini(frames - 1, roundi(frames * 0.95))], times[frames - 1]])
	var searches: int = _grid.path_searches - searches_before
	var search_ms: float = (_grid.path_search_usec - usec_before) / 1000.0
	print("[측정] 쫓는 몸 평균 %.1f마리, 길찾기 %d번 (초당 %.1f), 길찾기에 쓴 시간 %.1fms (프레임당 %.3fms, 한 번에 %.3fms)" % [float(chasing_sum) / frames, searches, searches / MEASURE_SECONDS, search_ms, search_ms / frames, search_ms / maxi(searches, 1)])
	finish(true)


## 네크로맨서를 고리의 이번 구간 끝 쪽으로 한 프레임만큼 옮긴다.
func _walk(loop: Array[Vector2], leg: int) -> void:
	var goal: Vector2 = loop[(leg + 1) % loop.size()]
	var step: float = WALK_SPEED / Engine.physics_ticks_per_second
	_necromancer.global_position = _necromancer.global_position.move_toward(goal, step)


func _tough(path: String) -> MonsterData:
	var data: MonsterData = (load(path) as MonsterData).duplicate()
	data.wander_speed = 0.0
	data.max_health = TOUGH_HEALTH
	data.chase_attacker_limit = 0.0
	data.chase_lost_time = 0.0
	data.chase_time_limit = 0.0
	return data


func _count(id: StringName) -> int:
	var count: int = 0
	for monster: Monster in _monsters:
		if monster.data.id == id:
			count += 1
	return count


## 빈 칸 가운데들 (SPAWN_STEP 타일 간격, 네크로맨서 출발 자리에서 먼 곳만).
func _spawn_spots(walls: PlaceholderWalls) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var size: Vector2i = walls.grid_size()
	var start: Vector2 = (LOOP_TILES[0] + Vector2(0.5, 0.5)) * walls.tile_size
	for y: int in range(1, size.y - 1, SPAWN_STEP):
		for x: int in range(1, size.x - 1, SPAWN_STEP):
			var cell: Vector2i = Vector2i(x, y)
			if walls.is_wall(cell):
				continue
			var center: Vector2 = walls.cell_center(cell)
			if center.distance_to(start) > SPAWN_MIN_DISTANCE:
				spots.append(center)
	return spots
