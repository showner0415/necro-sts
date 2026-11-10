extends View3DCheck
## 벽 가림을 실제로 그린 화면에서 잰다. 창을 띄운다. run_all.sh에는 넣지 않는다.
## bash tools/godot.sh --fixed-fps 60 --path . -s tests/view_3d/check_wall_occlusion.gd
## 얕은 굴에서 네크로맨서를 무작위 바닥 칸에 세우고, 화면에 든 바닥 점이 벽 색으로 보이면 가린 것으로 센다.
## 화면 회전 0도·45도, 앞벽 처리 끔·켬으로 잰다. 계산으로 잰 값은 tests/proto/check_view_3d.gd의 --occlusion.

const SCENE: String = "res://regions/shallow_cave.tscn"
const POSES: int = 40
const POSE_SEED: int = 7
const SAMPLE_RANGE: int = 30
## 바닥 점 간격 (칸)
const SAMPLE_STEP: float = 0.4
const NEAR_CELLS: float = 4.0
const FLOOR_MAX_ROW_SPAN: int = 3
const POSE_FRAMES: int = 3
const FADE_FRAMES: int = 30

var _view: RegionView3D
var _necromancer: Necromancer
var _cells: TerrainCells
## 벽 윗면·앞면에 쓰인 색들
var _wall_colors: Array[Color] = []


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
	for yaw: float in [0.0, 45.0]:
		_view.set_yaw(yaw)
		for front_walls: bool in [false, true]:
			_view.get_front_walls().enabled = front_walls
			await wait_frames(FADE_FRAMES)
			var ratio: Vector2 = await _measure(floors)
			print("[측정] 화면 회전 %d도, 앞벽 처리 %s: 가린 바닥 화면 전체 %.1f%%, 둘레 %d칸 %.1f%%" % [int(yaw), "켬" if front_walls else "끔", ratio.x * 100.0, int(NEAR_CELLS), ratio.y * 100.0])
	finish(true)


func _is_wall_color(color: Color) -> bool:
	for wall: Color in _wall_colors:
		if colors_close(color, wall):
			return true
	return false


## 가린 바닥 점의 비율 (화면 전체, 둘레 NEAR_CELLS칸 안)
func _measure(floors: Array[Vector2i]) -> Vector2:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = POSE_SEED
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
	return Vector2(counts.y / maxf(counts.x, 1.0), counts.w / maxf(counts.z, 1.0))
