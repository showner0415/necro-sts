class_name Monster
extends CharacterBody2D
## MonsterData 하나로 움직이는 몬스터.
## 배회하다가 네크로맨서나 언데드가 감지 범위에 들어오면 그중 가장 가까운 대상을 노린다.
## 감지 범위에 아무도 없을 때 맞으면 공격한 대상을 쫓고, 너무 멀어지면 포기하고 맞기 시작한 자리로 돌아간다 (Aggro).
## 무리(MonsterPack)에 속해 있으면 무리가 정한 대상(set_pack_target)을 자기 판단보다 먼저 노린다.
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
## 행동 조각이 바닥에 그리는 예고 표시(돌진 방향 선 등)의 색. 적은 위험 표시 색(e43b44)이다.
@export var indicator_color: Color = Color(0.89411765, 0.23137255, 0.26666668, 1)
## 네크로맨서에게 맞은 뒤 이 시간(초) 동안, 대상이 없는 언데드가 고를 수 있는 몬스터가 된다 (임시값)
@export var necromancer_mark_duration: float = 5.0

## 맞았을 때 (source는 때린 쪽). 무리가 이것으로 무리 대상을 정한다.
signal hit_by(source: Node2D)

var health: float
## 지금 노리는 대상 (네크로맨서 또는 언데드). take_damage(amount, source)가 있어야 한다.
var _target: Node2D
## 무리 대상과 상관없이 스스로 노렸을 대상 (감지·공격자 쫓기)
var _own_target: Node2D
## 무리(MonsterPack)가 정한 대상. 있으면 _own_target 대신 이것을 노린다.
var _pack_target: Node2D
## 무리 싸움을 시작한 자리 (무리가 포기하면 돌아갈 곳)
var _pack_home: Vector2
## 네크로맨서에게 맞은 표시가 남은 시간 (0이면 없음)
var _necromancer_mark_left: float = 0.0
## 네크로맨서에게 맞은 횟수. 언데드가 "방금 맞았다"(계기)를 알아보는 데 쓴다.
var _necromancer_hits: int = 0
var _wander_direction: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
## 대상과 싸우는 방식 (data.behavior의 이 몬스터용 복사본)
var _behavior: MonsterBehavior
var _knockback: Knockback = Knockback.new()
## 벽을 돌아서 가는 방향을 정한다 (벽이 없으면 곧장)
var _path_follower: PathFollower
## 평소에 감지해서 보던 대상과, 처음 그 대상을 본 자리 (놓치면 그 대상을 쫓는다)
var _seen_target: Node2D
var _seen_origin: Vector2
## 감지 범위 밖에서 맞았을 때 공격자를 쫓는 규칙
var _aggro: Aggro
## 그림이 있는 몬스터(data.has_sprite())의 8방향 그림. 없으면 null이고 임시 도형으로 그린다
var _sprite: FacingSprite
## 이보다 느리게 움직이면(벽에 미끄러질 때의 아주 작은 속도 등) 그림 방향을 바꾸지 않는다 (픽셀/초)
const SPRITE_TURN_SPEED: float = 1.0

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	health = data.max_health
	_behavior = data.make_enemy_behavior()
	_aggro = Aggro.new(data.chase_attacker_limit, data.chase_visible_home_limit, data.chase_lost_time, return_arrive_distance)
	_collision.shape = PlaceholderBody.make_shape(data)
	_collision.rotation = PlaceholderBody.shape_rotation(data)
	_collision.position = PlaceholderBody.center(data)
	_path_follower = PathFollower.new(data.get_placeholder_half_size(), PlaceholderBody.center(data))
	# 날아다니는 몸은 벽하고만 부딪히고, 다른 몸도 이 몸에 부딪히지 않는다 (탄은 이 층도 검사한다).
	if data.has_sprite():
		_sprite = FacingSprite.new()
		_sprite.sprite_frames = data.make_sprite_frames()
		_sprite.centered = false
		_sprite.idle_offset = data.sprite_offset
		add_child(_sprite)
	if data.flying:
		collision_layer = flying_layer
		collision_mask = flying_mask


