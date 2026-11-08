class_name Vision
extends Node2D
## 플레이어 시야 (화면에만 쓴다). 지역 데이터의 limit_vision이 켜진 지역에서 Region이 붙인다 (거점에는 없다).
## - 지형(Region이 넘겨준 노드들: 바닥·벽·상자·탈출 지점)만 darkness로 어둡게 칠하고, 네크로맨서에 단 빛 하나로 밝힌다.
##   빛은 부채꼴(마우스 쪽)과 둘레 원을 한 그림에 합친 PointLight2D다. 매 프레임 마우스 방향으로 돌린다
## - 빛과 그림자는 지형 빛 마스크(terrain_light_mask)에만 닿는다. 몸(네크로맨서·언데드·몬스터)은 마스크가 달라 늘 원래 밝기다
## - 벽 그림자는 PlaceholderWalls가 만든다 (WallOccluderRects). 바닥 쪽 벽 가장자리 wall_rim픽셀 띠는 빛을 받는다
## - 몬스터와 sight_hidden 그룹(바닥 물건·시체·몬스터의 돌)은 VisionRules(부채꼴 + 벽 가림)로 물체마다 판정해서
##   fade_time에 걸쳐 나타나고 사라진다. 언데드는 항상 보인다 (건드리지 않는다)
## - 언데드마다 자기 시야(몬스터 데이터의 SightData: 부채꼴, 벽 가림)의 빛을 하나씩 단다. 언데드가 바라보는 쪽(Undead.facing)으로 돌고,
##   지형을 SightData.brightness만큼 밝힌다 (플레이어 빛과 겹치면 더 밝아진다). 몬스터·물건은 플레이어나 언데드 중 하나에라도 보이면 보인다
## - 개발 빌드에서만 toggle_key로 시야를 끄고 켤 수 있다 (배포판에서는 키가 동작하지 않는다)

## 빛이 없는 지형의 밝기 (원래 색에 곱한다)
@export var darkness: float = 0.4
## 시야 빛과 벽 그림자가 닿는 빛 마스크 (지형만 이 마스크를 쓴다)
@export_flags_2d_render var terrain_light_mask: int = 2
## 빛 그림 반지름 (게임 픽셀). 화면 구석(가운데에서 약 367)까지 덮는다. 몬스터를 보는 거리도 이 값이다
@export var light_radius: float = 448.0
## 빛 그림 한 칸이 게임 픽셀 몇 개인지 (그림을 작게 만들어 늘린다)
@export var light_texel: int = 2
## 빛 그림 바깥 가장자리가 어두워지는 폭 (게임 픽셀)
@export var light_edge: float = 32.0
## 바닥 쪽 벽 가장자리에서 빛을 받는 띠 두께 (픽셀, 사용자 결정 7)
@export var wall_rim: float = 7.0
## 바닥에서 몇 칸 안의 벽까지 그림자 모양을 만드는지
@export var occluder_depth: int = 2
## 몬스터·물건이 나타나고 사라지는 시간 (초)
@export var fade_time: float = 0.15
## 개발용 시야 켜고 끄기 키
@export var toggle_key: Key = KEY_F2
@export_group("시야 규칙")
## 바라보는 방향에서 좌우 이 각도까지 완전히 밝다 (도)
@export var full_angle: float = 23.0
## 보이는 범위 전체: 좌우 이 각도 (도). full_angle부터 여기까지 매끄럽게 어두워진다
@export var total_angle: float = 35.0
## 방향과 상관없이 보이는 둘레 반지름 (픽셀, 제안값 1.5칸)
@export var near_radius: float = 48.0
## 둘레 원 바깥으로 어두워지는 폭 (픽셀)
@export var near_fade: float = 8.0

## 같은 값으로 만든 빛 그림은 다시 만들지 않는다 (지역을 오갈 때)
static var _texture_cache: Dictionary = {}

var rules: VisionRules = VisionRules.new()
## 시야 규칙을 쓰는 중인지 (개발용 키로 끌 수 있다)
var active: bool = true
## 확인용: ZERO가 아니면 마우스 대신 이 방향을 바라본다 (스크린샷·시나리오)
var facing_override: Vector2 = Vector2.ZERO
## 확인용: 마지막 프레임 처리에 걸린 시간 (마이크로초)
var last_update_usec: int = 0
## 확인용: 벽 그림자 모양 수 (합치기 전 칸 수, 합친 뒤 사각형 수)와 준비(_ready)에 걸린 시간 (마이크로초)
var occluder_counts: Vector2i = Vector2i.ZERO
var setup_usec: int = 0

