extends ScenarioTest
## 벽 모서리 픽셀 흔들림 검사 (계획서 2단계). 창을 띄운다. run_all.sh에는 넣지 않고, 값을 바꿔 가며 여러 번 실행해 비교한다.
## bash tools/godot.sh --fixed-fps 60 --path . -s tests/view_3d/check_wall_flicker.gd -- --target=proto --mode=static --out=<a.png>
## 움직이는 것을 모두 멈춘 같은 장면을 프레임 간격을 두고 찍어, 앞 장면과 달라진 픽셀을 출력한다.
## --target=proto|layer|terrain   proto: 시제품 층, layer: 같은 굴에 새 층(--depth_step=0이면 카메라 깊이를 격자에 맞추지 않음), terrain: 얕은 굴의 새 지형
## --mode=static|toggle|poses   toggle: 시제품 검사처럼 반투명을 켜고 끄며 찍는다. poses: 시제품 반투명 검사의 자세들을 옮겨 다니며 켬·끔을 비교한다 (둘 다 proto만)
##                          poses는 시야를 끈 채로 잰다 (시제품 검사와 같다). --vision=1이면 시야(그림자)를 켠다
## --shadow=0, --palette=0  시제품의 그림자·팔레트 끄기
## --out=<png>              마지막 장면 저장. 실행끼리는 tools/compare_images.gd로 비교한다

const SETTLE_FRAMES: int = 120
const WAIT_FRAMES: int = 40
const CAPTURES: int = 6
const MAX_LISTED: int = 6
const PROTO_SCENE: String = "res://proto_25d/proto_cave.tscn"
const TERRAIN_SCENE: String = "res://regions/shallow_cave.tscn"
const PROTO_AIM_OFFSET: Vector2 = Vector2(0, 300)
## poses 방식에서 쥐 그림 둘레 이만큼은 먼 곳으로 치지 않는다 (화면 픽셀)
const NEARBY_GROW: int = 64

var _target: String = "proto"
var _mode: String = "static"
var _shadow: bool = true
var _palette: bool = true
var _vision: bool = false
## 0 이상이면 새 층의 카메라 깊이 격자를 이 값으로 바꾼다
var _depth_step: float = -1.0
var _out_path: String = ""


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--target="):
			_target = arg.trim_prefix("--target=")
		elif arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg == "--shadow=0":
			_shadow = false
		elif arg == "--palette=0":
			_palette = false
		elif arg == "--vision=1":
			_vision = true
		elif arg.begins_with("--depth_step="):
			_depth_step = arg.trim_prefix("--depth_step=").to_float()
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")


func get_start_scene() -> String:
	return PROTO_SCENE if _target == "proto" or _target == "layer" else TERRAIN_SCENE


func _on_scene_ready() -> void:
	var necromancer: Necromancer = find_necromancer()
	for node: Node in get_nodes_in_group(&"monsters"):
		(node as CollisionObject2D).disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		node.process_mode = Node.PROCESS_MODE_DISABLED
	if _mode != "poses":
		necromancer.process_mode = Node.PROCESS_MODE_DISABLED
	var proto: Node = null
	if _target == "proto":
		proto = current_scene.get_node("View3D")
		proto.set(&"aim_override", necromancer.get_body_center() + PROTO_AIM_OFFSET)
		proto.set(&"palette_on", _palette)
		proto.call(&"_apply_view_mode")
		(proto.get(&"_light") as OmniLight3D).shadow_enabled = _shadow
	else:
		var old: Node = current_scene.get_node_or_null("View3D")
		if old != null:
			old.free()
		var layer: RegionView3D = current_scene.call(&"add_view_3d")
		layer.aim_lead.strength = 0.0
		if _depth_step >= 0.0:
			layer.depth_step = _depth_step
		proto = layer
		if _mode == "static":
			proto = null
	print("대상 %s, 방식 %s, 그림자 %s, 팔레트 %s" % [_target, _mode, _shadow, _palette])
	await wait_frames(SETTLE_FRAMES)
	if _mode == "poses":
		await _measure_poses(proto, necromancer)
		finish(true)
		return
	var previous: Image = await _capture()
	var total: int = 0
	for i: int in CAPTURES:
		if proto != null and _target == "proto" and _mode == "toggle":
			proto.set(&"see_through_on", i % 2 == 1)
		await wait_frames(WAIT_FRAMES)
		var current: Image = await _capture()
		var changed: Array[Vector2i] = ImageDiff.changed_pixels(previous, current)
		total += changed.size()
		print("장면 %d → %d: 달라진 픽셀 %d개 %s" % [i, i + 1, changed.size(), changed.slice(0, MAX_LISTED)])
		previous = current
	print("결과 요약: 달라진 픽셀 합계 %d개 (%d번 비교)" % [total, CAPTURES])
	if not _out_path.is_empty():
		previous.save_png(_out_path)
	finish(true)


