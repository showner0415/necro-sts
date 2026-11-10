extends ScenarioTest
## 시제품(2.5D) 통과 기준 검사. 창을 띄운다 (--headless로는 3D가 그려지지 않는다). run_all.sh에는 넣지 않는다.
## bash tools/godot.sh --path . -s tests/proto/check_view_3d.gd
## 1. 네크로맨서 그림이 원본 프레임과 픽셀까지 같다 (직교)
## 2. 쥐 그림 가운데를 8방향에서 조준해 쏘면 맞는다 (화면 → 탄 높이 평면)
## 3. 시야 판정(VisionRules)과 화면 밝기가 일치한다 (굴 안의 칸을 자리·방향 여러 개에서 비교)
## 4. 프레임 시간: 3D 화면, 3D + 언데드 몫 그림자 빛 8개, 2D 화면 (중앙값)
## 5. 걸을 때 바닥이 꿈틀거리지 않는다: 조금씩 움직여도 바닥 무늬가 정수 픽셀로만 옮겨 간다

const SCENE: String = "res://proto_25d/proto_cave.tscn"
const SETTLE_FRAMES: int = 10
const HIT_TIMEOUT_FRAMES: int = 90
const SHOT_DISTANCE: float = 110.0
const DIRECTIONS: int = 8
## 쥐 그림의 몸 가운데: 발밑에서 화면으로 이만큼(픽셀) 위. 평면 높이로는 cos(각도)로 나눈다
const RAT_SCREEN_CENTER: float = 8.0
const AGREE_TARGET: float = 0.95
## 밝기 비율이 이보다 크면 빛을 받은 것으로 본다 (원래 색 = 1, 빛 없는 지형 약 0.4)
const LIT_RATIO: float = 0.7
const FRAME_SAMPLES: int = 90
const EXTRA_LIGHTS: int = 8
const CRAWL_STEPS: int = 24
const CRAWL_STEP_PX: float = 0.37
const CRAWL_TARGET: float = 0.98

var _view: View3D
var _necromancer: Necromancer
var _rat: Monster


func get_start_scene() -> String:
	return SCENE


func _on_scene_ready() -> void:
	_view = current_scene.get_node("View3D")
	_necromancer = find_necromancer()
	_rat = current_scene.get_node("Actors/Rat")
	await wait_frames(SETTLE_FRAMES)
	_check_pixels()
	await _check_aim()
	await _check_vision()
	await _check_frame_time()
	await _check_crawl()
	finish(true)


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _report(step: String, ok: bool, evidence: String) -> void:
	# 실패해도 나머지를 끝까지 잰다.
	print("[%s] %s: %s" % ["통과" if ok else "실패", step, evidence])


func _check_pixels() -> void:
	await _prepare_clear_view()
	await wait_frames(SETTLE_FRAMES)
	var sprite: FacingSprite = _necromancer.get_node("Sprite")
	var image: Image = await _capture()
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var source: Image = texture.get_image()
	source.convert(Image.FORMAT_RGBA8)
	var feet: Vector2 = _view.world_to_screen(_necromancer.global_position, 0.0).round()
	var top_left: Vector2i = Vector2i(feet + sprite.offset)
	var compared: int = 0
	var same: int = 0
	for y: int in source.get_height():
		for x: int in source.get_width():
			var expected: Color = source.get_pixel(x, y)
			var at: Vector2i = top_left + Vector2i(x, y)
			if expected.a < 1.0 or at.x < 0 or at.y < 0 or at.x >= image.get_width() or at.y >= image.get_height():
				continue
			compared += 1
			if _close(image.get_pixelv(at), expected, 0.012):
				same += 1
	_report("네크로맨서 그림이 원본과 같음", compared > 0 and same == compared, "%s 프레임 %d, 불투명 픽셀 %d개 중 같은 픽셀 %d개" % [sprite.animation, sprite.frame, compared, same])


func _prepare_clear_view() -> void:
	# 처리만 멈추고 충돌은 남긴다 (기본값은 충돌도 빠진다).
	_rat.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	_rat.process_mode = Node.PROCESS_MODE_DISABLED
	_rat.global_position = Vector2(100, 100) * View3D.TILE
	_necromancer.global_position = Vector2(6.5, 11.5) * View3D.TILE
	_view.aim_override = _necromancer.get_body_center() + Vector2(0, 200)
	await wait_frames(2)


func _close(a: Color, b: Color, tolerance: float) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


func _check_aim() -> void:
	var center: Vector2 = Vector2(14.5, 5.0) * View3D.TILE
	_rat.global_position = center
	var height: float = RAT_SCREEN_CENTER / cos(deg_to_rad(_view.pitch_degrees))
	var results: PackedStringArray = []
	var hits: int = 0
	for i: int in DIRECTIONS:
		var direction: Vector2 = Vector2.from_angle(i * TAU / DIRECTIONS)
		_necromancer.global_position = center + direction * SHOT_DISTANCE
		_rat.health = 1000.0
		_necromancer.mana.current = _necromancer.mana.maximum
		await wait_frames(4)
		_view.aim_override = _view.aim_from_screen(_view.world_to_screen(_rat.global_position, height))
		var before: float = _rat.health
		press_mouse(true)
		var frames: int = 0
		while _rat.health == before and frames < HIT_TIMEOUT_FRAMES:
			await wait_frames(1)
			frames += 1
		press_mouse(false)
		var hit: bool = _rat.health < before
		hits += 1 if hit else 0
		results.append("%d도 %s(%d)" % [i * 360 / DIRECTIONS, "맞음" if hit else "빗나감", frames])
		await wait_frames(30)
	_report("쥐 그림 가운데를 8방향에서 조준해 맞힘", hits == DIRECTIONS, "%d / %d: %s" % [hits, DIRECTIONS, ", ".join(results)])


