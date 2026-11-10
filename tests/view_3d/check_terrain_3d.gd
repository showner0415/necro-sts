extends ScenarioTest
## 3D 지형 검사. 창을 띄운다 (--headless로는 3D가 그려지지 않는다). run_all.sh에는 넣지 않는다.
## bash tools/godot.sh --fixed-fps 60 --path . -s tests/view_3d/check_terrain_3d.gd -- --scene=res://regions/shallow_cave.tscn
## 1. 벽 윗면과 바닥 칸의 화면 색이 2D 색과 같다 (바닥은 앞벽에 가려졌으면 벽 색이어도 된다)
## 2. 맵 안쪽에 섰을 때 화면에 배경색 픽셀이 없다 (구역 경계에 틈이 없다). 구역 경계를 지나는 자리들에서 본다
## 3. 화면 밖 구역은 그리지 않는다 (그려진 삼각형 수가 전체보다 훨씬 적다)

const DEFAULT_SCENE: String = "res://regions/shallow_cave.tscn"
const SETTLE_FRAMES: int = 30
## 색 오차 허용 (8비트 한 단계)
const COLOR_TOLERANCE: float = 1.5 / 255.0
## 틈을 볼 때 맵 가장자리에서 떨어질 칸 수 (화면이 맵 안에 들어오게)
const MAP_MARGIN_CELLS: int = 24
## 구역 경계에 카메라를 놓을 자리 수와 한 번에 옮기는 칸 수
const SEAM_POSES: int = 6
const SEAM_STEP_CELLS: int = 8
## 그려진 삼각형이 전체의 이 비율을 넘으면 실패
const MAX_DRAWN_RATIO: float = 0.25

var _view: RegionView3D
var _necromancer: Necromancer
var _cells: Array[TerrainCells] = []


