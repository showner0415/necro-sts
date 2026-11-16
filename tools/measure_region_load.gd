extends SceneTree
## 지역에 들어갈 때의 로딩 시간을 단계별로 잰다 (창 모드. 3D 층까지 붙인 실제 상황).
## 거점(메인 씬)을 먼저 띄워 몇 프레임 돌린 뒤, 출구로 나갈 때처럼 지역 씬으로 바꾸며 잰다.
##
## 사용 예 (--headless를 붙이면 3D 층이 붙지 않고 그리기도 없으므로 붙이지 않는다):
##   bash tools/godot.sh --path . -s tools/measure_region_load.gd -- --scene=res://regions/shallow_cave.tscn
##
## --scene:    들어갈 지역 씬 (기본 얕은 굴)
## --top:      _ready가 오래 걸린 노드를 몇 개까지 보여 줄지 (기본 15)
## --frames:   들어간 뒤 프레임 시간을 몇 프레임 잴지 (기본 120)
## --deps:     씬보다 먼저 씬이 가리키는 리소스를 하나씩 불러와 각각의 시간을 잰다 (그만큼 씬 불러오기는 빨라진다)
## --strip=<스크립트 파일,…>: 원인 찾기용. 트리에 넣기 전에 그 스크립트의 노드를 모두 뺀다 (예: monster.gd,pack_spawn.gd)
## --hide=<노드 이름,…>: 원인 찾기용. 트리에 넣기 전에 그 이름의 노드를 숨긴다 (_draw를 하지 않는다. 예: Walls)
## --remove=<노드 이름,…>: 원인 찾기용. 트리에 넣기 전에 그 이름의 노드를 뺀다 (예: NavigationGrid)
## --no_physics=<이름,…>: 원인 찾기용. 들어간 직후 그 스크립트 파일(예: monster.gd)이나 클래스의 노드의 _physics_process·_process를 끈다 ("*"면 전부)
##
## 출력:
## - 단계: 이전 씬 지우기, 씬 파일 불러오기(load), 노드 만들기(instantiate), 트리에 넣기(_enter_tree·_ready 전부), 첫 프레임 그리기까지
## - _ready 오래 걸린 것: 노드마다 그 노드만의 시간(자식의 _ready는 빼고 잼, 대략값)과, 같은 스크립트끼리 합친 시간
## - 프레임: 들어간 뒤 처음 몇 프레임의 시간과 그 뒤 중앙값 (첫 그리기의 셰이더 준비가 여기서 보인다)

const DEFAULT_SCENE: String = "res://regions/shallow_cave.tscn"
## 거점을 띄우고 기다리는 프레임 (거점 그리기 준비가 끝나게)
const BASE_WARM_FRAMES: int = 30
## 들어간 뒤 프레임 안의 순서를 몇 줄까지 남길지 (프레임마다 4줄)
const TRACE_LINES: int = 24

var _scene_path: String = DEFAULT_SCENE
var _top: int = 15
var _frame_count: int = 120
var _measure_deps: bool = false
## 원인 찾기용: 들어간 직후 _physics_process·_process를 끌 노드 (스크립트 파일 이름이나 클래스 이름, "*"면 전부)
var _no_physics: PackedStringArray = PackedStringArray()
## 원인 찾기용: 트리에 넣기 전에 뺄 노드 이름
var _remove: PackedStringArray = PackedStringArray()
## 원인 찾기용: 트리에 넣기 전에 숨길 노드 이름 (_draw를 하지 않는다)
var _hide: PackedStringArray = PackedStringArray()
## 원인 찾기용: 트리에 넣기 전에 뺄 노드의 스크립트 파일 이름 (예: monster.gd,pack_spawn.gd)
var _strip: PackedStringArray = PackedStringArray()

