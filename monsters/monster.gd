class_name Monster
extends CharacterBody2D
## MonsterData 하나로 움직이는 몬스터.
## 배회하다가 네크로맨서나 언데드가 감지 범위에 들어오면 그중 가장 가까운 대상을 노린다.
## 감지 범위에 아무도 없을 때 맞으면 공격한 대상을 쫓고, 너무 멀어지면 포기하고 맞기 시작한 자리로 돌아간다 (Aggro).
## 무리(부모가 MonsterPack)에 속하면 어그로를 공유한다: 무리가 싸우는 중이면 감지 범위 밖이어도 가장 가까운 대상을 노린다.
## 대상과 어떻게 싸울지는 데이터의 행동 조각(data.behavior)이 정하고, 수치는 적일 때의 값(data.get_enemy_stats())을 쓴다.
## 죽으면 드랍 목록(data.drops)의 확률을 굴려 나온 것을 담은 시체(Corpse)를 남긴다. 네크로맨서가 시체에서 채집한다.

@export var data: MonsterData
## 죽을 때 남길 시체 씬
@export var corpse_scene: PackedScene
## 맞았을 때 하얗게 번쩍이는 시간 (초)
@export var hit_flash_duration: float = 0.1
## 포기하고 돌아갈 때, 맞기 시작한 자리에서 이 거리 안이면 다 돌아온 것으로 본다 (픽셀)
@export var return_arrive_distance: float = 4.0
## 날아다니는 몬스터(data.flying)가 쓰는 충돌층과, 부딪히는 대상(벽)
@export_flags_2d_physics var flying_layer: int = 32
@export_flags_2d_physics var flying_mask: int = 1
## 행동 조각이 바닥에 그리는 예고 표시(돌진 방향 선 등)의 색. 적은 위험 표시 색(e83b3b)이다.
@export var indicator_color: Color = Color(0.9098039, 0.23137255, 0.23137255, 1)

var health: float
## 지금 노리는 대상 (네크로맨서 또는 언데드). take_damage(amount, source)가 있어야 한다.
var _target: Node2D
var _wander_direction: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
## 대상과 싸우는 방식 (data.behavior의 이 몬스터용 복사본)
var _behavior: MonsterBehavior
var _knockback: Knockback = Knockback.new()
## 감지 범위 밖에서 맞았을 때 공격자를 쫓는 규칙
var _aggro: Aggro
## 속한 무리 (없으면 null)
var _pack: MonsterPack
## 이 몬스터가 직접 싸우는 중인지 (감지 범위에 대상이 있거나 공격자를 쫓는 중). 무리가 읽는다.
var _engaged_by_itself: bool = false

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	health = data.max_health
	_behavior = data.make_enemy_behavior()
	_aggro = Aggro.new(data.chase_attacker_limit, data.chase_home_limit, return_arrive_distance)
	_pack = get_parent() as MonsterPack
	_collision.shape = PlaceholderBody.make_shape(data)
	_collision.rotation = PlaceholderBody.shape_rotation(data)
	_collision.position = PlaceholderBody.center(data)
	# 날아다니는 몸은 벽하고만 부딪히고, 다른 몸도 이 몸에 부딪히지 않는다 (탄은 이 층도 검사한다).
	if data.flying:
		collision_layer = flying_layer
		collision_mask = flying_mask


func _physics_process(delta: float) -> void:
	_behavior.update(delta)
	var nearest: Node2D = _find_nearest_target()
	var attacker: Node2D = _aggro.attacker as Node2D
	var attacker_alive: bool = is_instance_valid(attacker) and not attacker.is_queued_for_deletion()
	_aggro.update(global_position, nearest != null, attacker_alive, attacker.global_position if attacker_alive else Vector2.ZERO)
	match _aggro.state:
		Aggro.State.CHASING:
			_target = _aggro.attacker as Node2D
		Aggro.State.RETURNING:
			_target = null
		_:
			_target = nearest
			# 무리가 싸우는 중이면 감지 범위 밖이어도 가장 가까운 대상을 노린다.
			if _target == null and _pack != null and _pack.is_engaged():
				_target = _find_nearest_target(INF)
	_engaged_by_itself = nearest != null or _aggro.state == Aggro.State.CHASING
	# 하던 동작(돌진 예고 등)은 대상이 사라져도 이어 간다.
	if _target != null or _behavior.is_busy():
		_behavior.act(self, data.get_enemy_stats(), _target, delta)
	elif _aggro.state == Aggro.State.RETURNING:
		velocity = global_position.direction_to(_aggro.origin) * data.move_speed
	else:
		_wander(delta)
	if _knockback.is_active():
		velocity = _knockback.get_velocity()
	move_and_slide()
	_knockback.update(delta)
	# 예고 표시(깜빡임, 방향 선)가 프레임마다 바뀐다.
	queue_redraw()


