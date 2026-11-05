class_name Undead
extends CharacterBody2D
## 머리뼈 하나로 소환한 언데드 한 마리. 능력치는 원본 몬스터 데이터의 "언데드" 값을 따른다.
## - 적이 없으면 네크로맨서와 follow_distance 안에 있도록 따라다닌다
## - 감지 범위 안의 가장 가까운 몬스터를 쫓아가 몸으로 부딪혀 공격한다
## - 쫓는 몬스터가 네크로맨서에게서 leash_distance보다 멀면 그만두고 돌아온다
## 체력·내구도는 이 노드가 아니라 머리뼈(Skull)에 있다. 피해를 받으면 damage_received로 알리기만 하고,
## 실제 계산과 사라지는 판단은 UndeadRoster가 한다 (Summoner가 연결한다).

signal damage_received(skull: Skull, amount: float)

## 네크로맨서에게서 이 거리 안이면 따라가지 않고 멈춘다 (픽셀, 임시값)
@export var follow_distance: float = 28.0
## 네크로맨서에게서 이 거리보다 먼 몬스터는 쫓지 않는다 (픽셀, 임시값)
@export var leash_distance: float = 120.0
## 맞았을 때 하얗게 번쩍이는 시간 (초)
@export var hit_flash_duration: float = 0.1

var skull: Skull
var data: MonsterData
var _master: Node2D
var _attack_timer: float = 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D


## 소환할 때 바깥에서 넣어 준다. 트리에 넣기 전에 부른다.
func setup(summoned_skull: Skull, monster_data: MonsterData, master: Node2D) -> void:
	skull = summoned_skull
	data = monster_data
	_master = master


func _ready() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = data.placeholder_radius
	_collision.shape = shape
	_collision.position = Vector2(0, -data.placeholder_radius)


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	var target: Monster = _find_target()
	if target != null:
		_fight(target)
	else:
		_follow()
	move_and_slide()


func _fight(target: Monster) -> void:
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() > data.undead_attack_range:
		velocity = to_target.normalized() * data.undead_move_speed
		return
	velocity = Vector2.ZERO
	if _attack_timer == 0.0:
		_attack_timer = data.undead_attack_cooldown
		target.take_damage(data.undead_contact_damage)


func _follow() -> void:
	if not is_instance_valid(_master):
		velocity = Vector2.ZERO
		return
	var to_master: Vector2 = _master.global_position - global_position
	velocity = to_master.normalized() * data.undead_move_speed if to_master.length() > follow_distance else Vector2.ZERO


func _find_target() -> Monster:
	var nearest: Monster = null
	var nearest_distance: float = data.undead_detect_range * data.undead_detect_range
	for node: Node in get_tree().get_nodes_in_group(&"monsters"):
		var monster: Monster = node as Monster
		if monster == null or monster.is_queued_for_deletion() or monster.health <= 0.0:
			continue
		if is_instance_valid(_master) and monster.global_position.distance_to(_master.global_position) > leash_distance:
			continue
		var distance: float = global_position.distance_squared_to(monster.global_position)
		if distance <= nearest_distance:
			nearest = monster
			nearest_distance = distance
	return nearest


func take_damage(amount: float) -> void:
	if is_queued_for_deletion():
		return
	damage_received.emit(skull, amount)
	# 죽거나 해제되었으면 이미 사라지는 중이다.
	if is_queued_for_deletion():
		return
	modulate = Color(3, 3, 3)
	create_tween().tween_property(self, "modulate", Color.WHITE, hit_flash_duration)


func _draw() -> void:
	# 그림이 생기기 전까지 쓰는 임시 도형. 원본 몬스터와 같은 크기의 원을 언데드 색으로 그린다.
	draw_circle(Vector2(0, -data.placeholder_radius), data.placeholder_radius, data.undead_placeholder_color)