var _frame: int = 0
var _phase: int = 0
## 시간을 잴 때 쓰는 기록: [시각(usec), 종류("add"/"ready"), 노드]
var _events: Array = []
var _recording: bool = false
var _frame_times: Array[int] = []
var _last_frame_usec: int = 0
var _entered_usec: int = 0
var _first_draw_usec: int = -1
var _phases: Array = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--top="):
			_top = arg.trim_prefix("--top=").to_int()
		elif arg.begins_with("--frames="):
			_frame_count = arg.trim_prefix("--frames=").to_int()
		elif arg == "--deps":
			_measure_deps = true
		elif arg.begins_with("--strip="):
			_strip = arg.trim_prefix("--strip=").split(",")
		elif arg.begins_with("--hide="):
			_hide = arg.trim_prefix("--hide=").split(",")
		elif arg.begins_with("--remove="):
			_remove = arg.trim_prefix("--remove=").split(",")
		elif arg.begins_with("--no_physics="):
			_no_physics = arg.trim_prefix("--no_physics=").split(",")
	var base: String = ProjectSettings.get_setting("application/run/main_scene", "")
	print("거점: %s → 들어갈 곳: %s" % [base, _scene_path])
	change_scene_to_file(base)
	node_added.connect(_on_node_added)


func _process(_delta: float) -> bool:
	_frame += 1
	if _phase == 0 and current_scene != null and _frame >= BASE_WARM_FRAMES:
		_phase = 1
		_enter_region()
	elif _phase == 2:
		var now: int = Time.get_ticks_usec()
		_frame_times.append(now - _last_frame_usec)
		_last_frame_usec = now
		if _frame_times.size() >= _frame_count:
			_phase = 3
			_report()
			quit(0)
	return false


func _enter_region() -> void:
	var start: int = Time.get_ticks_usec()
	var old: Node = current_scene
	old.free()
	_mark("이전 씬 지우기", start)

	if _measure_deps:
		for dep: String in ResourceLoader.get_dependencies(_scene_path):
			var dep_path: String = dep.get_slice("::", 2) if dep.contains("::") else dep
			var dep_start: int = Time.get_ticks_usec()
			var res: Resource = load(dep_path)
			var took: float = (Time.get_ticks_usec() - dep_start) / 1000.0
			if took >= 1.0:
				print("    리소스 %7.1f ms  %s (%s)" % [took, dep_path, res.get_class() if res != null else "실패"])

	var t: int = Time.get_ticks_usec()
	var packed: PackedScene = load(_scene_path)
	_mark("씬 파일 불러오기 (load)", t)

	t = Time.get_ticks_usec()
	var scene: Node = packed.instantiate()
	_mark("노드 만들기 (instantiate)", t)

	if not _strip.is_empty():
		var stripped: int = 0
		for node: Node in scene.find_children("*", "", true, false):
			# 부모를 먼저 지웠으면 자식도 이미 없다.
			if is_instance_valid(node) and _strip.has(_script_name(node)):
				node.get_parent().remove_child(node)
				node.free()
				stripped += 1
		print("  원인 찾기: %s 노드 %d개를 뺌" % [",".join(_strip), stripped])
	for node_name: String in _hide:
		var hidden: CanvasItem = scene.find_child(node_name, true, false) as CanvasItem
		if hidden != null:
			hidden.visible = false
			print("  원인 찾기: 노드 %s를 숨김 (_draw를 하지 않음)" % node_name)
	for node_name: String in _remove:
		var removed: Node = scene.find_child(node_name, true, false)
		if removed != null:
			removed.get_parent().remove_child(removed)
			removed.free()
			print("  원인 찾기: 노드 %s를 뺌" % node_name)

	t = Time.get_ticks_usec()
	_recording = true
	_events.append([t, "start", null])
	root.add_child(scene)
	current_scene = scene
	_recording = false
	if not _no_physics.is_empty():
		var off: int = 0
		for node: Node in scene.find_children("*", "", true, false):
			if _matches_no_physics(node):
				node.set_physics_process(false)
				node.set_process(false)
				off += 1
		print("  원인 찾기: _physics_process·_process를 끈 노드 %d개 (%s)" % [off, ",".join(_no_physics)])
	_events.append([Time.get_ticks_usec(), "end", null])
	_mark("트리에 넣기 (_enter_tree·_ready 전부)", t)

	_entered_usec = Time.get_ticks_usec()
	_mark("합계 (거점을 지운 때부터 _ready 끝까지)", start)
	RenderingServer.frame_post_draw.connect(_on_first_draw.bind(start), CONNECT_ONE_SHOT)
	_last_frame_usec = Time.get_ticks_usec()
	_phase = 2
	# 들어간 뒤 처음 몇 프레임 안에서 무엇에 시간이 걸리는지: 물리 처리 시작, _process 시작, 그리기 앞뒤 시각을 남긴다.
	_trace_start = _entered_usec
	physics_frame.connect(_trace.bind("물리 프레임 시작 (그 앞까지 = 이전 일)"))
	process_frame.connect(_trace.bind("_process 시작 (그 앞까지 = 물리 처리)"))
	RenderingServer.frame_pre_draw.connect(_trace.bind("그리기 시작 (그 앞까지 = _process)"))
	RenderingServer.frame_post_draw.connect(_trace.bind("그리기 끝 (그 앞까지 = 그리기)"))


