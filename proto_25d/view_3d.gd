class_name View3D
extends Node3D
## 시제품: 2D 규칙 세계를 읽어서 3D로 그리는 층. 규칙(이동, 충돌, 시야 판정)은 2D 그대로이고, 이 층은 규칙에 조준 위치만 돌려준다.
## - 좌표: 2D (x, y) → 3D (x / 32, 높이, y / 32). 타일 한 칸 = 3D 1단위
## - 지형: PlaceholderWalls의 벽 격자에서 바닥·벽 메시를 만든다. 그림자는 그림자 전용 메시가 맡는다 (앞벽을 잘라도 그림자는 그대로)
## - 몸: 숨긴 2D 스프라이트의 애니메이션·프레임을 3D 스프라이트에 그대로 옮긴다. 수직으로 세우고 세로만 1 / cos(각도)배라 직교에서 화면 1:1 픽셀이다
## - 시야: 낮은 전방향 빛 하나가 벽 그림자를 만들고, 부채꼴과 둘레 원은 지형 셰이더가 2D 규칙과 같은 모양으로 계산한다. 지형만 받고 몸은 원래 색이다. 몬스터가 보이는지는 2D 판정(Vision)의 투명도를 그대로 쓴다
## - 조준: 화면 광선과 탄 높이 평면의 교점을 2D 위치로 바꾼다
## 키: F3 직교/원근, F4 팔레트 후처리, F5 앞벽 (끔/반투명/잘라내기), F6 3D/2D 화면, F2 시야(기존)

const TILE: float = 32.0
const FLOOR_COLORS: Array[String] = ["3e2731", "262b44"]
const WALL_TOP_COLOR: String = "5a6988"
const WALL_FACE_COLOR: String = "8b9bb4"
const BACKGROUND_COLOR: String = "181425"
const BOLT_COLOR: String = "2ce8f5"
const CORPSE_COLOR: String = "8b9bb4"
const LABEL_COLOR: String = "fee761"
const PALETTE_PATH: String = "res://assets/palette/endesga-32.hex"
const CUT_NAMES: Array[String] = ["off", "see-through", "cut"]
## 앞벽을 잘라낸 자리의 낮은 윗면 높이 (단위). 셰이더의 cut_keep_height(0.2)보다 조금 낮다
const CUT_CAP_HEIGHT: float = 0.19
## 시야 빛의 범위 (칸). 범위 끝에서 어두워지는 구간이 보는 거리(14칸) 안에 들어오지 않을 만큼 크게 둔다
const LIGHT_RANGE_TILES: float = 30.0

## 카메라가 아래로 기운 각도 (도)
@export var pitch_degrees: float = 60.0
## 벽 높이 (픽셀)
@export var wall_height_px: float = 32.0
## 시야 빛의 높이 (픽셀). 벽보다 낮아야 2D와 같은 그림자가 생긴다
@export var light_height_px: float = 12.0
## 조준·탄이 있는 평면의 높이 (픽셀). 2D의 몸 가운데(발밑에서 y로 -6)와 같게 둔다
@export var aim_height_px: float = 6.0
## 원근일 때의 화각 (도)
@export var perspective_fov: float = 20.0
## 빛 없는 지형의 밝기 (2D 시야의 0.4배를 선형 색으로 바꾼 값)
@export var ambient_energy: float = 0.133
## 보는 거리와 부채꼴 (2D 시야와 같은 값)
@export var view_range_px: float = 448.0
@export var view_edge_px: float = 32.0
@export var full_angle: float = 23.0
@export var total_angle: float = 35.0
## 방향과 상관없이 밝은 둘레 반지름과 바깥으로 어두워지는 폭 (픽셀)
@export var near_radius_px: float = 48.0
@export var near_fade_px: float = 8.0
## 앞벽을 처리하는 범위 (칸, 좌우와 남쪽)
@export var cut_half_tiles: Vector2 = Vector2(3.0, 3.5)

