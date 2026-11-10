class_name RegionView3D
extends Node3D
## 2D 규칙 세계를 읽어서 3D로 그리는 층. 규칙(이동, 충돌, 시야 판정)은 2D 그대로이고, 이 층은 규칙에 조준 위치와 이동 입력의 회전만 돌려준다.
## 지역 데이터의 view_3d가 켜진 지역에 Region이 붙인다. 헤드리스(테스트·측정)에서는 붙이지 않는다.
## 지금은 카메라, 조준 변환, 화면 기준 이동, 지형까지 있다. 몸·바닥 표시·시야는 이전 단계마다 여기에 더한다. 그때까지 2D 세계는 숨겨 둔다.
## - 지형: 임시 벽·바닥과 같은 칸과 색으로 구역별 메시를 만든다 (TerrainCells, TerrainMesher). 빛은 시야 단계에서 넣고, 지금은 원래 색 그대로 그린다
## - 조준: 화면 광선과 탄 높이 평면의 교점을 2D 위치로 바꾼다
## - 화면 회전: 카메라만 돌린다. 규칙 좌표는 그대로이고, 이동 입력만 화면 기준으로 돌린다 (W = 화면 위)
## - 앞서 가기: 카메라가 마우스의 화면 위치 쪽으로 움직여 보는 쪽을 더 넓게 보여 준다 (AimLead)

## 카메라가 아래로 기운 각도 (도)
@export var pitch_degrees: float = 60.0
## 화면이 맵 기준으로 돌아간 각도 (도)
@export var yaw_degrees: float = 45.0
## 화각 (도)
@export var fov_degrees: float = 30.0
@export var camera_near: float = 0.1
@export var camera_far: float = 200.0
## 벽 높이 (픽셀)
@export var wall_height_px: float = 32.0
## 지형 구역 한 변의 칸 수
@export var chunk_cells: int = 16

## 카메라 앞서 가기 값 (나중에 설정에서 strength를 0까지 줄인다)
var aim_lead: AimLead = AimLead.new()

var _necromancer: Necromancer
var _camera: Camera3D
## 카메라가 지금 앞서 간 양 (화면 픽셀)
var _lead_offset: Vector2 = Vector2.ZERO
## 지형 구역 메시 노드들
var _terrain_chunks: Array[MeshInstance3D] = []
var _terrain_quads: int = 0
var _terrain_build_usec: int = 0


## add_child 전에 부른다.
func setup(necromancer: Necromancer) -> void:
	_necromancer = necromancer


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.fov = fov_degrees
	_camera.near = camera_near
	_camera.far = camera_far
	_camera.rotation_degrees = Vector3(-pitch_degrees, yaw_degrees, 0)
	_camera.current = true
	add_child(_camera)
	_necromancer.aim_provider = get_aim_position
	_necromancer.input_rotation = -deg_to_rad(yaw_degrees)
	_update_camera(0.0)
	_build_terrain()
	_hide_2d_world()


func _process(delta: float) -> void:
	if is_instance_valid(_necromancer):
		_update_camera(delta)


## 지금 조준하는 월드(2D) 좌표
func get_aim_position() -> Vector2:
	return aim_from_screen(get_viewport().get_mouse_position())


## 화면(내부 해상도)의 점을 누르면 조준되는 월드(2D) 좌표
func aim_from_screen(screen: Vector2) -> Vector2:
	return ViewSpace.aim_from_ray(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen), _aim_height_px(), _necromancer.get_body_center())


## 이 월드(2D) 좌표를 조준하려면 마우스를 둘 화면(내부 해상도) 위치. aim_from_screen의 반대다
func screen_from_aim(aim: Vector2) -> Vector2:
	return _camera.unproject_position(ViewSpace.aim_to_3d(aim, _aim_height_px()))


## 월드(2D) 좌표에서 높이 height_px의 점이 화면(내부 해상도)의 어디에 보이는지
func world_to_screen(world: Vector2, height_px: float) -> Vector2:
	return _camera.unproject_position(ViewSpace.to_3d(world, height_px))


func get_camera() -> Camera3D:
	return _camera


## 확인용: 지형 구역 메시 노드들
func get_terrain_chunks() -> Array[MeshInstance3D]:
	return _terrain_chunks


## 확인용: 지형 사각형 수
func get_terrain_quads() -> int:
	return _terrain_quads


## 확인용: 지형을 만드는 데 걸린 시간 (마이크로초)
func get_terrain_build_usec() -> int:
	return _terrain_build_usec


## 조준·탄이 있는 평면의 높이 (픽셀): 2D의 몸 가운데와 같다
func _aim_height_px() -> float:
	return _necromancer.global_position.y - _necromancer.get_body_center().y


## 지역의 임시 바닥·벽마다 구역별 메시를 만든다.
func _build_terrain() -> void:
	var started: int = Time.get_ticks_usec()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	var mesher: TerrainMesher = TerrainMesher.new()
	for child: Node in get_parent().get_children():
		var cells: TerrainCells = null
		if child is PlaceholderGround:
			cells = TerrainCells.from_ground(child as PlaceholderGround)
		elif child is PlaceholderWalls:
			cells = TerrainCells.from_walls(child as PlaceholderWalls)
		if cells == null:
			continue
		for mesh: ArrayMesh in mesher.build(cells, chunk_cells, wall_height_px):
			var chunk: MeshInstance3D = MeshInstance3D.new()
			chunk.mesh = mesh
			chunk.material_override = material
			chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(chunk)
			_terrain_chunks.append(chunk)
		_terrain_quads += mesher.quad_count
	_terrain_build_usec = Time.get_ticks_usec() - started


## 3D로 옮기지 않은 2D 세계(몸, 바닥 표시 등)는 2D 카메라 기준이라 3D 화면과 맞지 않으므로 숨긴다. 규칙은 그대로 돈다. HUD와 창은 CanvasLayer라 그대로 보인다.
func _hide_2d_world() -> void:
	for child: Node in get_parent().get_children():
		if child is Node2D:
			(child as Node2D).visible = false


func _update_camera(delta: float) -> void:
	var feet: Vector3 = ViewSpace.to_3d(_necromancer.global_position, 0.0)
	var camera_basis: Basis = _camera.global_transform.basis
	var right: Vector3 = camera_basis.x
	var up: Vector3 = camera_basis.y
	var back: Vector3 = camera_basis.z
	# 앞서 가기: 화면 픽셀만큼 카메라 평면에서 옮긴다 (화면 아래가 +y).
	var mouse: Vector2 = get_viewport().get_mouse_position()
	_lead_offset = aim_lead.follow(_lead_offset, aim_lead.target_offset(mouse, get_viewport().get_visible_rect().size * 0.5), delta)
	feet += (right * _lead_offset.x - up * _lead_offset.y) / ViewSpace.TILE
	# 카메라를 화면 픽셀 격자에 맞춘다 (바닥 무늬가 꿈틀거리지 않게).
	var pixel: float = 1.0 / ViewSpace.TILE
	var snapped_target: Vector3 = right * snappedf(feet.dot(right), pixel) + up * snappedf(feet.dot(up), pixel) + back * feet.dot(back)
	# 발밑 평면에서 그림 1픽셀이 화면 1픽셀이 되는 거리: 세로 화면 전체가 viewport_height / TILE 단위로 보인다.
	var view_height: float = ProjectSettings.get_setting("display/window/size/viewport_height") / ViewSpace.TILE
	_camera.global_position = snapped_target + back * (view_height * 0.5 / tan(deg_to_rad(fov_degrees * 0.5)))
