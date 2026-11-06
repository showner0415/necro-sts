class_name DiveBehavior
extends MonsterBehavior
## 행동 조각 "치고 빠지기" (박쥐). 다가가기 → 예고 → 돌진해 한 번 물기 → 물러나기 → 돌기 → 다시 예고를 반복한다.
## - 다가가기: 대상이 dive_range 밖이면 다가간다
## - 예고: windup_time초 동안 멈춰 깜빡인다
## - 돌진: 돌진을 시작하는 순간 대상이 있던 쪽으로 방향을 고정하고 곧게 날아간다.
##   칠 수 있는 상대(get_hostiles()) 중 하나가 bite_range 안에 들어오면 한 번 물고 끝난다. dive_distance까지 못 물면 빗나간 것으로 끝난다
## - 물러나기: 대상의 반대쪽으로, 대상과 도는 반경만큼 떨어질 때까지 물러난다
## - 돌기: orbit_time초 동안 대상 주변을 도는 반경으로 돈다. 칠 수 있는 상대 모두와 keep_distance 이상 떨어지도록 가까운 쪽에서는 바깥으로 비켜 돈다.
##   도는 방향(시계 / 반시계)과 도는 반경(orbit_radius_min~max)은 한 마리마다 무작위다.
##   도는 동안 속도와 방향이 약하게 흔들린다 (orbit_speed_wobble, orbit_angle_wobble_deg)
## - 무리에서 돌기: 무리(MonsterPack)가 알려 준 자리 번호로 구역을 나눈다. 구역 가운데는 "무리 회전각 + 번호 × 360°/마리 수"이고,
##   무리 회전각은 pack_formation_turn_time초에 한 바퀴 돈다. 박쥐는 구역 안에서 자기 방향으로 돌다가 구역 끝에 닿으면 방향을 바꾼다
##   (구역 밖이면 구역 쪽으로 돈다). 무리 동료와는 pack_spacing 이상 떨어진다. 1마리만 남으면 구역 없이 돈다
## - 동시 돌진 자리 잡기: 무리가 동시 돌진할 때가 되면 혼자 예고하지 않고 자기 자리(구역 가운데, 자기 반경)로 곧장 날아가
##   그 근처(pack_ready_angle_deg)에서 기다린다. 모두 모이거나 pack_assemble_timeout초가 지나면 무리 예고가 시작된다
## 물기 피해는 stats.contact_damage, 다가가는 속도는 stats.move_speed다.
## 무리 동시 돌진: 무리(MonsterPack)에 들어 있으면 공유 규칙(PackAttack)을 따라, 다가가거나 도는 중에 무리 예고가 시작되면
## 그 자리에 멈춰 pack_windup_time초 동안 깜빡이고, 끝나기 pack_lock_time초 전에 대상 쪽으로 방향을 고정한 뒤 모두 함께 돌진한다.
## 돌진부터는 평소와 같다 (물기 → 물러나기 → 돌기). 언데드나 무리 없는 박쥐는 동시 돌진을 하지 않는다.

enum State { APPROACH, WINDUP, DIVE, RETREAT, ORBIT, PACK_WINDUP }


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
## 돌 때 대상과의 거리 (픽셀). 한 마리마다 이 사이에서 무작위로 정한다
@export var orbit_radius_min: float = 60.0
@export var orbit_radius_max: float = 60.0
## 도는 속도가 흔들리는 비율 (0.15면 ±15%)
@export var orbit_speed_wobble: float = 0.0
## 도는 방향이 흔들리는 각도 (도)
@export var orbit_angle_wobble_deg: float = 0.0
## 흔들림의 빠르기 (초당 흔들리는 횟수, 한 마리마다 0.7~1.3배로 다르다)
@export var orbit_wobble_frequency: float = 0.8
## 돌 때 칠 수 있는 상대 모두와 유지하는 최소 거리 (픽셀)
@export var keep_distance: float = 40.0
## 너무 가까운 상대·동료에게서 비키는 세기 (도는 방향과 반경으로 되돌아가는 힘에 견준 배율)
@export var keep_push_strength: float = 4.0
## 도는 속도 (픽셀/초)
@export var orbit_speed: float = 80.0
## 돌고 나서 다시 예고하기까지 (초)
@export var orbit_time: float = 2.0
## 반경에서 벗어났을 때 되돌아가는 세기 (1이면 도는 속도만큼)
@export var radius_correction: float = 1.5

