extends SceneTree
## 시야(빛·벽 그림자)가 늘리는 프레임 시간을 잰다. 창을 띄워 실제로 그린다 (--headless 금지).
## 시야를 켠 구간과 끈 구간을 번갈아(phase_frames씩) 돌리며, 그동안 바라보는 방향을 한 바퀴씩 돌리고 네크로맨서를 좌우로 걷게 한다.
## 구간마다 CPU 처리(_process 전체), 그리기 CPU, 그리기 GPU 시간의 평균과, 프레임 하나에 실제로 걸린 시간의 중앙값을 낸다.
## 기준은 프레임 시간 중앙값의 차이다 (평균은 다른 프로그램 때문에 크게 흔들린다). 수직 동기화는 끈다.
## bash tools/godot.sh --path . -s tools/measure_vision_frame.gd -- --scene=res://regions/shallow_cave.tscn [--phases=6] [--phase_frames=120]
## 원인 나누기: --no_shadow (빛 그림자 끔), --no_occluders (벽 그림자 모양을 지움), --no_light (빛을 끄고 스크립트만)
## 언데드 시야 예상: --extra_lights=N --extra_radius=200 (그림자 있는 빛 N개를 네크로맨서 둘레 48px에 두고 같이 돌린다. 시야를 켠 구간에만 켬)
## 실제 언데드: --undead=N (쥐 언데드 N마리를 핫바·마나 없이 바로 세워 네크로맨서를 따라오게 한다. 언데드 시야 빛은 Vision이 단다)

var _scene_path: String = "res://regions/shallow_cave.tscn"
var _phases: int = 6
var _phase_frames: int = 120
## 처음에 버리는 프레임 (불러오기 직후 흔들림)
var _warmup: int = 60
var _frame: int = 0
var _vision: Vision
var _necromancer: Necromancer
var _start: Vector2
var _sums: Dictionary = {true: [0.0, 0.0, 0.0, 0], false: [0.0, 0.0, 0.0, 0]}
var _vp: RID
var _variant: Array[String] = []
var _extra_count: int = 0
var _extra_radius: float = 200.0
var _extras: Array[PointLight2D] = []
var _undead_count: int = 0
## --shot=<경로>: 시야를 켠 첫 구간 가운데쯤 한 프레임을 저장한다 (빛이 실제로 그려지는지 확인용)
var _shot: String = ""
## --at=x,y: 네크로맨서를 이 자리(픽셀)로 옮겨 잰다 (벽이 촘촘한 곳에서 재려고)
var _at: Vector2 = Vector2.INF
var _vision_usec: int = 0
## 프레임마다 실제로 걸린 시간 (이전 프레임 시작에서 이번 프레임 시작까지, ms)
var _frame_times: Dictionary = {true: [], false: []}
var _last_usec: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--phases="):
			_phases = arg.trim_prefix("--phases=").to_int()
		elif arg.begins_with("--phase_frames="):
			_phase_frames = arg.trim_prefix("--phase_frames=").to_int()
		elif arg.begins_with("--undead="):
			_undead_count = arg.trim_prefix("--undead=").to_int()
		elif arg.begins_with("--extra_lights="):
			_extra_count = arg.trim_prefix("--extra_lights=").to_int()
		elif arg.begins_with("--at="):
			var xy: PackedStringArray = arg.trim_prefix("--at=").split(",")
			_at = Vector2(xy[0].to_float(), xy[1].to_float())
		elif arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--extra_radius="):
			_extra_radius = arg.trim_prefix("--extra_radius=").to_float()
		elif arg in ["--no_shadow", "--no_occluders", "--no_light"]:
			_variant.append(arg)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	change_scene_to_file(_scene_path)


