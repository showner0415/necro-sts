extends View3DCheck
## 3D 시야 검사. 창을 띄운다. run_all.sh에는 넣지 않는다.
## bash tools/godot.sh --fixed-fps 60 --path . -s tests/view_3d/check_vision_3d.gd -- --out=<앞벽 뒤 예고 그림.png>
## 1. 2D 판정(VisionRules)과 화면 밝기가 일치한다 (얕은 굴의 여러 자세)
## 2. 어두운 곳·플레이어 빛·언데드 빛의 밝기가 원래 색의 0.4배·1배·0.75배다
## 3. 시야를 끄면 원래 밝기
## 4. 상자: 시야 밖이면 어둡고 앞벽을 반투명하게 하지 않으며, 시야 안이면 밝고 반투명하게 한다
## 5. 잘라내기 반경을 키로 바꾼다
## 6. [측정] 앞벽 뒤 바닥의 예고 표시가 몇 픽셀 보이는지 (--marks만 주면 이것만 잰다)
## 7. [측정] 언데드 0마리·8마리의 프레임 시간

const SCENE: String = "res://regions/shallow_cave.tscn"
const SETTLE_FRAMES: int = 20
const POSES: int = 12
const POSE_SEED: int = 11
const AGREE_TARGET: float = 0.95
## 밝음·어두움을 가르는 밝기 비율 (0.4와 1의 가운데)
const LIT_RATIO: float = 0.7
const NEAR_SKIP: float = 40.0
## 바닥 색에 밝기만 곱했다고 볼 수 있는 채널별 비율 차이
const FLOOR_RATIO_SPREAD: float = 0.1
const AIM_DISTANCE: float = 200.0
const BRIGHTNESS_TOLERANCE: float = 0.04
## 측정: 화면에서 밝기를 볼 거리 (월드 픽셀)
const FAN_POINT: float = 96.0
const UNDEAD_COUNT: int = 8
const FRAME_SAMPLES: int = 240
const CHEST_FADE_FRAMES: int = 30
## 앞벽 뒤 예고 측정: 시제품 굴의 남쪽 벽(15줄부터) 바로 위 바닥 자리들 (칸)
## 멧돼지가 벽에 몸을 붙이고 설 수 있는 줄: 벽(15줄)에서 약 10픽셀
const PROTO_BOAR_CELL: Vector2 = Vector2(6.5, 14.7)
const PROTO_RING_CELL: Vector2 = Vector2(12.5, 14.5)
## 벽이 화면 가운데에 가까운 경우 (가리는 폭이 가장 넓다). 잘라내기가 닿지 않게 옆으로 떨어뜨린다
const PROTO_MID_STAND_CELL: Vector2 = Vector2(9.5, 13.5)
const PROTO_MID_BOAR_CELL: Vector2 = Vector2(3.5, 14.7)
const PROTO_MID_RING_CELL: Vector2 = Vector2(14.5, 14.5)
## 대조군: 벽에서 떨어진 트인 바닥
const PROTO_OPEN_BOAR_CELL: Vector2 = Vector2(6.5, 11.5)
const PROTO_OPEN_RING_CELL: Vector2 = Vector2(12.5, 11.5)
## 잘라내기가 표시에 닿지 않을 만큼 떨어지되 표시가 화면 안에 드는 자리
const PROTO_STAND_CELL: Vector2 = Vector2(9.5, 10.5)
const LINE_SAMPLES: int = 24
const LINE_LENGTH: float = 120.0
const RING_RADIUS: float = 12.0
const RING_SAMPLES: int = 24
const BOAR_DATA: String = "res://data/monsters/boar.tres"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const SHADOW_COLOR: Color = Color(0.89411765, 0.23137255, 0.26666668, 1)
const ZOOM: int = 2
const UNDEAD_SCENE: String = "res://undead/undead.tscn"
const RAT_SKULL: String = "res://data/skulls/rat_skull.tres"
const RAT_DATA: String = "res://data/monsters/rat.tres"

var _view: RegionView3D
var _necromancer: Necromancer
var _vision: Vision
var _cells: TerrainCells
var _floors: Array[Vector2i] = []
var _marks_only: bool = false


