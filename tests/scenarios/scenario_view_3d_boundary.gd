extends ScenarioTest
## 시나리오: 2D 규칙 세계와 3D 화면 층의 경계.
## 1. 헤드리스에서는 지역 데이터의 view_3d를 켜도 3D 층이 붙지 않고, 조준은 2D 마우스 위치다
## 2. 3D 층을 붙이면 조준과 이동 입력이 층을 거치고, 임시 바닥이 지형 메시가 되며 2D 바닥은 숨고, 몸마다 3D 사각형이 생기고 사라지면 지운다
## 3. 카메라가 네크로맨서를 화면 가운데에 둔다
## 4. 여러 방향의 월드 좌표를 흉내 낸 마우스로 조준하면 같은 자리를 조준한다
## 5. W는 화면 위로 걷는다
## 6. 앞서 가기를 켜면 마우스 쪽으로 카메라가 움직인다
## 창에서 실제로 그린 화면은 이 시나리오가 보증하지 않는다.

const AIM_DISTANCES: Array[float] = [48.0, 120.0]
const AIM_DIRECTIONS: int = 8
const AIM_TOLERANCE: float = 1.0
const CENTER_TOLERANCE: float = 1.0
## 화면 계산(ViewSpace)을 실제 카메라와 비교할 점과 허용 오차 (화면 픽셀. 카메라는 픽셀 격자에 맞춘다)
const SAMPLE_OFFSET: Vector2 = Vector2(64, -48)
const OFFSET_TOLERANCE: float = 1.5
const SETTLE_FRAMES: int = 3
const WALK_FRAMES: int = 20
const LEAD_FRAMES: int = 60
## 걸은 방향과 화면 위 방향이 다를 수 있는 양 (cos)
const SCREEN_UP_MIN_DOT: float = 0.99
## 앞서 가기를 재려고 마우스를 둘, 화면 가운데에서 오른쪽으로 떨어진 거리 (화면 픽셀)
const LEAD_MOUSE_OFFSET: float = 200.0
const YAW_TOLERANCE: float = 0.001


func get_start_scene() -> String:
	return TEST_REGION_SCENE


func _on_scene_ready() -> void:
	_run()


func _run() -> void:
	var necromancer: Necromancer = find_necromancer()
	if not await _check_headless_stays_2d(necromancer):
		return
	var view: RegionView3D = current_scene.call(&"add_view_3d")
	view.aim_lead.strength = 0.0
	await wait_frames(SETTLE_FRAMES)
	if not necromancer.aim_provider.is_valid() or absf(necromancer.input_rotation + deg_to_rad(view.yaw_degrees)) > YAW_TOLERANCE:
		fail_step("연결", "조준 연결 %s, 이동 회전 %.3f" % [necromancer.aim_provider.is_valid(), necromancer.input_rotation])
		return
	pass_step("연결", "조준이 3D 층을 거침, 이동 입력 %.0f도 회전" % rad_to_deg(necromancer.input_rotation))
	var ground: PlaceholderGround = current_scene.get_node("Ground")
	var expected_quads: int = ground.size_in_tiles.x * ground.size_in_tiles.y
	if view.get_terrain_quads() != expected_quads or view.get_terrain_chunks().is_empty() or ground.visible:
		fail_step("지형", "사각형 %d (기대 %d), 구역 %d, 2D 바닥 보임 %s" % [view.get_terrain_quads(), expected_quads, view.get_terrain_chunks().size(), ground.visible])
		return
	pass_step("지형", "바닥 %d칸 = 사각형 %d, 구역 %d개, 2D 바닥은 숨김" % [expected_quads, view.get_terrain_quads(), view.get_terrain_chunks().size()])
	await wait_frames(SETTLE_FRAMES)
	var monsters: int = get_nodes_in_group(&"monsters").size()
	var chests: int = current_scene.find_children("*", "LootChest", true, false).size()
	if view.get_bodies().get_bodies().size() != monsters + chests + 1:
		fail_step("몸", "그리는 몸 %d (기대: 몬스터 %d + 상자 %d + 네크로맨서)" % [view.get_bodies().get_bodies().size(), monsters, chests])
		return
	var victim: Node = get_nodes_in_group(&"monsters")[0]
	victim.free()
	await wait_frames(SETTLE_FRAMES)
	if view.get_bodies().get_bodies().size() != monsters + chests:
		fail_step("몸", "몬스터가 사라졌는데 그리는 몸 %d (기대 %d)" % [view.get_bodies().get_bodies().size(), monsters + chests])
		return
	pass_step("몸", "몬스터 %d + 상자 %d + 네크로맨서를 그림, 사라진 몬스터는 지움" % [monsters, chests])
	var center: Vector2 = root.get_visible_rect().size * 0.5
	var feet_screen: Vector2 = view.world_to_screen(necromancer.global_position, 0.0)
	if feet_screen.distance_to(center) > CENTER_TOLERANCE:
		fail_step("카메라", "발밑 화면 위치 %s, 화면 가운데 %s" % [feet_screen, center])
		return
	pass_step("카메라", "발밑 화면 위치 %s = 화면 가운데" % feet_screen)
	var sample: Vector2 = necromancer.global_position + SAMPLE_OFFSET
	var measured: Vector2 = view.world_to_screen(sample, 0.0) - center
	# 카메라 거리는 내부 해상도 세로로 정해지고, 헤드리스 창은 세로가 달라 화면에서 그만큼 커진다.
	var design_height: float = ProjectSettings.get_setting("display/window/size/viewport_height")
	var calculated: Vector2 = ViewSpace.screen_offset(necromancer.global_position, sample, 0.0, view.pitch_degrees, view.yaw_degrees, view.fov_degrees, design_height) * (root.get_visible_rect().size.y / design_height)
	if measured.distance_to(calculated) > OFFSET_TOLERANCE:
		fail_step("화면 계산", "카메라 %s, 계산 %s" % [measured, calculated])
		return
	pass_step("화면 계산", "카메라 %s = 계산 %s" % [measured, calculated])
	if not await _check_aim_round_trip(necromancer):
		return
	if not await _check_screen_up(necromancer, view):
		return
	await _check_lead(view, center)
	finish(true)


