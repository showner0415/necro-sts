class_name RegionView3D
extends Node3D
## 2D 규칙 세계를 읽어서 3D로 그리는 층. 규칙(이동, 충돌, 시야 판정)은 2D 그대로이고, 이 층은 규칙에 조준 위치와 이동 입력의 회전만 돌려준다.
## 지역 데이터의 view_3d가 켜진 지역에 Region이 붙인다. 헤드리스(테스트·측정)에서는 붙이지 않는다.
## 2D 세계는 숨겨 둔다.
## - 팔레트: PalettePass가 3D 화면의 색을 팔레트로 맞춘다
## - 시야: SightLights가 플레이어·언데드 빛으로 지형을 밝힌다. 무엇이 보이는지는 2D 판정(Vision)이 정한다
## - 바닥 표시: GroundMarks가 2D 그리기 코드를 캔버스에 그려 바닥에 입힌다
## - 도넛·키 안내: ScreenAnchors가 화면 픽셀 그대로 몸 곁에 놓는다
## - 지형: 임시 벽·바닥과 같은 칸과 색으로 구역별 메시를 만든다 (TerrainCells, TerrainMesher). 그림자는 같은 메시를 그림자 전용으로 한 번 더 쓴다 (앞벽을 잘라도 그림자는 그대로)
## - 몸: BodyLayer가 2D 노드를 읽어 카메라를 정면으로 보는 사각형으로 그린다
## - 앞벽: FrontWalls가 플레이어·조준점 앞은 잘라내고, 보이는 몸 앞은 반투명하게 한다
## - 조준: 화면 광선과 탄 높이 평면의 교점을 2D 위치로 바꾼다
## - 화면 회전: 카메라만 돌린다. 규칙 좌표는 그대로이고, 이동 입력과 8방향 그림만 화면 기준으로 돌린다 (W = 화면 위)
## - 앞서 가기: 카메라가 마우스의 화면 위치 쪽으로 움직여 보는 쪽을 더 넓게 보여 준다 (AimLead)

const TERRAIN_SHADER: String = "res://view_3d/terrain.gdshader"
const STAMINA_RING_PATH: String = "StaminaRing"

## 카메라가 아래로 기운 각도 (도)
@export var pitch_degrees: float = 60.0
## 화면이 맵 기준으로 돌아간 각도 (도)
@export var yaw_degrees: float = 45.0
## 화각 (도)
@export var fov_degrees: float = 30.0
@export var camera_near: float = 0.1
@export var camera_far: float = 200.0
## 카메라 깊이를 맞출 격자 (단위, 0이면 맞추지 않음). 몸 위치의 아주 작은 흔들림이 벽 경계 픽셀을 뒤집지 않게 한다
@export var depth_step: float = 1.0 / 256.0
## 벽 높이 (픽셀)
@export var wall_height_px: float = 128.0
## 앞벽을 잘라낸 자리에 보이는 낮은 윗면 높이 (픽셀). 지형 셰이더의 cut_keep_height(0.2칸 = 6.4픽셀)보다 조금 낮다
@export var cut_cap_height_px: float = 6.08
## 지형 구역 한 변의 칸 수
@export var chunk_cells: int = 16

## 카메라 앞서 가기 값 (나중에 설정에서 strength를 0까지 줄인다)
var aim_lead: AimLead = AimLead.new()
## 확인용: 값이 있으면 마우스 대신 이 월드 좌표를 조준한다 (스크린샷·검사)
var aim_override: Vector2 = Vector2.INF
## 확인용: 값이 있으면 실제 마우스 대신 이 화면 위치를 쓴다 (앞서 가기·조준)
var mouse_override: Vector2 = Vector2.INF

var _necromancer: Necromancer
var _vision: Vision
var _sight_lights: SightLights
var _palette: PalettePass
var _camera: Camera3D
## 카메라 방향. 프레임마다 노드에서 다시 읽으면 값이 마지막 비트만큼 흔들려서, 회전을 바꿀 때 한 번만 읽는다
var _camera_basis: Basis = Basis.IDENTITY
var _bodies: BodyLayer
var _marks: GroundMarks
var _anchors: ScreenAnchors
var _front_walls: FrontWalls
## 카메라가 지금 앞서 간 양 (화면 픽셀)
var _lead_offset: Vector2 = Vector2.ZERO
## 지형 구역 메시 노드들
var _terrain_chunks: Array[MeshInstance3D] = []
var _terrain_quads: int = 0
var _terrain_build_usec: int = 0
## 그중 칸을 읽고 메시를 만들 때까지 걸린 시간
var _terrain_mesh_usec: int = 0


