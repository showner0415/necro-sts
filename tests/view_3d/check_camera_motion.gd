extends View3DCheck
## 에임을 밖에 둔 채 걸을 때 카메라와 몸이 일렁거리는지 잰다. 창을 띄운다. run_all.sh에는 넣지 않는다.
## bash tools/godot.sh --fixed-fps 60 --path . -s tests/view_3d/check_camera_motion.gd
## 네크로맨서를 8방향으로 걷게 하면서 프레임마다 잰다 (앞서 가기가 자리 잡은 뒤부터):
## - 몸의 화면 위치: 걷는 동안 움직이면 안 된다 (마우스가 고정이면 카메라도 몸과 함께 간다)
## - 바닥 한 점의 화면 이동: 걷는 방향과 반대로 되돌아간 프레임 수
## - 시야 방향: 프레임 사이에 바뀐 가장 큰 각도 (마우스를 안 움직여도 흔들리면 시야 가장자리가 일렁인다)

const SCENE: String = "res://regions/test_region.tscn"
const SETTLE_FRAMES: int = 90
const WALK_FRAMES: int = 90
const DIRECTIONS: int = 8
## 화면 가운데에서 마우스까지 (화면 픽셀). 앞서 가기가 최대 거리에 닿도록 멀리 둔다
const MOUSE_OFFSETS: Array[Vector2] = [Vector2.ZERO, Vector2(200, -70), Vector2(-150, 100)]
## 원근이라 화면 옆쪽에서는 몸이 드물게 1픽셀 움직일 수 있다. 자주 흔들리면 실패다
const PASS_BODY_RANGE: float = 1.0
const PASS_BODY_MOVES: int = 5
const PASS_REVERSALS: int = 0
## 눈에 보이는 바닥 움직임으로 치는 크기 (화면 픽셀)
const VISIBLE_STEP: float = 0.5

var _view: RegionView3D
var _necromancer: Necromancer


func get_start_scene() -> String:
	return SCENE


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	disable_vision()
	_view = open_layer()
	var center: Vector2 = root.get_visible_rect().size * 0.5
	var ok: bool = true
	for offset: Vector2 in MOUSE_OFFSETS:
		_view.mouse_override = center + offset
		var worst: Vector3 = Vector3.ZERO
		var worst_fan: float = 0.0
		for i: int in DIRECTIONS:
			var result: Array = await _walk(Vector2.from_angle(i * TAU / DIRECTIONS))
			var line: Vector3 = result[0]
			worst = Vector3(maxf(worst.x, line.x), maxf(worst.y, line.y), maxf(worst.z, line.z))
			worst_fan = maxf(worst_fan, result[1])
		print("[측정] 마우스 화면 가운데에서 %s: 앞서 간 양 %s, 몸의 화면 위치 범위 %.2fpx, 몸이 움직인 프레임 %d, 바닥이 되돌아간 프레임 %d, 시야 방향 변화 최대 %.2f도" % [offset, _view.get_lead_offset().round(), worst.x, int(worst.y), int(worst.z), worst_fan])
		if worst.x > PASS_BODY_RANGE or int(worst.y) > PASS_BODY_MOVES or int(worst.z) > PASS_REVERSALS:
			ok = false
	if ok:
		pass_step("걷는 동안 화면", "몸이 화면에서 움직이지 않고 바닥이 되돌아가지 않음")
	else:
		print("[실패] 걷는 동안 화면: 몸이 화면에서 움직이거나 바닥이 되돌아감")
	finish(ok)


## 한 방향으로 걸으며 잰다: [(몸 화면 범위, 몸이 움직인 프레임, 바닥이 되돌아간 프레임), 시야 방향 변화 최대]
func _walk(direction: Vector2) -> Array:
	press_moves(direction)
	await wait_frames(SETTLE_FRAMES)
	var quad: MeshInstance3D = _view.get_bodies().get_quad(_necromancer)
	var camera: Camera3D = _view.get_camera()
	var body_min: Vector2 = Vector2.INF
	var body_max: Vector2 = -Vector2.INF
	var previous_body: Vector2 = Vector2.INF
	var body_moves: int = 0
	var reversals: int = 0
	var anchor: Vector3 = quad.global_position
	var previous_floor: Vector2 = Vector2.INF
	var previous_fan: Vector2 = Vector2.ZERO
	var fan_change: float = 0.0
	var steps: Array[Vector2] = []
	for frame: int in WALK_FRAMES:
		await RenderingServer.frame_post_draw
		var body: Vector2 = camera.unproject_position(quad.global_position).round()
		body_min = body_min.min(body)
		body_max = body_max.max(body)
		if previous_body != Vector2.INF and body != previous_body:
			body_moves += 1
		previous_body = body
		var floor_point: Vector2 = camera.unproject_position(anchor)
		if previous_floor != Vector2.INF:
			steps.append(floor_point - previous_floor)
		previous_floor = floor_point
		var fan: Vector2 = (_view.get_aim_position() - _necromancer.get_body_center()).normalized()
		if previous_fan != Vector2.ZERO:
			fan_change = maxf(fan_change, absf(rad_to_deg(previous_fan.angle_to(fan))))
		previous_fan = fan
	# 바닥이 흘러간 전체 방향과 반대로 움직인 프레임을 센다.
	var flow: Vector2 = Vector2.ZERO
	for step: Vector2 in steps:
		flow += step
	for step: Vector2 in steps:
		# 카메라 깊이가 격자로 바뀔 때의 0.1픽셀 수준 움직임은 눈에 보이지 않으므로 세지 않는다.
		if step.length() >= VISIBLE_STEP and step.dot(flow) < 0.0:
			reversals += 1
	press_moves(Vector2.ZERO)
	await wait_frames(SETTLE_FRAMES / 3)
	return [Vector3((body_max - body_min).length(), body_moves, reversals), fan_change]
