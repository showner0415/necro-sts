extends ScenarioTest
## 줄 서기(콩고 라인) 측정: 무리가 물러나는 네크로맨서를 쫓는 동안 얼마나 한 줄로 서는지 잰다. 쫓는 움직임을 바꾸기 전과 뒤를 견줄 때 쓴다.
## 테스트 싸움터(벽 없음)에서 몬스터를 치우고 무리 하나를 네크로맨서 서쪽에 놓은 뒤 한 대씩 맞혀 쫓게 한다.
## 네크로맨서는 정해진 길(ROUTE의 점들을 차례로: 동 → 남 → 서)을 "거리 두기"로 걷는다: 가장 가까운 몬스터가 --keep 안이면 --speed로 걷고, 아니면 선다
## (쏘며 물러나는 플레이어 흉내. 그래서 평균 속도가 몬스터 속도에 맞춰진다). 이동 키 입력을 흉내 내 실제로 걷는다 (걷는 속도만 --speed로 바꾼다).
## 퍼져 다가가기 값 바꿔 재기 (측정 안에서만, 데이터 복사본): -- --fan_step=0 --lead=0 (둘 다 0이면 고치기 전처럼 대상을 곧장 쫓는다), --fan_max=<도>, --lead_time=<초>
## 몬스터는 데이터 복사로 배회 0·체력 크게·추격 포기 없음. 네크로맨서도 체력을 크게 한다. 실제 .tres는 바꾸지 않는다.
## 판정(통과/실패)을 내지 않으므로 run_all.sh에는 넣지 않는다. 결과는 tests/balance/results/에 적는다.
##   bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_conga.gd
## 일부만: -- --cases=rat_gang4,rat_big8 --seeds=3
## 걷는 속도·거리 두기 바꾸기: -- --speed=50 --keep=90 (기본: 쏘며 걷는 속도 50, 거리 90)
## 그림으로 보기: -- --cases=rat_big8 --seeds=1 --out=<PNG 경로> (PANEL_SECONDS초마다 한 칸: 네크로맨서 흰 십자와 지나온 길, 몬스터 점, 몬스터가 지나온 길)
##
## 재는 것 (쫓는 몬스터가 둘 이상인 프레임의 평균. 축 = 무리 가운데 → 네크로맨서):
## - 가로 폭: 축에 직각인 쪽으로 무리가 퍼진 폭 (px, 가장 왼쪽 ~ 가장 오른쪽)
## - 세로 길이: 축 방향으로 늘어선 길이 (px, 맨 앞 ~ 맨 뒤)
## - 줄 비율: 세로 길이 ÷ 가로 폭. 클수록 한 줄이다 (1이면 둥근 덩어리, 1보다 작으면 옆으로 넓게 선 것)
## - 각도 범위: 네크로맨서가 볼 때 몬스터들이 들어오는 방향의 범위 (도). 작으면 모두 같은 쪽에서 온다
## - 한 줄 시간: 줄 비율이 LINE_RATIO 이상인 프레임의 비율 (%)
## - 가장 가까운 거리, 문 횟수(네크로맨서가 맞은 횟수), 걸은 거리: 압박이 달라졌는지 본다

