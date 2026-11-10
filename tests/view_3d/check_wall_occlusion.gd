extends View3DCheck
## 벽 가림을 실제로 그린 화면에서 잰다. 창을 띄운다. run_all.sh에는 넣지 않는다.
## bash tools/godot.sh --fixed-fps 60 --path . -s tests/view_3d/check_wall_occlusion.gd
## 얕은 굴에서 네크로맨서를 무작위 바닥 칸에 세우고, 화면에 든 바닥 점이 벽 색으로 보이면 가린 것으로 센다.
## 화면 회전 0도·45도, 앞벽 처리 끔·켬으로 잰다.

const SCENE: String = "res://regions/shallow_cave.tscn"
const POSES: int = 40
const POSE_SEED: int = 7
const SAMPLE_RANGE: int = 30
## 바닥 점 간격 (칸)
const SAMPLE_STEP: float = 0.4
const NEAR_CELLS: float = 4.0
const NARROW_SPAN: int = 3
const FLOOR_MAX_ROW_SPAN: int = 3
const POSE_FRAMES: int = 3
const FADE_FRAMES: int = 30
## 지형 셰이더의 smoothstep 시작: 자리 반지름의 이 비율 안은 완전히 잘린다
const CUT_CORE: float = 0.7

var _view: RegionView3D
var _necromancer: Necromancer
var _cells: TerrainCells
## 벽 윗면·앞면에 쓰인 색들
var _wall_colors: Array[Color] = []
## 둘레 안 바닥 점을 나눈 것: 이름 → (점 수, 가린 수)
var _detail: Dictionary = {}


func get_start_scene() -> String:
	return SCENE


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	_necromancer.process_mode = Node.PROCESS_MODE_DISABLED
	_necromancer.visible = false
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	var vision: Vision = current_scene.call(&"get_vision")
	if vision != null:
		vision.set_active(false)
	_view = open_layer()
	_cells = TerrainCells.from_walls(current_scene.get_node("Walls") as PlaceholderWalls)
	var floors: Array[Vector2i] = []
	_wall_colors = [_cells.face_color]
	for y: int in _cells.size.y:
		for x: int in _cells.size.x:
			var color: Color = _cells.top_colors[_cells.index_of(x, y)]
			if _cells.is_wall(x, y):
				if not _wall_colors.has(color):
					_wall_colors.append(color)
			elif color.a > 0.0:
				floors.append(Vector2i(x, y))
	_view.aim_override = _necromancer.get_body_center()
	var pitches: PackedFloat64Array = _pitch_args()
	if not pitches.is_empty():
		await _measure_pitches(pitches, floors)
		finish(true)
		return
	for yaw: float in [0.0, 45.0]:
		_view.set_yaw(yaw)
		for front_walls: bool in [false, true]:
			_view.get_front_walls().enabled = front_walls
			await wait_frames(FADE_FRAMES)
			var ratio: Vector2 = await _measure(floors)
			print("[측정] 화면 회전 %d도, 앞벽 처리 %s: 가린 바닥 화면 전체 %.1f%%, 둘레 %d칸 %.1f%%" % [int(yaw), "켬" if front_walls else "끔", ratio.x * 100.0, int(NEAR_CELLS), ratio.y * 100.0])
			for key: String in _detail.keys():
				var entry: Vector2 = _detail[key]
				print("  둘레 %d칸 안, %s: 바닥 점 %d개, 가림 %d개 (%.1f%%)" % [int(NEAR_CELLS), key, int(entry.x), int(entry.y), 100.0 * entry.y / maxf(entry.x, 1.0)])
	finish(true)


func _pitch_args() -> PackedFloat64Array:
	var values: PackedFloat64Array = PackedFloat64Array()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pitches="):
			for text: String in arg.trim_prefix("--pitches=").split(","):
				values.append(text.to_float())
	return values


## 기울기마다 45도 화면에서 넓은 곳·좁은 길에 선 경우의 가림을 잰다 (--pitches=55,60,70).
func _measure_pitches(pitches: PackedFloat64Array, floors: Array[Vector2i]) -> void:
	var narrow: Array[Vector2i] = floors.filter(func(cell: Vector2i) -> bool: return _span(cell, Vector2i(0, 1)) <= NARROW_SPAN or _span(cell, Vector2i(1, 0)) <= NARROW_SPAN)
	print("벽 높이 %.0fpx, 좁은 길 칸 %d개 (폭 %d칸 이하)" % [_view.wall_height_px, narrow.size(), NARROW_SPAN])
	_view.set_yaw(45.0)
	for pitch: float in pitches:
		_view.set_pitch(pitch)
		for front_walls: bool in [false, true]:
			_view.get_front_walls().enabled = front_walls
			await wait_frames(FADE_FRAMES)
			var open_ratio: Vector2 = await _measure(floors)
			var narrow_ratio: Vector2 = await _measure(narrow)
			print("[측정] 기울기 %d도, 앞벽 처리 %s: 가린 바닥 화면 전체 %.1f%%, 둘레 %d칸 %.1f%%, 좁은 길에 섰을 때 화면 전체 %.1f%%, 둘레 %d칸 %.1f%%" % [int(pitch), "켬" if front_walls else "끔", open_ratio.x * 100.0, int(NEAR_CELLS), open_ratio.y * 100.0, narrow_ratio.x * 100.0, int(NEAR_CELLS), narrow_ratio.y * 100.0])