## 이 몬스터가 직접 싸우는 중인지 (무리의 어그로 공유가 읽는다)
func is_engaged_by_itself() -> bool:
	return _engaged_by_itself


## 테스트·디버그용: 지금 노리는 대상 (없으면 null)
func get_target() -> Node2D:
	return _target


## 테스트·디버그용: 공격자 추격 상태 (Aggro.State)와 맞기 시작한 자리
func get_aggro() -> Aggro:
	return _aggro


## 테스트·디버그용: 이 한 마리가 쓰는 행동 조각
func get_behavior() -> MonsterBehavior:
	return _behavior


## 돌진처럼 여러 상대를 치는 행동 조각이 칠 수 있는 상대: 네크로맨서와 언데드.
func get_hostiles() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var candidates: Array[Node] = get_tree().get_nodes_in_group(&"necromancer")
	candidates.append_array(get_tree().get_nodes_in_group(&"undead"))
	for node: Node in candidates:
		if node is Node2D and not node.is_queued_for_deletion():
			result.append(node as Node2D)
	return result


## offset만큼 duration초 동안 밀려난다 (언데드 멧돼지의 돌진 등).
func knock_back(offset: Vector2, duration: float) -> void:
	_knockback.start(offset, duration)


func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = data.wander_interval
		if randf() < data.wander_rest_chance:
			_wander_direction = Vector2.ZERO
		else:
			_wander_direction = Vector2.from_angle(randf() * TAU)
	velocity = _wander_direction * data.wander_speed


## source는 공격한 쪽. 감지 범위에 아무도 없을 때 맞으면 그 대상을 쫓는다.
func take_damage(amount: float, source: Node2D = null) -> void:
	if health <= 0.0:
		return
	_aggro.on_hit(source, global_position, _find_nearest_target() != null)
	health -= amount
	if health <= 0.0:
		_die()
		return
	modulate = Color(3, 3, 3)
	create_tween().tween_property(self, "modulate", Color.WHITE, hit_flash_duration)


func _die() -> void:
	# 머리뼈가 나올지는 죽는 이 순간에 정해진다. 시체는 정해진 것만 담는다.
	var corpse: Corpse = corpse_scene.instantiate()
	corpse.setup(data, CorpseLoot.from_drops(DropRoller.roll(data.drops), data.harvest_base_time))
	corpse.position = position
	# 물리 처리 중(탄에 맞은 순간)에는 Area2D를 바로 추가할 수 없어서 미룬다.
	get_parent().add_child.call_deferred(corpse)
	queue_free()


func _draw() -> void:
	# 그림이 생기기 전까지 쓰는 임시 도형. 바닥의 예고 표시를 먼저 그리고, 기준점(발밑) 위에 몸을 그린다.
	_behavior.draw_overlay(self, indicator_color)
	PlaceholderBody.draw(self, data, _behavior.get_body_color(data.placeholder_color), PlaceholderBody.center(data))


## max_range 안(기본: 감지 범위)의 네크로맨서·언데드 중 가장 가까운 것. 없으면 null.
## 몬스터는 둘을 똑같이 적으로 본다.
func _find_nearest_target(max_range: float = -1.0) -> Node2D:
	var nearest: Node2D = null
	var limit: float = data.detect_range if max_range < 0.0 else max_range
	var nearest_distance: float = limit * limit
	var candidates: Array[Node] = get_tree().get_nodes_in_group(&"necromancer")
	candidates.append_array(get_tree().get_nodes_in_group(&"undead"))
	for node: Node in candidates:
		var candidate: Node2D = node as Node2D
		if candidate == null or candidate.is_queued_for_deletion():
			continue
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest
