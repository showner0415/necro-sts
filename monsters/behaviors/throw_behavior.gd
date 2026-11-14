class_name ThrowBehavior
extends MonsterBehavior
## 행동 조각 "거리 두고 던지기" (고블린 투석병). 대상과 거리를 두고 돌(Stone)을 던진다.
## - 대상이 던지는 거리(stats.attack_range) 밖이면 다가간다 (stats.move_speed)
## - 대상이 retreat_distance보다 가까우면 대상 반대쪽으로 물러난다 (retreat_speed, 느리게)
## - 그 사이면 옆으로 걷는다 (strafe_speed, 0이면 멈춰 선다). 도는 쪽은 던질 때마다 정한다
## - 공격 간격(stats.attack_cooldown)이 되면 throw_windup_time초 멈춘 뒤 던진다. 그 사이 대상이 거리 밖으로 나가거나 벽이 가리면 던지지 않는다
## - 한 번에 stats.burst_count개를 stats.burst_interval초 간격으로 던지고, 던지는 동안 멈춰 있다. 다 던지면 throw_pause_time초 더 멈춘다
## - 돌마다 던지는 순간의 대상 위치와 속도로 도착할 곳을 다시 예측한다 (stats의 돌별 예측 비율과 오차). 돌은 예측 지점에 떨어지고 그림자 원이 돌마다 그려진다
## - 물러나거나 옆으로 걷는 쪽이 벽에 막히면 벽을 따라 미끄러지지 않고 방향을 틀거나 멈춘다
## 공격권(Monster.request_attack)이 없으면 던지러 들어오지 않고 대상에게서 맴도는 거리(stats.wait_distance)를 두고 돌며 기다린다. 다 던지면 공격 한 번이 끝난다(공격권 반납).
## 돌은 쓰는 쪽의 적(get_hostile_groups())에게 피해를 주고, 지나가는 그룹(get_stone_pass_groups())은 지나가며, 다른 몸과 벽에는 막힌다 (Stone).

enum Step { MOVE, WINDUP, BURST }

## 던질 돌 씬
@export var stone_scene: PackedScene
## 돌 속도 (픽셀/초)
@export var stone_speed: float = 160.0
## 대상이 이보다 가까우면 물러난다 (픽셀)
@export var retreat_distance: float = 90.0
## 물러나는 속도 (픽셀/초)
@export var retreat_speed: float = 40.0
## 돌을 던지는 높이 (발밑에서 몸 가운데까지, 픽셀)
@export var throw_height: float = 6.0
## 돌이 떨어지는 곳의 반지름 (픽셀). 그림자 원의 크기이자, 도착했을 때 맞는 범위다
@export var stone_landing_radius: float = 12.0
## 포물선 그림의 가장 높은 곳 (픽셀). 그림만 올라가고 충돌은 땅 높이 그대로다
@export var stone_arc_height: float = 24.0

@export_group("싸울 때 움직임")
## 던지기 직전 멈춰 있는 시간 (초)
@export var throw_windup_time: float = 0.0
## 돌을 다 던지고 멈춰 있는 시간 (초). 이 틈이 다가가서 때릴 기회다
@export var throw_pause_time: float = 0.0
## 던지는 사이 옆으로 걷는 속도 (픽셀/초). 0이면 멈춰 선다
@export var strafe_speed: float = 0.0
## 물러나거나 옆으로 걷는 쪽이 이 거리 안에서 벽에 막히면 방향을 틀거나 멈춘다 (픽셀)
@export var wall_probe_distance: float = 12.0
## 벽에 막혔을 때 틀 수 있는 최대 각도 (도). 그래도 막히면 멈춘다 (벽을 따라 미끄러지지 않게)
@export var max_wall_turn: float = 45.0

var _attack_timer: float = 0.0
## 던지고 멈춰 있는 남은 시간 (초)
var _pause_left: float = 0.0
## 옆으로 걷는 쪽: 1 또는 -1. 던질 때마다 정한다 (프레임마다 방향이 튀지 않게)
var _side: float = 1.0
var _step: Step = Step.MOVE
## 던지기 직전 남은 시간, 또는 다음 돌까지 남은 시간 (초)
var _step_timer: float = 0.0
## 이번 연달아 던지기에서 지금까지 던진 돌 수
var _thrown: int = 0