## cell에서 direction 양쪽으로 이어진 바닥 칸 수 (NARROW_SPAN + 1까지만 센다)
func _span(cell: Vector2i, direction: Vector2i) -> int:
	var count: int = 1
	for side: int in [1, -1]:
		var at: Vector2i = cell + direction * side
		while count <= NARROW_SPAN and at.x >= 0 and at.y >= 0 and at.x < _cells.size.x and at.y < _cells.size.y and not _cells.is_wall(at.x, at.y):
			count += 1
			at += direction * side
	return count


## 바닥 점을 잘라내기 자리와의 관계로 나눈다: 화면에서 자리 안쪽(완전히 잘림)·가장자리(점무늬)·밖, 그리고 플레이어보다 카메라 쪽 바닥인지.
## 플레이어보다 먼 쪽 바닥을 가리는 벽은 플레이어 뒤쪽 벽이라 잘리지 않는다 (앞벽 처리는 플레이어·조준점보다 카메라 쪽 벽만 자른다).
func _detail_key(world: Vector2, pixel: Vector2) -> String:
	var walls: FrontWalls = _view.get_front_walls()
	var feet: Vector2 = _necromancer.global_position
	var player: float = pixel.distance_to(_view.world_to_screen(feet, walls.player_zone_height)) / walls.cut_radius_player
	var aim: float = pixel.distance_to(_view.world_to_screen(feet, _view.get_aim_height())) / walls.cut_radius_aim
	var nearest: float = minf(player, aim)
	var zone: String = "잘라내기 안쪽" if nearest < CUT_CORE else ("점무늬 가장자리" if nearest <= 1.0 else "자리 밖")
	var back: Vector3 = _view.get_camera().global_transform.basis.z
	var side: String = "카메라 쪽 바닥" if (world - feet).dot(Vector2(back.x, back.z)) > 0.0 else "먼 쪽 바닥"
	return "%s, %s" % [zone, side]


func _is_wall_color(color: Color) -> bool:
	for wall: Color in _wall_colors:
		if colors_close(color, wall):
			return true
	return false


## 가린 바닥 점의 비율 (화면 전체, 둘레 NEAR_CELLS칸 안)
func _measure(floors: Array[Vector2i]) -> Vector2:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = POSE_SEED
	_detail.clear()
	var counts: Vector4 = Vector4.ZERO
	var tile: float = _cells.tile_size
	for pose: int in POSES:
		var cell: Vector2i = floors[random.randi() % floors.size()]
		_necromancer.global_position = _cells.origin + (Vector2(cell) + Vector2(0.5, 0.5)) * tile
		_view.aim_override = _necromancer.get_body_center()
		await wait_frames(POSE_FRAMES)
		var image: Image = await capture()
		var screen: Rect2i = Rect2i(Vector2i.ZERO, image.get_size())
		for dy: int in range(-SAMPLE_RANGE, SAMPLE_RANGE + 1):
			for dx: int in range(-SAMPLE_RANGE, SAMPLE_RANGE + 1):
				var point: Vector2 = Vector2(cell) + Vector2(0.5, 0.5) + (Vector2(dx, dy) + Vector2(random.randf(), random.randf()) - Vector2(0.5, 0.5)) * SAMPLE_STEP
				var at: Vector2i = Vector2i(point.floor())
				if at.x < 0 or at.y < 0 or at.x >= _cells.size.x or at.y >= _cells.size.y or _cells.is_wall(at.x, at.y):
					continue
				var expected: Color = _cells.top_colors[_cells.index_of(at.x, at.y)]
				var pixel: Vector2i = Vector2i(_view.world_to_screen(_cells.origin + point * tile, 0.0))
				if expected.a == 0.0 or not screen.has_point(pixel):
					continue
				# 칸 경계의 점은 옆 칸(바닥) 색으로 찍힐 수 있으므로, 벽 색으로 보일 때만 가린 것으로 센다.
				var hidden: bool = _is_wall_color(image.get_pixelv(pixel))
				var near: bool = Vector2(dx, dy).length() * SAMPLE_STEP <= NEAR_CELLS
				counts.x += 1.0
				counts.y += 1.0 if hidden else 0.0
				counts.z += 1.0 if near else 0.0
				counts.w += 1.0 if near and hidden else 0.0
				if near:
					var key: String = _detail_key(point * tile + _cells.origin, Vector2(pixel))
					var entry: Vector2 = _detail.get(key, Vector2.ZERO)
					_detail[key] = entry + Vector2(1.0, 1.0 if hidden else 0.0)
	return Vector2(counts.y / maxf(counts.x, 1.0), counts.w / maxf(counts.z, 1.0))
