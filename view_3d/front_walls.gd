class_name FrontWalls
extends Node
## 카메라 쪽 벽 처리. 플레이어와 조준점 앞의 벽은 잘라내고, 시야에 보이는 몸 앞의 벽은 반투명하게 한다. 값을 프레임마다 지형 셰이더에 넣는다.
## - 세기는 zone_fade_time에 걸쳐 서서히 바뀌어 깜빡이지 않는다
## - 몸은 시야 판정(Vision)이 정한 투명도를 따르므로, 시야 밖 몸은 벽을 반투명하게 만들지 않는다. 언데드는 늘 보인다
## - 네크로맨서는 잘라내기 자리가 맡으므로 반투명 대상에서 뺀다

## 셰이더의 반투명 자리 수와 같다
const SEE_ZONES: int = 16

## 자리의 반지름 (화면 픽셀)
@export var cut_radius_player: float = 64.0
@export var cut_radius_aim: float = 48.0
## 세기가 바뀌는 시간 (초)
@export var zone_fade_time: float = 0.2
## 잘라내기 자리의 가운데를 잡을 높이 (평면 높이, 픽셀): 플레이어 몸 가운데
@export var player_zone_height: float = 32.0

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


## add_child 전에 부른다.
func setup(view: RegionView3D, bodies: BodyLayer, necromancer: Necromancer, material: ShaderMaterial) -> void:
	_view = view
	_bodies = bodies
	_necromancer = necromancer
	_material = material


func update_walls(delta: float) -> void:
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
		# 상자는 지형처럼 늘 보이는 것이고, 탄·돌은 잠깐 지나가므로 벽을 반투명하게 하지 않는다.
		if body == _necromancer or body.is_queued_for_deletion() or body is InteractZone or body is Bolt or body is Stone:
			continue
		var wanted: float = 0.0
		if enabled and see_through_on:
			wanted = 1.0 if body.is_in_group(&"undead") else (body.modulate.a if body.visible else 0.0)
		_see_weights[body] = move_toward(_see_weights.get(body, 0.0), wanted, step)
		if _see_weights[body] > 0.0:
			seen.append(body)
	seen.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_squared_to(feet) < b.global_position.distance_squared_to(feet))
	return seen


func _zone(screen: Vector2, radius: float, weight: float) -> Vector4:
	return Vector4(screen.x, screen.y, radius, weight)