func _physics_process(delta: float) -> void:
	_behavior.update(delta)
	_necromancer_mark_left = maxf(_necromancer_mark_left - delta, 0.0)
	var nearest: Node2D = _find_nearest_target()
	_remember_seen_target(nearest)
	# 쫓던 공격자가 사라졌을 수 있다 (해제된 언데드 등). 사라진 객체는 형변환하면 오류이므로 먼저 확인한다.
	var attacker: Node2D = _aggro.attacker as Node2D if is_instance_valid(_aggro.attacker) else null
	var attacker_alive: bool = is_instance_valid(attacker) and not attacker.is_queued_for_deletion()
	var attacker_visible: bool = attacker_alive and _path_follower.can_see(self, attacker.global_position)
	_aggro.update(global_position, nearest != null, attacker_alive, attacker.global_position if attacker_alive else Vector2.ZERO, attacker_visible, delta)
	match _aggro.state:
		Aggro.State.CHASING:
			_own_target = _aggro.attacker as Node2D
		Aggro.State.RETURNING:
			_own_target = null
		_:
			_own_target = nearest
	# 무리에 대상이 있으면 자기 판단과 상관없이 그 대상을 노린다.
	_target = _pack_target if _is_alive_node(_pack_target) else _own_target
	# 하던 동작(돌진 예고 등)은 대상이 사라져도 이어 간다.
	if _target != null or _behavior.is_busy():
		_behavior.act(self, data.get_enemy_stats(), _target, delta)
	elif _aggro.state == Aggro.State.RETURNING and _target == null:
		velocity = get_move_direction(_aggro.origin) * data.move_speed
	else:
		_wander(delta)
	if _knockback.is_active():
		velocity = _knockback.get_velocity()
	move_and_slide()
	_knockback.update(delta)
	_update_sprite()
	# 예고 표시(깜빡임, 방향 선)가 프레임마다 바뀐다.
	queue_redraw()


## 테스트·디버그용: 지금 노리는 대상 (없으면 null)
func get_target() -> Node2D:
	return _target


## 행동 조각이 부른다: goal(발밑 좌표)로 가려면 움직일 방향. 벽이 가로막으면 돌아가는 방향이다.
func get_move_direction(goal: Vector2) -> Vector2:
	return _path_follower.get_direction(self, goal)


## 행동 조각이 부른다: goal(발밑 좌표)까지 벽이 가로막지 않는지.
func has_clear_line_to(goal: Vector2) -> bool:
	return _path_follower.is_line_clear(self, goal)


## 테스트·디버그용: 길찾기 (지금 따라가는 길)
func get_path_follower() -> PathFollower:
	return _path_follower


## 테스트·디버그용: 공격자 추격 상태 (Aggro.State)와 맞기 시작한 자리
func get_aggro() -> Aggro:
	return _aggro


## 테스트·디버그용: 이 한 마리가 쓰는 행동 조각
func get_behavior() -> MonsterBehavior:
	return _behavior


## 던지는 행동 조각의 돌이 피해를 줄 그룹: 네크로맨서와 언데드.
func get_hostile_groups() -> Array[StringName]:
	return [&"necromancer", &"undead"]


## 던진 돌이 지나가는 그룹: 없음 (적 투석병의 돌은 다른 몬스터 몸에도 막힌다).
func get_stone_pass_groups() -> Array[StringName]:
	return []


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


## 무리(MonsterPack)가 프레임마다 정해 준다: 무리 대상 (없으면 null). 있으면 자기 판단 대신 이 대상을 노린다.
## 무리 대상이 처음 생길 때의 자리를 기억해 두었다가, 무리가 포기하면(return_home) 그리로 돌아간다.
func set_pack_target(target: Node2D) -> void:
	if target != null and _pack_target == null:
		_pack_home = _aggro.origin if _aggro.state != Aggro.State.IDLE else global_position
	_pack_target = target


## 무리가 함께 포기했을 때 부른다. 무리 싸움을 시작한 자리로 돌아간다 (돌아가는 동안 감지·피격으로 대상을 바꾸지 않는다).
func return_home() -> void:
	_pack_target = null
	_aggro.start_return(_pack_home)


## 이 몬스터가 무리 대상 target을 아직 원하는지: 감지 범위 안이거나,
## 공격한 대상을 쫓는 한계 안(대상과 chase_attacker_limit, 무리 싸움을 시작한 자리에서 chase_home_limit)이면 원한다.
func wants_pack_target(target: Node2D) -> bool:
	var distance: float = global_position.distance_to(target.global_position)
	if distance <= data.detect_range:
		return true
	return distance <= data.chase_attacker_limit and global_position.distance_to(_pack_home) <= data.chase_home_limit


