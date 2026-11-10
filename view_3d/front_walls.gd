class_name FrontWalls
extends Node
## 카메라 쪽 벽 처리. 플레이어와 조준점 앞의 벽은 잘라내고, 시야에 보이는 몸 앞의 벽은 반투명하게 한다. 값을 프레임마다 지형 셰이더에 넣는다.
## - 세기는 zone_fade_time에 걸쳐 서서히 바뀌어 깜빡이지 않는다
## - 몸은 시야 판정(Vision)이 정한 투명도를 따르므로, 시야 밖 몸은 벽을 반투명하게 만들지 않는다. 언데드는 늘 보인다
## - 네크로맨서는 잘라내기 자리가 맡으므로 반투명 대상에서 뺀다. 상자는 시야 안에 있을 때 반투명하게 한다
## - 개발 빌드에서 [ ] 키로 플레이어, - = 키로 조준점 잘라내기 반경을 바꾼다

## 셰이더의 반투명 자리 수와 같다
const SEE_ZONES: int = 16
## 반경 값을 보여 주는 글자 자리 (화면 픽셀)
const RADIUS_LABEL_POSITION: Vector2 = Vector2(180, 8)

## 자리의 반지름 (화면 픽셀)
@export var cut_radius_player: float = 64.0
@export var cut_radius_aim: float = 48.0
## 세기가 바뀌는 시간 (초)
@export var zone_fade_time: float = 0.2
## 잘라내기 자리의 가운데를 잡을 높이 (평면 높이, 픽셀): 플레이어 몸 가운데
@export var player_zone_height: float = 32.0
@export_group("개발용 키")
## 잘라내기 반경을 바꾸는 키 (개발 빌드에서만)
@export var player_radius_down_key: Key = KEY_BRACKETLEFT
@export var player_radius_up_key: Key = KEY_BRACKETRIGHT
@export var aim_radius_down_key: Key = KEY_MINUS
@export var aim_radius_up_key: Key = KEY_EQUAL
## 한 번 누를 때 바뀌는 양과 가장 큰 값 (화면 픽셀)
@export var radius_step: float = 8.0
@export var max_radius: float = 240.0
## 바꾼 값을 화면에 보여 주는 시간 (초)
@export var radius_label_time: float = 2.5

var enabled: bool = true
## 확인용: 끄면 몸 앞 벽을 반투명하게 하지 않는다 (잘라내기는 그대로)
var see_through_on: bool = true

var _view: RegionView3D
var _bodies: BodyLayer
var _necromancer: Necromancer
var _material: ShaderMaterial
var _player_weight: float = 1.0
var _aim_weight: float = 1.0
var _see_weights: Dictionary = {}
var _radius_label: Label
var _radius_label_left: float = 0.0


## add_child 전에 부른다.
func setup(view: RegionView3D, bodies: BodyLayer, necromancer: Necromancer, material: ShaderMaterial) -> void:
	_view = view
	_bodies = bodies
	_necromancer = necromancer
	_material = material


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	_radius_label = Label.new()
	_radius_label.position = RADIUS_LABEL_POSITION
	_radius_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radius_label.visible = false
	layer.add_child(_radius_label)
	add_child(layer)


## 개발 빌드에서 잘라내기 반경을 키로 바꾼다. 값은 잠깐 화면에 보여 준다.
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or not OS.is_debug_build():
		return
	match key.keycode:
		player_radius_down_key:
			cut_radius_player = clampf(cut_radius_player - radius_step, 0.0, max_radius)
		player_radius_up_key:
			cut_radius_player = clampf(cut_radius_player + radius_step, 0.0, max_radius)
		aim_radius_down_key:
			cut_radius_aim = clampf(cut_radius_aim - radius_step, 0.0, max_radius)
		aim_radius_up_key:
			cut_radius_aim = clampf(cut_radius_aim + radius_step, 0.0, max_radius)
		_:
			return
	_radius_label.text = "잘라내기 반경: 플레이어 %d, 조준점 %d" % [int(cut_radius_player), int(cut_radius_aim)]
	_radius_label.visible = true
	_radius_label_left = radius_label_time
	get_viewport().set_input_as_handled()