const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const PALETTE_PATH: String = "res://assets/palette/endesga-32.hex"
const RAT: String = "res://data/monsters/rat.tres"
const BOAR: String = "res://data/monsters/boar.tres"
const GOBLIN: String = "res://data/monsters/goblin_slinger.tres"
## 경우 id → 이름과 무리원 데이터 목록
const CASES: Dictionary = {
	&"rat_gang4": {"name": "쥐 패거리(4)", "datas": [RAT, RAT, RAT, RAT]},
	&"rat_big8": {"name": "쥐 큰 무리(8)", "datas": [RAT, RAT, RAT, RAT, RAT, RAT, RAT, RAT]},
	&"boar_pack3": {"name": "멧돼지 무리(3)", "datas": [BOAR, BOAR, BOAR]},
	&"goblin_pack3": {"name": "투석병 무리(3)", "datas": [GOBLIN, GOBLIN, GOBLIN]},
	&"mixed4": {"name": "섞인 무리(멧돼지 1 + 쥐 3)", "datas": [BOAR, RAT, RAT, RAT]},
}
const DEFAULT_CASES: Array[StringName] = [&"rat_gang4", &"rat_big8", &"boar_pack3", &"goblin_pack3", &"mixed4"]
const BASE_SEED: int = 7000
const TOUGH_HEALTH: float = 100000.0
## 네크로맨서가 걷는 길 (첫 점이 출발 자리). 벽 없는 테스트 싸움터의 길
const ROUTE: Array[Vector2] = [Vector2(-220, -220), Vector2(180, -220), Vector2(180, 180), Vector2(-220, 180)]
## --walls=1이면 벽 막대가 있는 부하 측정 굴에서 잰다 (길찾기로 벽을 돌아 쫓는 동안의 줄 서기). 길은 타일 좌표: 막대 사이 틈을 두 번 지난다
const WALL_SCENE: String = "res://tests/balance/stress_cave.tscn"
const WALL_ROUTE_TILES: Array[Vector2] = [Vector2(8.5, 7.5), Vector2(24, 7.5), Vector2(24, 15.5), Vector2(8, 15.5), Vector2(8, 23.5), Vector2(24, 23.5)]
const WALL_TILE_SIZE: float = 32.0
## 길의 점에 이 거리(px) 안으로 오면 다음 점으로 간다
const ROUTE_ARRIVE: float = 3.0
## 무리 자리: 출발 자리에서 이만큼 (서쪽). 무리원은 PackSpawn처럼 이 자리 둘레 PLACE_RADIUS 안에 서로 PLACE_SPACING 띄워 놓는다
const PACK_OFFSET: Vector2 = Vector2(-110, 0)
const PLACE_RADIUS: float = 48.0
const PLACE_SPACING: float = 16.0
const PLACE_TRIES: int = 30
## 한 판의 최대 시간 (초). 길을 다 걷거나 이 시간이 지나면 끝난다
const TIME_LIMIT: float = 60.0
## 줄 비율이 이 값 이상이면 한 줄로 센다. 가로 폭이 MIN_WIDTH보다 좁으면 이 값으로 나눈다 (0으로 나누지 않게)
const LINE_RATIO: float = 2.0
const MIN_WIDTH: float = 8.0
## 그림: 배율, 네크로맨서에서 그릴 거리(px), 한 칸의 시간(초), 칸 사이 간격, 지나온 길을 그리는 시간(초)
const SCALE: float = 1.5
const VIEW_RADIUS: float = 170.0
const PANEL_SECONDS: float = 5.0
const PANEL_GAP: int = 4
const TRAIL_SECONDS: float = 2.0
const BACKGROUND_INDEX: int = 25
const GRID_INDEX: int = 24
const NECRO_INDEX: int = 19
const MONSTER_COLOR_INDICES: Array[int] = [10, 17, 28, 14, 6, 22, 12, 30]

var _speed: float = 50.0
var _keep: float = 90.0
var _seeds: int = 3
var _cases: Array[StringName] = DEFAULT_CASES
var _out_path: String = ""
var _palette: Array[Color] = []
var _clip: Rect2i
var _bites: int = 0
## 퍼져 다가가기 값 덮어쓰기 (0보다 작으면 데이터 그대로)
var _fan_step: float = -1.0
var _fan_max: float = -1.0
var _lead: float = -1.0
var _lead_time: float = -1.0


func get_start_scene() -> String:
	return _scene()


## 재는 씬: --walls=1이면 벽 막대 굴, 아니면 테스트 싸움터
func _scene() -> String:
	return WALL_SCENE if OS.get_cmdline_user_args().has("--walls=1") else TEST_REGION_SCENE


## 걷는 길 (발밑 좌표의 점들)
func _route() -> Array[Vector2]:
	if _scene() != WALL_SCENE:
		return ROUTE
	var route: Array[Vector2] = []
	for tile: Vector2 in WALL_ROUTE_TILES:
		route.append(tile * WALL_TILE_SIZE)
	return route


