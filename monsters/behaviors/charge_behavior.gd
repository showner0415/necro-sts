class_name ChargeBehavior
extends MonsterBehavior
## 행동 조각 "돌진하기". 돌진 거리 밖이면 대상에게 다가가기만 하고(공격하지 않음), 안이면 예고 → 돌진 → 멈칫을 반복한다.
## - 예고: 제자리에 멈춰 깜빡이고 바닥에 돌진 방향 선을 그린다. 선은 대상을 따라 돌다가 끝나기 lock_time초 전에 고정된다
## - 돌진: 고정된 방향으로, 돌진을 시작할 때 노린 대상이 있던 자리를 지나 overshoot_distance만큼 더 달린다 (최대 charge_distance).
##   벽(world_collision_mask)에 부딪히면 그 자리에서 끝난다
##   돌진하는 동안 몸끼리는 부딪히지 않고 지나간다 (자기 충돌층을 비워서 상대도 이 몸에 밀리지 않는다). 닿은 상대마다 한 번만 피해(stats.contact_damage)를 주고 밀쳐낸다
## - 멈칫: recover_time초 동안 멈춘다 (때릴 기회)
## 노리는 대상은 다가가는 중에만 바뀐다. 예고를 시작할 때의 대상을 멈칫이 끝날 때까지 유지한다.
## 칠 수 있는 상대는 쓰는 쪽의 get_hostiles()가 정한다 (적 멧돼지: 네크로맨서·언데드, 언데드 멧돼지: 몬스터).

enum State { APPROACH, WINDUP, CHARGE, RECOVER }

## 대상이 이 거리 안에 들어오면 예고를 시작한다 (픽셀)
@export var charge_range: float = 90.0
## 예고 시간 (초)
@export var windup_time: float = 0.7
## 예고가 끝나기 이 시간 전에 방향이 고정된다 (초)
@export var lock_time: float = 0.2
## 돌진 속도 (픽셀/초)
@export var charge_speed: float = 200.0
## 한 번 돌진하는 최대 거리 (픽셀)
@export var charge_distance: float = 120.0
## 노린 대상이 있던 자리를 지나 더 달리는 거리 (픽셀). 언데드를 노린 돌진이 그 뒤의 네크로맨서까지 오지 않게 한다.
@export var overshoot_distance: float = 40.0
## 돌진이 끝난 뒤 멈춰 있는 시간 (초)
@export var recover_time: float = 1.2
## 상대의 발밑이 이 거리 안에 들어오면 돌진에 맞는다 (픽셀)
@export var hit_radius: float = 12.0
## 맞은 상대를 밀쳐내는 거리 (픽셀)와 시간 (초)
@export var knockback_distance: float = 24.0
@export var knockback_duration: float = 0.15
## 돌진하는 동안 부딪히는 충돌층 (벽). 몸끼리는 지나간다.
@export_flags_2d_physics var world_collision_mask: int = 1

@export_group("예고 표시")
## 깜빡일 때의 몸 색과, 한 번 켜지거나 꺼지는 시간 (초)
@export var blink_color: Color = Color(1, 1, 1, 1)
@export var blink_interval: float = 0.1
## 바닥 방향 선의 두께 (픽셀)
@export var line_width: float = 2.0

var _state: State = State.APPROACH
var _timer: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _charge_start: Vector2
## 이번 돌진에서 달릴 거리 (돌진을 시작할 때 정한다)
var _charge_length: float = 0.0
var _hit: Array[Node2D] = []
var _saved_mask: int = 0
var _saved_layer: int = 0
## 예고를 시작할 때 고른 대상. 멈칫이 끝날 때까지 이 대상을 겨눈다.
var _locked_target: Node2D


func is_busy() -> bool:
	return _state != State.APPROACH


func get_state() -> State:
	return _state


## 지금(또는 마지막으로) 정해진 돌진 방향
func get_direction() -> Vector2:
	return _direction


## 예고 중 방향이 고정되었는지
func is_direction_locked() -> bool:
	return _state == State.WINDUP and _timer >= windup_time - lock_time


## 공격 반경: 돌진을 시작하는 거리 (charge_range).
func get_engage_range(_stats: CombatStats) -> float:
	return charge_range


func is_telegraphing() -> bool:
	return _state == State.WINDUP or _state == State.CHARGE


func get_attack_direction() -> Vector2:
	return _direction if is_telegraphing() else Vector2.ZERO


func is_attack_locked() -> bool:
	return is_direction_locked() or _state == State.CHARGE


