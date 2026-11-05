class_name Monster
extends CharacterBody2D
## MonsterData 하나로 움직이는 몬스터.
## 배회하다가 네크로맨서나 언데드가 감지 범위에 들어오면, 그중 가장 가까운 대상을 쫓아가 몸으로 부딪혀 공격한다.
## 죽으면 드랍 목록(data.drops)의 확률을 굴려 나온 것을 담은 시체(Corpse)를 남긴다. 네크로맨서가 시체에서 채집한다.

@export var data: MonsterData
## 죽을 때 남길 시체 씬
@export var corpse_scene: PackedScene
## 맞았을 때 하얗게 번쩍이는 시간 (초)
@export var hit_flash_duration: float = 0.1

var health: float
## 지금 쫓는 대상 (네크로맨서 또는 언데드). take_damage(amount)가 있어야 한다.
var _target: Node2D
var _wander_direction: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _attack_timer: float = 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	health = data.max_health
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = data.placeholder_radius
	_collision.shape = shape
	_collision.position = Vector2(0, -data.placeholder_radius)


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_target = _find_nearest_target()
	if _target != null:
		_chase()
	else:
		_wander(delta)
	move_and_slide()


func _chase() -> void:
	var to_target: Vector2 = _target.global_position - global_position
	if to_target.length() > data.attack_range:
		velocity = to_target.normalized() * data.move_speed
		return
	velocity = Vector2.ZERO
	if _attack_timer == 0.0:
		_attack_timer = data.attack_cooldown
		# 네크로맨서와 언데드는 서로 다른 클래스라서 이름으로 부른다.
		_target.call(&"take_damage", data.contact_damage)


func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = data.wander_interval
		if randf() < data.wander_rest_chance:
			_wander_direction = Vector2.ZERO
		else:
			_wander_direction = Vector2.from_angle(randf() * TAU)
	velocity = _wander_direction * data.wander_speed


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
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
	# 그림이 생기기 전까지 쓰는 임시 도형. 기준점(발밑) 위에 원을 그린다.
	draw_circle(Vector2(0, -data.placeholder_radius), data.placeholder_radius, data.placeholder_color)


## 감지 범위 안의 네크로맨서·언데드 중 가장 가까운 것. 없으면 null.
## 몬스터는 둘을 똑같이 적으로 본다.
func _find_nearest_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = data.detect_range * data.detect_range
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