func _on_scene_ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="):
			_speed = arg.trim_prefix("--speed=").to_float()
		elif arg.begins_with("--keep="):
			_keep = arg.trim_prefix("--keep=").to_float()
		elif arg.begins_with("--seeds="):
			_seeds = arg.trim_prefix("--seeds=").to_int()
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--fan_step="):
			_fan_step = arg.trim_prefix("--fan_step=").to_float()
		elif arg.begins_with("--fan_max="):
			_fan_max = arg.trim_prefix("--fan_max=").to_float()
		elif arg.begins_with("--lead="):
			_lead = arg.trim_prefix("--lead=").to_float()
		elif arg.begins_with("--lead_time="):
			_lead_time = arg.trim_prefix("--lead_time=").to_float()
		elif arg.begins_with("--cases="):
			_cases = []
			for id: String in arg.trim_prefix("--cases=").split(","):
				_cases.append(StringName(id))
	_load_palette()
	_run_all()


func _run_all() -> void:
	print("[측정] 걷는 속도 %.0f, 거리 두기 %.0f, 경우마다 %d판 (시드 %d부터)" % [_speed, _keep, _seeds, BASE_SEED])
	print("| 무리 | 가로 폭 | 세로 길이 | 줄 비율 | 각도 범위 | 한 줄 시간 | 가장 가까운 거리 | 문 횟수 | 걸은 거리 | 시간 |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for id: StringName in _cases:
		if not CASES.has(id):
			print("[실패] 모르는 경우: %s" % id)
			start_failures += 1
			continue
		var sums: Dictionary = {}
		var runs: int = 0
		for run: int in _seeds:
			var result: Dictionary = await _run(id, run)
			if result.is_empty():
				continue
			runs += 1
			for key: String in result:
				sums[key] = sums.get(key, 0.0) + result[key]
		if runs == 0:
			continue
		var mean: Dictionary = {}
		for key: String in sums:
			mean[key] = sums[key] / runs
		print("| %s | %.0f | %.0f | %.2f | %.0f° | %.0f%% | %.0f | %.1f | %.0f | %.1f초 |" % [CASES[id]["name"], mean["width"], mean["length"], mean["ratio"], mean["arc"],
			mean["line_share"] * 100.0, mean["nearest"], mean["bites"], mean["walked"], mean["time"]])
	finish(start_failures == 0)


## 한 판. 결과: width, length, ratio, arc, line_share, nearest, bites, walked, time (모두 float). 시작 검사에 실패하면 빈 Dictionary.
func _run(id: StringName, run: int) -> Dictionary:
	await reload_fight_scene(_scene(), BASE_SEED + run)
	seed(BASE_SEED + run)
	var region: Node = current_scene
	var necromancer: Necromancer = find_necromancer()
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	for node: Node in region.find_children("*", "EscapePoint", true, false):
		node.free()
	necromancer.max_health = TOUGH_HEALTH
	necromancer.health = TOUGH_HEALTH
	var route: Array[Vector2] = _route()
	necromancer.global_position = route[0]
	necromancer.move_speed = _speed
	_bites = 0
	necromancer.health_changed.connect(_on_health_changed.bind([TOUGH_HEALTH]))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = BASE_SEED + run
	var datas: Array = CASES[id]["datas"]
	var copies: Dictionary = {}
	var monsters: Array[Monster] = []
	var placed: Array[Vector2] = []
	for path: String in datas:
		if not copies.has(path):
			copies[path] = _tough(path)
		var monster: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		monster.data = copies[path]
		monster.position = _place(rng, placed, route[0] + PACK_OFFSET)
		placed.append(monster.position)
		necromancer.get_parent().add_child(monster)
		monsters.append(monster)
	var pack: MonsterPack = MonsterPack.new()
	pack.set_members(monsters)
	region.add_child(pack)
	if not check_fight_start(_scene(), monsters.size()):
		return {}
	await wait_frames(3)
	for monster: Monster in monsters:
		monster.take_damage(0.01, necromancer)

	var ticks: int = Engine.physics_ticks_per_second
	var leg: int = 1
	var last_position: Vector2 = necromancer.global_position
	var walked: float = 0.0
	var frames: int = 0
	var samples: int = 0
	var sum_width: float = 0.0
	var sum_length: float = 0.0
	var sum_ratio: float = 0.0
	var sum_arc: float = 0.0
	var sum_nearest: float = 0.0
	var line_frames: int = 0
	# 그림용 기록: 프레임마다 네크로맨서 자리와 몬스터 자리들
	var necro_track: Array[Vector2] = []
	var monster_tracks: Array = []
	while leg < route.size() and frames < roundi(TIME_LIMIT * ticks):
		var target: Vector2 = necromancer.global_position
		var chasing: Array[Vector2] = []
		var nearest: float = INF
		for monster: Monster in monsters:
			nearest = minf(nearest, monster.global_position.distance_to(target))
			if monster.get_target() != null:
				chasing.append(monster.global_position)
		if chasing.size() >= 2:
			var shape: Dictionary = measure_shape(chasing, target)
			samples += 1
			sum_width += shape["width"]
			sum_length += shape["length"]
			sum_ratio += shape["ratio"]
			sum_arc += shape["arc"]
			sum_nearest += nearest
			if shape["ratio"] >= LINE_RATIO:
				line_frames += 1
		necro_track.append(target)
		monster_tracks.append(monsters.map(func(m: Monster) -> Vector2: return m.global_position))
		# 거리 두기: 가장 가까운 몬스터가 keep 안이면 길을 따라 걷는다.
		walked += target.distance_to(last_position)
		last_position = target
		if target.distance_to(route[leg]) <= ROUTE_ARRIVE:
			leg += 1
			if leg >= route.size():
				break
		press_moves(target.direction_to(route[leg]) if nearest < _keep else Vector2.ZERO)
		await wait_frames(1)
		frames += 1
	press_moves(Vector2.ZERO)
	if not _out_path.is_empty() and run == 0:
		_draw(necro_track, monster_tracks, _out_path if _cases.size() == 1 else _out_path.get_basename() + "_" + String(id) + ".png")
	var count: float = maxf(samples, 1)
	return {"width": sum_width / count, "length": sum_length / count, "ratio": sum_ratio / count, "arc": sum_arc / count, "line_share": line_frames / count,
		"nearest": sum_nearest / count, "bites": float(_bites), "walked": walked, "time": float(frames) / ticks}


## 무리 모양: 쫓는 몬스터 자리들(points)과 대상 자리(target)로 가로 폭·세로 길이·줄 비율·각도 범위를 낸다.
## tests/scenarios/scenario_chase_fan.gd가 이 함수의 가로 폭으로 통과 기준(60px, 사용자 결정 2026-11-18)을 본다. 재는 법을 바꾸면 그 시나리오를 다시 돌린다.
static func measure_shape(points: Array[Vector2], target: Vector2) -> Dictionary:
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in points:
		center += point
	center /= points.size()
	var axis: Vector2 = center.direction_to(target) if center.distance_to(target) > 0.001 else Vector2.RIGHT
	var side: Vector2 = axis.orthogonal()
	var along_min: float = INF
	var along_max: float = -INF
	var side_min: float = INF
	var side_max: float = -INF
	var bearings: Array[float] = []
	for point: Vector2 in points:
		var offset: Vector2 = point - center
		along_min = minf(along_min, offset.dot(axis))
		along_max = maxf(along_max, offset.dot(axis))
		side_min = minf(side_min, offset.dot(side))
		side_max = maxf(side_max, offset.dot(side))
		bearings.append((point - target).angle())
	var width: float = side_max - side_min
	var length: float = along_max - along_min
	# 각도 범위: 모든 방향을 담는 가장 작은 호 = 360 - 이웃한 방향 사이의 가장 큰 빈틈
	bearings.sort()
	var widest_gap: float = 0.0
	for i: int in bearings.size():
		var next: float = bearings[(i + 1) % bearings.size()] + (TAU if i == bearings.size() - 1 else 0.0)
		widest_gap = maxf(widest_gap, next - bearings[i])
	return {"width": width, "length": length, "ratio": length / maxf(width, MIN_WIDTH), "arc": rad_to_deg(TAU - widest_gap)}


func _on_health_changed(health: float, _max_health: float, last: Array) -> void:
	if health < last[0]:
		_bites += 1
	last[0] = health


## 무리원 자리: 무리 자리 둘레 PLACE_RADIUS 안의 마구 자리, 이미 놓은 무리원과 PLACE_SPACING 띄운다 (PLACE_TRIES번 안에 못 고르면 마지막 자리)
func _place(rng: RandomNumberGenerator, placed: Array[Vector2], center: Vector2) -> Vector2:
	var spot: Vector2 = center
	for attempt: int in PLACE_TRIES:
		spot = center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * PLACE_RADIUS
		if placed.all(func(other: Vector2) -> bool: return other.distance_to(spot) >= PLACE_SPACING):
			break
	return spot


func _tough(path: String) -> MonsterData:
	var data: MonsterData = (load(path) as MonsterData).duplicate()
	data.wander_speed = 0.0
	data.max_health = TOUGH_HEALTH
	data.chase_attacker_limit = 0.0
	data.chase_lost_time = 0.0
	data.chase_time_limit = 0.0
	if _fan_step >= 0.0:
		data.chase_fan_step_degrees = _fan_step
	if _fan_max >= 0.0:
		data.chase_fan_max_half_degrees = _fan_max
	if _lead >= 0.0:
		data.chase_lead_ratio = _lead
	if _lead_time >= 0.0:
		data.chase_lead_max_time = _lead_time
	return data


## PANEL_SECONDS초마다 한 칸씩 왼쪽부터 그린다. 칸의 가운데가 그 순간의 네크로맨서다.
func _draw(necro_track: Array[Vector2], monster_tracks: Array, path: String) -> void:
	var ticks: int = Engine.physics_ticks_per_second
	var per_panel: int = roundi(PANEL_SECONDS * ticks)
	var panel_count: int = maxi(1, necro_track.size() / per_panel)
	var panel: int = roundi(VIEW_RADIUS * 2.0 * SCALE)
	var image: Image = Image.create(panel * panel_count + PANEL_GAP * (panel_count - 1), panel, false, Image.FORMAT_RGBA8)
	image.fill(_palette[GRID_INDEX])
	var trail: int = roundi(TRAIL_SECONDS * ticks)
	for k: int in panel_count:
		_clip = Rect2i(k * (panel + PANEL_GAP), 0, panel, panel)
		image.fill_rect(_clip, _palette[BACKGROUND_INDEX])
		var frame: int = mini((k + 1) * per_panel - 1, necro_track.size() - 1)
		var center: Vector2 = necro_track[frame]
		for f: int in range(maxi(frame - per_panel, 1), frame + 1):
			_line(image, necro_track[f - 1], necro_track[f], center, _palette[GRID_INDEX])
		var now: Array = monster_tracks[frame]
		for i: int in now.size():
			var color: Color = _palette[MONSTER_COLOR_INDICES[i % MONSTER_COLOR_INDICES.size()]]
			for f: int in range(maxi(frame - trail, 1), frame + 1):
				_line(image, monster_tracks[f - 1][i], monster_tracks[f][i], center, color)
			_plot(image, now[i], center, color, 3)
		for d: int in range(-6, 7):
			_plot(image, center + Vector2(d, 0) / SCALE, center, _palette[NECRO_INDEX], 0)
			_plot(image, center + Vector2(0, d) / SCALE, center, _palette[NECRO_INDEX], 0)
	image.save_png(path)
	print("[그림] %s (%d칸, 칸마다 %.0f초)" % [path, panel_count, PANEL_SECONDS])


func _to_pixel(world: Vector2, center: Vector2) -> Vector2i:
	return _clip.position + Vector2i(((world - center) * SCALE + Vector2.ONE * VIEW_RADIUS * SCALE).round())


func _plot(image: Image, world: Vector2, center: Vector2, color: Color, radius: int) -> void:
	var p: Vector2i = _to_pixel(world, center)
	for dx: int in range(-radius, radius + 1):
		for dy: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var q: Vector2i = p + Vector2i(dx, dy)
			if _clip.has_point(q):
				image.set_pixelv(q, color)


func _line(image: Image, from: Vector2, to: Vector2, center: Vector2, color: Color) -> void:
	var steps: int = maxi(1, ceili(from.distance_to(to) * SCALE))
	for s: int in steps + 1:
		_plot(image, from.lerp(to, float(s) / steps), center, color, 0)


func _load_palette() -> void:
	var file: FileAccess = FileAccess.open(PALETTE_PATH, FileAccess.READ)
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if not line.is_empty():
			_palette.append(Color.html(line))