@export_group("무리 동시 돌진")
## 싸우는 동안 이 시간(초)마다 무리가 동시 돌진한다
@export var pack_interval: float = 6.0
## 동시 돌진 예고 시간 (초)
@export var pack_windup_time: float = 0.4
## 예고가 끝나기 이 시간(초) 전에 돌진 방향이 고정된다. 0이면 날아가는 순간 대상이 있던 쪽으로 정한다 (걷기로는 피하지 못하고, 날아오는 순간 구르면 무적으로 피한다)
@export var pack_lock_time: float = 0.0
## 싸우는 멤버가 이 수 이상일 때만 동시 돌진한다
@export var pack_min_members: int = 2
## 무리의 구역들이 한 바퀴 도는 시간 (초). 0이면 돌지 않는다
@export var pack_formation_turn_time: float = 12.0
## 무리 동료와 유지하는 최소 거리 (픽셀)
@export var pack_spacing: float = 32.0
## 구역 중 실제로 오가는 비율 (1이면 구역 끝까지). 이웃 구역과 겹치지 않게 조금 남긴다
@export var pack_sector_fill: float = 0.8
## 동시 돌진 때가 되면 구역 가운데로 모이고, 모두 가운데에서 이 각도(도) 안에 들어오면 예고를 시작한다
@export var pack_ready_angle_deg: float = 20.0
## 동시 돌진 때가 되고 이 시간(초)이 지나도 다 모이지 못하면, 자리와 상관없이 시작한다
@export var pack_assemble_timeout: float = 1.5
## 자리 잡기에서 자리에 이 거리(픽셀) 안으로 들어오면 느려지기 시작한다 (지나쳐 흔들리지 않게)
@export var pack_assemble_slowdown: float = 12.0

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
## 무리의 동시 공격 규칙 (무리가 없으면 null)
var _pack: PackAttack
## 마지막으로 들어간 동시 공격 번호 (같은 예고에 두 번 들어가지 않게)
var _pack_round: int = 0
## 동시 돌진 예고에서 방향을 고정했는지
var _pack_locked: bool = false
## 지금 돌진이 동시 돌진인지
var _pack_dive: bool = false
## 무리 안의 자리 번호와 살아 있는 마리 수 (무리가 없거나 1마리면 구역 없음), 동료들의 위치
var _pack_index: int = 0
var _pack_count: int = 0
var _pack_mates: Array[Vector2] = []
## 이 박쥐의 도는 반경 (처음 쓸 때 정한다, 0이면 아직)
var _radius: float = 0.0
## 흔들림: 흐른 시간, 박쥐마다 다른 빠르기 배율과 위상 4개
var _wobble_time: float = 0.0
var _wobble_rate: float = 1.0
var _wobble_phases: Array[float] = []
## 처음 정한 도는 방향. 동시 돌진 자리 잡기로 바뀐 방향을 돌진 뒤 되돌릴 때 쓴다
var _home_sign: float = 1.0
## 마지막으로 act에서 본 자기 위치 (구역 안인지 판단할 때)
var _last_position: Vector2


func make_pack_attack() -> PackAttack:
	var pack: PackAttack = PackAttack.new(pack_interval, pack_windup_time, pack_lock_time, pack_min_members, pack_formation_turn_time)
	pack.assemble_timeout = pack_assemble_timeout
	return pack


func join_pack(pack: PackAttack) -> void:
	_pack = pack


## 무리가 프레임마다 알려 준다: 자리 번호(0부터), 살아 있는 마리 수, 자기를 뺀 동료들의 위치.
func set_pack_slot(index: int, count: int, mates: Array[Vector2]) -> void:
	_pack_index = index
	_pack_count = count
	_pack_mates = mates


## 동시 돌진은 다가가는 중이거나, 자기 구역 가운데 근처(pack_ready_angle_deg)에서 도는 중일 때 들어갈 수 있다 (흩어진 자리에서 들어오도록).
func can_join_pack_attack() -> bool:
	if _state == State.APPROACH:
		return true
	return _state == State.ORBIT and (not _has_sector() or _pack.is_assembly_overdue() or absf(get_sector_offset(_last_position, _anchor)) <= deg_to_rad(pack_ready_angle_deg))


## 이 박쥐의 도는 반경 (orbit_radius_min~max에서 한 번 정한다)
func get_orbit_radius() -> float:
	if _radius <= 0.0:
		_radius = randf_range(orbit_radius_min, orbit_radius_max)
	return _radius


## 무리 구역을 쓰는지 (무리에 있고 2마리 이상 살아 있음)
func _has_sector() -> bool:
	return _pack != null and _pack_count > 1


