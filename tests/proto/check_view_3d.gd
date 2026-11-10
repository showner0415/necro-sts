extends ScenarioTest
## 시제품(2.5D) 검사. 창을 띄운다 (--headless로는 3D가 그려지지 않는다). run_all.sh에는 넣지 않는다.
## bash tools/godot.sh --path . -s tests/proto/check_view_3d.gd
## 결정된 설정(원근 30도, 화면 회전 45도)에서: 조준 8방향, 시야 일치, 앞벽 처리(시야 안 물체만 반투명, 세기가 튀지 않음), 프레임 시간
## 카메라 설정마다(직교, 원근 30/35/40도 × 화면 회전 0/45도): 그림 픽셀 일치와 화면 위치별 크기 배율, 바닥 떨림, 벽에 가리는 바닥 비율
## 벽 가림은 렌더링 없이 계산한다: 시제품 굴과 실제 얕은 굴(2배 맵)에서 네크로맨서를 여러 자리에 세우고, 화면에 든 바닥 점마다 카메라까지의 선이 벽에 막히는지 본다.

const SCENE: String = "res://proto_25d/proto_cave.tscn"
const CAVE_SCENE: String = "res://regions/shallow_cave.tscn"
const SETTLE_FRAMES: int = 10
const HIT_TIMEOUT_FRAMES: int = 90
const SHOT_DISTANCE: float = 110.0
const DIRECTIONS: int = 8
## 쥐 그림의 몸 가운데: 발밑에서 화면으로 이만큼(픽셀) 위
const RAT_SCREEN_CENTER: float = 8.0
const AGREE_TARGET: float = 0.95
## 밝기 비율이 이보다 크면 빛을 받은 것으로 본다 (팔레트를 끄고 잰다)
const LIT_RATIO: float = 0.7
const FRAME_SAMPLES: int = 90
const EXTRA_LIGHTS: int = 8
const CRAWL_STEPS: int = 24
const CRAWL_STEP_PX: float = 0.37
const CRAWL_TARGET: float = 0.98
## 세기가 한 프레임에 바뀔 수 있는 양의 여유 (fade 시간으로 정해지는 값의 배수)
const WEIGHT_STEP_MARGIN: float = 2.5
## 벽 가림: 네크로맨서를 세울 자리 수, 바닥 칸 안의 점 간격 (칸), 선을 따라 벽을 볼 간격 (칸)
const OCCLUSION_POSES: int = 40
const OCCLUSION_SAMPLE: float = 0.4
const OCCLUSION_STEP: float = 0.1
const OCCLUSION_SEED: int = 7
## 앞서 가기 검사의 마우스 화면 위치
const LEAD_MOUSE: Vector2 = Vector2(560, 60)
## 좁은 길목으로 보는 폭 (칸). 한 방향으로 트인 칸 수가 이 이하인 바닥
const NARROW_SPAN: int = 3

var _view: View3D
var _necromancer: Necromancer
var _rat: Monster


func get_start_scene() -> String:
	return SCENE


func _on_scene_ready() -> void:
	_view = current_scene.get_node("View3D")
	_necromancer = find_necromancer()
	_rat = current_scene.get_node("Actors/Rat")
	_rat.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	_rat.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_frames(SETTLE_FRAMES)
	if OS.get_cmdline_user_args().has("--see-through"):
		await _check_see_through()
		finish(true)
		return
	if OS.get_cmdline_user_args().has("--wall-touch"):
		await _check_wall_touch()
		finish(true)
		return
	if OS.get_cmdline_user_args().has("--pixels"):
		for entry: Array in [["원근 30 45도", true, 45.0], ["직교 45도", false, 45.0]]:
			_set_camera(entry[1], 30.0, entry[2])
			await _check_pixels(entry[0])
		_set_camera(true, 30.0, 45.0)
		await _check_wall_depth()
		finish(true)
		return
	if OS.get_cmdline_user_args().has("--crawl-mouse"):
		for entry: Array in [["원근 30, 빠른 마우스", true, 0.15], ["원근 30, 느린 마우스", true, 0.03], ["직교, 빠른 마우스", false, 0.15], ["직교, 느린 마우스", false, 0.03]]:
			_set_camera(entry[1], 30.0, 45.0)
			await _check_crawl_mouse(entry[0], entry[2])
		finish(true)
		return
	if OS.get_cmdline_user_args().has("--occlusion"):
		_check_occlusion()
		finish(true)
		return
	_set_camera(true, 30.0, 45.0)
	await _check_aim()
	_view.palette_on = false
	_view.call(&"_apply_view_mode")
	await _check_wall_depth()
	await _check_vision("앞서 가기 없음")
	await _check_front_walls()
	await _check_see_through()
	await _check_frame_time()
	await _check_lead()
	_view.mouse_override = LEAD_MOUSE
	await wait_frames(60)
	await _check_vision("앞서 가기 %s" % _view.get_lead_offset().round())
	await _check_crawl("앞서 가기 고정, 플레이어 이동")
	await _check_crawl_mouse()
	_view.mouse_override = Vector2.INF
	for setting: Array in [[true, 30.0, 45.0], [true, 30.0, 0.0]]:
		_set_camera(setting[0], setting[1], setting[2])
		var name_text: String = "%s %d도" % ["직교" if not setting[0] else "원근 %d" % int(setting[1]), int(setting[2])]
		await _check_pixels(name_text)
		await _check_crawl(name_text)
	_check_occlusion()
	finish(true)


func _set_camera(perspective: bool, fov: float, yaw: float) -> void:
	_view.perspective = perspective
	_view.perspective_fov = fov
	_view.yaw_degrees = yaw
	_view.call(&"_apply_view_mode")


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _report(step: String, ok: bool, evidence: String) -> void:
	# 실패해도 나머지를 끝까지 잰다.
	print("[%s] %s: %s" % ["통과" if ok else "실패", step, evidence])


