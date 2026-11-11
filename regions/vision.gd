class_name Vision
extends Node
## 플레이어 시야 (화면에만 쓴다). 지역 데이터의 limit_vision이 켜진 지역에서 Region이 붙인다 (거점에는 없다).
## 무엇이 보이는지를 판정한다. 지형을 밝히는 일은 3D 화면 층(SightLights)이 이 노드의 값을 읽어서 한다.
## - 몬스터와 sight_hidden 그룹(바닥 물건·시체·몬스터의 돌)은 VisionRules(부채꼴 + 벽 가림)로 물체마다 판정해서
##   fade_time에 걸쳐 나타나고 사라진다. 언데드는 항상 보인다 (건드리지 않는다)
## - 언데드마다 자기 시야(몬스터 데이터의 SightData: 부채꼴, 벽 가림)가 있다. 몬스터·물건은 플레이어나 언데드 중 하나에라도 보이면 보인다
## - 개발 빌드에서만 toggle_key로 시야를 끄고 켤 수 있다 (배포판에서는 키가 동작하지 않는다)

## 빛이 없는 지형의 밝기 (원래 색에 곱한다)
@export var darkness: float = 0.4
## 보는 거리 (게임 픽셀). 화면 구석(가운데에서 약 367)까지 덮는다
@export var light_radius: float = 448.0
## 보는 거리 끝에서 어두워지는 폭 (게임 픽셀)
@export var light_edge: float = 32.0
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

var rules: VisionRules = VisionRules.new()
## 시야 규칙을 쓰는 중인지 (개발용 키로 끌 수 있다)
var active: bool = true
## 확인용: ZERO가 아니면 마우스 대신 이 방향을 바라본다 (스크린샷·시나리오)
var facing_override: Vector2 = Vector2.ZERO
## 확인용: 마지막 프레임 처리에 걸린 시간 (마이크로초)
var last_update_usec: int = 0
## 확인용: 준비(_ready)에 걸린 시간 (마이크로초)
var setup_usec: int = 0

var _necromancer: Necromancer
var _walls: PlaceholderWalls
var _origin: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.ZERO
## 지금 소환된 언데드들과, 시야 데이터마다 판정 규칙 (SightData → VisionRules)
var _undead_list: Array[Undead] = []
var _sight_rules: Dictionary = {}


## Region이 트리에 넣기 전에 부른다.
func setup(necromancer: Necromancer, walls: PlaceholderWalls) -> void:
	_necromancer = necromancer
	_walls = walls


func _ready() -> void:
	var started: int = Time.get_ticks_usec()
	rules.full_angle = full_angle
	rules.total_angle = total_angle
	rules.near_radius = near_radius
	rules.view_range = light_radius
	_set_rule_walls(rules)
	setup_usec = Time.get_ticks_usec() - started


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == toggle_key and OS.is_debug_build():
		set_active(not active)
		get_viewport().set_input_as_handled()


func get_origin() -> Vector2:
	return _origin


func get_facing() -> Vector2:
	return _facing


## 지형을 밝힐 언데드들 (네크로맨서에게 가까운 순서로 limit마리까지)
func get_lit_undead(limit: int) -> Array[Undead]:
	var list: Array[Undead] = _undead_list.filter(func(undead: Undead) -> bool: return is_instance_valid(undead))
	list.sort_custom(func(a: Undead, b: Undead) -> bool: return a.global_position.distance_squared_to(_origin) < b.global_position.distance_squared_to(_origin))
	return list.slice(0, limit)


## 시야 규칙을 켜거나 끈다 (끄면 지형이 원래 밝기이고 모두 보인다).
func set_active(value: bool) -> void:
	active = value
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
		var to_mouse: Vector2 = _necromancer.get_aim_position() - _origin
		if to_mouse != Vector2.ZERO:
			_facing = to_mouse
	_update_undead_list()
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
	for undead: Undead in _undead_list:
		if is_instance_valid(undead) and _undead_sees(undead, world):
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
		_set_rule_walls(sight_rules)
		_sight_rules[sight] = sight_rules
	return _sight_rules[sight]


## 시야 판정에 벽을 넣는다. 윤곽이 있는 지역은 윤곽의 작은 칸, 없으면 벽 타일이다.
func _set_rule_walls(target: VisionRules) -> void:
	if _walls == null:
		return
	if _walls.outline != null:
		target.set_walls(_walls.outline.sight_cells, _walls.outline.sight_size(), _walls.outline.settings.sight_cell_px, _walls.global_position)
	else:
		target.set_walls(_walls.wall_grid(), _walls.grid_size(), _walls.tile_size, _walls.global_position)


## 지금 소환된 언데드 목록을 새로 만든다.
func _update_undead_list() -> void:
	_undead_list.clear()
	for node: Node in get_tree().get_nodes_in_group(&"undead"):
		var undead: Undead = node as Undead
		if undead != null and not undead.is_queued_for_deletion():
			_undead_list.append(undead)


## 확인용: 지금 시야를 가진 언데드 수
func get_undead_sight_count() -> int:
	return _undead_list.size()


func _hideable() -> Array[Node]:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(&"monsters")
	nodes.append_array(get_tree().get_nodes_in_group(&"sight_hidden"))
	return nodes