var _trace_start: int = 0
var _trace_lines: Array[String] = []
var _trace_last: int = 0


func _trace(label: String) -> void:
	if _trace_lines.size() >= TRACE_LINES:
		return
	var now: int = Time.get_ticks_usec()
	if _trace_last == 0:
		_trace_last = _trace_start
	_trace_lines.append("  +%8.1f ms (앞에서 %8.1f ms)  %s  [물리: 충돌 쌍 %d, 움직이는 물체 %d, 지난 물리 프레임 %.1f ms, 객체 %d]" % [
		(now - _trace_start) / 1000.0, (now - _trace_last) / 1000.0, label,
		Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS), Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.OBJECT_COUNT)])
	_trace_last = now


func _on_first_draw(start: int) -> void:
	_first_draw_usec = Time.get_ticks_usec()
	_phases.append(["_ready 끝 → 첫 프레임 그리기 끝", (_first_draw_usec - _entered_usec) / 1000.0])
	_phases.append(["거점을 지운 때부터 첫 프레임까지 (사람이 느끼는 멈춤)", (_first_draw_usec - start) / 1000.0])


func _mark(label: String, since: int) -> void:
	_phases.append([label, (Time.get_ticks_usec() - since) / 1000.0])


func _on_node_added(node: Node) -> void:
	if not _recording:
		return
	_events.append([Time.get_ticks_usec(), "add", node])
	node.ready.connect(_on_node_ready.bind(node), CONNECT_ONE_SHOT)


func _on_node_ready(node: Node) -> void:
	if _recording:
		_events.append([Time.get_ticks_usec(), "ready", node])