func get_start_scene() -> String:
	_marks_only = OS.get_cmdline_user_args().has("--marks")
	return PROTO_CAVE_SCENE if _marks_only else SCENE


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	if _marks_only:
		await _measure_marks_behind_wall()
		finish(true)
		return
	_necromancer.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	_vision = current_scene.call(&"get_vision")
	_view = open_layer()
	_view.get_front_walls().enabled = false
	_cells = TerrainCells.from_walls(current_scene.get_node("Walls") as PlaceholderWalls)
	for y: int in _cells.size.y:
		for x: int in _cells.size.x:
			if not _cells.is_wall(x, y) and _cells.top_colors[_cells.index_of(x, y)].a > 0.0:
				_floors.append(Vector2i(x, y))
	await wait_frames(SETTLE_FRAMES)
	await _check_agreement()
	await _check_brightness()
	await _check_chest()
	await _check_radius_keys()
	await _measure_frame_time()
	finish(true)


func _cell_center(cell: Vector2i) -> Vector2:
	return _cells.origin + (Vector2(cell) + Vector2(0.5, 0.5)) * _cells.tile_size


func _set_pose(world: Vector2, facing: Vector2) -> void:
	_necromancer.global_position = world
	_view.aim_override = _necromancer.get_body_center() + facing.normalized() * AIM_DISTANCE
	await wait_frames(SETTLE_FRAMES)


func _brightness(image: Image, cell: Vector2i) -> float:
	var base: Color = _cells.top_colors[_cells.index_of(cell.x, cell.y)]
	var pixel: Color = image.get_pixelv(Vector2i(_view.world_to_screen(_cell_center(cell), 0.0)))
	return (pixel.r + pixel.g + pixel.b) / (base.r + base.g + base.b)


func _check_agreement() -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = POSE_SEED
	var total: int = 0
	var agree: int = 0
	var covered: int = 0
	for pose: int in POSES:
		await _set_pose(_cell_center(_floors[random.randi() % _floors.size()]), Vector2.from_angle(random.randf() * TAU))
		var image: Image = await capture()
		var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(image.get_size()))
		var origin: Vector2 = _necromancer.get_body_center()
		var facing: Vector2 = _view.aim_override - origin
		for cell: Vector2i in _floors:
			var world: Vector2 = _cell_center(cell)
			var screen: Vector2 = _view.world_to_screen(world, 0.0)
			if not bounds.has_point(screen) or world.distance_to(_necromancer.global_position) < NEAR_SKIP:
				continue
			if not _is_floor_pixel(image, screen, cell):
				covered += 1
				continue
			var level: int = _vision.rules.level_with_walls(origin, facing, world)
			if level != 0 and level != _vision.rules.hidden_level():
				continue
			total += 1
			if (_brightness(image, cell) > LIT_RATIO) == (level == 0):
				agree += 1
	var ratio: float = float(agree) / maxf(total, 1)
	if ratio < AGREE_TARGET:
		fail_step("판정과 밝기", "일치 %.1f%% (기준 %.0f%%), 칸 %d개" % [ratio * 100.0, AGREE_TARGET * 100.0, total])
		return
	pass_step("판정과 밝기", "일치 %.1f%%, %d자세 칸 %d개 (벽에 가려 뺀 칸 %d개)" % [ratio * 100.0, POSES, total, covered])


## 이 화면 점이 그 칸의 바닥을 보여 주는지: 바닥 색에 밝기만 곱한 색이면 바닥이고, 색 비율이 다르면 앞에 벽이 있다.
func _is_floor_pixel(image: Image, screen: Vector2, cell: Vector2i) -> bool:
	var base: Color = _cells.top_colors[_cells.index_of(cell.x, cell.y)]
	var pixel: Color = image.get_pixelv(Vector2i(screen))
	var r: float = pixel.r / maxf(base.r, 0.001)
	var g: float = pixel.g / maxf(base.g, 0.001)
	var b: float = pixel.b / maxf(base.b, 0.001)
	return maxf(r, maxf(g, b)) - minf(r, minf(g, b)) < FLOOR_RATIO_SPREAD


