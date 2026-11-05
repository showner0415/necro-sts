class_name DiveBehavior
extends MonsterBehavior
## 행동 조각 "치고 빠지기" (박쥐). 다가가기 → 예고 → 돌진해 한 번 물기 → 물러나기 → 돌기 → 다시 예고를 반복한다.
## - 다가가기: 대상이 dive_range 밖이면 다가간다
## - 예고: windup_time초 동안 멈춰 깜빡인다
## - 돌진: 돌진을 시작하는 순간 대상이 있던 쪽으로 방향을 고정하고 곧게 날아간다.
##   칠 수 있는 상대(get_hostiles()) 중 하나가 bite_range 안에 들어오면 한 번 물고 끝난다. dive_distance까지 못 물면 빗나간 것으로 끝난다
## - 물러나기: 대상의 반대쪽으로, 대상과 orbit_radius만큼 떨어질 때까지 물러난다
## - 돌기: orbit_time초 동안 대상 주변을 orbit_radius로 돈다. 칠 수 있는 상대 모두와 keep_distance 이상 떨어지도록 가까운 쪽에서는 바깥으로 비켜 돈다.
##   도는 방향(시계 / 반시계)은 한 마리마다 무작위다
## 물기 피해는 stats.contact_damage, 다가가는 속도는 stats.move_speed다.

enum State { APPROACH, WINDUP, DIVE, RETREAT, ORBIT }

## 대상이 이 거리 안에 들어오면 첫 예고를 시작한다 (픽셀)
@export var dive_range: float = 70.0
## 예고 시간 (초)
@export var windup_time: float = 0.3
## 돌진 속도 (픽셀/초)와 최대 거리 (픽셀)
@export var dive_speed: float = 220.0
@export var dive_distance: float = 100.0
## 상대의 발밑이 이 거리 안에 들어오면 문다 (픽셀)
@export var bite_range: float = 8.0
## 물러나는 속도 (픽셀/초)
@export var retreat_speed: float = 150.0
## 돌 때 대상과의 거리 (픽셀)
@export var orbit_radius: float = 60.0
## 돌 때 칠 수 있는 상대 모두와 유지하는 최소 거리 (픽셀)
@export var keep_distance: float = 40.0
## 도는 속도 (픽셀/초)
@export var orbit_speed: float = 80.0
## 돌고 나서 다시 예고하기까지 (초)
@export var orbit_time: float = 2.0
## 반경에서 벗어났을 때 되돌아가는 세기 (1이면 도는 속도만큼)
@export var radius_correction: float = 1.5

@export_group("예고 표시")
@export var blink_color: Color = Color(1, 1, 1, 1)
@export var blink_interval: float = 0.05

var _state: State = State.APPROACH
var _timer: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _dive_start: Vector2
## 마지막으로 본 대상 위치 (대상이 사라져도 물러날 기준)
var _anchor: Vector2
## 도는 방향: 1 반시계, -1 시계. 0이면 아직 정하지 않음.
var _orbit_sign: float = 0.0


func is_busy() -> bool:
	return _state == State.WINDUP or _state == State.DIVE or _state == State.RETREAT


func get_state() -> State:
	return _state


func get_orbit_sign() -> float:
	return _orbit_sign


func is_telegraphing() -> bool:
	return _state == State.WINDUP or _state == State.DIVE


func get_attack_direction() -> Vector2:
	return _direction if _state == State.DIVE else Vector2.ZERO


## 박쥐는 돌진을 시작해야 방향이 정해진다.
func is_attack_locked() -> bool:
	return _state == State.DIVE


func act(body: CharacterBody2D, stats: CombatStats, target: Node2D, delta: float) -> void:
	if _orbit_sign == 0.0:
		_orbit_sign = 1.0 if randf() < 0.5 else -1.0
	if target != null:
		_anchor = target.global_position
	match _state:
		State.APPROACH:
			_approach(body, stats, target)
		State.WINDUP:
			body.velocity = Vector2.ZERO
			_timer += delta
			if _timer >= windup_time:
				_begin_dive(body)
		State.DIVE:
			_dive(body, stats)
		State.RETREAT:
			_retreat(body)
		State.ORBIT:
			_orbit(body, target, delta)