## 자기 구역 가운데의 각도
func get_sector_center() -> float:
	return _pack.get_formation_angle() + _pack_index * TAU / _pack_count


## 구역 가운데에서 한쪽으로 오가는 최대 각도
func get_sector_half_width() -> float:
	return PI / _pack_count * pack_sector_fill


## position이 center 주위에서 구역 가운데로부터 몇 라디안 떨어졌는지 (-PI~PI)
func get_sector_offset(position: Vector2, center: Vector2) -> float:
	return wrapf((position - center).angle() - get_sector_center(), -PI, PI)


func is_group_attack() -> bool:
	return _state == State.PACK_WINDUP or (_state == State.DIVE and _pack_dive)


func is_busy() -> bool:
	return _state == State.WINDUP or _state == State.DIVE or _state == State.RETREAT or _state == State.PACK_WINDUP


func get_state() -> State:
	return _state


func get_orbit_sign() -> float:
	return _orbit_sign


func is_telegraphing() -> bool:
	return _state == State.WINDUP or _state == State.DIVE or _state == State.PACK_WINDUP


func get_attack_direction() -> Vector2:
	return _direction if is_attack_locked() else Vector2.ZERO


## 박쥐는 돌진을 시작해야 방향이 정해진다. 동시 돌진은 예고가 끝나기 조금 전에 정해진다.
func is_attack_locked() -> bool:
	return _state == State.DIVE or (_state == State.PACK_WINDUP and _pack_locked)


func act(body: CharacterBody2D, stats: CombatStats, target: Node2D, delta: float) -> void:
	if _orbit_sign == 0.0:
		_orbit_sign = 1.0 if randf() < 0.5 else -1.0
		_home_sign = _orbit_sign
		get_orbit_radius()
		_wobble_rate = randf_range(0.7, 1.3)
		for i: int in 4:
			_wobble_phases.append(randf() * TAU)
	if target != null:
		_anchor = target.global_position
	_last_position = body.global_position
	# 무리 예고가 새로 시작되었으면, 자기 공격 중이 아닐 때 따라 들어간다.
	if _pack != null and _pack.is_winding_up() and _pack.get_round() != _pack_round and can_join_pack_attack():
		_begin_pack_windup(body)
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
		State.PACK_WINDUP:
			_pack_windup(body, delta)


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
	_aim(body)
	_dive_start = body.global_position
	_state = State.DIVE
	_pack_dive = false


## 대상이 있던 쪽으로 방향을 정한다.
func _aim(body: CharacterBody2D) -> void:
	var direction: Vector2 = body.global_position.direction_to(_anchor)
	if direction != Vector2.ZERO:
		_direction = direction


func _begin_pack_windup(body: CharacterBody2D) -> void:
	body.velocity = Vector2.ZERO
	_state = State.PACK_WINDUP
	_timer = 0.0
	_pack_round = _pack.get_round()
	_orbit_sign = _home_sign
	_pack_locked = false


## 무리 예고: 멈춰 깜빡이다가, 규칙이 방향을 고정하라고 하면 고정하고, 예고가 끝나면 함께 돌진한다.
func _pack_windup(body: CharacterBody2D, delta: float) -> void:
	body.velocity = Vector2.ZERO
	_timer += delta
	if not _pack_locked and (_pack.is_direction_locked() or not _pack.is_winding_up()):
		_aim(body)
		_pack_locked = true
	if not _pack.is_winding_up():
		_dive_start = body.global_position
		_state = State.DIVE
		_pack_dive = true
		_pack_locked = false


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
	if body.global_position.distance_to(_anchor) >= get_orbit_radius():
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
	var assembling: bool = _has_sector() and _pack.is_assembling()
	# 무리가 동시 돌진 자리를 잡는 중이면 혼자 예고하지 않는다.
	if _timer >= orbit_time and not assembling:
		_begin_windup(body)
		return
	var center: Vector2 = target.global_position
	if assembling:
		body.velocity = get_assemble_velocity(body.global_position, center, _hostile_positions(body))
		return
	if _has_sector():
		_turn_at_sector_edge(body.global_position, center)
	var mates: Array[Vector2] = _pack_mates if _has_sector() else ([] as Array[Vector2])
	var velocity: Vector2 = get_orbit_velocity(body.global_position, center, _hostile_positions(body), mates)
	_wobble_time += delta
	body.velocity = apply_wobble(velocity, _wobble_time)


