class_name Bolt
extends Area2D
## 네크로맨서의 기본 공격 탄. 곧게 날아가다 몬스터(날아다니는 몬스터 포함)에 맞거나 사거리를 넘으면 사라진다.
## 맞히면 hit_target으로 알린다 (밸런스 측정에서 명중률을 셀 때 쓴다).

signal hit_target(body: Node2D)
## 속도·피해·사거리·크기는 쏘는 쪽(Necromancer)이 공격 데이터(AttackData)에서 정해서 넣는다.

@export_group("임시 도형")
@export var placeholder_color: Color = Color(0.17254902, 0.9098039, 0.9607843, 1)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var damage: float = 0.0
var max_distance: float = 0.0
## 보이는 원의 반지름
var visual_radius: float = 2.0
## 맞는 범위(충돌 원)의 반지름
var hit_radius: float = 2.0
## 쏜 쪽 (네크로맨서). 맞은 몬스터가 누구에게 맞았는지 안다.
var source: Node2D
var _traveled: float = 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = hit_radius
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
		(body as Monster).take_damage(damage, source)
		hit_target.emit(body)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, visual_radius, placeholder_color)