func update_walls(delta: float) -> void:
	if _radius_label_left > 0.0:
		_radius_label_left -= delta
		_radius_label.visible = _radius_label_left > 0.0
	var step: float = delta / zone_fade_time
	var on_target: float = 1.0 if enabled else 0.0
	_player_weight = move_toward(_player_weight, on_target, step)
	_aim_weight = move_toward(_aim_weight, on_target, step)
	var feet: Vector2 = _necromancer.global_position
	var aim_height: float = _view.get_aim_height()
	var aim_ground: Vector2 = _view.get_aim_position() + Vector2(0, aim_height)
	var cut_zones: PackedVector4Array = PackedVector4Array([_zone(_view.world_to_screen(feet, player_zone_height), cut_radius_player, _player_weight), _zone(_view.world_to_screen(aim_ground, aim_height), cut_radius_aim, _aim_weight)])
	_material.set_shader_parameter(&"cut_zones", cut_zones)
	_material.set_shader_parameter(&"cut_world", PackedVector2Array([feet / ViewSpace.TILE, aim_ground / ViewSpace.TILE]))
	var seen: Array[Node2D] = _update_see_weights(step, feet)
	var see_zones: PackedVector4Array = PackedVector4Array()
	var see_world: PackedVector2Array = PackedVector2Array()
	var see_weights: PackedFloat32Array = PackedFloat32Array()
	see_zones.resize(SEE_ZONES)
	see_world.resize(SEE_ZONES)
	see_weights.resize(SEE_ZONES)
	for i: int in mini(seen.size(), SEE_ZONES):
		var rect: Rect2 = _bodies.get_see_rect(seen[i])
		see_zones[i] = Vector4(rect.get_center().x, rect.get_center().y, rect.size.x * 0.5, rect.size.y * 0.5)
		see_weights[i] = _see_weights[seen[i]]
		see_world[i] = seen[i].global_position / ViewSpace.TILE
	_material.set_shader_parameter(&"see_zones", see_zones)
	_material.set_shader_parameter(&"see_world", see_world)
	_material.set_shader_parameter(&"see_weights", see_weights)
	var back: Vector3 = _view.get_camera().global_transform.basis.z
	var toward: Vector2 = Vector2(back.x, back.z)
	_material.set_shader_parameter(&"toward_camera", toward.normalized())
	# 그림의 깊이를 당긴 만큼은 벽이 그림을 가리지 않으므로 반투명하게 하지 않는다.
	_material.set_shader_parameter(&"see_min_front", _bodies.get_depth_bias() * toward.length())


## 확인용: 이 몸 앞 벽의 반투명 세기 (0~1)
func get_see_weight(node: Node2D) -> float:
	return _see_weights.get(node, 0.0)


## 몸마다 세기를 옮기고, 세기가 있는 몸을 플레이어에게 가까운 순서로 돌려준다.
func _update_see_weights(step: float, feet: Vector2) -> Array[Node2D]:
	var bodies: Array[Node2D] = _bodies.get_bodies()
	for node: Variant in _see_weights.keys():
		if not is_instance_valid(node) or not bodies.has(node):
			_see_weights.erase(node)
	var seen: Array[Node2D] = []
	for body: Node2D in bodies:
		# 탄·돌은 잠깐 지나가므로 벽을 반투명하게 하지 않는다.
		if body == _necromancer or body.is_queued_for_deletion() or body is Bolt or body is Stone:
			continue
		var wanted: float = 0.0
		if enabled and see_through_on:
			if body is InteractZone:
				wanted = _bodies.get_chest_sight(body)
			else:
				wanted = 1.0 if body.is_in_group(&"undead") else (body.modulate.a if body.visible else 0.0)
		_see_weights[body] = move_toward(_see_weights.get(body, 0.0), wanted, step)
		if _see_weights[body] > 0.0:
			seen.append(body)
	seen.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_squared_to(feet) < b.global_position.distance_squared_to(feet))
	return seen


func _zone(screen: Vector2, radius: float, weight: float) -> Vector4:
	return Vector4(screen.x, screen.y, radius, weight)