var _necromancer: Necromancer
var _walls: PlaceholderWalls
var _terrain: Array[CanvasItem] = []
var _light: PointLight2D
var _origin: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.ZERO
## 언데드마다 단 빛 (Undead → PointLight2D)과 시야 데이터마다 판정 규칙 (SightData → VisionRules)
var _undead_lights: Dictionary = {}
var _sight_rules: Dictionary = {}


## Region이 트리에 넣기 전에 부른다. terrain: 어둡게 칠할 지형 노드들 (아래 자식까지 빛 마스크를 바꾼다)
func setup(necromancer: Necromancer, walls: PlaceholderWalls, terrain: Array[CanvasItem]) -> void:
	_necromancer = necromancer
	_walls = walls
	_terrain = terrain


func _ready() -> void:
	var started: int = Time.get_ticks_usec()
	rules.full_angle = full_angle
	rules.total_angle = total_angle
	rules.near_radius = near_radius
	rules.view_range = light_radius
	if _walls != null:
		rules.set_walls(_walls.wall_grid(), _walls.grid_size(), _walls.tile_size, _walls.global_position)
		occluder_counts = _walls.add_light_occluders(wall_rim, occluder_depth, terrain_light_mask)
	for item: CanvasItem in _terrain:
		_set_light_mask(item)
	_light = _make_light(_light_texture(light_radius, full_angle, total_angle, near_radius, near_fade), 1.0)
	add_child(_light)
	_apply_darkness()
	setup_usec = Time.get_ticks_usec() - started


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == toggle_key and OS.is_debug_build():
		set_active(not active)
		get_viewport().set_input_as_handled()


## 시야 규칙을 켜거나 끈다 (끄면 지형이 원래 밝기이고 모두 보인다).
func set_active(value: bool) -> void:
	active = value
	_light.enabled = active
	for light: PointLight2D in _undead_lights.values():
		light.enabled = active
	_apply_darkness()
	if not active:
		for node: Node in _hideable():
			var item: CanvasItem = node as CanvasItem
			item.remove_meta(&"sight_alpha")
			item.modulate.a = 1.0
			item.visible = true


func _process(delta: float) -> void:
	if not active or not is_instance_valid(_necromancer):
		return
	var started: int = Time.get_ticks_usec()
	_origin = _necromancer.get_body_center()
	if facing_override != Vector2.ZERO:
		_facing = facing_override
	else:
		var to_mouse: Vector2 = _necromancer.get_global_mouse_position() - _origin
		if to_mouse != Vector2.ZERO:
			_facing = to_mouse
	_light.global_position = _origin
	_light.rotation = _facing.angle()
	_update_undead_lights()
	var step: float = delta / fade_time if fade_time > 0.0 else 1.0
	for node: Node in _hideable():
		var item: Node2D = node as Node2D
		var target: float = 1.0 if is_visible_at(item.global_position) else 0.0
		# 새로 생긴 물체는 지금 판정대로 바로 보이거나 숨는다.
		var alpha: float = move_toward(item.get_meta(&"sight_alpha", target), target, step)
		item.set_meta(&"sight_alpha", alpha)
		item.modulate.a = alpha
		item.visible = alpha > 0.0
	last_update_usec = Time.get_ticks_usec() - started


## world 위치가 지금 보이는지: 플레이어 시야(부채꼴·둘레 원 안이고 벽에 가리지 않음)나 언데드 시야 중 하나에라도 들어오면. 시야를 끄면 늘 보인다.
func is_visible_at(world: Vector2) -> bool:
	if is_visible_to_player(world):
		return true
	for undead: Variant in _undead_lights.keys():
		if is_instance_valid(undead) and _undead_sees(undead as Undead, world):
			return true
	return false


## 플레이어 시야로만 world 위치가 보이는지
func is_visible_to_player(world: Vector2) -> bool:
	return not active or rules.level_with_walls(_origin, _facing, world) < rules.hidden_level()


func _undead_sees(undead: Undead, world: Vector2) -> bool:
	var sight_rules: VisionRules = _rules_for(undead.data.get_undead_sight())
	var origin: Vector2 = undead.get_sight_origin()
	if origin.distance_squared_to(world) > sight_rules.view_range * sight_rules.view_range:
		return false
	return sight_rules.level_with_walls(origin, undead.facing, world) < sight_rules.hidden_level()