## 시제품 반투명 검사와 같은 자세들에서 반투명 켬·끔 화면을 비교해, 쥐에서 먼 곳의 달라진 픽셀만 센다.
func _measure_poses(proto: Node, necromancer: Necromancer) -> void:
	var rat: Monster = current_scene.get_node("Actors/Rat")
	var vision: Vision = current_scene.call(&"get_vision")
	if vision != null and not _vision:
		vision.set_active(false)
	var tile: float = ViewSpace.TILE
	var half: Vector2 = rat.data.get_placeholder_half_size()
	var poses: Array[Array] = [
		["북쪽 벽", Vector2(6.5 * tile, 2.0 * tile + half.y * 2.0), Vector2(70, 70)],
		["서쪽 벽", Vector2(2.0 * tile + half.x, 8.5 * tile), Vector2(70, 70)],
		["북서 모서리", Vector2(2.0 * tile + half.x, 2.0 * tile + half.y * 2.0), Vector2(70, 70)],
		["기둥 남쪽 면", Vector2(11.5 * tile, 10.0 * tile + half.y * 2.0), Vector2(70, 70)],
		["남쪽 벽에 가림", Vector2(12.5, 14.7) * tile, Vector2(-128, -102)],
		["동쪽 기둥에 가림", Vector2(9.7, 7.5) * tile, Vector2(-100, -70)],
	]
	var total: int = 0
	for pose: Array in poses:
		rat.global_position = pose[1]
		necromancer.global_position = (pose[1] as Vector2) + (pose[2] as Vector2)
		proto.set(&"aim_override", necromancer.get_body_center() + PROTO_AIM_OFFSET)
		_set_see_through(proto, true)
		await wait_frames(WAIT_FRAMES)
		var on_image: Image = await _capture()
		var on_camera: Vector3 = _camera_position(proto)
		var on_lead: Vector2 = proto.call(&"get_lead_offset")
		var on_feet: Vector2 = necromancer.global_position
		_set_see_through(proto, false)
		await wait_frames(WAIT_FRAMES)
		var off_image: Image = await _capture()
		var off_camera: Vector3 = _camera_position(proto)
		var off_lead: Vector2 = proto.call(&"get_lead_offset")
		var off_feet: Vector2 = necromancer.global_position
		var nearby: Rect2i = Rect2i(proto.call(&"get_see_rect", rat) as Rect2).grow(NEARBY_GROW)
		var far: Array[Vector2i] = ImageDiff.changed_pixels(on_image, off_image).filter(func(point: Vector2i) -> bool: return not nearby.has_point(point))
		total += far.size()
		var deltas: PackedStringArray = []
		for point: Vector2i in far.slice(0, MAX_LISTED):
			deltas.append("%s %s→%s" % [point, on_image.get_pixelv(point).to_html(false), off_image.get_pixelv(point).to_html(false)])
		print("%s: 먼 곳 %d개 %s" % [pose[0], far.size(), ", ".join(deltas)])
		print("  카메라 %s, 켬 %s 끔 %s, 차이 %.9f, 앞서 가기 켬 %s 끔 %s, 발밑 %s (차이 %.9f)" % ["같음" if on_camera == off_camera else "다름", _text(on_camera), _text(off_camera), on_camera.distance_to(off_camera), on_lead, off_lead, "같음" if on_feet == off_feet else "다름", on_feet.distance_to(off_feet)])
	print("결과 요약: 먼 곳 합계 %d개" % total)


func _set_see_through(view: Node, value: bool) -> void:
	if view is RegionView3D:
		(view as RegionView3D).get_front_walls().see_through_on = value
	else:
		view.set(&"see_through_on", value)


func _camera_position(view: Node) -> Vector3:
	return (view.call(&"get_camera") as Camera3D).global_position


## 소수 아래 7자리까지 적는다 (Vector3의 기본 글자는 짧게 줄여서 작은 차이가 보이지 않는다)
func _text(point: Vector3) -> String:
	return "(%.7f, %.7f, %.7f)" % [point.x, point.y, point.z]


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
