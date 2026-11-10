class_name Stone
extends Area2D
## 고블린 투석병이 던지는 돌. 곧게 날아가다 처음 닿는 몸이나 벽에서 멈춘다 (사라진다). 포물선은 그림만이고 충돌은 땅 높이다.
## 떨어질 곳(max_distance만큼 날아간 곳)에는 그림자 원이 그려지고, 도착하면 원 안의 가장 가까운 적 하나가 맞는다.
## - 던진 쪽의 적(hostile_groups에 든 몸)에 닿으면 피해를 주고 멈춘다
## - 그 밖의 몸(다른 몬스터 등)이나 벽에 닿으면 피해 없이 막혀 멈춘다. 던진 몸 자신과 pass_groups에 든 몸은 지나간다
## - max_distance를 다 날면 사라진다
## 속도·피해·사거리·적 그룹은 던지는 쪽(행동 조각 ThrowBehavior)이 정해서 넣는다.

## 닿으면 멈추는 벽의 충돌층
@export_flags_2d_physics var wall_mask: int = 1

@export_group("임시 도형")
## 돌 색 (Endesga 32의 c28569)
@export var placeholder_color: Color = Color(0.7607843, 0.52156866, 0.4117647, 1)
## 그림과 충돌 판정에 같이 쓰는 원의 반지름
@export var placeholder_radius: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var damage: float = 0.0
var max_distance: float = 0.0
## 던진 쪽 (맞은 쪽이 누구에게 맞았는지 안다). 날아가는 동안 사라질 수 있다.
var thrower: Node2D
## 피해를 줄 그룹들 (적 투석병이면 necromancer·undead, 언데드 투석병이면 monsters)
var hostile_groups: Array[StringName] = []
## 지나가는 그룹들 (언데드 투석병의 돌은 네크로맨서·언데드를 지나간다)
var pass_groups: Array[StringName] = []
## 떨어지는 곳의 반지름. 0이면 그림자를 그리지 않고 도착해도 아무도 맞지 않는다
var landing_radius: float = 0.0
## 포물선 그림의 가장 높은 곳, 돌 높이에서 발밑까지의 거리, 그림자 원의 색 (던지는 쪽의 표시 색)
var arc_height: float = 0.0
var ground_offset: float = 0.0
var shadow_color: Color = Color.WHITE
var _traveled: float = 0.0
var _shadow: StoneShadow

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	# 시야 밖에서는 보이지 않는다 (Vision).
	add_to_group(&"sight_hidden")
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = placeholder_radius
	_collision.shape = shape
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# 몸에 맞아 지워지기를 기다리는 돌은 더 날아가거나 도착 판정을 하지 않는다 (피해가 두 번 들어가지 않게).
	if is_queued_for_deletion():
		return
	var step: float = speed * delta
	# 벽(StaticBody2D)은 Area2D의 겹침으로 잡히지 않아서, 이번에 움직일 선에 벽이 있는지 따로 확인한다.
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + direction * step, wall_mask)
	# 트리 밖(단위 테스트에서 직접 부를 때)에는 물리 공간이 없어서 건너뛴다.
	if is_inside_tree() and not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		queue_free()
		return
	position += direction * step
	_traveled += step
	if arc_height > 0.0:
		queue_redraw()
	if _traveled >= max_distance:
		_land()
		queue_free()


## 지금까지 날아간 거리 (측정 봇이 떨어질 곳을 계산할 때 쓴다)
func get_traveled() -> float:
	return _traveled


## 떨어질 곳을 바닥에 표시한다 (던지는 쪽이 돌을 놓은 뒤 부른다).
func show_landing() -> void:
	if landing_radius <= 0.0:
		return
	_shadow = StoneShadow.new()
	_shadow.radius = landing_radius
	_shadow.color = shadow_color
	get_parent().add_child(_shadow)
	_shadow.global_position = global_position + direction * max_distance + Vector2(0, ground_offset)


func _exit_tree() -> void:
	if is_instance_valid(_shadow):
		_shadow.queue_free()


## 떨어질 곳에 도착했다: 그림자 원 안의 가장 가까운 적 하나가 맞는다. 없으면 그냥 사라진다.
func _land() -> void:
	if landing_radius <= 0.0 or not is_inside_tree():
		return
	var ground: Vector2 = global_position + Vector2(0, ground_offset)
	var bodies: Array[Node2D] = []
	var positions: Array[Vector2] = []
	for group: StringName in hostile_groups:
		for node: Node in get_tree().get_nodes_in_group(group):
			var body: Node2D = node as Node2D
			if body == null or body == thrower or body.is_queued_for_deletion() or _in_groups(body, pass_groups):
				continue
			bodies.append(body)
			positions.append(body.global_position)
	var index: int = nearest_in_radius(ground, landing_radius, positions)
	if index >= 0:
		bodies[index].call(&"take_damage", damage, thrower if is_instance_valid(thrower) else null)


## positions 중 ground에서 radius 안의 가장 가까운 것의 번호. 없으면 -1.
static func nearest_in_radius(ground: Vector2, radius: float, positions: Array[Vector2]) -> int:
	var best: int = -1
	var best_distance: float = radius
	for i: int in positions.size():
		var distance: float = positions[i].distance_to(ground)
		if distance <= best_distance:
			best = i
			best_distance = distance
	return best


func _on_body_entered(body: Node2D) -> void:
	# 한 프레임에 두 몸에 동시에 닿아도 하나만 친다.
	if is_queued_for_deletion() or body == thrower or _in_groups(body, pass_groups):
		return
	if _in_groups(body, hostile_groups):
		body.call(&"take_damage", damage, thrower if is_instance_valid(thrower) else null)
	queue_free()


func _in_groups(body: Node2D, groups: Array[StringName]) -> bool:
	for group: StringName in groups:
		if body.is_in_group(group):
			return true
	return false


func _draw() -> void:
	draw_circle(Vector2(0, -_arc_offset()), placeholder_radius, placeholder_color)


## 3D 화면 층이 쓰는 지금 높이 (픽셀): 던진 높이 + 포물선
func get_view_height() -> float:
	return ground_offset + _arc_offset()


## 포물선 그림의 지금 높이 (충돌과 상관없이 그림만 올린다)
func _arc_offset() -> float:
	if arc_height <= 0.0 or max_distance <= 0.0:
		return 0.0
	var t: float = clampf(_traveled / max_distance, 0.0, 1.0)
	return 4.0 * arc_height * t * (1.0 - t)