## 바닥 칸 가운데에서 east로 FAN_POINT 안쪽에 벽이 없는 자리를 찾는다.
func _open_floor() -> Vector2:
	for cell: Vector2i in _floors:
		var clear: bool = true
		for dy: int in range(-6, 7):
			for dx: int in range(-6, 7):
				if _cells.is_wall(cell.x + dx, cell.y + dy) or _cells.top_colors[_cells.index_of(clampi(cell.x + dx, 0, _cells.size.x - 1), clampi(cell.y + dy, 0, _cells.size.y - 1))].a == 0.0:
					clear = false
		if clear:
			return _cell_center(cell)
	return Vector2.INF


func _level_at(image: Image, world: Vector2) -> float:
	var cell: Vector2i = Vector2i(((world - _cells.origin) / _cells.tile_size).floor())
	return _brightness(image, cell)


func _check_brightness() -> void:
	var open: Vector2 = _open_floor()
	if open == Vector2.INF:
		fail_step("밝기", "트인 바닥을 찾지 못함")
		return
	await _set_pose(open, Vector2.RIGHT)
	var image: Image = await capture()
	var lit: float = _level_at(image, open + Vector2.RIGHT * FAN_POINT)
	var dark: float = _level_at(image, open + Vector2.LEFT * FAN_POINT)
	var undead: Undead = _spawn_undead(open + Vector2.LEFT * 16.0)
	undead.process_mode = Node.PROCESS_MODE_DISABLED
	undead.facing = Vector2.LEFT
	await wait_frames(SETTLE_FRAMES)
	var with_undead: Image = await capture()
	var undead_lit: float = _level_at(with_undead, undead.global_position + Vector2.LEFT * FAN_POINT)
	var overlap_undead: Vector2 = Vector2.RIGHT
	undead.facing = overlap_undead
	await wait_frames(SETTLE_FRAMES)
	var overlap_image: Image = await capture()
	var overlap: float = _level_at(overlap_image, open + Vector2.RIGHT * FAN_POINT)
	undead.free()
	_vision.set_active(false)
	await wait_frames(SETTLE_FRAMES)
	var off_image: Image = await capture()
	var off: float = _level_at(off_image, open + Vector2.LEFT * FAN_POINT)
	_vision.set_active(true)
	await wait_frames(SETTLE_FRAMES)
	var expected: Dictionary = {"어두운 곳": [dark, _vision.darkness], "플레이어 빛": [lit, 1.0], "언데드 빛": [undead_lit, 0.75], "시야 끔": [off, 1.0]}
	for label: String in expected.keys():
		var pair: Array = expected[label]
		if absf(float(pair[0]) - float(pair[1])) > BRIGHTNESS_TOLERANCE:
			fail_step("밝기", "%s %.2f배 (기대 %.2f배)" % [label, pair[0], pair[1]])
			return
	pass_step("밝기", "어두운 곳 %.2f, 플레이어 빛 %.2f, 언데드 빛 %.2f, 시야 끔 %.2f배" % [dark, lit, undead_lit, off])
	print("[측정] 플레이어 빛과 언데드 빛이 겹친 곳: 원래 색의 %.2f배 (2D는 약 1.35배)" % overlap)


func _spawn_undead(at: Vector2) -> Undead:
	var undead: Undead = (load(UNDEAD_SCENE) as PackedScene).instantiate()
	undead.setup(Skull.create(load(RAT_SKULL)), load(RAT_DATA), _necromancer)
	undead.follow_speed = _necromancer.move_speed
	undead.catch_up_speed = _necromancer.run_speed
	_necromancer.get_parent().add_child(undead)
	undead.global_position = at
	return undead