func _close(a: Color, b: Color, tolerance: float) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


func _check_pixels(name_text: String) -> void:
	_rat.global_position = Vector2(100, 100) * View3D.TILE
	_necromancer.global_position = Vector2(6.5, 11.5) * View3D.TILE
	_view.aim_override = _necromancer.get_body_center() + Vector2(0, 200)
	await wait_frames(SETTLE_FRAMES)
	var sprite: FacingSprite = _necromancer.get_node("Sprite")
	var image: Image = await _capture()
	var source: Image = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_image()
	source.convert(Image.FORMAT_RGBA8)
	var feet: Vector2 = _view.world_to_screen(_necromancer.global_position, 0.0).round()
	var best_same: int = 0
	var compared: int = 0
	# 화면 위치가 1픽셀 어긋난 것은 봐준다. 크기가 다른 것(늘어남·줄어듦)만 본다.
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			var top_left: Vector2i = Vector2i(feet + sprite.offset) + Vector2i(offset_x, offset_y)
			var same: int = 0
			compared = 0
			for y: int in source.get_height():
				for x: int in source.get_width():
					var expected: Color = source.get_pixel(x, y)
					if expected.a < 1.0:
						continue
					compared += 1
					if _close(image.get_pixelv(top_left + Vector2i(x, y)), expected, 0.012):
						same += 1
			best_same = maxi(best_same, same)
	print("[측정] %s 네크로맨서 그림: 원본과 같은 픽셀 %d / %d (%.0f%%)" % [name_text, best_same, compared, 100.0 * best_same / maxf(compared, 1)])
	await _check_sprite_positions(name_text)


## 화면 위치마다 쥐 그림의 크기 배율(가로, 세로)과 원본과 같은 픽셀 비율. 벽이 끼지 않는 넓은 곳에서 시야를 끄고 잰다.
func _check_sprite_positions(name_text: String) -> void:
	var yaw: float = deg_to_rad(_view.yaw_degrees)
	var screen_up: Vector2 = Vector2(0, -1).rotated(-yaw)
	var center: Vector2 = Vector2(9.0, 11.0) * View3D.TILE
	var vision: Vision = current_scene.call(&"get_vision")
	vision.set_active(false)
	_view.front_walls_on = false
	_necromancer.global_position = center
	_view.aim_override = center + Vector2(0, 400)
	var sprite: FacingSprite = _rat.get_children().filter(func(n: Node) -> bool: return n is FacingSprite).front()
	var lines: PackedStringArray = []
	for entry: Array in [["가운데 옆", screen_up.orthogonal() * 1.5], ["위", screen_up * 4.2], ["아래", -screen_up * 4.0], ["옆", -screen_up.orthogonal() * 7.0]]:
		_rat.global_position = center + (entry[1] as Vector2) * View3D.TILE
		await wait_frames(12)
		var image: Image = await _capture()
		var source: Image = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_image()
		source.convert(Image.FORMAT_RGBA8)
		var feet: Vector2 = _view.world_to_screen(_rat.global_position, 0.0).round()
		var best: int = 0
		var compared: int = 0
		for offset_y: int in range(-1, 2):
			for offset_x: int in range(-1, 2):
				var top_left: Vector2i = Vector2i(feet + sprite.offset) + Vector2i(offset_x, offset_y)
				var same: int = 0
				compared = 0
				for y: int in source.get_height():
					for x: int in source.get_width():
						var expected: Color = source.get_pixel(x, y)
						if expected.a < 1.0:
							continue
						compared += 1
						var at: Vector2i = top_left + Vector2i(x, y)
						if at.x >= 0 and at.y >= 0 and at.x < image.get_width() and at.y < image.get_height() and _close(image.get_pixelv(at), expected, 0.012):
							same += 1
				best = maxi(best, same)
		lines.append("%s %.0f%%" % [entry[0], 100.0 * best / maxf(compared, 1)])
	print("[측정] %s 쥐 그림이 원본과 같은 픽셀 (화면 위치별): %s" % [name_text, " / ".join(lines)])
	_view.front_walls_on = true
	vision.set_active(true)
	_rat.global_position = Vector2(100, 100) * View3D.TILE


func _check_crawl(name_text: String) -> void:
	_rat.global_position = Vector2(100, 100) * View3D.TILE
	_necromancer.global_position = Vector2(14.5, 4.5) * View3D.TILE
	_view.aim_override = _necromancer.get_body_center() + Vector2(200, 0)
	(current_scene.call(&"get_vision") as Vision).set_active(false)
	await wait_frames(6)
	var previous: Image = await _capture()
	var region: Rect2i = Rect2i(200, 40, 240, 80)
	var worst: float = 1.0
	var total: float = 0.0
	for i: int in CRAWL_STEPS:
		_necromancer.global_position += Vector2(CRAWL_STEP_PX, CRAWL_STEP_PX * 0.5)
		await wait_frames(2)
		var current: Image = await _capture()
		var best_match: float = 0.0
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				best_match = maxf(best_match, _match(previous, current, region, Vector2i(dx, dy)))
		worst = minf(worst, best_match)
		total += best_match
		previous = current
	print("[측정] %s 바닥 떨림: 정수 픽셀 이동과의 일치 가장 낮음 %.1f%%, 평균 %.1f%% (떨림이 없으면 100%%, 기준 %.0f%%)" % [name_text, worst * 100.0, total / CRAWL_STEPS * 100.0, CRAWL_TARGET * 100.0])
	(current_scene.call(&"get_vision") as Vision).set_active(true)


func _match(a: Image, b: Image, region: Rect2i, shift: Vector2i) -> float:
	var total: int = 0
	var same: int = 0
	for y: int in range(region.position.y, region.end.y, 2):
		for x: int in range(region.position.x, region.end.x, 2):
			total += 1
			if _close(a.get_pixel(x, y), b.get_pixel(x + shift.x, y + shift.y), 0.004):
				same += 1
	return float(same) / maxf(total, 1)


