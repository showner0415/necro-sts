class_name Bolt
extends Area2D
## 네크로맨서의 기본 공격 탄. 곧게 날아가다 몬스터에 맞거나 사거리를 넘으면 사라진다.
## 속도·피해·사거리는 쏘는 쪽(Necromancer)이 정해서 넣는다.

@export_group("임시 도형")
@export var placeholder_color: Color = Color(0.56078434, 0.972549, 0.8862745, 1)
## 그림과 충돌 판정에 같이 쓰는 원의 반지름
@export var placeholder_radius: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var damage: float = 0.0
var max_distance: float = 0.0
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
	# 한 프레임에 두 몬스터에 동시에 닿아도 한 마리만 맞힌다.
	if is_queued_for_deletion():
		return
	if body is Monster:
		(body as Monster).take_damage(damage)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, placeholder_radius, placeholder_color)
