extends SceneTree
## 시야가 움직일 때의 모습을 연속으로 찍는다 (창을 띄움, --headless 금지). 얕은 굴 쥐 둥지(vision_preview.gd와 같은 자리)에서
## 1. 가만히 서서 바라보는 방향을 한 바퀴 돌리기  2. 서쪽으로 걷기(걷는 쪽을 봄)  3. 바위의 긴 옆면을 따라 걸으며 바위 너머 한 점 보기
## 장면마다 interval프레임 간격으로 frames장을 찍어, 반 크기로 줄여 4장씩 줄지은 한 장(<out>/<장면>.png)과 낱장(<out>/<장면>/NN.png)으로 저장한다.
## bash tools/godot.sh --path . -s tools/record_vision_sequence.gd -- --out=<폴더> [--frames=12] [--interval=6]

const PREVIEW: String = "res://tools/screenshot_setups/vision_preview.gd"
const SCENE: String = "res://regions/shallow_cave.tscn"
const MAP_PNG: String = "res://art_src/maps/shallow_cave.png"
const TILE: float = 32.0
## 걷는 속도 (네크로맨서 걷기와 같은 픽셀/초)
const WALK_SPEED: float = 80.0
const COLUMNS: int = 4

var _out: String = ""
var _frames: int = 12
var _interval: int = 6
var _vision: Vision
var _necromancer: Necromancer
var _scenes: Array[Dictionary] = []
var _scene_index: int = -1
var _t: int = 0
var _shots: Array[Image] = []
var _ready_done: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--frames="):
			_frames = arg.trim_prefix("--frames=").to_int()
		elif arg.begins_with("--interval="):
			_interval = arg.trim_prefix("--interval=").to_int()
	if _out.is_empty():
		printerr("--out=<폴더>가 필요합니다")
		quit(2)
		return
	change_scene_to_file(SCENE)


func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	if not _ready_done:
		_ready_done = true
		(load(PREVIEW) as GDScript).call(&"run", current_scene)
		_vision = current_scene.call(&"get_vision")
		_necromancer = get_first_node_in_group(&"necromancer")
		_build_scenes()
		_next_scene()
		return false
	var scene: Dictionary = _scenes[_scene_index]
	var interval: int = scene.get("interval", _interval)
	var length: int = _frames * interval
	var k: float = float(_t) / length
	_necromancer.global_position = (scene.from as Vector2).lerp(scene.to, k)
	var look: Callable = scene.look
	_vision.facing_override = look.call(k)
	# 처음 몇 프레임은 카메라가 따라오게 둔다
	if _t >= 0 and _t % interval == 0 and _shots.size() < _frames:
		RenderingServer.frame_post_draw.connect(_capture, CONNECT_ONE_SHOT)
	_t += 1
	if _t > length:
		_save_scene()
		_next_scene()
	return false


func _build_scenes() -> void:
	var start: Vector2 = _necromancer.global_position
	var layout: MapLayout = MapLayout.from_file(MAP_PNG)
	var rat_room: int = layout.room_at(layout.cells_of("rat")[0])
	var rock: Dictionary = {}
	for r: Dictionary in layout.rocks:
		if r.room == rat_room and (rock.is_empty() or r.cells.size() > rock.cells.size()):
			rock = r
	var rect: Rect2 = Rect2(Vector2(rock.rect.position) * TILE, Vector2(rock.rect.size) * TILE)
	var walk_time: float = _frames * _interval / 60.0
	_scenes.append({"name": "1_turn", "from": start, "to": start, "look": func(k: float) -> Vector2: return Vector2.from_angle(k * TAU)})
	_scenes.append({"name": "2_walk", "from": start, "to": start + Vector2.LEFT * WALK_SPEED * walk_time, "look": func(_k: float) -> Vector2: return Vector2.LEFT})
	# 바위의 긴 서쪽 옆면을 따라 1.5칸 떨어져 위에서 아래로 걸으며, 바위 너머(동쪽 4칸) 한 점을 계속 본다.
	var lane_x: float = rect.position.x - 1.5 * TILE
	var from: Vector2 = Vector2(lane_x, rect.position.y)
	var to: Vector2 = Vector2(lane_x, rect.end.y)
	var target: Vector2 = Vector2(rect.end.x + 4.0 * TILE, rect.get_center().y)
	var pass_interval: int = ceili((to.y - from.y) / WALK_SPEED * 60.0 / _frames)
	_scenes.append({"name": "3_pass_rock", "from": from, "to": to, "interval": pass_interval, "look": func(k: float) -> Vector2: return target - from.lerp(to, k)})
	print("바위 %s, 서쪽 옆 x=%.0f을 y %.0f → %.0f로 걸음 (%d프레임 간격)" % [rect, lane_x, from.y, to.y, pass_interval])


func _next_scene() -> void:
	_scene_index += 1
	if _scene_index >= _scenes.size():
		quit(0)
		return
	_shots.clear()
	# 장면을 바꾸면 카메라가 따라올 시간을 준다 (음수 동안은 찍지 않는다)
	_t = -30


func _capture() -> void:
	_shots.append(root.get_texture().get_image())


func _save_scene() -> void:
	var name: String = _scenes[_scene_index].name
	DirAccess.make_dir_recursive_absolute("%s/%s" % [_out, name])
	var w: int = _shots[0].get_width() / 2
	var h: int = _shots[0].get_height() / 2
	var rows: int = ceili(float(_shots.size()) / COLUMNS)
	var gap: int = 4
	var sheet: Image = Image.create(COLUMNS * w + (COLUMNS - 1) * gap, rows * h + (rows - 1) * gap, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	for i: int in _shots.size():
		var shot: Image = _shots[i]
		shot.save_png("%s/%s/%02d.png" % [_out, name, i])
		var small: Image = shot.duplicate()
		small.convert(Image.FORMAT_RGBA8)
		small.resize(w, h, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(small, Rect2i(0, 0, w, h), Vector2i((i % COLUMNS) * (w + gap), (i / COLUMNS) * (h + gap)))
	sheet.save_png("%s/%s.png" % [_out, name])
	print("저장: %s/%s.png (%d장)" % [_out, name, _shots.size()])