## 무리 판단용: 무리 대상과 상관없이 이 몬스터가 스스로 노렸을 대상 (감지·공격자 쫓기 규칙)
func get_own_target() -> Node2D:
	return _own_target


func _is_alive_node(node: Node2D) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion()


## source는 공격한 쪽. 감지 범위에 아무도 없을 때 맞으면 그 대상을 쫓는다. 무리는 hit_by로 알고 무리 전체가 source를 노린다.
func take_damage(amount: float, source: Node2D = null) -> void:
	if health <= 0.0:
		return
	_aggro.on_hit(source, global_position, _find_nearest_target() != null)
	if source != null and source.is_in_group(&"necromancer"):
		_necromancer_mark_left = necromancer_mark_duration
		_necromancer_hits += 1
	if source != null:
		hit_by.emit(source)
	health -= amount
	if health <= 0.0:
		_die()
		return
	# 번쩍임은 색만 바꾼다. 투명도(modulate.a)는 시야(Vision)가 나타나고 사라질 때 쓴다.
	modulate = Color(3, 3, 3, modulate.a)
	var flash: Tween = create_tween().set_parallel()
	for channel: String in ["r", "g", "b"]:
		flash.tween_property(self, "modulate:" + channel, 1.0, hit_flash_duration)


func _die() -> void:
	# 머리뼈가 나올지는 죽는 이 순간에 정해진다. 시체는 정해진 것만 담는다.
	var corpse: Corpse = corpse_scene.instantiate()
	corpse.setup(data, CorpseLoot.from_drops(DropRoller.roll(data.drops), data.harvest_base_time))
	corpse.position = position
	# 물리 처리 중(탄에 맞은 순간)에는 Area2D를 바로 추가할 수 없어서 미룬다.
	get_parent().add_child.call_deferred(corpse)
	queue_free()


func _draw() -> void:
	# 바닥의 예고 표시를 먼저 그리고, 기준점(발밑) 위에 몸을 그린다. 그림이 있으면 몸은 그림(_sprite)이고, 없으면 임시 도형이다.
	_behavior.draw_overlay(self, indicator_color)
	if _sprite == null:
		PlaceholderBody.draw(self, data, _behavior.get_body_color(data.placeholder_color), PlaceholderBody.center(data))


## 평소(IDLE)에 보던 대상을 기억했다가, 놓치면(벽 뒤로 숨거나 감지 범위를 벗어남) 공격자를 쫓을 때와 같은 한계까지 쫓는다.
## 쫓는 한계의 "시작 자리"는 처음 대상을 본 자리다.
func _remember_seen_target(nearest: Node2D) -> void:
	if _aggro.state != Aggro.State.IDLE:
		_seen_target = null
		return
	if nearest != null:
		if _seen_target == null:
			_seen_origin = global_position
		_seen_target = nearest
		return
	# 사라진 객체는 형이 있는 인자로 넘기면 오류이므로 여기서 바로 확인한다.
	if is_instance_valid(_seen_target) and not _seen_target.is_queued_for_deletion():
		_aggro.start_chase(_seen_target, _seen_origin)
	_seen_target = null


## 감지 범위 안에서 보이는(벽이 가리지 않는) 네크로맨서·언데드 중 가장 가까운 것. 없으면 null.
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
		if distance <= nearest_distance and _path_follower.can_see(self, candidate.global_position):
			nearest = candidate
			nearest_distance = distance
	return nearest


## 네크로맨서가 최근(necromancer_mark_duration 안)에 때렸는지. 대상이 없는 언데드는 이런 몬스터를 고를 수 있다.
func is_marked_by_necromancer() -> bool:
	return _necromancer_mark_left > 0.0


## 지금까지 네크로맨서에게 맞은 횟수. 언데드가 지난 프레임의 값과 비교해 새로 맞았는지 본다.
func get_necromancer_hit_count() -> int:
	return _necromancer_hits


## 그림이 있으면 실제로 움직인 방향의 그림을 보여 준다. 멈추면 마지막 방향 그대로다.
func _update_sprite() -> void:
	if _sprite == null:
		return
	var moved: Vector2 = get_real_velocity()
	if moved.length() > SPRITE_TURN_SPEED:
		_sprite.face(moved)
	_sprite.update_motion(moved, data.move_speed)