func _check_aim() -> void:
	var center: Vector2 = Vector2(14.5, 5.0) * View3D.TILE
	_rat.global_position = center
	var results: PackedStringArray = []
	var hits: int = 0
	for i: int in DIRECTIONS:
		var direction: Vector2 = Vector2.from_angle(i * TAU / DIRECTIONS)
		_necromancer.global_position = center + direction * SHOT_DISTANCE
		_rat.health = 1000.0
		_necromancer.mana.current = _necromancer.mana.maximum
		await wait_frames(4)
		_view.aim_override = _view.aim_from_screen(_view.world_to_screen(_rat.global_position, 0.0) - Vector2(0, RAT_SCREEN_CENTER))
		var before: float = _rat.health
		press_mouse(true)
		var frames: int = 0
		while _rat.health == before and frames < HIT_TIMEOUT_FRAMES:
			await wait_frames(1)
			frames += 1
		press_mouse(false)
		var hit: bool = _rat.health < before
		hits += 1 if hit else 0
		results.append("%d도 %s" % [i * 360 / DIRECTIONS, "맞음" if hit else "빗나감"])
		await wait_frames(30)
	_report("원근 30도 45도 회전: 쥐 그림 가운데를 8방향에서 조준해 맞힘", hits == DIRECTIONS, "%d / %d: %s" % [hits, DIRECTIONS, ", ".join(results)])


func _check_vision(name_text: String) -> void:
	_rat.global_position = Vector2(100, 100) * View3D.TILE
	var vision: Vision = current_scene.call(&"get_vision")
	var walls: PlaceholderWalls = current_scene.get_node("Walls")
	var grid: PackedByteArray = walls.wall_grid()
	var size: Vector2i = walls.grid_size()
	var poses: Array[Array] = [[Vector2(6.5, 8.5), Vector2.RIGHT], [Vector2(6.5, 8.5), Vector2(1, 1)], [Vector2(15.5, 8.5), Vector2.LEFT], [Vector2(15.5, 4.5), Vector2(0, 1)], [Vector2(30.5, 6.5), Vector2(1, 0.5)]]
	var total: int = 0
	var agree: int = 0
	var bounds: Vector2 = Vector2(root.get_texture().get_size())
	_view.front_walls_on = false
	for pose: Array in poses:
		_necromancer.global_position = (pose[0] as Vector2) * View3D.TILE
		_view.aim_override = _necromancer.get_body_center() + (pose[1] as Vector2).normalized() * 200.0
		await wait_frames(20)
		var image: Image = await _capture()
		var origin: Vector2 = _necromancer.get_body_center()
		var facing: Vector2 = _view.aim_override - origin
		for y: int in size.y:
			for x: int in size.x:
				if grid[y * size.x + x] == 1 or y + 1 >= size.y or grid[(y + 1) * size.x + x] == 1:
					continue
				var world: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * View3D.TILE
				if world.distance_to(_necromancer.global_position) < 40.0:
					continue
				var screen: Vector2 = _view.world_to_screen(world, 0.0)
				if screen.x < 0 or screen.y < 0 or screen.x >= bounds.x or screen.y >= bounds.y or (screen.x < 96 and screen.y > 280) or (screen.x < 110 and screen.y < 50) or screen.y > 340:
					continue
				var level: int = vision.rules.level_with_walls(origin, facing, world)
				if level != 0 and level != vision.rules.hidden_level():
					continue
				var base: Color = Color.html(View3D.FLOOR_COLORS[(x + y) % View3D.FLOOR_COLORS.size()])
				var pixel: Color = image.get_pixelv(Vector2i(screen))
				total += 1
				if ((pixel.r + pixel.g + pixel.b) / (base.r + base.g + base.b) > LIT_RATIO) == (level == 0):
					agree += 1
	_view.front_walls_on = true
	var ratio: float = float(agree) / maxf(total, 1)
	_report("시야 판정과 화면 밝기 일치 (%s)" % name_text, ratio >= AGREE_TARGET, "%.1f%% (기준 %.0f%%), 칸 %d개" % [ratio * 100.0, AGREE_TARGET * 100.0, total])


## 앞뒤 판정: 뒤쪽 벽(화면 위쪽)에 붙어도 그림이 파묻히지 않고, 앞쪽 벽(화면 아래쪽)에는 앞벽 처리를 끄면 가려진다.
func _check_wall_depth() -> void:
	_rat.global_position = Vector2(100, 100) * View3D.TILE
	(current_scene.call(&"get_vision") as Vision).set_active(false)
	_view.front_walls_on = false
	var back: float = await _necromancer_same_ratio(Vector2(6.5, 2.4) * View3D.TILE)
	var front: float = await _necromancer_same_ratio(Vector2(6.5, 14.8) * View3D.TILE)
	_view.front_walls_on = true
	(current_scene.call(&"get_vision") as Vision).set_active(true)
	_report("그림 앞뒤 판정", back >= 0.95 and front < 0.9, "뒤쪽 벽에 붙음: 보이는 픽셀 %.0f%% (95%% 이상), 앞쪽 벽에 붙음: %.0f%% (가려져서 90%% 미만)" % [back * 100.0, front * 100.0])