## add_child 전에 부른다. vision은 시야가 없는 지역이면 null이다.
func setup(necromancer: Necromancer, vision: Vision) -> void:
	_necromancer = necromancer
	_vision = vision


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.fov = fov_degrees
	_camera.near = camera_near
	_camera.far = camera_far
	_camera.current = true
	add_child(_camera)
	_necromancer.aim_provider = get_aim_position
	set_yaw(yaw_degrees)
	_update_camera(0.0)
	var terrain_material: ShaderMaterial = _build_terrain()
	_bodies = BodyLayer.new()
	_bodies.setup(self)
	add_child(_bodies)
	_marks = GroundMarks.new()
	add_child(_marks)
	_anchors = ScreenAnchors.new()
	_anchors.setup(self)
	add_child(_anchors)
	_anchors.adopt(_necromancer.get_node(STAMINA_RING_PATH), _necromancer)
	_front_walls = FrontWalls.new()
	_front_walls.setup(self, _bodies, _necromancer, terrain_material)
	add_child(_front_walls)
	_sight_lights = SightLights.new()
	_sight_lights.setup(_vision, _necromancer, [terrain_material, _marks.get_material()] as Array[ShaderMaterial])
	add_child(_sight_lights)
	_palette = PalettePass.new()
	add_child(_palette)
	_hide_2d_world()


func _process(delta: float) -> void:
	if not is_instance_valid(_necromancer):
		return
	_update_camera(delta)
	var nodes: Array[Node2D] = _world_nodes()
	_bodies.sync_bodies(nodes, delta)
	_marks.sync_marks(nodes, aim_from_screen(get_viewport().get_visible_rect().size * 0.5))
	_anchors.sync_anchors(nodes)
	_front_walls.update_walls(delta, nodes)
	_sight_lights.update_sights()


## 카메라 기울기를 바꾼다 (검사에서 값을 비교할 때 쓴다).
func set_pitch(degrees: float) -> void:
	pitch_degrees = degrees
	set_yaw(yaw_degrees)


## 화면 회전을 바꾼다. 이동 입력도 같이 돌아간다 (8방향 그림은 BodyLayer가 프레임마다 맞춘다).
func set_yaw(degrees: float) -> void:
	yaw_degrees = degrees
	_camera.rotation_degrees = Vector3(-pitch_degrees, yaw_degrees, 0)
	_camera_basis = _camera.basis
	_necromancer.input_rotation = -deg_to_rad(yaw_degrees)


## 지금 조준하는 월드(2D) 좌표
func get_aim_position() -> Vector2:
	return aim_override if aim_override != Vector2.INF else aim_from_screen(_mouse())


## 화면(내부 해상도)의 점을 누르면 조준되는 월드(2D) 좌표
func aim_from_screen(screen: Vector2) -> Vector2:
	return ViewSpace.aim_from_ray(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen), get_aim_height(), _necromancer.get_body_center())


## 이 월드(2D) 좌표를 조준하려면 마우스를 둘 화면(내부 해상도) 위치. aim_from_screen의 반대다
func screen_from_aim(aim: Vector2) -> Vector2:
	return _camera.unproject_position(ViewSpace.aim_to_3d(aim, get_aim_height()))


## 월드(2D) 좌표에서 높이 height_px의 점이 화면(내부 해상도)의 어디에 보이는지
func world_to_screen(world: Vector2, height_px: float) -> Vector2:
	return _camera.unproject_position(ViewSpace.to_3d(world, height_px))


## 조준·탄이 있는 평면의 높이 (픽셀): 2D의 몸 가운데와 같다
func get_aim_height() -> float:
	return _necromancer.global_position.y - _necromancer.get_body_center().y


## 바닥 위의 점을 화면 픽셀에 맞춘다: 화면 위치를 정수로 반올림한 뒤 그 픽셀이 가리키는 같은 높이의 점으로 되돌린다.
func snap_to_pixels(point: Vector3) -> Vector3:
	var screen: Vector2 = _camera.unproject_position(point).round()
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var direction: Vector3 = _camera.project_ray_normal(screen)
	if is_zero_approx(direction.y):
		return point
	return origin + direction * ((point.y - origin.y) / direction.y)


func get_camera() -> Camera3D:
	return _camera


func get_bodies() -> BodyLayer:
	return _bodies


func get_front_walls() -> FrontWalls:
	return _front_walls


func get_palette() -> PalettePass:
	return _palette


## 시야 (시야가 없는 지역이면 null)
func get_vision() -> Vision:
	return _vision


## 몸 그림이 화면에서 차지하는 사각형 (검사용)
func get_see_rect(node: Node2D) -> Rect2:
	return _bodies.get_see_rect(node)


## 확인용: 카메라가 지금 앞서 간 양 (화면 픽셀)
func get_lead_offset() -> Vector2:
	return _lead_offset


## 확인용: 지형 구역 메시 노드들
func get_terrain_chunks() -> Array[MeshInstance3D]:
	return _terrain_chunks


## 확인용: 지형 사각형 수
func get_terrain_quads() -> int:
	return _terrain_quads


## 확인용: 지형을 만드는 데 걸린 시간 (마이크로초)
func get_terrain_build_usec() -> int:
	return _terrain_build_usec


