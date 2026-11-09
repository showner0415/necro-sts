class_name Undead
extends CharacterBody2D
## 머리뼈 하나로 소환한 언데드 한 마리. 능력치는 원본 몬스터 데이터의 "언데드" 값을 따른다.
## - 적이 없으면 네크로맨서와 follow_distance 안에 있도록 따라다닌다. 따라가는 동안 다른 언데드와 spacing_distance 안이면 서로 비켜 선다. 따라갈 때는 적어도 네크로맨서가 걷는 속도(follow_speed),
##   catch_up_distance보다 멀면 네크로맨서가 뛰는 속도(catch_up_speed)로 따라간다. 싸울 때는 원래 몬스터의 속도다
## - 이유 없이 먼저 공격하지 않는다. 싸울 몬스터는 UndeadTargeting 규칙으로 정한다: 네크로맨서를 노리는 몬스터가 네크로맨서의 공격 반경
##   (master_attack_radius) 안에 들어오거나, 네크로맨서가 몬스터를 맞히거나, 이 언데드를 노리는 몬스터가 언데드의 공격 반경 안에 들어오면
##   그 몬스터를 노린다. 언데드의 공격 반경(행동 조각의 get_engage_range)에 들어오면 대상을 고정한다.
##   싸우는 방식은 원본 몬스터의 언데드용 행동 조각(data.make_undead_behavior())이고, 수치는 언데드 값이다 (MonsterData.get_undead_stats)
## - 대상이 네크로맨서에게서 leash_distance보다 멀어지면 그만두고 돌아온다
## 체력·내구도는 이 노드가 아니라 머리뼈(Skull)에 있다. 피해를 받으면 damage_received로 알리기만 하고,
## 실제 계산과 사라지는 판단은 UndeadRoster가 한다 (Summoner가 연결한다).

signal damage_received(skull: Skull, amount: float)

## 네크로맨서에게서 이 거리 안이면 따라가지 않고 멈춘다 (픽셀, 임시값)
@export var follow_distance: float = 28.0
## 따라갈 때(싸우지 않을 때) 다른 언데드와 이 거리 안이면 서로 비켜 선다 (픽셀, 임시값).
## 멧돼지 돌진 한 번에 둘 다 맞지 않게 하려는 것이다 (돌진은 노린 자리를 40px 지나고 맞는 범위가 20px)
@export var spacing_distance: float = 64.0
## 비켜 서는 힘(0~1)이 이보다 작으면 무시하고 멈춘다 (멈춰 있을 때 조금씩 떨리지 않게)
@export var spacing_deadband: float = 0.05
## 네크로맨서에게서 이 거리보다 먼 몬스터는 쫓지 않는다 (픽셀, 임시값. 네크로맨서의 공격 반경과 같게 둔다)
@export var leash_distance: float = 160.0
## 따라가는 중에 네크로맨서에게서 이 거리보다 멀면 catch_up_speed로 빨라진다 (픽셀, 임시값)
@export var catch_up_distance: float = 48.0
## 맞았을 때 하얗게 번쩍이는 시간 (초)
@export var hit_flash_duration: float = 0.1
## 날아다니는 몬스터(data.flying)가 쓰는 충돌층과, 부딪히는 대상(벽)
@export_flags_2d_physics var flying_layer: int = 32
@export_flags_2d_physics var flying_mask: int = 1
## 행동 조각이 바닥에 그리는 예고 표시(돌진 방향 선 등)의 색. 적의 표시(빨강)와 구별되는 아군 색(2ce8f5)이다.
@export var indicator_color: Color = Color(0.17254902, 0.9098039, 0.9607843, 1)