var cut_mode: int = 0
var perspective: bool = false
var palette_on: bool = false
var show_3d: bool = true
## 확인용: 값이 있으면 마우스 대신 이 월드 좌표를 조준한다 (스크린샷·검사)
var aim_override: Vector2 = Vector2.INF

var _necromancer: Necromancer
var _walls: PlaceholderWalls
var _actors: Node2D
var _camera: Camera3D
var _light: OmniLight3D
var _floor_material: ShaderMaterial
var _wall_material: ShaderMaterial
var _environment: Environment
var _palette_layer: CanvasLayer
var _label: Label
## 2D 노드 → 3D 노드
var _visuals: Dictionary = {}


func _ready() -> void:
	var region: Node = get_parent()
	_walls = region.get_node("Walls")
	_actors = region.get_node("Actors")
	_necromancer = _actors.get_node("Necromancer")
	_necromancer.aim_provider = get_aim_position
	_build_environment()
	_build_terrain()
	_build_camera()
	_build_lights()
	_build_overlay()
	_apply_view_mode()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F3:
			perspective = not perspective
		KEY_F4:
			palette_on = not palette_on
		KEY_F5:
			cut_mode = (cut_mode + 1) % CUT_NAMES.size()
		KEY_F6:
			show_3d = not show_3d
		_:
			return
	_apply_view_mode()
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_instance_valid(_necromancer) or not show_3d:
		return
	_update_camera()
	_update_lights()
	_sync_actors()


## 비교용 상태를 적용한다 (키나 스크린샷 설정에서 값을 바꾼 뒤 부른다).
func _apply_view_mode() -> void:
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE if perspective else Camera3D.PROJECTION_ORTHOGONAL
	_palette_layer.visible = palette_on and show_3d
	_wall_material.set_shader_parameter(&"cut_mode", cut_mode)
	visible = show_3d
	_walls.visible = not show_3d
	_actors.visible = not show_3d
	_label.text = "[F3] %s  [F4] palette %s  [F5] wall %s  [F6] %s" % ["persp" if perspective else "ortho", "on" if palette_on else "off", CUT_NAMES[cut_mode], "3D" if show_3d else "2D"]


## 월드(2D) 좌표에서 높이 height_px의 점이 화면(내부 해상도)의 어디에 보이는지. 검사가 마우스를 옮길 때 쓴다
func world_to_screen(world: Vector2, height_px: float) -> Vector2:
	return _camera.unproject_position(_to_3d(world, height_px))


## 지금 조준하는 월드(2D) 좌표: 화면 광선이 탄 높이 평면과 만나는 점
func get_aim_position() -> Vector2:
	if aim_override != Vector2.INF:
		return aim_override
	if not show_3d:
		return _necromancer.get_global_mouse_position()
	return aim_from_screen(get_viewport().get_mouse_position())


## 화면(내부 해상도)의 점을 누르면 조준되는 월드(2D) 좌표
func aim_from_screen(screen: Vector2) -> Vector2:
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var direction: Vector3 = _camera.project_ray_normal(screen)
	var height: float = aim_height_px / TILE
	if is_zero_approx(direction.y):
		return _necromancer.get_body_center()
	var hit: Vector3 = origin + direction * ((height - origin.y) / direction.y)
	# 2D의 탄은 발밑 평면에서 y로 aim_height_px 위쪽 자리에 있다.
	return Vector2(hit.x, hit.z) * TILE - Vector2(0, aim_height_px)


func get_camera() -> Camera3D:
	return _camera


func _to_3d(world: Vector2, height_px: float) -> Vector3:
	return Vector3(world.x / TILE, height_px / TILE, world.y / TILE)


func _build_environment() -> void:
	var environment: Environment = Environment.new()
	_environment = environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.html(BACKGROUND_COLOR)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = ambient_energy
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