func _check_chest() -> void:
	var chests: Array[Node] = current_scene.find_children("*", "LootChest", true, false)
	if chests.is_empty():
		fail_step("상자", "상자가 없음")
		return
	var chest: LootChest = chests[0] as LootChest
	var front_walls: FrontWalls = _view.get_front_walls()
	front_walls.enabled = true
	# 네크로맨서를 상자 곁에 세우고 상자 반대쪽을 보게 한다.
	var side: Vector2 = chest.global_position.direction_to(_nearest_floor_center(chest.global_position + Vector2.RIGHT * 48.0))
	var stand: Vector2 = chest.global_position + side * 100.0
	await _set_pose(stand, side)
	await wait_frames(CHEST_FADE_FRAMES)
	var away_sight: float = _view.get_bodies().get_chest_sight(chest)
	var away_weight: float = front_walls.get_see_weight(chest)
	await _set_pose(stand, -side)
	await wait_frames(CHEST_FADE_FRAMES)
	var toward_sight: float = _view.get_bodies().get_chest_sight(chest)
	var toward_weight: float = front_walls.get_see_weight(chest)
	front_walls.enabled = false
	if away_sight > 0.0 or away_weight > 0.0 or toward_sight < 0.99 or toward_weight < 0.99:
		fail_step("상자", "시야 밖 %.2f / 반투명 %.2f, 시야 안 %.2f / 반투명 %.2f" % [away_sight, away_weight, toward_sight, toward_weight])
		return
	pass_step("상자", "시야 밖 %.2f (반투명 %.2f), 시야 안 %.2f (반투명 %.2f)" % [away_sight, away_weight, toward_sight, toward_weight])


func _nearest_floor_center(world: Vector2) -> Vector2:
	var best: Vector2 = world
	var best_distance: float = INF
	for cell: Vector2i in _floors:
		var distance: float = _cell_center(cell).distance_squared_to(world)
		if distance < best_distance:
			best_distance = distance
			best = _cell_center(cell)
	return best


func _check_radius_keys() -> void:
	var front_walls: FrontWalls = _view.get_front_walls()
	var player_before: float = front_walls.cut_radius_player
	var aim_before: float = front_walls.cut_radius_aim
	for key: Key in [front_walls.player_radius_up_key, front_walls.aim_radius_down_key]:
		press_key(key, true)
		await wait_frames(2)
		press_key(key, false)
		await wait_frames(2)
	if front_walls.cut_radius_player != player_before + front_walls.radius_step or front_walls.cut_radius_aim != aim_before - front_walls.radius_step:
		fail_step("반경 키", "플레이어 %.0f → %.0f, 조준점 %.0f → %.0f" % [player_before, front_walls.cut_radius_player, aim_before, front_walls.cut_radius_aim])
		return
	pass_step("반경 키", "] 로 플레이어 %.0f → %.0f, - 로 조준점 %.0f → %.0f" % [player_before, front_walls.cut_radius_player, aim_before, front_walls.cut_radius_aim])


func _median_frame_usec() -> float:
	var samples: Array[int] = []
	var last: int = Time.get_ticks_usec()
	for i: int in FRAME_SAMPLES:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		samples.append(now - last)
		last = now
	samples.sort()
	return float(samples[samples.size() / 2])


func _measure_frame_time() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var open: Vector2 = _open_floor()
	await _set_pose(open, Vector2.RIGHT)
	var alone: float = await _median_frame_usec()
	var undead_list: Array[Undead] = []
	for i: int in UNDEAD_COUNT:
		var undead: Undead = _spawn_undead(open + Vector2.from_angle(i * TAU / UNDEAD_COUNT) * 40.0)
		undead.process_mode = Node.PROCESS_MODE_DISABLED
		undead.facing = Vector2.from_angle(i * TAU / UNDEAD_COUNT)
		undead_list.append(undead)
	await wait_frames(SETTLE_FRAMES)
	var with_undead: float = await _median_frame_usec()
	for undead: Undead in undead_list:
		undead.free()
	print("[측정] 프레임 시간 중앙값: 플레이어 빛만 %.2fms, 언데드 %d마리 %.2fms (+%.2fms)" % [alone / 1000.0, UNDEAD_COUNT, with_undead / 1000.0, (with_undead - alone) / 1000.0])
	await wait_frames(2)


