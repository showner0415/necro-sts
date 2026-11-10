extends View3DCheck
## 바닥 표시·탄·돌·도넛·상자·키 안내 검사 (3D 층). 창을 띄운다. run_all.sh에는 넣지 않는다.
## bash tools/godot.sh --fixed-fps 60 --path . -s tests/view_3d/check_marks_3d.gd -- --scene=res://regions/test_region.tscn
## 씬에 있는 것만 본다 (거점: 출구·창고 상자, 시험 지역: 탈출 지점·지역 상자·전투 표시).
## 화면 좌표를 계산해 그 자리의 색이 2D 색과 같은지 본다. 표시가 몇 픽셀 안에서 어긋나는 것은 허용한다 (SEARCH).

const DEFAULT_SCENE: String = "res://regions/test_region.tscn"
const SETTLE_FRAMES: int = 10
## 색을 찾는 범위 (화면 픽셀, 사방)
const SEARCH: int = 1
const BOAR_DATA: String = "res://data/monsters/boar.tres"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const STONE_SCENE: String = "res://monsters/stone.tscn"
const BOLT_SCENE: String = "res://necromancer/bolt.tscn"
const BOAR_OFFSET: Vector2 = Vector2(-120, 70)
const LINE_SAMPLES: Array[float] = [24.0, 40.0, 56.0]
const STONE_OFFSET: Vector2 = Vector2(90, -60)
const STONE_RANGE: float = 100.0
const STONE_ARC: float = 24.0
const STONE_THROW_HEIGHT: float = 6.0
const STONE_LANDING: float = 12.0
const RING_SAMPLES: int = 8
const BOLT_OFFSET: Vector2 = Vector2(-60, -70)
const BOLT_RADIUS: float = 3.0
## 도넛에서 볼 채운 쪽 각도: 12시에서 시계 방향으로 조금 간 자리
const RING_SAMPLE_ANGLE: float = -PI / 2.0 + 0.3
const PROMPT_DISTANCE: float = 80.0

var _view: RegionView3D
var _necromancer: Necromancer


func get_start_scene() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			return arg.trim_prefix("--scene=")
	return DEFAULT_SCENE


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	disable_vision()
	_view = open_layer()
	# 실제 마우스 위치에 따라 카메라가 앞서 가면 계산한 화면 위치와 찍은 화면이 어긋난다.
	_view.aim_override = _necromancer.get_body_center()
	await wait_frames(SETTLE_FRAMES)
	# 시험 지역에는 전투 표시를 놓는다.
	if current_scene.scene_file_path == DEFAULT_SCENE:
		await _check_combat_marks()
	await _check_ring()
	await _check_floor_marks()
	await _check_chests_and_prompts()
	finish(true)


## 이 자리 둘레에 expected 색이 있는지
func _has_color(image: Image, at: Vector2, expected: Color) -> bool:
	var center: Vector2i = Vector2i(at)
	for y: int in range(-SEARCH, SEARCH + 1):
		for x: int in range(-SEARCH, SEARCH + 1):
			var point: Vector2i = center + Vector2i(x, y)
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(point) and colors_close(image.get_pixelv(point), expected):
				return true
	return false


func _expect(image: Image, label: String, at: Vector2, expected: Color) -> bool:
	if _has_color(image, at, expected):
		return true
	fail_step(label, "자리 %s에 %s 없음 (화면 %s)" % [at, expected.to_html(false), image.get_pixelv(Vector2i(at)).to_html(false)])
	return false