## 동시 돌진 자리 잡기: 원을 따라 돌지 않고 자기 자리(구역 가운데, 자기 반경)로 곧장 날아간다 (retreat_speed).
## 대상이 움직여도 따라잡도록 빠르게 가고, 가까워지면 느려져서 자리에 머문다. 칠 수 있는 상대와는 keep_distance를 둔다.
func get_assemble_velocity(position: Vector2, center: Vector2, hostiles: Array[Vector2]) -> Vector2:
	var spot: Vector2 = center + Vector2.RIGHT.rotated(get_sector_center()) * get_orbit_radius()
	var to_spot: Vector2 = spot - position
	var push: Vector2 = _push_away(position, hostiles, keep_distance, center.direction_to(position))
	var direction: Vector2 = to_spot.normalized() + push * keep_push_strength
	if direction == Vector2.ZERO:
		return Vector2.ZERO
	# 자리에서 pack_assemble_slowdown 픽셀 안이면 거리에 비례해 느려진다.
	return direction.normalized() * retreat_speed * minf(1.0, to_spot.length() / pack_assemble_slowdown)


## 구역 끝을 넘었으면 구역 가운데 쪽으로 돌도록 방향을 바꾼다. 안쪽에서는 지금 방향을 그대로 둔다.
## (_orbit_sign 1은 각도가 줄어드는 쪽, -1은 늘어나는 쪽이다. orthogonal()이 (y, -x)이므로.)
func _turn_at_sector_edge(position: Vector2, center: Vector2) -> void:
	var offset: float = get_sector_offset(position, center)
	var half: float = get_sector_half_width()
	if offset > half:
		_orbit_sign = 1.0
	elif offset < -half:
		_orbit_sign = -1.0


## 돌 때의 속도: 대상 주변 접선 방향 + 반경으로 되돌아가기 + 너무 가까운 상대에게서 바깥으로 비키기
## + 너무 가까운 무리 동료(mates)에게서 비키기.
func get_orbit_velocity(position: Vector2, center: Vector2, hostiles: Array[Vector2], mates: Array[Vector2] = []) -> Vector2:
	var from_center: Vector2 = center.direction_to(position)
	if from_center == Vector2.ZERO:
		from_center = Vector2.RIGHT
	var tangent: Vector2 = from_center.orthogonal() * _orbit_sign
	var radius: float = get_orbit_radius()
	var radial_error: float = (radius - position.distance_to(center)) / radius
	var push: Vector2 = _push_away(position, hostiles, keep_distance, from_center) + _push_away(position, mates, pack_spacing, tangent)
	var direction: Vector2 = tangent + from_center * radial_error * radius_correction + push * keep_push_strength
	return direction.normalized() * orbit_speed


## others 중 limit보다 가까운 것들에게서 멀어지는 방향 (가까울수록 세다). 같은 자리면 fallback 쪽.
func _push_away(position: Vector2, others: Array[Vector2], limit: float, fallback: Vector2) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for other: Vector2 in others:
		var distance: float = position.distance_to(other)
		if distance < limit:
			var away: Vector2 = other.direction_to(position)
			push += (away if away != Vector2.ZERO else fallback) * (limit - distance) / limit
	return push


## 도는 속도에 약한 흔들림을 더한다: 속도는 ±orbit_speed_wobble 비율, 방향은 ±orbit_angle_wobble_deg 도.
## 박쥐마다 빠르기와 위상이 다른 사인파 두 개를 섞어 부드럽게 불규칙하게 만든다.
func apply_wobble(velocity: Vector2, time: float) -> Vector2:
	if _wobble_phases.size() < 4:
		return velocity
	var t: float = time * orbit_wobble_frequency * _wobble_rate * TAU
	var speed_noise: float = sin(t + _wobble_phases[0]) * 0.6 + sin(t * 1.73 + _wobble_phases[1]) * 0.4
	var angle_noise: float = sin(t * 1.31 + _wobble_phases[2]) * 0.6 + sin(t * 2.17 + _wobble_phases[3]) * 0.4
	return velocity.rotated(deg_to_rad(orbit_angle_wobble_deg) * angle_noise) * (1.0 + orbit_speed_wobble * speed_noise)


func _hostile_positions(body: CharacterBody2D) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for hostile: Node2D in body.call(&"get_hostiles"):
		positions.append(hostile.global_position)
	return positions


func get_body_color(base: Color) -> Color:
	if (_state == State.WINDUP or _state == State.PACK_WINDUP) and fmod(_timer, blink_interval * 2.0) < blink_interval:
		return blink_color
	return base