func _check_headless_stays_2d(necromancer: Necromancer) -> bool:
	var data: RegionData = (current_scene.get(&"data") as RegionData).duplicate()
	data.view_3d = true
	current_scene.set(&"data", data)
	if current_scene.call(&"wants_view_3d") or current_scene.call(&"get_view_3d") != null or necromancer.aim_provider.is_valid():
		fail_step("헤드리스", "3D 층을 붙이려 함 또는 이미 붙어 있음")
		return false
	var aim: Vector2 = necromancer.get_body_center() + Vector2(100, 0)
	aim_mouse_at(aim)
	await wait_frames(SETTLE_FRAMES)
	var distance: float = necromancer.get_aim_position().distance_to(aim)
	if distance > AIM_TOLERANCE:
		fail_step("헤드리스", "2D 조준 오차 %.2f" % distance)
		return false
	pass_step("헤드리스", "view_3d를 켜도 3D 층 없음, 2D 조준 오차 %.2f" % distance)
	return true


func _check_aim_round_trip(necromancer: Necromancer) -> bool:
	var worst: float = 0.0
	for distance: float in AIM_DISTANCES:
		for i: int in AIM_DIRECTIONS:
			var aim: Vector2 = necromancer.get_body_center() + Vector2.from_angle(i * TAU / AIM_DIRECTIONS) * distance
			aim_mouse_at(aim)
			await wait_frames(SETTLE_FRAMES)
			worst = maxf(worst, necromancer.get_aim_position().distance_to(aim))
	if worst > AIM_TOLERANCE:
		fail_step("조준", "가장 큰 오차 %.2fpx (허용 %.2f)" % [worst, AIM_TOLERANCE])
		return false
	pass_step("조준", "%d자리에서 가장 큰 오차 %.3fpx" % [AIM_DISTANCES.size() * AIM_DIRECTIONS, worst])
	return true


func _check_screen_up(necromancer: Necromancer, view: RegionView3D) -> bool:
	var start: Vector2 = necromancer.global_position
	press_moves(Vector2.UP)
	await wait_frames(WALK_FRAMES)
	press_moves(Vector2.ZERO)
	var moved: Vector2 = necromancer.global_position - start
	if moved == Vector2.ZERO:
		fail_step("화면 위로 걷기", "움직이지 않음")
		return false
	var walked: Vector3 = ViewSpace.to_3d(moved, 0.0).normalized()
	var camera_up: Vector3 = view.get_camera().global_transform.basis.y
	var screen_up: Vector3 = Vector3(camera_up.x, 0.0, camera_up.z).normalized()
	var dot: float = walked.dot(screen_up)
	if dot < SCREEN_UP_MIN_DOT:
		fail_step("화면 위로 걷기", "이동 %s, 화면 위와의 내적 %.3f" % [moved, dot])
		return false
	pass_step("화면 위로 걷기", "W로 %s 이동, 화면 위와의 내적 %.3f" % [moved, dot])
	return true


func _check_lead(view: RegionView3D, center: Vector2) -> void:
	view.aim_lead.strength = 1.0
	move_mouse_to_ui(center + Vector2(LEAD_MOUSE_OFFSET, 0))
	await wait_frames(LEAD_FRAMES)
	var feet_screen: Vector2 = view.world_to_screen(find_necromancer().global_position, 0.0)
	if feet_screen.x >= center.x:
		fail_step("앞서 가기", "발밑 화면 x %.1f, 가운데 %.1f" % [feet_screen.x, center.x])
		return
	pass_step("앞서 가기", "마우스를 오른쪽에 두니 발밑이 화면 왼쪽으로 %.1fpx 밀림" % (center.x - feet_screen.x))