var skull: Skull
var data: MonsterData
var _master: Node2D
## 멀리 떨어져 따라갈 때의 속도. 소환할 때 네크로맨서의 뛰는 속도를 넣어 준다. 언데드 자기 속도보다 느리면 쓰지 않는다.
var catch_up_speed: float = 0.0
## 따라갈 때의 최소 속도. 소환할 때 네크로맨서가 걷는 속도를 넣어 준다 (몬스터 속도가 느려도 걷는 네크로맨서를 따라오게).
var follow_speed: float = 0.0
## 네크로맨서의 공격 반경 (기본 공격 사거리). 소환할 때 넣어 준다. 네크로맨서를 노리는 몬스터가 이 안에 들어오면 싸우러 간다.
var master_attack_radius: float = 0.0
## 싸울 몬스터를 정하는 규칙
var _targeting: UndeadTargeting = UndeadTargeting.new()
## 몬스터마다 지난 프레임까지 본 "네크로맨서에게 맞은 횟수" (늘었으면 방금 맞은 것)
var _seen_necromancer_hits: Dictionary = {}
## 몬스터와 싸우는 방식 (원본 몬스터의 언데드용 행동 조각 복사본)
var _behavior: MonsterBehavior
var _knockback: Knockback = Knockback.new()
## 벽을 돌아서 가는 방향을 정한다 (벽이 없으면 곧장)
var _path_follower: PathFollower
## 시야(Vision)가 쓰는 바라보는 방향 (길이 1): 싸울 때는 대상 쪽, 움직일 때는 움직이는 쪽, 멈추면 그대로.
## 시야 데이터의 turn_speed까지만 돈다
var facing: Vector2 = Vector2.DOWN
var _sight: SightData

@onready var _collision: CollisionShape2D = $CollisionShape2D


## 소환할 때 바깥에서 넣어 준다. 트리에 넣기 전에 부른다.
func setup(summoned_skull: Skull, monster_data: MonsterData, master: Node2D) -> void:
	skull = summoned_skull
	data = monster_data
	_master = master


func _ready() -> void:
	_behavior = data.make_undead_behavior()
	_sight = data.get_undead_sight()
	_collision.shape = PlaceholderBody.make_shape(data)
	_collision.rotation = PlaceholderBody.shape_rotation(data)
	_collision.position = PlaceholderBody.center(data)
	_path_follower = PathFollower.new(data.get_placeholder_half_size(), PlaceholderBody.center(data))
	# 날아다니는 몸은 벽하고만 부딪히고, 다른 몸도 이 몸에 부딪히지 않는다 (탄은 이 층도 검사한다).
	if data.flying:
		collision_layer = flying_layer
		collision_mask = flying_mask


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
	_update_facing(target, delta)
	# 예고 표시(깜빡임, 방향 선)가 프레임마다 바뀐다.
	queue_redraw()


func _update_facing(target: Monster, delta: float) -> void:
	var want: Vector2 = Vector2.ZERO
	if target != null:
		want = global_position.direction_to(target.global_position)
	elif velocity.length() > 1.0:
		want = velocity.normalized()
	if want == Vector2.ZERO:
		return
	var max_turn: float = deg_to_rad(_sight.turn_speed) * delta
	facing = facing.rotated(clampf(facing.angle_to(want), -max_turn, max_turn)).normalized()


## 시야의 중심 (몸 가운데)
func get_sight_origin() -> Vector2:
	return global_position + PlaceholderBody.center(data)


## 테스트·디버그용: 이 한 마리가 쓰는 행동 조각
func get_behavior() -> MonsterBehavior:
	return _behavior


## 던지는 행동 조각의 돌이 피해를 줄 그룹: 몬스터만.
func get_hostile_groups() -> Array[StringName]:
	return [&"monsters"]


## 던진 돌이 지나가는 그룹: 네크로맨서와 언데드 (네크로맨서 뒤에서 던져도 막히지 않게).
func get_stone_pass_groups() -> Array[StringName]:
	return [&"necromancer", &"undead"]


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


## 행동 조각과 따라다니기가 부른다: goal(발밑 좌표)로 가려면 움직일 방향. 벽이 가로막으면 돌아가는 방향이다.
func get_move_direction(goal: Vector2) -> Vector2:
	return _path_follower.get_direction(self, goal)