func _approach(body: CharacterBody2D, stats: CombatStats, target: Node2D) -> void:
	if target == null:
		body.velocity = Vector2.ZERO
		return
	var to_target: Vector2 = target.global_position - body.global_position
	if to_target.length() > dive_range:
		body.velocity = to_target.normalized() * stats.move_speed
		return
	_begin_windup(body)


func _begin_windup(body: CharacterBody2D) -> void:
	body.velocity = Vector2.ZERO
	_state = State.WINDUP
	_timer = 0.0


func _begin_dive(body: CharacterBody2D) -> void:
	var direction: Vector2 = body.global_position.direction_to(_anchor)
	if direction != Vector2.ZERO:
		_direction = direction
	_dive_start = body.global_position
	_state = State.DIVE


func _dive(body: CharacterBody2D, stats: CombatStats) -> void:
	# 지난 프레임의 이동에서 벽에 부딪혔거나 최대 거리를 다 날았으면 빗나간 것이다.
	if body.get_slide_collision_count() > 0 or body.global_position.distance_to(_dive_start) >= dive_distance:
		_begin_retreat(body)
		return
	for hostile: Node2D in body.call(&"get_hostiles"):
		if body.global_position.distance_to(hostile.global_position) <= bite_range:
			hostile.call(&"take_damage", stats.contact_damage, body)
			_begin_retreat(body)
			return
	body.velocity = _direction * dive_speed


func _begin_retreat(body: CharacterBody2D) -> void:
	body.velocity = Vector2.ZERO
	_state = State.RETREAT


func _retreat(body: CharacterBody2D) -> void:
	var away: Vector2 = _anchor.direction_to(body.global_position)
	if away == Vector2.ZERO:
		away = -_direction
	if body.global_position.distance_to(_anchor) >= orbit_radius:
		_state = State.ORBIT
		_timer = 0.0
		body.velocity = Vector2.ZERO
		return
	body.velocity = away * retreat_speed


func _orbit(body: CharacterBody2D, target: Node2D, delta: float) -> void:
	if target == null:
		body.velocity = Vector2.ZERO
		return
	_timer += delta
	if _timer >= orbit_time:
		_begin_windup(body)
		return
	body.velocity = get_orbit_velocity(body.global_position, target.global_position, _hostile_positions(body))


## 돌 때의 속도: 대상 주변 접선 방향 + 반경으로 되돌아가기 + 너무 가까운 상대에게서 바깥으로 비키기.
func get_orbit_velocity(position: Vector2, center: Vector2, hostiles: Array[Vector2]) -> Vector2:
	var from_center: Vector2 = center.direction_to(position)
	if from_center == Vector2.ZERO:
		from_center = Vector2.RIGHT
	var tangent: Vector2 = from_center.orthogonal() * _orbit_sign
	var radial_error: float = (orbit_radius - position.distance_to(center)) / orbit_radius
	var push: Vector2 = Vector2.ZERO
	for hostile: Vector2 in hostiles:
		var distance: float = position.distance_to(hostile)
		if distance < keep_distance:
			var away: Vector2 = hostile.direction_to(position)
			push += (away if away != Vector2.ZERO else from_center) * (keep_distance - distance) / keep_distance
	var direction: Vector2 = tangent + from_center * radial_error * radius_correction + push * 2.0
	return direction.normalized() * orbit_speed


func _hostile_positions(body: CharacterBody2D) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for hostile: Node2D in body.call(&"get_hostiles"):
		positions.append(hostile.global_position)
	return positions


func get_body_color(base: Color) -> Color:
	if _state == State.WINDUP and fmod(_timer, blink_interval * 2.0) < blink_interval:
		return blink_color
	return base
