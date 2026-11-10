class_name SightLights
extends Node3D
## 시야를 지형에 그린다. 플레이어와 언데드마다 낮은 3D 빛 하나가 벽 그림자를 만들고, 부채꼴과 둘레 원은 셰이더가 2D 규칙과 같은 모양으로 계산한다.
## 무엇이 보이는지(몬스터·물건)는 2D 판정(Vision)이 그대로 정한다. 이 노드는 밝기만 맡는다.
## - 빛은 플레이어(0번)와 언데드(1번부터). 언데드가 MAX_SIGHTS - 1마리보다 많으면 가까운 언데드만 지형을 밝힌다
## - 빛의 색에 번호를 담아 셰이더가 어느 빛인지 안다 (sight.gdshaderinc)
## - 시야가 없거나 꺼져 있으면 지형은 원래 밝기다

## 셰이더의 MAX_SIGHTS와 같다
const MAX_SIGHTS: int = 9

## 빛의 높이 (픽셀). 벽보다 낮아야 2D와 같은 그림자가 생긴다
@export var light_height_px: float = 12.0
## 빛의 범위를 보는 거리보다 이만큼 넉넉히 둔다 (칸). 범위 끝에서 어두워지는 구간이 보이지 않게 한다
@export var range_margin_cells: float = 16.0

var _vision: Vision
var _necromancer: Necromancer
var _materials: Array[ShaderMaterial] = []
var _lights: Array[OmniLight3D] = []


## add_child 전에 부른다. vision은 시야가 없는 지역이면 null이다.
func setup(vision: Vision, necromancer: Necromancer, materials: Array[ShaderMaterial]) -> void:
	_vision = vision
	_necromancer = necromancer
	_materials = materials


func _ready() -> void:
	for i: int in MAX_SIGHTS:
		var light: OmniLight3D = OmniLight3D.new()
		var coded: float = Color(float(i + 1) / MAX_SIGHTS, 0.0, 0.0).linear_to_srgb().r
		light.light_color = Color(1.0, coded, 0.0)
		light.omni_attenuation = 0.0
		light.light_specular = 0.0
		light.shadow_enabled = true
		light.visible = false
		add_child(light)
		_lights.append(light)
	update_sights()


## 프레임마다 부른다: 빛을 옮기고 셰이더 값을 넣는다.
func update_sights() -> void:
	var active: bool = _vision != null and _vision.active
	_set_all(&"terrain_dark", _vision.darkness if active else 1.0)
	if not active:
		for light: OmniLight3D in _lights:
			light.visible = false
		return
	var origins: PackedVector2Array = PackedVector2Array()
	var facings: PackedVector2Array = PackedVector2Array()
	var shapes: PackedVector4Array = PackedVector4Array()
	var nears: PackedVector2Array = PackedVector2Array()
	var energies: PackedFloat32Array = PackedFloat32Array()
	for array: Variant in [origins, facings, nears]:
		array.resize(MAX_SIGHTS)
	shapes.resize(MAX_SIGHTS)
	energies.resize(MAX_SIGHTS)
	var player_range: float = _vision.light_radius / ViewSpace.TILE
	var edge: float = _vision.light_edge / ViewSpace.TILE
	origins[0] = _vision.get_origin() / ViewSpace.TILE
	facings[0] = _vision.get_facing().normalized()
	shapes[0] = Vector4(_vision.full_angle, _vision.total_angle, player_range, edge)
	nears[0] = Vector2(_vision.near_radius, _vision.near_fade) / ViewSpace.TILE
	energies[0] = 1.0
	_place(_lights[0], _necromancer.global_position, player_range)
	var undead_list: Array[Undead] = _vision.get_lit_undead(MAX_SIGHTS - 1)
	for i: int in MAX_SIGHTS - 1:
		var light: OmniLight3D = _lights[i + 1]
		if i >= undead_list.size():
			light.visible = false
			continue
		var undead: Undead = undead_list[i]
		var sight: SightData = undead.data.get_undead_sight()
		var view_range: float = sight.view_range / ViewSpace.TILE
		origins[i + 1] = undead.get_sight_origin() / ViewSpace.TILE
		facings[i + 1] = undead.facing.normalized()
		shapes[i + 1] = Vector4(sight.full_angle, sight.total_angle, view_range, edge)
		nears[i + 1] = Vector2(sight.near_radius, sight.near_fade) / ViewSpace.TILE
		energies[i + 1] = _energy_for(sight.brightness)
		_place(light, undead.global_position, view_range)
	_set_all(&"sight_origin", origins)
	_set_all(&"sight_facing", facings)
	_set_all(&"sight_shape", shapes)
	_set_all(&"sight_near", nears)
	_set_all(&"sight_energy", energies)


func _place(light: OmniLight3D, feet: Vector2, view_range: float) -> void:
	light.visible = true
	light.global_position = ViewSpace.to_3d(feet, light_height_px)
	light.omni_range = view_range + range_margin_cells


## 이 빛만 받은 지형이 brightness배(sRGB)로 보이게 하는, 어두운 색과 원래 색 사이의 비율 (선형)
func _energy_for(brightness: float) -> float:
	var dark: float = Color(_vision.darkness, 0.0, 0.0).srgb_to_linear().r
	var lit: float = Color(brightness, 0.0, 0.0).srgb_to_linear().r
	return (lit - dark) / (1.0 - dark)


func _set_all(parameter: StringName, value: Variant) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(parameter, value)
