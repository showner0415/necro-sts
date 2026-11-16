extends View3DCheck
## 고해상도 UI(--hd_ui, docs/plans/2026-11-14_hd_ui_layer_plan.md)에서 3D 화면과 조준이 지금과 같은지 본다. 창을 띄운다. run_all.sh에는 넣지 않는다.
## bash tools/godot.sh --fixed-fps 60 --path . -s tests/view_3d/check_hd_ui.gd -- --hd_ui
## - 루트 창이 canvas_items이고, 카메라가 GameScreen의 SubViewport에 있다
## - 카메라가 그리는 화면의 크기가 화면(내부 해상도) 크기와 같다
## - 화면 점의 조준 월드 좌표가 내부 해상도로 직접 계산한 카메라 광선과 같다 (viewport 모드와 같은 계산)
## - 창 그림의 3D 화면이 SubViewport 그림을 정수 배율 그대로 늘린 것이다 (도트가 그대로)
## - 개발용 F4 키로 팔레트 후처리를 켜고 끈다 (PalettePass가 SubViewport 안에 있어도)
## --hd_ui 없이 돌리면 구조·도트 그대로·F4는 건너뛰고, 크기와 조준만 본다 (직접 계산이 지금 구조에서도 맞는지).

const SETTLE_FRAMES: int = 30
const KEY_FRAMES: int = 3
## 조준을 견줄 화면 점 (내부 해상도 비율)
const SCREEN_RATIOS: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.15, 0.3), Vector2(0.5, 0.5), Vector2(0.9, 0.2), Vector2(0.95, 0.95)]
## 조준 좌표 허용 차 (월드 픽셀)
const AIM_TOLERANCE: float = 0.01
## 도트 비교에서 건너 뛸 간격 (내부 해상도 픽셀)
const PIXEL_STRIDE: int = 3
## 몸 가운데에서 조준점까지 (카메라가 실제 마우스를 따라가지 않게 고정)
const AIM_DISTANCE: float = 128.0

var _view: RegionView3D


func _on_scene_ready() -> void:
	var necromancer: Necromancer = find_necromancer()
	_view = open_layer()
	_view.aim_override = necromancer.get_body_center() + Vector2.RIGHT * AIM_DISTANCE
	await wait_frames(SETTLE_FRAMES)
	if RegionView3D.use_hd_ui:
		_check_structure()
	_check_screen_size()
	_check_aim()
	if RegionView3D.use_hd_ui:
		await _check_pixels()
		await _check_palette_key()
	finish(true)


func _check_structure() -> void:
	var camera_viewport: Viewport = _view.get_camera().get_viewport()
	var ok: bool = root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and camera_viewport is SubViewport and camera_viewport.get_parent() is SubViewportContainer
	var evidence: String = "루트 늘리기 방식 %d (canvas_items = %d), 카메라 뷰포트 %s" % [root.content_scale_mode, Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, camera_viewport.get_class()]
	if ok:
		pass_step("구조", evidence)
	else:
		fail_step("구조", evidence)


func _check_screen_size() -> void:
	var expected: Vector2 = root.get_visible_rect().size
	var actual: Vector2 = _view.get_camera().get_viewport().get_visible_rect().size
	var evidence: String = "카메라 화면 %s, 화면(내부 해상도) %s, 창 %s" % [actual, expected, root.size]
	if actual.is_equal_approx(expected):
		pass_step("화면 크기", evidence)
	else:
		fail_step("화면 크기", evidence)


func _check_aim() -> void:
	var size: Vector2 = root.get_visible_rect().size
	var worst: float = 0.0
	var worst_point: Vector2 = Vector2.ZERO
	for ratio: Vector2 in SCREEN_RATIOS:
		var point: Vector2 = (size * ratio).floor()
		var gap: float = _view.aim_from_screen(point).distance_to(_expected_aim(point, size))
		if gap > worst:
			worst = gap
			worst_point = point
	var evidence: String = "화면 점 %d개, 가장 큰 차이 %.4f픽셀 (%s, 허용 %.2f)" % [SCREEN_RATIOS.size(), worst, worst_point, AIM_TOLERANCE]
	if worst <= AIM_TOLERANCE:
		pass_step("조준", evidence)
	else:
		fail_step("조준", evidence)


## 내부 해상도(size)의 화면 점에서 나가는 카메라 광선으로 구한 조준 좌표. Camera3D.project_ray_normal과 같은 식이다.
func _expected_aim(point: Vector2, size: Vector2) -> Vector2:
	var camera: Camera3D = _view.get_camera()
	var half_height: float = tan(deg_to_rad(camera.fov * 0.5))
	var local: Vector3 = Vector3((point.x / size.x * 2.0 - 1.0) * half_height * size.x / size.y, ((1.0 - point.y / size.y) * 2.0 - 1.0) * half_height, -1.0).normalized()
	var origin: Vector3 = camera.global_position
	return ViewSpace.aim_from_ray(origin, camera.global_basis * local, _view.get_aim_offset(), _view.get_aim_height(), Vector2.INF)


func _check_pixels() -> void:
	var window_image: Image = await capture()
	var screen_image: Image = _view.get_camera().get_viewport().get_texture().get_image()
	var scale: int = window_image.get_width() / screen_image.get_width()
	var checked: int = 0
	var different: int = 0
	for y: int in range(0, screen_image.get_height(), PIXEL_STRIDE):
		for x: int in range(0, screen_image.get_width(), PIXEL_STRIDE):
			var window_x: int = x * scale + scale / 2
			var window_y: int = y * scale + scale / 2
			if window_x >= window_image.get_width() or window_y >= window_image.get_height():
				continue
			checked += 1
			if not colors_close(window_image.get_pixel(window_x, window_y), screen_image.get_pixel(x, y)):
				different += 1
	var evidence: String = "창 %d×%d, 3D 화면 %d×%d, 배율 %d, 견준 픽셀 %d개 중 다름 %d개" % [window_image.get_width(), window_image.get_height(), screen_image.get_width(), screen_image.get_height(), scale, checked, different]
	if scale >= 1 and checked > 0 and different == 0:
		pass_step("도트 그대로", evidence)
	else:
		fail_step("도트 그대로", evidence)


func _check_palette_key() -> void:
	var palette: PalettePass = _view.get_palette()
	var before: bool = palette.is_enabled()
	await _tap_key(KEY_F4)
	var toggled: bool = palette.is_enabled()
	await _tap_key(KEY_F4)
	var restored: bool = palette.is_enabled()
	var evidence: String = "처음 %s → F4 → %s → F4 → %s" % [before, toggled, restored]
	if toggled != before and restored == before:
		pass_step("F4 팔레트", evidence)
	else:
		fail_step("F4 팔레트", evidence)


func _tap_key(key: Key) -> void:
	press_key(key, true)
	await wait_frames(KEY_FRAMES)
	press_key(key, false)
	await wait_frames(KEY_FRAMES)
