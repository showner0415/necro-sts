class_name Monster
extends CharacterBody2D
## MonsterData 하나로 움직이는 몬스터.
## 배회하다가 네크로맨서나 언데드가 감지 범위에 들어오면, 그중 가장 가까운 대상을 쫓아가 몸으로 부딪혀 공격한다.
## 죽으면 드랍 목록(data.drops)의 확률을 굴려 나온 것을 바닥에 떨어뜨린다.

@export var data: MonsterData
## 죽을 때 드랍을 바닥에 놓을 씬
@export var pickup_scene: PackedScene
## 맞았을 때 하얗게 번쩍이는 시간 (초)
@export var hit_flash_duration: float = 0.1
## 드랍이 여러 개일 때 죽은 자리에서 이만큼 떨어진 원 위에 흩뜨린다 (픽셀)
@export var drop_scatter_radius: float = 8.0

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
	var pickups: Array[Pickup] = []
	for entry: DropEntry in DropRoller.roll(data.drops):
		if entry.item is SkullData:
			# 머리뼈는 하나하나 따로 존재하므로 개수만큼 더미를 따로 만든다.
			for i: int in entry.count:
				pickups.append(_make_pickup(ItemStack.of_skull(Skull.create(entry.item))))
		else:
			pickups.append(_make_pickup(ItemStack.of_item(entry.item, entry.count)))

	# 여러 개가 한자리에 겹치지 않게, 죽은 자리를 중심으로 원 위에 고르게 흩뜨린다.
	var start_angle: float = randf() * TAU
	for i: int in pickups.size():
		var offset: Vector2 = Vector2.ZERO
		if pickups.size() > 1:
			offset = Vector2.from_angle(start_angle + TAU * i / pickups.size()) * drop_scatter_radius
		pickups[i].position = position + offset
		# 물리 처리 중(탄에 맞은 순간)에는 Area2D를 바로 추가할 수 없어서 미룬다.
		get_parent().add_child.call_deferred(pickups[i])
	queue_free()


func _make_pickup(stack: ItemStack) -> Pickup:
	var pickup: Pickup = pickup_scene.instantiate()
	pickup.stack = stack
	return pickup


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