## 앞벽(남쪽 벽) 바로 뒤 바닥의 돌진 선과 돌 원이 몇 자리나 보이는지 잰다. 잘라내기가 닿지 않게 네크로맨서는 멀리 둔다.
func _measure_marks_behind_wall() -> void:
	var rat: Monster = current_scene.get_node("Actors/Rat")
	freeze_monster(rat)
	rat.global_position = Vector2.ONE * ViewSpace.TILE * 100.0
	_vision = current_scene.call(&"get_vision")
	_vision.set_active(false)
	_view = open_layer()
	_necromancer.process_mode = Node.PROCESS_MODE_DISABLED
	_necromancer.global_position = PROTO_STAND_CELL * ViewSpace.TILE
	_view.aim_override = _necromancer.get_body_center()
	var boar: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	boar.data = load(BOAR_DATA)
	freeze_monster(boar)
	rat.get_parent().add_child(boar)
	boar.global_position = PROTO_BOAR_CELL * ViewSpace.TILE
	var charge: ChargeBehavior = boar._behavior as ChargeBehavior
	charge._state = ChargeBehavior.State.WINDUP
	charge._direction = Vector2.RIGHT
	var shadow: StoneShadow = StoneShadow.new()
	shadow.radius = RING_RADIUS
	shadow.color = SHADOW_COLOR
	rat.get_parent().add_child(shadow)
	shadow.global_position = PROTO_RING_CELL * ViewSpace.TILE
	for yaw: float in [45.0, 0.0]:
		_view.set_yaw(yaw)
		for row: Array in [["앞벽 바로 앞, 화면 아래쪽", PROTO_BOAR_CELL, PROTO_RING_CELL, PROTO_STAND_CELL], ["앞벽 바로 앞, 화면 가운데쪽", PROTO_MID_BOAR_CELL, PROTO_MID_RING_CELL, PROTO_MID_STAND_CELL], ["트인 바닥 (대조군)", PROTO_OPEN_BOAR_CELL, PROTO_OPEN_RING_CELL, PROTO_STAND_CELL]]:
			boar.global_position = (row[1] as Vector2) * ViewSpace.TILE
			shadow.global_position = (row[2] as Vector2) * ViewSpace.TILE
			_necromancer.global_position = (row[3] as Vector2) * ViewSpace.TILE
			_view.aim_override = _necromancer.get_body_center()
			await wait_frames(SETTLE_FRAMES)
			var image: Image = await capture()
			var bounds: Rect2 = Rect2(Vector2.ONE, Vector2(image.get_size()) - Vector2.ONE * 2.0)
			var line: Vector3i = Vector3i.ZERO
			for i: int in LINE_SAMPLES:
				line += _sample_mark(image, bounds, boar.global_position + Vector2.RIGHT * LINE_LENGTH * float(i + 1) / LINE_SAMPLES, boar.indicator_color)
			var ring: Vector3i = Vector3i.ZERO
			for i: int in RING_SAMPLES:
				ring += _sample_mark(image, bounds, shadow.global_position + Vector2.from_angle(i * TAU / RING_SAMPLES) * RING_RADIUS, SHADOW_COLOR)
			print("[측정] %s, 화면 회전 %d도: 돌진 선 %d / %d자리 보임 (화면 밖 %d), 돌 원 %d / %d자리 보임 (화면 밖 %d)" % [row[0], int(yaw), line.x, line.y, line.z, ring.x, ring.y, ring.z])
			for arg: String in OS.get_cmdline_user_args():
				if arg.begins_with("--out=") and yaw == 45.0 and row[1] == PROTO_MID_BOAR_CELL:
					var large: Image = image.duplicate()
					large.resize(image.get_width() * ZOOM, image.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
					large.save_png(arg.trim_prefix("--out="))


## 화면 안이면 (보임 수, 화면 안 수, 0), 화면 밖이면 (0, 0, 1). 화면 밖 점을 "안 보임"으로 세지 않는다.
func _sample_mark(image: Image, bounds: Rect2, world: Vector2, color: Color) -> Vector3i:
	var at: Vector2 = _view.world_to_screen(world, 0.0)
	if not bounds.has_point(at):
		return Vector3i(0, 0, 1)
	return Vector3i(1 if _color_near(image, at, color) else 0, 1, 0)


func _color_near(image: Image, at: Vector2, expected: Color) -> bool:
	var center: Vector2i = Vector2i(at)
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			var point: Vector2i = center + Vector2i(x, y)
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(point) and colors_close(image.get_pixelv(point), expected):
				return true
	return false
