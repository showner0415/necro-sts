class_name Undead
extends CharacterBody2D
## 머리뼈 하나로 소환한 언데드 한 마리. 능력치는 원본 몬스터 데이터의 "언데드" 값을 따른다.
## - 적이 없으면 네크로맨서와 follow_distance 안에 있도록 따라다닌다. catch_up_distance보다 멀면 네크로맨서가 뛰는 속도로 따라간다
## - 감지 범위 안의 가장 가까운 몬스터와 싸운다. 싸우는 방식은 원본 몬스터의 언데드용 행동 조각(data.make_undead_behavior())이고, 수치는 언데드 값이다
## - 쫓는 몬스터가 네크로맨서에게서 leash_distance보다 멀면 그만두고 돌아온다
## 체력·내구도는 이 노드가 아니라 머리뼈(Skull)에 있다. 피해를 받으면 damage_received로 알리기만 하고,
## 실제 계산과 사라지는 판단은 UndeadRoster가 한다 (Summoner가 연결한다).

signal damage_received(skull: Skull, amount: float)

## 네크로맨서에게서 이 거리 안이면 따라가지 않고 멈춘다 (픽셀, 임시값)
@export var follow_distance: float = 28.0
## 네크로맨서에게서 이 거리보다 먼 몬스터는 쫓지 않는다 (픽셀, 임시값)
@export var leash_distance: float = 120.0
## 따라가는 중에 네크로맨서에게서 이 거리보다 멀면 catch_up_speed로 빨라진다 (픽셀, 임시값)
@export var catch_up_distance: float = 48.0
## 맞았을 때 하얗게 번쩍이는 시간 (초)
@export var hit_flash_duration: float = 0.1
## 행동 조각이 바닥에 그리는 예고 표시(돌진 방향 선 등)의 색. 적의 표시(빨강)와 구별되는 아군 색(30e1b9)이다.
@export var indicator_color: Color = Color(0.1882353, 0.88235295, 0.7254902, 1)

var skull: Skull
var data: MonsterData
var _master: Node2D
## 멀리 떨어져 따라갈 때의 속도. 소환할 때 네크로맨서의 뛰는 속도를 넣어 준다. 언데드 자기 속도보다 느리면 쓰지 않는다.
var catch_up_speed: float = 0.0
## 몬스터와 싸우는 방식 (원본 몬스터의 언데드용 행동 조각 복사본)
var _behavior: MonsterBehavior
var _knockback: Knockback = Knockback.new()

@onready var _collision: CollisionShape2D = $CollisionShape2D


## 소환할 때 바깥에서 넣어 준다. 트리에 넣기 전에 부른다.
func setup(summoned_skull: Skull, monster_data: MonsterData, master: Node2D) -> void:
	skull = summoned_skull
	data = monster_data
	_master = master


func _ready() -> void:
	_behavior = data.make_undead_behavior()
	_collision.shape = PlaceholderBody.make_shape(data)
	_collision.rotation = PlaceholderBody.shape_rotation(data)
	_collision.position = PlaceholderBody.center(data)


func _physics_process(delta: float) -> void:
	_behavior.update(delta)
	var target: Monster = _find_target()
	# 하던 동작(돌진 예고 등)은 대상이 사라져도 이어 간다.
	if target != null or _behavior.is_busy():
		_behavior.act(self, data.get_undead_stats(), target, delta)
	else:
		_follow()
	if _knockback.is_active():
		velocity = _knockback.get_velocity()
	move_and_slide()
	_knockback.update(delta)
	# 예고 표시(깜빡임, 방향 선)가 프레임마다 바뀐다.
	queue_redraw()


## 테스트·디버그용: 이 한 마리가 쓰는 행동 조각
func get_behavior() -> MonsterBehavior:
	return _behavior


## 돌진처럼 여러 상대를 치는 행동 조각이 칠 수 있는 상대: 살아 있는 몬스터만.
func get_hostiles() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node: Node in get_tree().get_nodes_in_group(&"monsters"):
		var monster: Monster = node as Monster
		if monster != null and not monster.is_queued_for_deletion() and monster.health > 0.0:
			result.append(monster)
	return result


## offset만큼 duration초 동안 밀려난다 (적 멧돼지의 돌진 등).
func knock_back(offset: Vector2, duration: float) -> void:
	_knockback.start(offset, duration)


func _follow() -> void:
	if not is_instance_valid(_master):
		velocity = Vector2.ZERO
		return
	var to_master: Vector2 = _master.global_position - global_position
	var distance: float = to_master.length()
	if distance <= follow_distance:
		velocity = Vector2.ZERO
		return
	# 싸울 때는 원래 속도이고, 멀리 떨어져 따라갈 때만 빨라진다.
	var speed: float = maxf(data.undead_move_speed, catch_up_speed) if distance > catch_up_distance else data.undead_move_speed
	velocity = to_master.normalized() * speed


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
	# 그림이 생기기 전까지 쓰는 임시 도형. 원본 몬스터와 같은 모양·크기를 언데드 색으로 그린다.
	_behavior.draw_overlay(self, indicator_color)
	PlaceholderBody.draw(self, data, _behavior.get_body_color(data.undead_placeholder_color), PlaceholderBody.center(data))
