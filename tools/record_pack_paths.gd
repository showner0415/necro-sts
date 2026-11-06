extends ScenarioTest
## 박쥐 무리가 움직인 경로를 그림(PNG)으로 남긴다. 무리가 흩어져 서로 다른 방향으로 도는지 눈으로 확인하는 개발용 도구.
## 시험 지역에서 박쥐 말고 다른 몬스터는 치우고, 네크로맨서를 박쥐 무리 동쪽에 세운 뒤 한 발 쏴서 싸움을 건다.
## 그 뒤로 네크로맨서는 제자리에 서 있고(체력을 크게 해서 죽지 않게), --seconds초 동안 박쥐 위치를 프레임마다 기록한다.
##
## bash tools/godot.sh --headless --fixed-fps 60 --path . -s tools/record_pack_paths.gd -- --seconds=12 --out=<PNG 경로>
##
## 그림: 3초씩 칸을 나눠 왼쪽부터 그린다. 네크로맨서가 가운데(흰 십자), 박쥐마다 다른 색 선. 칸의 시작은 빈 네모, 끝은 큰 점,
## 동시 돌진 예고 자리는 흰 테두리 점.
## 회색 원은 도는 반경의 최소·최대. 0.5초마다 선 위에 밝은 점을 찍어 빠르기를 볼 수 있게 한다.
## 출력: 박쥐마다 도는 방향이 바뀐 횟수, 박쥐끼리 가장 가까웠던 거리, 동시 돌진을 시작할 때 박쥐 사이 각도.

const PALETTE_PATH: String = "res://assets/palette/endesga-32.hex"
## 팔레트에서 쓸 색의 번호 (endesga-32.hex의 줄 순서, 0부터)
const BACKGROUND_INDEX: int = 25
const GRID_INDEX: int = 24
const NECRO_INDEX: int = 19
const SECOND_MARK_INDEX: int = 20
const BAT_COLOR_INDICES: Array[int] = [10, 17, 28]
## 그림 배율과 그릴 범위 (네크로맨서에서 이 거리까지, 픽셀)
const SCALE: float = 2.0
const VIEW_RADIUS: float = 120.0
## 네크로맨서를 세울 자리 (박쥐 무리에서 동쪽, 감지 범위 밖)
const STAND_OFFSET: Vector2 = Vector2(130, 0)
const DEFAULT_SECONDS: float = 12.0
## 한 칸에 그리는 시간 (초)과 칸 사이 간격 (픽셀)
const PANEL_SECONDS: float = 3.0
const PANEL_GAP: int = 4

var _seconds: float = DEFAULT_SECONDS
var _out_path: String = ""
var _palette: Array[Color] = []
## 지금 그리는 칸 (이 밖으로는 그리지 않는다)
var _clip: Rect2i


func get_start_scene() -> String:
	return TEST_REGION_SCENE


func _on_scene_ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = arg.trim_prefix("--seconds=").to_float()
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
	if _out_path.is_empty():
		_out_path = OS.get_user_data_dir().path_join("pack_paths.png")
	_load_palette()
	_record()


func _record() -> void:
	var necromancer: Necromancer = find_necromancer()
	var bats: Array[Monster] = []
	for node: Node in get_nodes_in_group(&"monsters"):
		var monster: Monster = node as Monster
		if monster.data.id == &"bat":
			bats.append(monster)
		else:
			monster.free()
	var pack_center: Vector2 = Vector2.ZERO
	for bat: Monster in bats:
		pack_center += bat.global_position / bats.size()
	necromancer.global_position = pack_center + STAND_OFFSET
	necromancer.max_health = 10000.0
	necromancer.health = 10000.0
	await wait_frames(2)

	# 한 발 쏴서 싸움을 건다.
	aim_mouse_at(bats[0].global_position + Vector2(0, -4))
	press_mouse(true)
	await wait_frames(2)
	press_mouse(false)
	for i: int in 120:
		await wait_frames(1)
		if bats.any(func(bat: Monster) -> bool: return bat.get_target() != null):
			break

	var center: Vector2 = necromancer.global_position
	var paths: Array = []
	var windups: Array = []
	for bat: Monster in bats:
		paths.append([] as Array[Vector2])
		windups.append([] as Array[bool])
	var sign_changes: Array[int] = []
	sign_changes.resize(bats.size())
	var last_signs: Array[float] = []
	last_signs.resize(bats.size())
	var closest_pair: float = INF
	var pack_angles: Array[String] = []
	var was_winding: bool = false
	var frames: int = roundi(_seconds * Engine.physics_ticks_per_second)
	for frame: int in frames:
		await wait_frames(1)
		var winding_now: bool = false
		var orbiting: Array[Monster] = []
		for i: int in bats.size():
			var bat: Monster = bats[i]
			if not is_instance_valid(bat):
				continue
			(paths[i] as Array[Vector2]).append(bat.global_position)
			var behavior: DiveBehavior = bat.get_behavior() as DiveBehavior
			var winding_bat: bool = behavior.get_state() == DiveBehavior.State.PACK_WINDUP
			winding_now = winding_now or winding_bat
			(windups[i] as Array[bool]).append(winding_bat)
			if behavior.get_state() == DiveBehavior.State.ORBIT:
				orbiting.append(bat)
				var orbit_sign: float = behavior.get_orbit_sign()
				if last_signs[i] != 0.0 and orbit_sign != last_signs[i]:
					sign_changes[i] += 1
				last_signs[i] = orbit_sign
		for a: int in orbiting.size():
			for b: int in range(a + 1, orbiting.size()):
				closest_pair = minf(closest_pair, orbiting[a].global_position.distance_to(orbiting[b].global_position))
		if winding_now and not was_winding:
			pack_angles.append(_describe_angles(bats, center))
		was_winding = winding_now

	_draw(paths, windups, center)
	print("기록: %.1f초, 박쥐 %d마리, 네크로맨서 %s에 서 있음" % [_seconds, bats.size(), center.round()])
	for i: int in bats.size():
		print("  박쥐 %d (%s): 도는 방향 바꾼 횟수 %d" % [i + 1, _palette[BAT_COLOR_INDICES[i]].to_html(false), sign_changes[i]])
	print("  돌 때 박쥐끼리 가장 가까웠던 거리: %.1f" % closest_pair)
	for line: String in pack_angles:
		print("  동시 돌진 예고 시작: %s" % line)
	print("그림 저장: %s" % _out_path)
	finish(true)