## position에 네크로맨서를 세웠을 때 그림 중 원본대로 보이는 픽셀 비율
func _necromancer_same_ratio(position: Vector2) -> float:
	_necromancer.global_position = position
	_view.aim_override = position + Vector2(0, 200)
	await wait_frames(30)
	var sprite: FacingSprite = _necromancer.get_node("Sprite")
	var image: Image = await _capture()
	var source: Image = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_image()
	source.convert(Image.FORMAT_RGBA8)
	var feet: Vector2 = _view.world_to_screen(_necromancer.global_position, 0.0).round()
	var best: int = 0
	var compared: int = 0
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			var top_left: Vector2i = Vector2i(feet + sprite.offset) + Vector2i(offset_x, offset_y)
			var same: int = 0
			compared = 0
			for y: int in source.get_height():
				for x: int in source.get_width():
					var expected: Color = source.get_pixel(x, y)
					if expected.a < 1.0:
						continue
					compared += 1
					var at: Vector2i = top_left + Vector2i(x, y)
					if at.x >= 0 and at.y >= 0 and at.x < image.get_width() and at.y < image.get_height() and _close(image.get_pixelv(at), expected, 0.012):
						same += 1
			best = maxi(best, same)
	return float(best) / maxf(compared, 1)


## 벽 바로 앞에 선 몸의 그림이 파묻히거나 잘리지 않는지. 화면 위쪽에 있는 벽(북쪽·서쪽, 기둥의 남쪽 면)에 몸이 닿을 만큼 붙인다.
## --out=<PNG>를 주면 자리마다 잘라 3배로 키운 그림을 모아 저장한다 (왼쪽 위부터 포즈 순서).
func _check_wall_touch() -> void:
	_set_camera(true, 30.0, 45.0)
	_view.palette_on = false
	_view.call(&"_apply_view_mode")
	(current_scene.call(&"get_vision") as Vision).set_active(false)
	var tile: float = View3D.TILE
	var rat_half: Vector2 = _rat.data.get_placeholder_half_size()
	var necro_radius: float = _necromancer.body_radius
	var far_away: Vector2 = Vector2(30.0, 8.0) * tile
	var poses: Array[Array] = [
		["네크로맨서, 북쪽 벽", _necromancer, Vector2(6.5 * tile, 2.0 * tile + necro_radius * 2.0)],
		["네크로맨서, 서쪽 벽", _necromancer, Vector2(2.0 * tile + necro_radius, 8.5 * tile)],
		["네크로맨서, 북서 모서리", _necromancer, Vector2(2.0 * tile + necro_radius, 2.0 * tile + necro_radius * 2.0)],
		["네크로맨서, 기둥 남쪽 면", _necromancer, Vector2(11.5 * tile, 10.0 * tile + necro_radius * 2.0)],
		["쥐, 북쪽 벽", _rat, Vector2(6.5 * tile, 2.0 * tile + rat_half.y * 2.0)],
		["쥐, 서쪽 벽", _rat, Vector2(2.0 * tile + rat_half.x, 8.5 * tile)],
		["쥐, 북서 모서리", _rat, Vector2(2.0 * tile + rat_half.x, 2.0 * tile + rat_half.y * 2.0)],
		["쥐, 기둥 남쪽 면", _rat, Vector2(11.5 * tile, 10.0 * tile + rat_half.y * 2.0)],
	]
	var out_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	const CROP: int = 72
	const ZOOM: int = 3
	const COLUMNS: int = 4
	var sheet: Image = Image.create((CROP * ZOOM + 4) * COLUMNS, (CROP * ZOOM + 4) * 2, false, Image.FORMAT_RGB8)
	sheet.fill(Color.WHITE)
	var lowest: float = 1.0
	var lines: PackedStringArray = []
	for i: int in poses.size():
		var pose: Array = poses[i]
		var body: Node2D = pose[1]
		# 재는 몸이 아닌 쪽은 멀리 치운다. 네크로맨서를 치우면 카메라가 따라가므로 쥐를 잴 때는 네크로맨서를 쥐 남동쪽 가까이에 둔다.
		if body == _necromancer:
			_rat.global_position = far_away
			_necromancer.global_position = pose[2]
		else:
			_rat.global_position = pose[2]
			_necromancer.global_position = (pose[2] as Vector2) + Vector2(70, 70)
		_view.aim_override = _necromancer.get_body_center() + Vector2(0, 300)
		await wait_frames(30)
		var image: Image = await _capture()
		var ratio: float = _same_ratio_in(image, body)
		lowest = minf(lowest, ratio)
		lines.append("%s %.0f%%" % [pose[0], ratio * 100.0])
		var center: Vector2i = Vector2i(_view.world_to_screen(body.global_position, 0.0)) - Vector2i(CROP / 2, CROP * 2 / 3)
		var crop: Image = image.get_region(Rect2i(center, Vector2i(CROP, CROP)))
		crop.convert(Image.FORMAT_RGB8)
		crop.resize(CROP * ZOOM, CROP * ZOOM, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(crop, Rect2i(0, 0, CROP * ZOOM, CROP * ZOOM), Vector2i((CROP * ZOOM + 4) * (i % COLUMNS), (CROP * ZOOM + 4) * (i / COLUMNS)))
	if not out_path.is_empty():
		sheet.save_png(out_path)
	# 쥐는 벽 없는 곳의 값(_rat_open_ratio)과 비교해야 하므로 포즈별 값을 그대로 출력한다.
	_rat.global_position = Vector2(9.0, 11.0) * tile
	_necromancer.global_position = Vector2(14.5, 11.0) * tile
	_view.aim_override = _necromancer.get_body_center() + Vector2(0, 300)
	await wait_frames(30)
	var open_image: Image = await _capture()
	var open_ratio: float = _same_ratio_in(open_image, _rat)
	_print_rat_mismatch(open_image)
	print("[측정] 벽 앞 그림이 원본대로 보이는 픽셀: %s (쥐는 벽 없는 곳에서 %.0f%%)" % [", ".join(lines), open_ratio * 100.0])


## image에서 body의 그림 중 원본과 같은 픽셀 비율 (위치 ±1픽셀은 봐준다)
func _same_ratio_in(image: Image, body: Node2D) -> float:
	var sprite: FacingSprite = body.get_children().filter(func(n: Node) -> bool: return n is FacingSprite).front()
	var source: Image = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_image()
	source.convert(Image.FORMAT_RGBA8)
	var feet: Vector2 = _view.world_to_screen(body.global_position, 0.0).round()
	var best: int = 0
	var compared: int = 0
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			var top_left: Vector2i = Vector2i(feet + sprite.offset) + Vector2i(offset_x, offset_y)
			var same: int = 0
			compared = 0
			for y: int in source.get_height():
				for x: int in source.get_width():
					var expected: Color = source.get_pixel(x, y)
					if expected.a < 1.0:
						continue
					compared += 1
					var at: Vector2i = top_left + Vector2i(x, y)
					if at.x >= 0 and at.y >= 0 and at.x < image.get_width() and at.y < image.get_height() and _close(image.get_pixelv(at), expected, 0.012):
						same += 1
			best = maxi(best, same)
	return float(best) / maxf(compared, 1)


## 쥐 그림에서 원본과 다른 픽셀의 색을 출력한다 (93%의 원인 확인용).
func _print_rat_mismatch(image: Image) -> void:
	var sprite: FacingSprite = _rat.get_children().filter(func(n: Node) -> bool: return n is FacingSprite).front()
	var source: Image = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_image()
	source.convert(Image.FORMAT_RGBA8)
	var feet: Vector2 = _view.world_to_screen(_rat.global_position, 0.0).round()
	var top_left: Vector2i = Vector2i(feet + sprite.offset)
	var differences: Dictionary = {}
	var opaque: int = 0
	var semi: int = 0
	for y: int in source.get_height():
		for x: int in source.get_width():
			var expected: Color = source.get_pixel(x, y)
			if expected.a > 0.0 and expected.a < 1.0:
				semi += 1
			if expected.a < 1.0:
				continue
			opaque += 1
			var actual: Color = image.get_pixelv(top_left + Vector2i(x, y))
			if not _close(actual, expected, 0.012):
				var key: String = "%s → %s" % [expected.to_html(false), actual.to_html(false)]
				differences[key] = differences.get(key, 0) + 1
	var keys: Array = differences.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return differences[a] > differences[b])
	print("[측정] 쥐 그림: %s 프레임 %d, 불투명 %d, 반투명 %d, 다른 픽셀 색(원본 → 화면): %s" % [sprite.animation, sprite.frame, opaque, semi, ", ".join(keys.slice(0, 8).map(func(k: String) -> String: return "%s ×%d" % [k, differences[k]]))])