func update(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_pause_left = maxf(_pause_left - delta, 0.0)
	if _step != Step.MOVE:
		_step_timer -= delta


## 던지는 중에는 대상이 사라져도 act를 불러서 던지기를 끝낸다.
func is_busy() -> bool:
	return _step != Step.MOVE


func allows_spacing() -> bool:
	return _step == Step.MOVE and _pause_left <= 0.0


func is_paused_after_throw() -> bool:
	return _pause_left > 0.0


func is_winding_up() -> bool:
	return _step == Step.WINDUP


## 던지기 직전이거나 연달아 던지는 중인지 (멈춰 있다)
func is_throwing() -> bool:
	return _step != Step.MOVE


func act(body: CharacterBody2D, stats: CombatStats, target: Node2D, _delta: float) -> void:
	if _step != Step.MOVE:
		body.velocity = Vector2.ZERO
		_continue_attack(body, stats, target)
		return
	if _pause_left > 0.0:
		body.velocity = Vector2.ZERO
		return
	# 공격권을 묻는 거리 안에서 공격권이 없으면 던지러 들어오지 않고 맴도는 거리에서 기다린다.
	if must_wait_for_token(body, stats, target):
		wait_around(body, stats, target)
		return
	var to_target: Vector2 = target.global_position - body.global_position
	var distance: float = to_target.length()
	# 던지는 거리 안이어도 벽이 가로막으면 던지지 않고 돌아서 다가간다.
	if distance > stats.attack_range or not has_clear_line(body, target):
		body.velocity = move_direction(body, target.global_position) * stats.move_speed
		return
	if distance < retreat_distance and distance > 0.0:
		body.velocity = free_direction(body, -to_target.normalized(), wall_probe_distance, _side, max_wall_turn) * retreat_speed
	elif strafe_speed > 0.0 and distance > 0.0:
		body.velocity = free_direction(body, to_target.normalized().orthogonal() * _side, wall_probe_distance, _side, max_wall_turn) * strafe_speed
	else:
		body.velocity = Vector2.ZERO
	if _attack_timer == 0.0:
		if throw_windup_time > 0.0:
			_step = Step.WINDUP
			_step_timer = throw_windup_time
			body.velocity = Vector2.ZERO
		else:
			_release_first(body, stats, target)


## 던지기 직전이거나 연달아 던지는 중: 멈춰 있으면서 때가 되면 던진다. 대상이 사라지거나 거리 밖으로 나가거나 벽이 가리면 그만둔다.
func _continue_attack(body: CharacterBody2D, stats: CombatStats, target: Node2D) -> void:
	var can_throw: bool = target != null and body.global_position.distance_to(target.global_position) <= stats.attack_range and has_clear_line(body, target)
	if not can_throw:
		# 던지기 전에 그만두면 공격 간격을 쓰지 않은 것이다. 던지는 도중이면 던진 뒤처럼 끝낸다.
		if _step == Step.WINDUP:
			_step = Step.MOVE
		else:
			_finish_attack(body)
		return
	if _step_timer > 0.0:
		return
	if _step == Step.WINDUP:
		_release_first(body, stats, target)
		return
	throw_stone(body, stats, target, _thrown)
	_thrown += 1
	if _thrown >= stats.burst_count:
		_finish_attack(body)
	else:
		_step_timer = stats.burst_interval


func _release_first(body: CharacterBody2D, stats: CombatStats, target: Node2D) -> void:
	_attack_timer = stats.attack_cooldown
	throw_stone(body, stats, target, 0)
	_thrown = 1
	if stats.burst_count > 1:
		_step = Step.BURST
		_step_timer = stats.burst_interval
		body.velocity = Vector2.ZERO
	else:
		_finish_attack(body)


func _finish_attack(body: CharacterBody2D) -> void:
	_step = Step.MOVE
	# 연달아 던지는 돌을 다 던지면 공격 한 번이 끝난다 (공격권 반납, 제안).
	attack_done(body)
	_side = 1.0 if randf() < 0.5 else -1.0
	if throw_pause_time > 0.0:
		_pause_left = throw_pause_time
		body.velocity = Vector2.ZERO


## 대상의 도착 시점 자리를 예측해 돌을 하나 던진다 (index는 이번 연달아 던지기에서 몇 번째 돌인지). 던진 돌을 돌려준다 (테스트용).
func throw_stone(body: CharacterBody2D, stats: CombatStats, target: Node2D, index: int = 0) -> Stone:
	var origin: Vector2 = body.global_position + Vector2(0, -throw_height)
	var aim: Vector2 = target.global_position + Vector2(0, -throw_height)
	var target_velocity: Vector2 = (target as CharacterBody2D).get_real_velocity() if target is CharacterBody2D else Vector2.ZERO
	var landing: Vector2 = predict_landing(origin, aim, target_velocity, stone_speed, stats.get_lead_ratio(index), stats.get_aim_error(index), stats.attack_range)
	landing = _before_wall(body, origin, landing)
	var stone: Stone = stone_scene.instantiate()
	stone.direction = origin.direction_to(landing) if origin != landing else Vector2.RIGHT
	stone.speed = stone_speed
	stone.damage = stats.contact_damage
	stone.max_distance = origin.distance_to(landing)
	stone.thrower = body
	stone.hostile_groups = body.call(&"get_hostile_groups")
	stone.pass_groups = body.call(&"get_stone_pass_groups")
	stone.landing_radius = stone_landing_radius
	stone.arc_height = stone_arc_height
	stone.ground_offset = throw_height
	var color: Variant = body.get(&"indicator_color")
	if color != null:
		stone.shadow_color = color
	body.get_parent().add_child(stone)
	stone.global_position = origin
	stone.show_landing()
	return stone


## 돌이 떨어질 곳: 대상이 지금 속도로 도착 시점에 있을 자리의 lead_ratio 비율만큼 앞을 노리고, 조준 방향을 ±error_degrees 안에서 흔든다. max_distance를 넘지 않는다.
static func predict_landing(origin: Vector2, aim: Vector2, target_velocity: Vector2, speed: float, lead_ratio: float, error_degrees: float, max_distance: float) -> Vector2:
	var flight_time: float = origin.distance_to(aim) / speed
	var predicted: Vector2 = aim + target_velocity * flight_time * lead_ratio
	# 예측 지점까지의 시간으로 한 번 더 고친다 (멀어지는 대상은 더 앞을 노려야 한다).
	flight_time = origin.distance_to(predicted) / speed
	predicted = aim + target_velocity * flight_time * lead_ratio
	var offset: Vector2 = (predicted - origin).limit_length(max_distance)
	if error_degrees > 0.0:
		offset = offset.rotated(deg_to_rad(randf_range(-error_degrees, error_degrees)))
	return origin + offset


## 떨어질 곳까지 벽이 가로막으면 벽 앞으로 당긴다.
func _before_wall(body: CharacterBody2D, origin: Vector2, landing: Vector2) -> Vector2:
	if not body.is_inside_tree():
		return landing
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, landing, world_collision_mask)
	var hit: Dictionary = body.get_world_2d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return landing
	return (hit["position"] as Vector2) - origin.direction_to(landing) * WALL_MARGIN


const WALL_MARGIN: float = 2.0