## 대상 주위 박쥐들의 각도와, 각도 순으로 이웃끼리의 차이
func _describe_angles(bats: Array[Monster], center: Vector2) -> String:
	var angles: Array[float] = []
	for bat: Monster in bats:
		if is_instance_valid(bat):
			angles.append(rad_to_deg(wrapf((bat.global_position - center).angle(), 0.0, TAU)))
	angles.sort()
	var gaps: Array[String] = []
	for i: int in angles.size():
		var next: float = angles[(i + 1) % angles.size()] + (360.0 if i == angles.size() - 1 else 0.0)
		gaps.append("%.0f" % (next - angles[i]))
	return "각도 %s, 사이 %s도" % [angles.map(func(a: float) -> String: return "%.0f" % a), gaps]


## PANEL_SECONDS초씩 잘라 왼쪽부터 칸에 나눠 그린다 (한 칸에 다 그리면 무리가 도는 동안 원 전체가 덮여 읽기 어렵다).
func _draw(paths: Array, windups: Array, center: Vector2) -> void:
	var panel: int = roundi(VIEW_RADIUS * 2.0 * SCALE)
	var frames: int = (paths[0] as Array[Vector2]).size()
	var per_panel: int = roundi(PANEL_SECONDS * Engine.physics_ticks_per_second)
	var panel_count: int = maxi(1, ceili(float(frames) / per_panel))
	var image: Image = Image.create(panel * panel_count + PANEL_GAP * (panel_count - 1), panel, false, Image.FORMAT_RGBA8)
	image.fill(_palette[GRID_INDEX])
	var behavior: DiveBehavior = load("res://data/behaviors/dive.tres")
	for k: int in panel_count:
		_clip = Rect2i(k * (panel + PANEL_GAP), 0, panel, panel)
		image.fill_rect(_clip, _palette[BACKGROUND_INDEX])
		for radius: float in [behavior.orbit_radius_min, behavior.orbit_radius_max]:
			for step: int in 360:
				_plot(image, center + Vector2.RIGHT.rotated(deg_to_rad(step)) * radius, center, _palette[GRID_INDEX], 0)
		var first: int = k * per_panel
		var last: int = mini(frames - 1, first + per_panel)
		for i: int in paths.size():
			var path: Array[Vector2] = paths[i]
			var flags: Array[bool] = windups[i]
			var color: Color = _palette[BAT_COLOR_INDICES[i % BAT_COLOR_INDICES.size()]]
			if path.size() <= first:
				continue
			for p: int in range(first + 1, mini(last + 1, path.size())):
				_line(image, path[p - 1], path[p], center, color)
			for p: int in range(first, mini(last + 1, path.size())):
				if (p - first) % 30 == 0:
					_plot(image, path[p], center, _palette[SECOND_MARK_INDEX], 1)
				if flags[p]:
					_plot(image, path[p], center, _palette[NECRO_INDEX], 3)
					_plot(image, path[p], center, color, 2)
			_square(image, path[first], center, color, 4)
			_plot(image, path[mini(last, path.size() - 1)], center, color, 3)
		for d: int in range(-6, 7):
			_plot(image, center + Vector2(d, 0) / SCALE, center, _palette[NECRO_INDEX], 0)
			_plot(image, center + Vector2(0, d) / SCALE, center, _palette[NECRO_INDEX], 0)
	image.save_png(_out_path)


func _to_pixel(world: Vector2, center: Vector2) -> Vector2i:
	return _clip.position + Vector2i(((world - center) * SCALE + Vector2.ONE * VIEW_RADIUS * SCALE).round())


func _plot(image: Image, world: Vector2, center: Vector2, color: Color, radius: int) -> void:
	var p: Vector2i = _to_pixel(world, center)
	for dx: int in range(-radius, radius + 1):
		for dy: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var x: int = p.x + dx
			var y: int = p.y + dy
			if x >= 0 and y >= 0 and _clip.has_point(Vector2i(x, y)):
				image.set_pixel(x, y, color)


func _square(image: Image, world: Vector2, center: Vector2, color: Color, half: int) -> void:
	var p: Vector2i = _to_pixel(world, center)
	for d: int in range(-half, half + 1):
		for edge: Vector2i in [Vector2i(d, -half), Vector2i(d, half), Vector2i(-half, d), Vector2i(half, d)]:
			var q: Vector2i = p + edge
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