## 반투명 범위: 반투명을 켠 화면과 끈 화면을 비교해, 물체 주변(그림 사각형에서 64픽셀 안)에서 그림 사각형 밖의 픽셀이 바뀌지 않았는지 본다.
## 더 먼 곳에서 바뀐 픽셀은 반투명과 상관없는 벽 모서리의 흔들림이라 따로 세어 출력한다.
## 뒤쪽 벽에 붙은 쥐와, 앞쪽 벽에 가린 쥐. --out=<PNG>를 주면 자리마다 위(켬)·아래(끔)로 잘라 모아 저장한다.
func _check_see_through() -> void:
	_set_camera(true, 30.0, 45.0)
	_view.palette_on = false
	_view.call(&"_apply_view_mode")
	var vision: Vision = current_scene.call(&"get_vision")
	vision.set_active(false)
	var tile: float = View3D.TILE
	var half: Vector2 = _rat.data.get_placeholder_half_size()
	var poses: Array[Array] = [
		["북쪽 벽", Vector2(6.5 * tile, 2.0 * tile + half.y * 2.0), Vector2(70, 70)],
		["서쪽 벽", Vector2(2.0 * tile + half.x, 8.5 * tile), Vector2(70, 70)],
		["북서 모서리", Vector2(2.0 * tile + half.x, 2.0 * tile + half.y * 2.0), Vector2(70, 70)],
		["기둥 남쪽 면", Vector2(11.5 * tile, 10.0 * tile + half.y * 2.0), Vector2(70, 70)],
		["남쪽 벽에 가림", Vector2(12.5, 14.7) * tile, Vector2(-128, -102)],
		["동쪽 기둥에 가림", Vector2(9.7, 7.5) * tile, Vector2(-100, -70)],
	]
	var out_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	const CROP: int = 72
	const ZOOM: int = 2
	var sheet: Image = Image.create((CROP * ZOOM + 4) * poses.size(), (CROP * ZOOM + 4) * 2, false, Image.FORMAT_RGB8)
	sheet.fill(Color.WHITE)
	var feather: int = 5
	# 시작 직후에는 화면이 아직 자리 잡지 않았다.
	_rat.global_position = (poses[0][1] as Vector2)
	_necromancer.global_position = (poses[0][1] as Vector2) + (poses[0][2] as Vector2)
	_view.aim_override = _necromancer.get_body_center() + Vector2(0, 300)
	await wait_frames(120)
	var total_outside: int = 0
	var lines: PackedStringArray = []
	var hidden_changed: int = 0
	for i: int in poses.size():
		var pose: Array = poses[i]
		_rat.global_position = pose[1]
		_necromancer.global_position = (pose[1] as Vector2) + (pose[2] as Vector2)
		_view.aim_override = _necromancer.get_body_center() + Vector2(0, 300)
		_view.see_through_on = true
		await wait_frames(40)
		var on_image: Image = await _capture()
		_view.see_through_on = false
		await wait_frames(40)
		var off_image: Image = await _capture()
		_view.see_through_on = true
		var rect: Rect2i = Rect2i(_view.get_see_rect(_rat))
		var grown: Rect2i = rect.grow(feather)
		var nearby: Rect2i = rect.grow(64)
		var inside: int = 0
		var outside: int = 0
		var far: int = 0
		for y: int in on_image.get_height():
			for x: int in on_image.get_width():
				if _close(on_image.get_pixel(x, y), off_image.get_pixel(x, y), 0.012):
					continue
				if grown.has_point(Vector2i(x, y)):
					inside += 1
				elif nearby.has_point(Vector2i(x, y)):
					outside += 1
				else:
					far += 1
		total_outside += outside
		if i >= 4:
			hidden_changed += inside
		lines.append("%s: 그림 영역 안 %d, 주변 %d, 먼 곳 %d" % [pose[0], inside, outside, far])
		var center: Vector2i = Vector2i(_view.world_to_screen(_rat.global_position, 0.0)) - Vector2i(CROP / 2, CROP * 2 / 3)
		for row: int in 2:
			var crop: Image = (on_image if row == 0 else off_image).get_region(Rect2i(center, Vector2i(CROP, CROP)))
			crop.convert(Image.FORMAT_RGB8)
			crop.resize(CROP * ZOOM, CROP * ZOOM, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(crop, Rect2i(0, 0, CROP * ZOOM, CROP * ZOOM), Vector2i((CROP * ZOOM + 4) * i, (CROP * ZOOM + 4) * row))
	if not out_path.is_empty():
		sheet.save_png(out_path)
	_report("반투명은 물체 그림과 겹치는 앞벽에만", total_outside == 0 and hidden_changed > 0, "바뀐 픽셀 수 (켬·끔 비교): %s" % " / ".join(lines))
	vision.set_active(true)
	_rat.global_position = Vector2(100, 100) * tile


## 앞벽 반투명: 시야 안 물체만 벽을 반투명하게 하고, 세기가 한 프레임에 튀지 않는다.
func _check_front_walls() -> void:
	_rat.global_position = Vector2(12.5, 14.7) * View3D.TILE
	_necromancer.global_position = Vector2(8.5, 11.5) * View3D.TILE
	await wait_frames(4)
	var to_rat: Vector2 = (_rat.global_position - _necromancer.get_body_center()).normalized()
	# 시야 밖: 쥐 반대쪽을 본다.
	_view.aim_override = _necromancer.get_body_center() - to_rat * 300.0
	await wait_frames(40)
	var hidden_weight: float = _view.get_see_weight(_rat)
	var hidden_image: Image = await _capture()
	# 시야 안: 조준점 잘라내기가 겹치지 않게 쥐 너머 멀리를 본다.
	_view.aim_override = _necromancer.get_body_center() + to_rat * 400.0
	await wait_frames(40)
	var seen_weight: float = _view.get_see_weight(_rat)
	var vision: Vision = current_scene.call(&"get_vision")
	var seen_by_rules: bool = vision.is_visible_at(_rat.global_position)
	var seen_image: Image = await _capture()
	var rect: Rect2i = Rect2i(_view.get_see_rect(_rat))
	var changed: int = 0
	var region: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			region += 1
			if not _close(hidden_image.get_pixel(x, y), seen_image.get_pixel(x, y), 0.02):
				changed += 1
	_report("시야 밖 물체는 벽을 반투명하게 하지 않음", hidden_weight == 0.0 and seen_weight == 1.0 and seen_by_rules and changed > 0, "시야 밖 세기 %.2f, 시야 안 세기 %.2f (규칙상 보임 %s), 쥐 앞 벽에서 바뀐 픽셀 %d / %d" % [hidden_weight, seen_weight, seen_by_rules, changed, region])
	# 부채꼴 경계를 오가며 세기가 프레임마다 튀지 않는지 본다.
	var largest: float = 0.0
	var last: float = _view.get_see_weight(_rat)
	var fade_step: float = 1.0 / (_view.zone_fade_time * 60.0)
	for frame: int in 180:
		var swing: float = deg_to_rad(sin(frame * 0.2) * 50.0)
		_view.aim_override = _necromancer.get_body_center() + to_rat.rotated(swing) * 400.0
		await wait_frames(1)
		var now: float = _view.get_see_weight(_rat)
		largest = maxf(largest, absf(now - last))
		last = now
	_report("앞벽 세기가 튀지 않음", largest <= fade_step * WEIGHT_STEP_MARGIN, "프레임당 가장 큰 변화 %.3f (허용 %.3f)" % [largest, fade_step * WEIGHT_STEP_MARGIN])
	_rat.global_position = Vector2(100, 100) * View3D.TILE


## 앞서 가기: 움직이지 않는 구역, 최대 거리, 되먹임 없음(마우스가 그대로면 값이 수렴하고 멈춤), 플레이어가 화면 안쪽에 남음.
func _check_lead() -> void:
	var center: Vector2 = get_root().get_visible_rect().size * 0.5
	_necromancer.global_position = Vector2(14.5, 8.5) * View3D.TILE
	_view.mouse_override = center + Vector2(10, 10)
	await wait_frames(120)
	_report("앞서 가기: 움직이지 않는 구역", _view.get_lead_offset().length() < 0.5, "마우스가 가운데에서 14px: 움직인 양 %s" % _view.get_lead_offset())
	_view.mouse_override = LEAD_MOUSE
	await wait_frames(180)
	var settled: Vector2 = _view.get_lead_offset()
	var largest_change: float = 0.0
	var last: Vector2 = settled
	var aim_start: Vector2 = _view.aim_from_screen(LEAD_MOUSE)
	var aim_drift: float = 0.0
	for frame: int in 60:
		await wait_frames(1)
		largest_change = maxf(largest_change, _view.get_lead_offset().distance_to(last))
		last = _view.get_lead_offset()
		aim_drift = maxf(aim_drift, _view.aim_from_screen(LEAD_MOUSE).distance_to(aim_start))
	var player: Vector2 = _view.world_to_screen(_necromancer.global_position, 0.0)
	var margin: float = minf(minf(player.x, player.y), minf(get_root().get_visible_rect().size.x - player.x, get_root().get_visible_rect().size.y - player.y))
	_report("앞서 가기: 최대 거리 안, 되먹임 없음", settled.length() <= _view.aim_lead.max_distance + 0.5 and largest_change < 0.05 and aim_drift < 1.0, "움직인 양 %.1f (최대 %.0f), 멈춘 뒤 프레임당 변화 %.3f, 조준 위치 흔들림 %.2fpx" % [settled.length(), _view.aim_lead.max_distance, largest_change, aim_drift])
	_report("앞서 가기: 플레이어가 화면 가장자리로 밀려나지 않음", margin >= 60.0, "플레이어 화면 위치 %s, 가장 가까운 가장자리까지 %.0fpx" % [player.round(), margin])
	_view.mouse_override = Vector2.INF


## 플레이어는 멈추고 마우스만 움직일 때(카메라가 부드럽게 움직이는 동안) 바닥이 정수 픽셀로만 옮겨 가는지.
func _check_crawl_mouse(name_text: String = "마우스만 움직임", angle_step: float = 0.15) -> void:
	_rat.global_position = Vector2(100, 100) * View3D.TILE
	_necromancer.global_position = Vector2(14.5, 6.5) * View3D.TILE
	_view.aim_override = _necromancer.get_body_center() + Vector2(200, 0)
	(current_scene.call(&"get_vision") as Vision).set_active(false)
	# 시작 위치로 먼저 옮겨 카메라가 자리 잡은 뒤부터 잰다 (첫 프레임의 큰 이동을 섞지 않는다).
	_view.mouse_override = Vector2(320, 180) + Vector2.RIGHT * 240.0
	await wait_frames(120)
	var floor_point: Vector2 = Vector2(14.5, 5.0) * View3D.TILE
	var last_screen: Vector2 = _view.world_to_screen(floor_point, 0.0)
	var previous: Image = await _capture()
	var region: Rect2i = Rect2i(200, 40, 240, 80)
	var worst: float = 1.0
	var total: float = 0.0
	var steps: int = 40
	var largest_move: float = 0.0
	for i: int in steps:
		_view.mouse_override = Vector2(320, 180) + Vector2.from_angle(i * angle_step) * 240.0
		await wait_frames(2)
		var current: Image = await _capture()
		# 바닥의 한 점이 화면에서 실제로 움직인 양 둘레 1픽셀만 찾는다.
		var now_screen: Vector2 = _view.world_to_screen(floor_point, 0.0)
		var moved: Vector2i = Vector2i((now_screen - last_screen).round())
		largest_move = maxf(largest_move, (now_screen - last_screen).length())
		last_screen = now_screen
		var best_match: float = 0.0
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				best_match = maxf(best_match, _match(previous, current, region, moved + Vector2i(dx, dy)))
		worst = minf(worst, best_match)
		total += best_match
		previous = current
	print("[측정] 앞서 가기 (%s) 바닥 떨림: 정수 픽셀 이동과의 일치 가장 낮음 %.1f%%, 평균 %.1f%% (기준 %.0f%%), 2프레임 사이 가장 큰 화면 이동 %.1fpx" % [name_text, worst * 100.0, total / steps * 100.0, CRAWL_TARGET * 100.0, largest_move])
	_view.mouse_override = LEAD_MOUSE
	(current_scene.call(&"get_vision") as Vision).set_active(true)


func _frame_median() -> float:
	var samples: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for i: int in FRAME_SAMPLES:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		samples.append((now - last) / 1000.0)
		last = now
	samples.sort()
	return samples[samples.size() / 2]


func _check_frame_time() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_necromancer.global_position = Vector2(6.5, 8.5) * View3D.TILE
	_view.aim_override = _necromancer.get_body_center() + Vector2(200, 0)
	await wait_frames(30)
	var plain_3d: float = await _frame_median()
	var extras: Array[OmniLight3D] = []
	for i: int in EXTRA_LIGHTS:
		var light: OmniLight3D = OmniLight3D.new()
		light.omni_range = 6.25
		light.shadow_enabled = true
		light.position = Vector3(4.0 + i * 1.5, 0.375, 4.0 + (i % 3) * 2.0)
		_view.add_child(light)
		extras.append(light)
	await wait_frames(30)
	var with_lights: float = await _frame_median()
	for light: OmniLight3D in extras:
		light.queue_free()
	_view.show_3d = false
	_view.call(&"_apply_view_mode")
	await wait_frames(30)
	var plain_2d: float = await _frame_median()
	_view.show_3d = true
	_view.call(&"_apply_view_mode")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	print("[측정] 프레임 시간 중앙값 (다른 프로그램이 돌고 있으면 크게 흔들린다): 2D %.2fms, 3D %.2fms, 3D + 그림자 빛 %d개 %.2fms" % [plain_2d, plain_3d, EXTRA_LIGHTS, with_lights])
	await wait_frames(10)


func _check_occlusion() -> void:
	var proto: PlaceholderWalls = current_scene.get_node("Walls")
	var cave: Node = (load(CAVE_SCENE) as PackedScene).instantiate()
	var maps: Array[Array] = [["시제품 굴", proto.layout, "#"], ["얕은 굴 2배", (cave.get_node("Walls") as PlaceholderWalls).layout, "#x"]]
	var settings: Array[Array] = [[false, 35.0, 0.0], [true, 30.0, 0.0], [true, 35.0, 0.0], [true, 40.0, 0.0], [false, 35.0, 45.0], [true, 30.0, 45.0], [true, 35.0, 45.0], [true, 40.0, 45.0]]
	for map: Array in maps:
		var rows: PackedStringArray = map[1]
		var all: Array[Vector2i] = []
		var narrow_ns: Array[Vector2i] = []
		var narrow_ew: Array[Vector2i] = []
		for y: int in rows.size():
			for x: int in rows[y].length():
				if map[2].contains(rows[y][x]):
					continue
				all.append(Vector2i(x, y))
				if _span(rows, map[2], Vector2i(x, y), Vector2i(0, 1)) <= NARROW_SPAN:
					narrow_ns.append(Vector2i(x, y))
				if _span(rows, map[2], Vector2i(x, y), Vector2i(1, 0)) <= NARROW_SPAN:
					narrow_ew.append(Vector2i(x, y))
		for setting: Array in settings:
			var name_text: String = "%s %d도" % ["직교" if not setting[0] else "원근 %d" % int(setting[1]), int(setting[2])]
			var everywhere: Vector2 = _hidden_ratio(rows, map[2], setting[0], setting[1], setting[2], all, {})
			var ns: Vector2 = _hidden_ratio(rows, map[2], setting[0], setting[1], setting[2], narrow_ns, _as_set(narrow_ns))
			var ew: Vector2 = _hidden_ratio(rows, map[2], setting[0], setting[1], setting[2], narrow_ew, _as_set(narrow_ew))
			print("[측정] 벽 가림 %s, %s: 화면의 바닥 %.1f%%, 둘레 4칸 %.1f%%, 동서로 뻗은 좁은 길(남북 폭 %d칸 이하) %.1f%%, 남북으로 뻗은 좁은 길 %.1f%% (표본 %d / %d칸)" % [map[0], name_text, everywhere.x * 100.0, everywhere.y * 100.0, NARROW_SPAN, ns.x * 100.0, ew.x * 100.0, narrow_ns.size(), narrow_ew.size()])
	cave.free()


func _as_set(cells: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in cells:
		result[cell] = true
	return result


## cell에서 direction 양쪽으로 이어진 바닥 칸 수 (cell 포함)
func _span(rows: PackedStringArray, wall_chars: String, cell: Vector2i, direction: Vector2i) -> int:
	var count: int = 1
	for sign_value: int in [1, -1]:
		var p: Vector2i = cell + direction * sign_value
		while p.y >= 0 and p.y < rows.size() and p.x >= 0 and p.x < rows[p.y].length() and not wall_chars.contains(rows[p.y][p.x]) and count <= NARROW_SPAN:
			count += 1
			p += direction * sign_value
	return count


func _is_wall(rows: PackedStringArray, wall_chars: String, x: float, y: float) -> bool:
	var row: int = floori(y)
	var column: int = floori(x)
	if row < 0 or row >= rows.size() or column < 0 or column >= rows[row].length():
		return false
	return wall_chars.contains(rows[row][column])


## poses의 칸에 네크로맨서를 세우고, 화면에 든 바닥 점이 벽에 가리는 비율. only가 비어 있지 않으면 그 칸의 점만 센다. (전체, 둘레 4칸 안)
## 점 위치는 칸 격자에 맞지 않게 흩뜨린다 (격자에 맞추면 가리는 거리가 간격보다 짧을 때 0으로 나온다).
func _hidden_ratio(rows: PackedStringArray, wall_chars: String, perspective: bool, fov: float, yaw: float, poses: Array[Vector2i], only: Dictionary) -> Vector2:
	var pitch: float = deg_to_rad(_view.pitch_degrees)
	var camera_basis: Basis = Basis.from_euler(Vector3(-pitch, deg_to_rad(yaw), 0))
	var half_height: float = 11.25 * 0.5
	var distance: float = half_height / tan(deg_to_rad(fov * 0.5)) if perspective else 40.0
	var wall_height: float = _view.wall_height_px / View3D.TILE
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = OCCLUSION_SEED
	var counts: Vector4 = Vector4.ZERO
	if poses.is_empty():
		return Vector2.ZERO
	for pose: int in OCCLUSION_POSES:
		var cell: Vector2i = poses[random.randi() % poses.size()]
		var eye: Vector3 = Vector3(cell.x + 0.5, 0.0, cell.y + 0.5) + camera_basis.z * distance
		for dy: int in range(-30, 31):
			for dx: int in range(-30, 31):
				var px: float = cell.x + 0.5 + (dx + random.randf() - 0.5) * OCCLUSION_SAMPLE
				var pz: float = cell.y + 0.5 + (dy + random.randf() - 0.5) * OCCLUSION_SAMPLE
				if pz < 0.0 or px < 0.0 or int(pz) >= rows.size() or int(px) >= rows[int(pz)].length() or _is_wall(rows, wall_chars, px, pz):
					continue
				if not only.is_empty() and not only.has(Vector2i(int(px), int(pz))):
					continue
				var point: Vector3 = Vector3(px, 0.0, pz)
				var in_camera: Vector3 = camera_basis.inverse() * (point - eye)
				var scale_factor: float = (distance / -in_camera.z) if perspective else 1.0
				if absf(in_camera.x * scale_factor) > half_height * 16.0 / 9.0 or absf(in_camera.y * scale_factor) > half_height:
					continue
				var to_eye: Vector3 = (eye - point) if perspective else camera_basis.z
				var ground_length: float = Vector2(to_eye.x, to_eye.z).length()
				var along: float = OCCLUSION_STEP
				var hidden: bool = false
				while not hidden:
					var travel: float = along / ground_length
					if to_eye.y * travel >= wall_height:
						break
					hidden = _is_wall(rows, wall_chars, px + to_eye.x * travel, pz + to_eye.z * travel)
					along += OCCLUSION_STEP
				var near: bool = Vector2(dx, dy).length() * OCCLUSION_SAMPLE <= 4.0
				counts.x += 1.0
				counts.y += 1.0 if hidden else 0.0
				counts.z += 1.0 if near else 0.0
				counts.w += 1.0 if near and hidden else 0.0
	return Vector2(counts.y / maxf(counts.x, 1.0), counts.w / maxf(counts.z, 1.0))