## 기록 사이의 시간을 다음 기록의 노드에 붙인다.
## ready 앞의 시간은 그 노드의 _ready (자식은 먼저 끝나므로 빠진다), add 앞의 시간은 그 노드를 넣기 전 부모가 한 일과 _enter_tree다.
func _report() -> void:
	print("")
	print("== 단계 (ms) ==")
	for phase: Array in _phases:
		print("  %8.1f  %s" % [phase[1], phase[0]])

	var per_node: Dictionary = {}
	var per_script: Dictionary = {}
	var node_count: int = 0
	for i: int in range(1, _events.size()):
		var event: Array = _events[i]
		var node: Node = event[2]
		if node == null:
			continue
		var gap: int = event[0] - _events[i - 1][0]
		var kind: String = event[1]
		if kind == "add":
			node_count += 1
		var key: String = "%s %s" % [kind, _describe(node)]
		per_node[key] = per_node.get(key, 0) + gap
		var script_key: String = "%s %s" % [kind, _script_name(node)]
		per_script[script_key] = per_script.get(script_key, [0, 0])
		per_script[script_key][0] += gap
		per_script[script_key][1] += 1
	print("")
	print("== 트리에 넣은 노드 %d개. 오래 걸린 노드 (ms, ready = 그 노드의 _ready, add = 넣기 전 부모의 일·_enter_tree) ==" % node_count)
	var node_keys: Array = per_node.keys()
	node_keys.sort_custom(func(a: String, b: String) -> bool: return per_node[a] > per_node[b])
	for key: String in node_keys.slice(0, _top):
		print("  %8.1f  %s" % [per_node[key] / 1000.0, key])
	print("")
	print("== 같은 스크립트·클래스끼리 합친 시간 (ms, 개수) ==")
	var script_keys: Array = per_script.keys()
	script_keys.sort_custom(func(a: String, b: String) -> bool: return per_script[a][0] > per_script[b][0])
	for key: String in script_keys.slice(0, _top):
		print("  %8.1f  ×%-4d %s" % [per_script[key][0] / 1000.0, per_script[key][1], key])

	print("")
	print("== 들어간 뒤 처음 몇 프레임의 순서 (_ready 끝을 0으로) ==")
	for line: String in _trace_lines:
		print(line)
	var nav: Node = current_scene.get_tree().get_first_node_in_group(&"navigation_grid")
	if nav != null:
		print("")
		print("== 길찾기 (NavigationGrid) ==")
		print("  길찾기 %d번, 걸린 시간 합 %.1f ms (막힌 칸 표를 처음 만드는 시간 포함)" % [nav.get(&"path_searches"), nav.get(&"path_search_usec") / 1000.0])
		var grids: Dictionary = nav.get(&"_grids")
		for key: Vector2 in grids:
			var grid: GridPath = grids[key]
			print("  몸 크기(줄인 반 크기) %s: 칸 %s" % [key, grid.get_size()])
		# NavigationGrid._ready가 벽이 있는지 볼 때 하는 질의(맵 전체 크기 사각형)를 한 번 더 해서 시간을 잰다.
		var bounds: Rect2 = nav.get(&"bounds")
		var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		var whole: RectangleShape2D = RectangleShape2D.new()
		whole.size = bounds.size
		params.shape = whole
		params.transform = Transform2D(0.0, bounds.get_center())
		params.collision_mask = nav.get(&"world_mask")
		var t: int = Time.get_ticks_usec()
		var hits: int = current_scene.get_viewport().world_2d.direct_space_state.intersect_shape(params, 1).size()
		print("  벽이 있는지 보는 질의 (맵 전체 사각형, 결과 1개까지): %.1f ms, 맞은 것 %d개" % [(Time.get_ticks_usec() - t) / 1000.0, hits])
	print("")
	print("== 들어간 뒤 프레임 시간 (ms) ==")
	var first: Array[String] = []
	for i: int in mini(10, _frame_times.size()):
		first.append("%.1f" % (_frame_times[i] / 1000.0))
	print("  처음 10프레임: %s" % ", ".join(first))
	var rest: Array[int] = _frame_times.slice(10)
	rest.sort()
	if not rest.is_empty():
		print("  그 뒤 %d프레임: 중앙값 %.1f, 가장 긴 것 %.1f" % [rest.size(), rest[rest.size() / 2] / 1000.0, rest[rest.size() - 1] / 1000.0])
	var over: int = 0
	for value: int in _frame_times:
		if value > 50000:
			over += 1
	print("  50ms 넘은 프레임: %d개" % over)


func _matches_no_physics(node: Node) -> bool:
	var name: String = _script_name(node)
	for pattern: String in _no_physics:
		if pattern == "*" or pattern == name:
			return true
	return false


func _describe(node: Node) -> String:
	var path: String = str(node.get_path()) if node.is_inside_tree() else node.name
	return "%s (%s)" % [path.trim_prefix("/root/"), _script_name(node)]


func _script_name(node: Node) -> String:
	var script: Script = node.get_script()
	if script != null and not script.resource_path.is_empty():
		return script.resource_path.get_file()
	return node.get_class()