func _rules_for(sight: SightData) -> VisionRules:
	if not _sight_rules.has(sight):
		var sight_rules: VisionRules = sight.make_rules()
		if _walls != null:
			sight_rules.set_walls(_walls.wall_grid(), _walls.grid_size(), _walls.tile_size, _walls.global_position)
		_sight_rules[sight] = sight_rules
	return _sight_rules[sight]


## 소환된 언데드마다 빛을 달고(새로 생기면 만들고, 없어지면 지운다) 몸 가운데·바라보는 방향에 맞춘다.
func _update_undead_lights() -> void:
	var present: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"undead"):
		var undead: Undead = node as Undead
		if undead == null or undead.is_queued_for_deletion():
			continue
		present[undead] = true
		if not _undead_lights.has(undead):
			var sight: SightData = undead.data.get_undead_sight()
			var light: PointLight2D = _make_light(_light_texture(sight.view_range, sight.full_angle, sight.total_angle, sight.near_radius, sight.near_fade), sight.brightness)
			add_child(light)
			_undead_lights[undead] = light
		var undead_light: PointLight2D = _undead_lights[undead]
		undead_light.global_position = undead.get_sight_origin()
		undead_light.rotation = undead.facing.angle()
	for undead: Variant in _undead_lights.keys():
		if not is_instance_valid(undead) or not present.has(undead):
			(_undead_lights[undead] as PointLight2D).queue_free()
			_undead_lights.erase(undead)


## 확인용: 지금 언데드 빛 수
func get_undead_light_count() -> int:
	return _undead_lights.size()


## 지형만 밝히고 벽 그림자를 받는 빛. brightness: 이 빛만 받은 지형의 밝기 (원래 색 = 1)
func _make_light(texture: Texture2D, brightness: float) -> PointLight2D:
	var light: PointLight2D = PointLight2D.new()
	light.texture = texture
	light.texture_scale = light_texel
	# 더하기 빛은 어둡게 칠한 색에 곱해 더해진다: darkness × (1 + energy) = brightness
	light.energy = brightness / darkness - 1.0
	light.range_item_cull_mask = terrain_light_mask
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_NONE
	light.shadow_item_cull_mask = terrain_light_mask
	light.enabled = active
	return light


func _hideable() -> Array[Node]:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(&"monsters")
	nodes.append_array(get_tree().get_nodes_in_group(&"sight_hidden"))
	return nodes


func _apply_darkness() -> void:
	var b: float = darkness if active else 1.0
	for item: CanvasItem in _terrain:
		if is_instance_valid(item):
			item.modulate = Color(b, b, b, item.modulate.a)


func _set_light_mask(item: CanvasItem) -> void:
	item.light_mask = terrain_light_mask
	for child: Node in item.get_children():
		if child is CanvasItem:
			_set_light_mask(child as CanvasItem)


## 부채꼴(full까지 밝고 total까지 매끄럽게 어두워짐, 바깥 light_edge 폭에서 어두워짐)과
## 둘레 원(near, 바깥 near_fade_width 폭. near가 0이면 없음)을 합친 빛 그림. 바라보는 방향은 +x다. 위아래가 같아 절반만 계산한다.
func _light_texture(radius: float, full: float, total: float, near: float, near_fade_width: float) -> ImageTexture:
	var key: String = "%s/%s/%s/%s/%s/%s/%s" % [radius, light_texel, light_edge, full, total, near, near_fade_width]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var half: int = ceili(radius / light_texel)
	var size: int = half * 2
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size * size)
	for y: int in half:
		for x: int in size:
			var offset: Vector2 = Vector2(x + 0.5 - half, y + 0.5 - half) * light_texel
			var distance: float = offset.length()
			var angle: float = absf(rad_to_deg(offset.angle()))
			var v: float = 1.0 - clampf((angle - full) / (total - full), 0.0, 1.0)
			v *= 1.0 - clampf((distance - (radius - light_edge)) / light_edge, 0.0, 1.0)
			if near > 0.0:
				v = maxf(v, 1.0 - clampf((distance - near) / near_fade_width, 0.0, 1.0))
			var value: int = roundi(v * 255.0)
			bytes[y * size + x] = value
			bytes[(size - 1 - y) * size + x] = value
	var texture: ImageTexture = ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_L8, bytes))
	_texture_cache[key] = texture
	return texture