func get_start_scene() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			return arg.trim_prefix("--scene=")
	return DEFAULT_SCENE


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	_necromancer.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in get_nodes_in_group(&"monsters"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	# 바닥·벽 색만 보려고 몸과 바닥 표시·상자를 숨긴다.
	_necromancer.visible = false
	for child: Node in current_scene.get_children():
		if child is InteractZone or child is EscapePoint:
			(child as CanvasItem).visible = false
	# 칸 색을 2D 색과 비교하므로 시야로 어두워지지 않게 끈다.
	var vision: Vision = current_scene.call(&"get_vision") if current_scene.has_method(&"get_vision") else null
	if vision != null:
		vision.set_active(false)
	_view = current_scene.call(&"add_view_3d")
	_view.aim_lead.strength = 0.0
	# 실제 마우스 자리의 벽이 잘려서 색이 달라지지 않게 앞벽 처리를 끄고 조준을 고정한다.
	_view.aim_override = _necromancer.get_body_center()
	_view.get_front_walls().enabled = false
	(current_scene.get_node("HUD") as CanvasLayer).visible = false
	for child: Node in current_scene.get_children():
		if child is PlaceholderGround:
			_cells.append(TerrainCells.from_ground(child as PlaceholderGround))
		elif child is PlaceholderWalls:
			_cells.append(TerrainCells.from_walls(child as PlaceholderWalls))
	print("지형: 사각형 %d, 구역 %d개, 만드는 시간 %.0fms" % [_view.get_terrain_quads(), _view.get_terrain_chunks().size(), _view.get_terrain_build_usec() / 1000.0])
	await wait_frames(SETTLE_FRAMES)
	await _check_colors()
	var map: TerrainCells = _largest_map()
	if map.size.x > MAP_MARGIN_CELLS * 2 and map.size.y > MAP_MARGIN_CELLS * 2:
		await _check_seams(map)
		await _check_culling()
	else:
		print("[건너뜀] 틈·구역 검사: 맵이 화면보다 작음 (%s)" % map.size)
	finish(true)


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _largest_map() -> TerrainCells:
	var largest: TerrainCells = _cells[0]
	for cells: TerrainCells in _cells:
		if cells.size.x * cells.size.y > largest.size.x * largest.size.y:
			largest = cells
	return largest


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= COLOR_TOLERANCE and absf(a.g - b.g) <= COLOR_TOLERANCE and absf(a.b - b.b) <= COLOR_TOLERANCE


func _check_colors() -> void:
	var image: Image = await _capture()
	var screen: Rect2i = Rect2i(Vector2i.ZERO, image.get_size())
	var checked: int = 0
	var hidden_floors: int = 0
	for cells: TerrainCells in _cells:
		for y: int in cells.size.y:
			for x: int in cells.size.x:
				var expected: Color = cells.top_colors[cells.index_of(x, y)]
				if expected.a == 0.0:
					continue
				var center: Vector2 = cells.origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * cells.tile_size
				var wall: bool = cells.is_wall(x, y)
				var point: Vector2i = Vector2i(_view.world_to_screen(center, _view.wall_height_px if wall else 0.0))
				if not screen.has_point(point):
					continue
				var actual: Color = image.get_pixelv(point)
				checked += 1
				if _close(actual, expected):
					continue
				if not wall and (_is_wall_color(actual) or _other_layer_has(cells, actual)):
					hidden_floors += 1
					continue
				fail_step("색", "칸 (%d, %d) %s: 화면 %s, 기대 %s, 자리 %s" % [x, y, "벽" if wall else "바닥", actual.to_html(false), expected.to_html(false), point])
				return
	if checked == 0:
		fail_step("색", "화면에 든 칸이 없음")
		return
	pass_step("색", "화면의 %d칸이 2D 색과 같음 (앞벽에 가린 바닥 %d칸)" % [checked, hidden_floors])


func _is_wall_color(color: Color) -> bool:
	for cells: TerrainCells in _cells:
		if _close(color, cells.face_color):
			return true
		for i: int in cells.walls.size():
			if cells.walls[i] == 1 and _close(color, cells.top_colors[i]):
				return true
	return false


## 칸 색이 겹치는 층(시험 통로의 바닥과 벽 층)이 있으면 다른 층의 색일 수 있다
func _other_layer_has(cells: TerrainCells, color: Color) -> bool:
	for other: TerrainCells in _cells:
		if other != cells and other.top_colors.has(color):
			return true
	return false


func _check_seams(map: TerrainCells) -> void:
	var background: Color = RenderingServer.get_default_clear_color()
	var start: Vector2i = map.size / 2 / _view.chunk_cells * _view.chunk_cells
	var worst: int = 0
	var checked: int = 0
	for i: int in SEAM_POSES:
		var cell: Vector2i = start + Vector2i(i, i - SEAM_POSES / 2) * SEAM_STEP_CELLS
		_necromancer.global_position = map.origin + Vector2(cell * map.tile_size)
		await wait_frames(SETTLE_FRAMES)
		var image: Image = await _capture()
		var gaps: int = 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				if _close(image.get_pixel(x, y), background):
					gaps += 1
		worst = maxi(worst, gaps)
		checked += 1
	if worst > 0:
		fail_step("틈", "배경색 픽셀 최대 %d개 (%d자리)" % [worst, checked])
		return
	pass_step("틈", "구역 경계를 지나는 %d자리에서 배경색 픽셀 0개" % checked)


func _check_culling() -> void:
	await wait_frames(SETTLE_FRAMES)
	var drawn: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var total: int = _view.get_terrain_quads() * 2
	var objects: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var chunks: int = _view.get_terrain_chunks().size()
	if drawn == 0 or float(drawn) / total > MAX_DRAWN_RATIO or objects >= chunks:
		fail_step("구역", "그려진 삼각형 %d / 전체 %d, 그려진 물체 %d / 구역 %d" % [drawn, total, objects, chunks])
		return
	pass_step("구역", "그려진 삼각형 %d / 전체 %d (%.1f%%), 그려진 물체 %d / 구역 %d" % [drawn, total, 100.0 * drawn / total, objects, chunks])