## 3D로 그릴 수 있는 2D 노드들: Actors의 자식과 지역의 직접 자식 (상자, 탈출 지점 등)
func _world_nodes() -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	for holder: Node in [_necromancer.get_parent(), get_parent()]:
		for child: Node in holder.get_children():
			if child is Node2D:
				nodes.append(child as Node2D)
	return nodes


## 확인용: 지형 메시를 만드는 데 걸린 시간 (마이크로초, 노드 만들기 제외)
func get_terrain_mesh_usec() -> int:
	return _terrain_mesh_usec


## 지역의 임시 바닥·벽마다 구역별 메시를 만든다. 지형 재질을 돌려준다.
func _build_terrain() -> ShaderMaterial:
	var started: int = Time.get_ticks_usec()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(TERRAIN_SHADER)
	var shadow_material: StandardMaterial3D = StandardMaterial3D.new()
	# 빛 쪽 면을 빼고 그림자를 만들어, 빛을 받는 벽 앞면과 바닥에 얼룩이 지지 않게 한다.
	shadow_material.cull_mode = BaseMaterial3D.CULL_FRONT
	var mesher: TerrainMesher = TerrainMesher.new()
	for child: Node in get_parent().get_children():
		var cells: TerrainCells = null
		if child is PlaceholderGround:
			cells = TerrainCells.from_ground(child as PlaceholderGround)
		elif child is PlaceholderWalls:
			cells = TerrainCells.from_walls(child as PlaceholderWalls)
		if cells == null:
			continue
		var meshes: Array[ArrayMesh] = mesher.build(cells, chunk_cells, wall_height_px, cut_cap_height_px)
		_terrain_mesh_usec += Time.get_ticks_usec() - started
		for mesh: ArrayMesh in meshes:
			var chunk: MeshInstance3D = MeshInstance3D.new()
			chunk.mesh = mesh
			chunk.material_override = material
			chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(chunk)
			_terrain_chunks.append(chunk)
			var shadow: MeshInstance3D = MeshInstance3D.new()
			shadow.mesh = mesh
			shadow.material_override = shadow_material
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			add_child(shadow)
		_terrain_quads += mesher.quad_count
	_terrain_build_usec = Time.get_ticks_usec() - started
	return material


## 2D 세계는 2D 카메라 기준이라 3D 화면과 맞지 않으므로 숨긴다. 규칙은 그대로 돈다. HUD와 창은 CanvasLayer라 그대로 보인다.
func _hide_2d_world() -> void:
	for child: Node in get_parent().get_children():
		if child is InteractZone or child is EscapePoint:
			# 3D 층이 이 노드의 보임을 읽으므로 visible은 그대로 두고 자기 2D 그림만 투명하게 한다.
			(child as CanvasItem).self_modulate.a = 0.0
		elif child is Node2D:
			(child as Node2D).visible = false


func _update_camera(delta: float) -> void:
	var feet: Vector3 = ViewSpace.to_3d(_necromancer.global_position, 0.0)
	var right: Vector3 = _camera_basis.x
	var up: Vector3 = _camera_basis.y
	var back: Vector3 = _camera_basis.z
	# 앞서 가기: 화면 픽셀만큼 카메라 평면에서 옮긴다 (화면 아래가 +y).
	var screen_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	_lead_offset = aim_lead.follow(_lead_offset, aim_lead.target_offset(_lead_mouse(screen_center), screen_center), delta)
	# 카메라를 화면 픽셀 격자에 맞춘다 (바닥 무늬가 꿈틀거리지 않게). 몸과 앞서 간 양을 따로 맞춰야,
	# 앞서 간 양에 소수가 있어도 걷는 동안 몸이 화면에서 1픽셀씩 흔들리지 않는다.
	var pixel: float = 1.0 / ViewSpace.TILE
	var lead_right: float = round(_lead_offset.x) * pixel
	var lead_up: float = -round(_lead_offset.y) * pixel
	var snapped_target: Vector3 = right * (snappedf(feet.dot(right), pixel) + lead_right) + up * (snappedf(feet.dot(up), pixel) + lead_up) + back * snappedf(feet.dot(back), depth_step)
	# 발밑 평면에서 그림 1픽셀이 화면 1픽셀이 되는 거리: 세로 화면 전체가 viewport_height / TILE 단위로 보인다.
	var view_height: float = ProjectSettings.get_setting("display/window/size/viewport_height") / ViewSpace.TILE
	_camera.global_position = snapped_target + back * (view_height * 0.5 / tan(deg_to_rad(fov_degrees * 0.5)))


## 앞서 가기가 쓰는 마우스의 화면 위치. 조준을 코드로 정한 확인 상태에서는 앞서 가지 않는다.
func _lead_mouse(screen_center: Vector2) -> Vector2:
	return screen_center if aim_override != Vector2.INF else _mouse()


## 마우스의 화면 위치 (검사에서는 mouse_override)
func _mouse() -> Vector2:
	return mouse_override if mouse_override != Vector2.INF else get_viewport().get_mouse_position()