## 행동 조각이 부른다: goal(발밑 좌표)까지 벽이 가로막지 않는지.
func has_clear_line_to(goal: Vector2) -> bool:
	return _path_follower.is_line_clear(self, goal)


func _follow() -> void:
	if not is_instance_valid(_master):
		velocity = Vector2.ZERO
		return
	var to_master: Vector2 = _master.global_position - global_position
	var distance: float = to_master.length()
	# 싸울 때는 원래 속도이고, 따라갈 때는 적어도 걷는 네크로맨서만큼, 멀리 떨어지면 뛰는 네크로맨서만큼 빠르다.
	var speed: float = maxf(data.move_speed, follow_speed)
	if distance > catch_up_distance:
		speed = maxf(speed, catch_up_speed)
	var apart: Vector2 = _spacing_push()
	# 멈추는 거리는 두 마리가 네크로맨서 양쪽에 서면 spacing_distance보다 넉넉히 떨어질 수 있게 잡는다 (딱 맞추면 정확히 반대편에 서야만 떨어진다).
	if distance <= maxf(follow_distance, spacing_distance * 0.6):
		velocity = apart * speed if apart.length() >= spacing_deadband else Vector2.ZERO
		return
	velocity = (get_move_direction(_master.global_position) + apart).limit_length(1.0) * speed


## 따라가는 동안 다른 언데드에게서 비켜 서는 방향과 세기 (가까울수록 세다, 길이 최대 1)
func _spacing_push() -> Vector2:
	var others: Array[Vector2] = []
	var ids: Array[int] = []
	for node: Node in get_tree().get_nodes_in_group(&"undead"):
		var other: Node2D = node as Node2D
		if other == self or other == null or other.is_queued_for_deletion():
			continue
		others.append(other.global_position)
		ids.append(other.get_instance_id())
	return BodySpacing.push(global_position, get_instance_id(), others, ids, spacing_distance)


## 살아 있는 몬스터마다 이번 프레임 정보를 모아 UndeadTargeting에 넣고, 정해진 대상을 돌려준다.
func _find_target() -> Monster:
	var engage_range: float = _behavior.get_engage_range(data.get_undead_stats())
	var candidates: Array[UndeadTargeting.Candidate] = []
	var hits: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"monsters"):
		var monster: Monster = node as Monster
		if monster == null or monster.is_queued_for_deletion() or monster.health <= 0.0:
			continue
		var c: UndeadTargeting.Candidate = UndeadTargeting.Candidate.new()
		c.monster = monster
		c.distance = global_position.distance_to(monster.global_position)
		c.in_engage_range = c.distance <= engage_range
		var hit_count: int = monster.get_necromancer_hit_count()
		# 처음 보는 몬스터는 지금까지의 횟수부터 센다 (소환 전에 맞은 것은 계기가 아니다. 최근이면 is_marked_by_necromancer로 고른다).
		c.hit_by_necromancer = hit_count > _seen_necromancer_hits.get(monster, hit_count)
		hits[monster] = hit_count
		if is_instance_valid(_master):
			var to_master: float = monster.global_position.distance_to(_master.global_position)
			c.within_leash = to_master <= leash_distance
			var monster_target: Node2D = monster.get_target()
			c.qualified = monster.is_marked_by_necromancer() \
					or (monster_target == _master and to_master <= master_attack_radius) \
					or (monster_target == self and c.in_engage_range)
		candidates.append(c)
	# 사라진 몬스터는 지운다.
	_seen_necromancer_hits = hits
	return _targeting.update(candidates) as Monster


## 테스트·디버그용: 지금 노리는 몬스터 (없으면 null)
func get_target() -> Monster:
	return _targeting.target as Monster if is_instance_valid(_targeting.target) else null


## 테스트·디버그용: 지금 대상이 고정되었는지
func is_target_locked() -> bool:
	return _targeting.locked


## source는 공격한 쪽 (언데드는 쓰지 않는다. 몬스터 타게팅 규칙은 언데드에 적용하지 않는다).
func take_damage(amount: float, _source: Node2D = null) -> void:
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