func _check_combat_marks() -> void:
	var feet: Vector2 = _necromancer.global_position
	var parent: Node = _necromancer.get_parent()
	var boar: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	boar.data = load(BOAR_DATA)
	freeze_monster(boar)
	parent.add_child(boar)
	boar.global_position = feet + BOAR_OFFSET
	var charge: ChargeBehavior = boar._behavior as ChargeBehavior
	charge._state = ChargeBehavior.State.WINDUP
	charge._direction = Vector2.RIGHT
	var stone: Stone = (load(STONE_SCENE) as PackedScene).instantiate()
	stone.process_mode = Node.PROCESS_MODE_DISABLED
	stone.direction = Vector2.RIGHT
	stone.max_distance = STONE_RANGE
	stone.arc_height = STONE_ARC
	stone.ground_offset = STONE_THROW_HEIGHT
	stone.landing_radius = STONE_LANDING
	stone.shadow_color = boar.indicator_color
	parent.add_child(stone)
	stone.global_position = feet + STONE_OFFSET
	stone.show_landing()
	stone._traveled = STONE_RANGE * 0.5
	var bolt: Bolt = (load(BOLT_SCENE) as PackedScene).instantiate()
	bolt.process_mode = Node.PROCESS_MODE_DISABLED
	bolt.visual_radius = BOLT_RADIUS
	bolt.hit_radius = BOLT_RADIUS
	parent.add_child(bolt)
	bolt.global_position = feet + BOLT_OFFSET
	await wait_frames(SETTLE_FRAMES)
	var image: Image = await capture()
	for distance: float in LINE_SAMPLES:
		if not _expect(image, "돌진 선", _view.world_to_screen(boar.global_position + Vector2.RIGHT * distance, 0.0), boar.indicator_color):
			return
	pass_step("돌진 선", "%d자리가 예고 색 %s" % [LINE_SAMPLES.size(), boar.indicator_color.to_html(false)])
	var ground: Vector2 = stone.global_position + Vector2(0, STONE_THROW_HEIGHT)
	var peak_height: float = stone.get_view_height()
	if peak_height != STONE_THROW_HEIGHT + STONE_ARC:
		fail_step("돌 높이", "가운데 지점 높이 %.1f (기대 %.1f)" % [peak_height, STONE_THROW_HEIGHT + STONE_ARC])
		return
	if not _expect(image, "돌", _view.world_to_screen(ground, peak_height), stone.placeholder_color):
		return
	pass_step("돌", "포물선 꼭대기 높이 %.0f에 돌 색" % peak_height)
	# 그림자는 show_landing을 부른 자리(돌을 놓은 자리)에서 사거리만큼 앞이다.
	var landing: Vector2 = ground + Vector2.RIGHT * STONE_RANGE
	for i: int in RING_SAMPLES:
		var point: Vector2 = landing + Vector2.from_angle(i * TAU / RING_SAMPLES) * STONE_LANDING
		if not _expect(image, "돌 그림자", _view.world_to_screen(point, 0.0), boar.indicator_color):
			return
	pass_step("돌 그림자", "떨어질 자리 원 위 %d자리가 표시 색" % RING_SAMPLES)
	if not _expect(image, "탄", _view.screen_from_aim(bolt.global_position), bolt.placeholder_color):
		return
	pass_step("탄", "조준 높이에 탄 색")
	boar.free()
	stone.free()
	bolt.free()
	await wait_frames(SETTLE_FRAMES)


func _check_ring() -> void:
	var ring: StaminaRing = _ring()
	_necromancer.stamina.try_roll()
	await wait_frames(2)
	if not ring.visible:
		fail_step("도넛", "스태미나를 썼는데 숨어 있음")
		return
	var image: Image = await capture()
	var center: Vector2 = ring.global_position
	var expected_center: Vector2 = _view.world_to_screen(_necromancer.global_position, 0.0).round() + Vector2(13, -6)
	if center.distance_to(expected_center) > 0.5:
		fail_step("도넛", "자리 %s, 기대 %s" % [center, expected_center])
		return
	if not _expect(image, "도넛", center + Vector2.from_angle(RING_SAMPLE_ANGLE) * ring.radius, ring.fill_color):
		return
	pass_step("도넛", "네크로맨서 오른쪽 %s에 채움 색" % center)


func _ring() -> StaminaRing:
	return _view.find_children("StaminaRing", "", true, false)[0] as StaminaRing


func _check_floor_marks() -> void:
	var image: Image = await capture()
	for node: Node in current_scene.find_children("*", "EscapePoint", true, false) + current_scene.find_children("*", "RegionExit", true, false):
		var point: Node2D = node as Node2D
		if node.is_queued_for_deletion():
			continue
		var at: Vector2 = _view.world_to_screen(point.global_position, 0.0)
		if not Rect2(Vector2.ZERO, Vector2(image.get_size())).has_point(at):
			continue
		var radius: float = node.get(&"radius")
		if not _expect(image, String(node.name), at, node.get(&"fill_color")):
			return
		var ring_at: Vector2 = _view.world_to_screen(point.global_position + Vector2.RIGHT * (radius - 0.5), 0.0)
		if not _expect(image, String(node.name), ring_at, node.get(&"ring_color")):
			return
		pass_step(String(node.name), "바닥에 원과 테두리")


func _check_chests_and_prompts() -> void:
	for node: Node in current_scene.find_children("*", "LootChest", true, false) + current_scene.find_children("*", "StorageChest", true, false):
		var chest: InteractZone = node as InteractZone
		_necromancer.global_position = chest.global_position + Vector2(0, 10)
		await wait_frames(SETTLE_FRAMES)
		var image: Image = await capture()
		var rect: Rect2 = _view.get_see_rect(chest)
		var box: Color = node.get(&"box_color")
		var lid: Color = node.get(&"lid_color")
		if not _expect(image, String(node.name), rect.get_center() + Vector2(0, 3), box) or not _expect(image, String(node.name), rect.position + Vector2(rect.size.x * 0.5, 1), lid):
			return
		var prompt: Label = _prompt_of(chest)
		if prompt == null or not prompt.visible:
			fail_step("키 안내", "%s 곁에서 안내가 보이지 않음" % node.name)
			return
		var distance: float = prompt.get_global_rect().get_center().distance_to(rect.get_center())
		if distance > PROMPT_DISTANCE:
			fail_step("키 안내", "%s 안내가 상자에서 %.0f 떨어짐" % [node.name, distance])
			return
		pass_step(String(node.name), "상자 몸통·뚜껑 색, 안내 \"%s\" (상자에서 %.0f)" % [prompt.text.replace("\n", " "), distance])


func _prompt_of(chest: InteractZone) -> Label:
	for label: Node in _view.find_children("*", "Label", true, false):
		if chest.get(&"_prompt") == label:
			return label as Label
	return null