func _check_vision() -> void:
	_rat.global_position = Vector2(100, 100) * View3D.TILE
	var vision: Vision = current_scene.call(&"get_vision")
	var walls: PlaceholderWalls = current_scene.get_node("Walls")
	var grid: PackedByteArray = walls.wall_grid()
	var size: Vector2i = walls.grid_size()
	var poses: Array[Array] = [[Vector2(6.5, 8.5), Vector2.RIGHT], [Vector2(6.5, 8.5), Vector2(1, 1)], [Vector2(15.5, 8.5), Vector2.LEFT], [Vector2(15.5, 4.5), Vector2(0, 1)], [Vector2(30.5, 6.5), Vector2(1, 0.5)]]
	var total: int = 0
	var agree: int = 0
	var lines: PackedStringArray = []
	var ground_size: Vector2 = Vector2(root.get_texture().get_size())
	for pose: Array in poses:
		_necromancer.global_position = (pose[0] as Vector2) * View3D.TILE
		_view.aim_override = _necromancer.get_body_center() + (pose[1] as Vector2).normalized() * 200.0
		await wait_frames(8)
		var image: Image = await _capture()
		var rules: VisionRules = vision.rules
		var pose_total: int = 0
		var pose_agree: int = 0
		var origin: Vector2 = _necromancer.get_body_center()
		var facing: Vector2 = _view.aim_override - origin
		for y: int in size.y:
			for x: int in size.x:
				# 벽, 앞벽에 가리는 칸(바로 남쪽이 벽), 화면 밖은 뺀다.
				if grid[y * size.x + x] == 1 or y + 1 >= size.y or grid[(y + 1) * size.x + x] == 1:
					continue
				var world: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * View3D.TILE
				if world.distance_to(_necromancer.global_position) < 40.0:
					continue
				var screen: Vector2 = _view.world_to_screen(world, 0.0)
				if screen.x < 0 or screen.y < 0 or screen.x >= ground_size.x or screen.y >= ground_size.y or (screen.x < 96 and screen.y > 280) or (screen.x < 110 and screen.y < 50):
					continue
				var level: int = rules.level_with_walls(origin, facing, world)
				# 가장자리 단계(1, 2)는 어느 쪽이든 맞으므로 뺀다.
				if level != 0 and level != rules.hidden_level():
					continue
				var base: Color = Color.html(View3D.FLOOR_COLORS[(x + y) % View3D.FLOOR_COLORS.size()])
				var pixel: Color = image.get_pixelv(Vector2i(screen))
				var lit: bool = (pixel.r + pixel.g + pixel.b) / (base.r + base.g + base.b) > LIT_RATIO
				pose_total += 1
				if lit == (level == 0):
					pose_agree += 1
				elif OS.get_cmdline_user_args().has("--detail"):
					print("불일치 %s 칸 (%d, %d) 판정 %d 밝기 %.2f" % [pose[1], x, y, level, (pixel.r + pixel.g + pixel.b) / (base.r + base.g + base.b)])
		total += pose_total
		agree += pose_agree
		lines.append("%s %s: %d/%d" % [pose[0], pose[1], pose_agree, pose_total])
	var ratio: float = float(agree) / maxf(total, 1)
	_report("시야 판정과 화면 밝기 일치", ratio >= AGREE_TARGET, "%.1f%% (기준 %.0f%%), 자리별: %s" % [ratio * 100.0, AGREE_TARGET * 100.0, ", ".join(lines)])


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
	# 언제 찍히든 같은 조건이 되게 수직 동기화를 끈다.
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
	print("[측정] 프레임 시간 중앙값: 2D %.2fms, 3D %.2fms, 3D + 그림자 빛 %d개 %.2fms" % [plain_2d, plain_3d, EXTRA_LIGHTS, with_lights])
	await wait_frames(10)


func _check_crawl() -> void:
	_rat.global_position = Vector2(100, 100) * View3D.TILE
	_necromancer.global_position = Vector2(14.5, 4.5) * View3D.TILE
	_view.aim_override = _necromancer.get_body_center() + Vector2(200, 0)
	(current_scene.call(&"get_vision") as Vision).set_active(false)
	await wait_frames(6)
	var previous: Image = await _capture()
	var region: Rect2i = Rect2i(200, 40, 240, 80)
	var worst: float = 1.0
	var shifts: Dictionary = {}
	for i: int in CRAWL_STEPS:
		_necromancer.global_position += Vector2(CRAWL_STEP_PX, CRAWL_STEP_PX * 0.5)
		await wait_frames(2)
		var current: Image = await _capture()
		var best_match: float = 0.0
		var best_shift: Vector2i = Vector2i.ZERO
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				var match_ratio: float = _match(previous, current, region, Vector2i(dx, dy))
				if match_ratio > best_match:
					best_match = match_ratio
					best_shift = Vector2i(dx, dy)
		worst = minf(worst, best_match)
		shifts[best_shift] = shifts.get(best_shift, 0) + 1
		previous = current
	_report("걸을 때 바닥이 정수 픽셀로만 옮겨 감", worst >= CRAWL_TARGET, "가장 낮은 일치 %.1f%% (기준 %.0f%%), 프레임별 옮겨 간 칸 %s" % [worst * 100.0, CRAWL_TARGET * 100.0, shifts])
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
