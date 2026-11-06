class_name Stone
extends Area2D
## 고블린 투석병이 던지는 돌. 곧게 날아가다 처음 닿는 몸이나 벽에서 멈춘다 (사라진다).
## - 던진 쪽의 적(hostile_groups에 든 몸)에 닿으면 피해를 주고 멈춘다
## - 그 밖의 몸(다른 몬스터 등)이나 벽에 닿으면 피해 없이 막혀 멈춘다. 던진 몸 자신과 pass_groups에 든 몸은 지나간다
## - max_distance를 다 날면 사라진다
## 속도·피해·사거리·적 그룹은 던지는 쪽(행동 조각 ThrowBehavior)이 정해서 넣는다.

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
var _traveled: float = 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = placeholder_radius
	_collision.shape = shape
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step: float = speed * delta
	position += direction * step
	_traveled += step
	if _traveled >= max_distance:
		queue_free()


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
	draw_circle(Vector2.ZERO, placeholder_radius, placeholder_color)