func act(body: CharacterBody2D, stats: CombatStats, target: Node2D, delta: float) -> void:
	match _state:
		State.APPROACH:
			_approach(body, stats, target)
		State.WINDUP:
			_windup(body, delta)
		State.CHARGE:
			_charge(body, stats)
		State.RECOVER:
			body.velocity = Vector2.ZERO
			_timer += delta
			if _timer >= recover_time:
				_state = State.APPROACH
				_locked_target = null


func _approach(body: CharacterBody2D, stats: CombatStats, target: Node2D) -> void:
	if target == null:
		body.velocity = Vector2.ZERO
		return
	# 돌진 거리 안이어도 벽이 가로막으면 돌진하지 않고 돌아서 다가간다.
	if body.global_position.distance_to(target.global_position) > charge_range or not has_clear_line(body, target):
		body.velocity = move_direction(body, target.global_position) * stats.move_speed
		return
	body.velocity = Vector2.ZERO
	_state = State.WINDUP
	_timer = 0.0
	_locked_target = target
	_aim_at(body, target)


func _windup(body: CharacterBody2D, delta: float) -> void:
	body.velocity = Vector2.ZERO
	# 고정되기 전까지는 예고를 시작할 때의 대상을 따라 돈다 (그사이 노리는 대상이 바뀌어도). 사라졌으면 마지막 방향 그대로.
	if not is_direction_locked() and is_instance_valid(_locked_target):
		_aim_at(body, _locked_target)
	_timer += delta
	if _timer >= windup_time:
		_state = State.CHARGE
		_charge_start = body.global_position
		_charge_length = get_charge_length(body.global_position)
		_hit.clear()
		_saved_mask = body.collision_mask
		_saved_layer = body.collision_layer
		body.collision_mask = world_collision_mask
		body.collision_layer = 0


func _charge(body: CharacterBody2D, stats: CombatStats) -> void:
	# 지난 프레임의 이동에서 무언가(벽)에 부딪혔거나 거리를 다 달렸으면 끝난다.
	if body.get_slide_collision_count() > 0 or body.global_position.distance_to(_charge_start) >= _charge_length:
		_end_charge(body)
		return
	body.velocity = _direction * charge_speed
	_hit_hostiles(body, stats)


## 이번(또는 마지막) 돌진에서 달리기로 정한 거리
func get_current_charge_length() -> float:
	return _charge_length


## from에서 돌진하면 달릴 거리: 노린 대상까지 + overshoot_distance, 최대 charge_distance. 대상이 없으면 최대 거리.
func get_charge_length(from: Vector2) -> float:
	if not is_instance_valid(_locked_target):
		return charge_distance
	return minf(from.distance_to(_locked_target.global_position) + overshoot_distance, charge_distance)


func _end_charge(body: CharacterBody2D) -> void:
	body.velocity = Vector2.ZERO
	body.collision_mask = _saved_mask
	body.collision_layer = _saved_layer
	_state = State.RECOVER
	_timer = 0.0


func _hit_hostiles(body: CharacterBody2D, stats: CombatStats) -> void:
	for hostile: Node2D in body.call(&"get_hostiles"):
		if _hit.has(hostile) or body.global_position.distance_to(hostile.global_position) > hit_radius:
			continue
		# 구르기 무적이라 피해가 없어도 맞은 것으로 친다 (같은 돌진에서 다시 맞지 않는다).
		_hit.append(hostile)
		hostile.call(&"take_damage", stats.contact_damage, body)
		var push: Vector2 = body.global_position.direction_to(hostile.global_position)
		if push == Vector2.ZERO:
			push = _direction
		if hostile.has_method(&"knock_back"):
			hostile.call(&"knock_back", push * knockback_distance, knockback_duration)


func _aim_at(body: CharacterBody2D, target: Node2D) -> void:
	var direction: Vector2 = body.global_position.direction_to(target.global_position)
	if direction != Vector2.ZERO:
		_direction = direction


func get_body_color(base: Color) -> Color:
	if _state == State.WINDUP and fmod(_timer, blink_interval * 2.0) < blink_interval:
		return blink_color
	return base


func draw_overlay(canvas: CanvasItem, indicator_color: Color) -> void:
	if _state == State.WINDUP:
		# 선 길이는 지금 돌진하면 달릴 거리다.
		var length: float = get_charge_length((canvas as Node2D).global_position) if canvas is Node2D else charge_distance
		canvas.draw_line(Vector2.ZERO, _direction * length, indicator_color, line_width)