func _build_terrain() -> void:
	var grid: PackedByteArray = _walls.wall_grid()
	var size: Vector2i = _walls.grid_size()
	var origin: Vector3 = _to_3d(_walls.global_position, 0.0)
	var height: float = wall_height_px / TILE
	var floor_mesh: _MeshBuilder = _MeshBuilder.new()
	var wall_mesh: _MeshBuilder = _MeshBuilder.new()
	var top: Color = Color.html(WALL_TOP_COLOR).srgb_to_linear()
	var face: Color = Color.html(WALL_FACE_COLOR).srgb_to_linear()
	for y: int in size.y:
		for x: int in size.x:
			var cell: Vector3 = origin + Vector3(x, 0, y)
			if grid[y * size.x + x] != 1:
				floor_mesh.quad(cell, Vector3.RIGHT, Vector3.BACK, Vector3.UP, Color.html(FLOOR_COLORS[(x + y) % FLOOR_COLORS.size()]).srgb_to_linear())
				continue
			wall_mesh.quad(cell + Vector3.UP * height, Vector3.RIGHT, Vector3.BACK, Vector3.UP, top)
			# 앞벽을 잘라낸 자리에 보이는 낮은 윗면 (평소에는 진짜 윗면에 가려진다)
			wall_mesh.quad(cell + Vector3.UP * CUT_CAP_HEIGHT, Vector3.RIGHT, Vector3.BACK, Vector3.UP, top)
			if _is_floor(grid, size, x, y + 1):
				wall_mesh.quad(cell + Vector3.BACK, Vector3.UP * height, Vector3.RIGHT, Vector3.BACK, face)
			if _is_floor(grid, size, x, y - 1):
				wall_mesh.quad(cell, Vector3.RIGHT, Vector3.UP * height, Vector3.FORWARD, face)
			if _is_floor(grid, size, x + 1, y):
				wall_mesh.quad(cell + Vector3.RIGHT + Vector3.BACK, Vector3.FORWARD, Vector3.UP * height, Vector3.RIGHT, face)
			if _is_floor(grid, size, x - 1, y):
				wall_mesh.quad(cell, Vector3.UP * height, Vector3.BACK, Vector3.LEFT, face)
	var shader: Shader = load("res://proto_25d/terrain.gdshader")
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = shader
	_wall_material = ShaderMaterial.new()
	_wall_material.shader = shader
	_wall_material.set_shader_parameter(&"cut_half", cut_half_tiles)
	_add_mesh(floor_mesh.build(), _floor_material, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_mesh(wall_mesh.build(), _wall_material, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var shadow_material: StandardMaterial3D = StandardMaterial3D.new()
	shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(wall_mesh.build(), shadow_material, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)


func _is_floor(grid: PackedByteArray, size: Vector2i, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size.x and y < size.y and grid[y * size.x + x] != 1


func _add_mesh(mesh: ArrayMesh, material: Material, shadow: GeometryInstance3D.ShadowCastingSetting) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = shadow
	add_child(instance)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.rotation_degrees = Vector3(-pitch_degrees, 0, 0)
	# 세로 360픽셀 = 11.25칸이면 그림 1픽셀이 화면 1픽셀이다.
	_camera.size = ProjectSettings.get_setting("display/window/size/viewport_height") / TILE
	_camera.fov = perspective_fov
	_camera.near = 0.1
	_camera.far = 200.0
	_camera.current = true
	add_child(_camera)


func _update_camera() -> void:
	var feet: Vector3 = _to_3d(_necromancer.global_position, 0.0)
	var basis_now: Basis = _camera.global_transform.basis
	var right: Vector3 = basis_now.x
	var up: Vector3 = basis_now.y
	var back: Vector3 = basis_now.z
	# 카메라를 화면 픽셀 격자에 맞춘다 (바닥 무늬가 꿈틀거리지 않게).
	var snapped_target: Vector3 = right * snappedf(feet.dot(right), 1.0 / TILE) + up * snappedf(feet.dot(up), 1.0 / TILE) + back * feet.dot(back)
	var distance: float = (_camera.size * 0.5) / tan(deg_to_rad(perspective_fov * 0.5)) if perspective else 40.0
	_camera.global_position = snapped_target + back * distance


func _build_lights() -> void:
	_light = OmniLight3D.new()
	# 빛은 벽 그림자만 맡는다. 범위 끝에서 어두워지는 구간이 보이지 않게 보는 거리보다 넉넉히 둔다.
	_light.omni_range = LIGHT_RANGE_TILES
	_light.omni_attenuation = 0.0
	_light.light_energy = 1.0 - ambient_energy
	_light.light_specular = 0.0
	_light.shadow_enabled = true
	add_child(_light)
	for material: ShaderMaterial in [_floor_material, _wall_material]:
		material.set_shader_parameter(&"full_angle", full_angle)
		material.set_shader_parameter(&"total_angle", total_angle)
		material.set_shader_parameter(&"near_radius", near_radius_px / TILE)
		material.set_shader_parameter(&"near_fade", near_fade_px / TILE)
		material.set_shader_parameter(&"view_range", view_range_px / TILE)
		material.set_shader_parameter(&"view_edge", view_edge_px / TILE)


func _update_lights() -> void:
	var active: bool = _vision_active()
	_light.visible = active
	# 시야를 끄면 지형을 원래 밝기로 그린다.
	_environment.ambient_light_energy = ambient_energy if active else 1.0
	_light.global_position = _to_3d(_necromancer.global_position, light_height_px)
	var origin: Vector2 = _necromancer.get_body_center()
	var to_aim: Vector2 = get_aim_position() - origin
	for material: ShaderMaterial in [_floor_material, _wall_material]:
		material.set_shader_parameter(&"sight_origin", _to_3d(origin, 0.0))
		if to_aim != Vector2.ZERO:
			material.set_shader_parameter(&"sight_facing", to_aim.normalized())
	_wall_material.set_shader_parameter(&"cut_center", _to_3d(_necromancer.global_position, 0.0))


func _vision_active() -> bool:
	var region: Node = get_parent()
	var vision: Vision = region.call(&"get_vision") if region.has_method(&"get_vision") else null
	return vision != null and vision.active


func _build_overlay() -> void:
	_palette_layer = CanvasLayer.new()
	_palette_layer.layer = -1
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material_2d: ShaderMaterial = ShaderMaterial.new()
	material_2d.shader = load("res://proto_25d/palette.gdshader")
	material_2d.set_shader_parameter(&"palette", _palette_colors())
	rect.material = material_2d
	_palette_layer.add_child(rect)
	add_child(_palette_layer)
	var label_layer: CanvasLayer = CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(130, 348)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override(&"font_size", 8)
	_label.add_theme_color_override(&"font_color", Color.html(LABEL_COLOR))
	label_layer.add_child(_label)
	add_child(label_layer)


func _palette_colors() -> PackedVector3Array:
	var colors: PackedVector3Array = PackedVector3Array()
	for line: String in FileAccess.get_file_as_string(PALETTE_PATH).split("\n", false):
		var color: Color = Color.html(line.strip_edges())
		colors.append(Vector3(color.r, color.g, color.b))
	return colors


## Actors의 자식마다 3D 노드를 하나 두고 위치·그림·투명도를 옮긴다. 사라진 것은 지운다.
func _sync_actors() -> void:
	var alive: Dictionary = {}
	for child: Node in _actors.get_children():
		var node: Node2D = child as Node2D
		if node == null or node.is_queued_for_deletion():
			continue
		alive[node] = true
		if not _visuals.has(node):
			_visuals[node] = _make_visual(node)
		_update_visual(node, _visuals[node])
	for node: Variant in _visuals.keys():
		if not alive.has(node):
			(_visuals[node] as Node3D).queue_free()
			_visuals.erase(node)


func _sprite_of(node: Node2D) -> FacingSprite:
	for child: Node in node.get_children():
		if child is FacingSprite:
			return child as FacingSprite
	return null


func _make_visual(node: Node2D) -> Node3D:
	var result: Node3D
	var sprite: FacingSprite = _sprite_of(node)
	if sprite != null:
		var sprite_3d: AnimatedSprite3D = AnimatedSprite3D.new()
		sprite_3d.sprite_frames = sprite.sprite_frames
		sprite_3d.pixel_size = 1.0 / TILE
		sprite_3d.centered = false
		sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite_3d.shaded = false
		sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 수직으로 세운 그림은 화면에서 cos(각도)배로 줄어들므로 세로를 그만큼 키운다.
		sprite_3d.scale.y = 1.0 / cos(deg_to_rad(pitch_degrees))
		result = sprite_3d
	else:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if node is Bolt:
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = (node as Bolt).visual_radius / TILE
			sphere.height = sphere.radius * 2.0
			mesh.mesh = sphere
			material.albedo_color = Color.html(BOLT_COLOR)
		else:
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(0.5, 0.1, 0.35)
			mesh.mesh = box
			material.albedo_color = Color.html(CORPSE_COLOR)
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		result = mesh
	add_child(result)
	return result


func _update_visual(node: Node2D, visual: Node3D) -> void:
	if node is Bolt:
		# 2D의 탄은 발밑 평면에서 y로 위쪽 자리에 있다. 3D에서는 그만큼 되돌리고 높이로 올린다.
		visual.global_position = _to_3d(node.global_position + Vector2(0, aim_height_px), aim_height_px)
		return
	var sprite: FacingSprite = _sprite_of(node)
	if sprite == null:
		visual.global_position = _to_3d(node.global_position, 2.0)
		visual.visible = node.visible
		return
	var sprite_3d: AnimatedSprite3D = visual as AnimatedSprite3D
	if sprite_3d.animation != sprite.animation:
		sprite_3d.animation = sprite.animation
	sprite_3d.frame = sprite.frame
	var height: float = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_height()
	# 2D offset은 왼쪽 위 기준(아래가 +y), 3D offset은 왼쪽 아래 기준(위가 +y)이다.
	sprite_3d.offset = Vector2(sprite.offset.x, -(height + sprite.offset.y))
	sprite_3d.global_position = _snap_to_pixels(_to_3d(node.global_position, 0.0))
	sprite_3d.modulate = Color(1, 1, 1, node.modulate.a)
	sprite_3d.visible = node.visible


## 바닥 위의 점을 화면 픽셀 격자에 맞춘다 (가로는 1픽셀 = 1 / 32단위, 세로는 sin(각도)로 줄어든다).
func _snap_to_pixels(point: Vector3) -> Vector3:
	var depth_step: float = 1.0 / (TILE * sin(deg_to_rad(pitch_degrees)))
	return Vector3(snappedf(point.x, 1.0 / TILE), point.y, snappedf(point.z, depth_step))


## 사각형을 모아 메시를 만든다.
class _MeshBuilder:
	var _vertices: PackedVector3Array = PackedVector3Array()
	var _normals: PackedVector3Array = PackedVector3Array()
	var _colors: PackedColorArray = PackedColorArray()

	## corner에서 u, v로 펼친 사각형. 앞면에서 볼 때 u → v가 시계 방향이어야 한다 (u × v = -normal).
	func quad(corner: Vector3, u: Vector3, v: Vector3, normal: Vector3, color: Color) -> void:
		for point: Vector3 in [corner, corner + u, corner + u + v, corner, corner + u + v, corner + v]:
			_vertices.append(point)
			_normals.append(normal)
			_colors.append(color)

	func build() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vertices
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_COLOR] = _colors
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