func _process(_delta: float) -> bool:
	if current_scene == null:
		return false
	if _vision == null:
		_vision = current_scene.call(&"get_vision")
		_necromancer = get_first_node_in_group(&"necromancer")
		if _vision == null:
			printerr("이 씬에는 시야가 없습니다: %s" % _scene_path)
			quit(1)
			return false
		if _at != Vector2.INF:
			_necromancer.global_position = _at
			for node: Node in get_nodes_in_group(&"monsters"):
				node.queue_free()
		_start = _necromancer.global_position
		for i: int in _undead_count:
			var undead: Undead = (load("res://undead/undead.tscn") as PackedScene).instantiate()
			undead.setup(Skull.create(load("res://data/skulls/rat_skull.tres")), load("res://data/monsters/rat.tres"), _necromancer)
			undead.follow_speed = _necromancer.move_speed
			undead.catch_up_speed = _necromancer.run_speed
			_necromancer.get_parent().add_child(undead)
			undead.global_position = _start + Vector2.from_angle(TAU * i / _undead_count) * 40.0
		var size: Vector2i = (current_scene.get_node("Walls") as PlaceholderWalls).grid_size()
		var light: PointLight2D = _vision.find_children("*", "PointLight2D", false, false)[0]
		if _variant.has("--no_shadow"):
			light.shadow_enabled = false
		if _variant.has("--no_occluders"):
			current_scene.get_node("Walls/LightOccluders").free()
		if _variant.has("--no_light"):
			light.visible = false
		for i: int in _extra_count:
			var extra: PointLight2D = PointLight2D.new()
			var gradient: GradientTexture2D = GradientTexture2D.new()
			gradient.fill = GradientTexture2D.FILL_RADIAL
			gradient.fill_from = Vector2(0.5, 0.5)
			gradient.fill_to = Vector2(1.0, 0.5)
			gradient.width = 256
			gradient.gradient = Gradient.new()
			gradient.gradient.set_color(0, Color.WHITE)
			gradient.gradient.set_color(1, Color(1, 1, 1, 0))
			gradient.height = 256
			extra.texture = gradient
			extra.texture_scale = _extra_radius * 2.0 / 256.0
			extra.energy = light.energy * 0.6
			extra.range_item_cull_mask = light.range_item_cull_mask
			extra.shadow_enabled = true
			extra.shadow_item_cull_mask = light.shadow_item_cull_mask
			current_scene.add_child(extra)
			_extras.append(extra)
		print("시험: %s%s%s" % [", ".join(_variant) if not _variant.is_empty() else "그대로", " + 빛 %d개 (반지름 %.0f)" % [_extra_count, _extra_radius] if _extra_count > 0 else "", " + 언데드 %d마리" % _undead_count if _undead_count > 0 else ""])
		print("맵 %d×%d칸, 그림자 모양: 합치기 전 %d칸 → 합친 뒤 %d개, 시야 준비 %.1fms" % [size.x, size.y, _vision.occluder_counts.x, _vision.occluder_counts.y, _vision.setup_usec / 1000.0])
	_frame += 1
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = (now - _last_usec) / 1000.0
	_last_usec = now
	var t: int = _frame - _warmup
	if t < 0:
		return false
	var phase: int = t / _phase_frames
	if phase >= _phases * 2:
		_report()
		quit(0)
		return false
	var on: bool = phase % 2 == 0
	if _vision.active != on:
		_vision.set_active(on)
		if on and _variant.has("--no_light"):
			(_vision.find_children("*", "PointLight2D", false, false)[0] as PointLight2D).enabled = false
	# 한 구간에 한 바퀴 돌고, 좌우로 2칸씩 오간다 (시야를 켜든 끄든 같은 움직임).
	var k: float = float(t % _phase_frames) / _phase_frames
	_vision.facing_override = Vector2.from_angle(k * TAU)
	_necromancer.global_position = _start + Vector2(sin(k * TAU) * 64.0, 0.0)
	for i: int in _extras.size():
		var extra: PointLight2D = _extras[i]
		extra.enabled = on
		extra.global_position = _necromancer.global_position + Vector2.from_angle(TAU * i / _extras.size() + k * TAU) * 48.0
	if not _shot.is_empty() and t == _phase_frames / 3:
		RenderingServer.frame_post_draw.connect(func() -> void: root.get_texture().get_image().save_png(_shot), CONNECT_ONE_SHOT)
	if t % _phase_frames >= 10:
		var sum: Array = _sums[on]
		sum[0] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		sum[1] += RenderingServer.viewport_get_measured_render_time_cpu(_vp) + RenderingServer.get_frame_setup_time_cpu()
		sum[2] += RenderingServer.viewport_get_measured_render_time_gpu(_vp)
		sum[3] += 1
		# 이번 프레임 시간은 지난 프레임(같은 구간)의 것이다
		(_frame_times[on] as Array).append(frame_ms)
		if on:
			_vision_usec += _vision.last_update_usec
	return false


func _report() -> void:
	var labels: Array[String] = ["CPU 처리", "그리기 CPU", "그리기 GPU"]
	var off: Array = _sums[false]
	var on: Array = _sums[true]
	for i: int in 3:
		var a: float = on[i] / on[3]
		var b: float = off[i] / off[3]
		print("%s: 시야 켬 %.3fms / 끔 %.3fms / 늘어남 %+.3fms" % [labels[i], a, b, a - b])
	var total: float = (on[0] + on[1] + on[2]) / on[3] - (off[0] + off[1] + off[2]) / off[3]
	var med: Array[float] = []
	for state: bool in [true, false]:
		var times: Array = _frame_times[state]
		times.sort()
		med.append(times[times.size() / 2])
	print("프레임 시간 중앙값: 시야 켬 %.3fms / 끔 %.3fms / 늘어남 %+.3fms" % [med[0], med[1], med[0] - med[1]])
	print("시야 스크립트(_process) 평균 %.3fms" % [_vision_usec / 1000.0 / on[3]])
	print("합계 늘어남: %+.3fms (프레임 %d / %d)" % [total, on[3], off[3]])
