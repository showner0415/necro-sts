class_name ApproachBehavior
extends MonsterBehavior
## 행동 조각 "다가가기": 대상에게 다가가서, 공격 거리 안이면 공격 간격마다 몸으로 부딪혀 피해를 준다.
## - hit_and_run을 끄면(쥐 언데드 등): 공격 거리 안에서 멈춰 서서 계속 붙어 싸운다
## - hit_and_run을 켜면(살아 있는 쥐): 물고 나서 back_off_distance만큼 물러나고, pause_time초 멈췄다가 옆으로 돌며 다시 들어온다.
##   공격 간격이 아직 안 지났으면 대상 곁을 돌며 기다린다 (제자리에 서 있지 않는다).
##   옆으로 도는 쪽은 물 때마다 한 번만 정한다 (프레임마다 방향이 튀어 떨리지 않게)
## 공격권(Monster.request_attack)이 없으면 들어오지 않고 대상에게서 맴도는 거리(stats.wait_distance)를 두고 돌며 기다린다. 물면 공격 한 번이 끝난다(공격권 반납).

enum Phase { CLOSE_IN, BACK_OFF, PAUSE }

## 물기 직전 멈춰 있는 시간 (초)
@export var attack_windup: float = 0.0

@export_group("치고 빠지기")
## 물고 나서 물러나는지. 꺼져 있으면 붙어서 싸운다
@export var hit_and_run: bool = false
## 물고 나서 물러나는 거리 (픽셀)와 속도 (픽셀/초)
@export var back_off_distance: float = 40.0
@export var back_off_speed: float = 40.0
## 물러난 뒤 멈추는 시간 (초). 이 틈이 때릴 기회다
@export var pause_time: float = 0.25
## 대상이 이 거리 안이면 곧장 오지 않고 옆으로 돌며 들어온다 (픽셀)
@export var circle_range: float = 56.0
## 들어올 때 옆으로 도는 비율 (1이면 앞으로 가는 것과 같은 세기)
@export var circle_strength: float = 0.75
## 대상 곁을 돌며 기다리는 속도 (픽셀/초)
@export var circle_speed: float = 30.0
## 물러나는 쪽이 이 거리 안에서 벽에 막히면 방향을 튼다 (픽셀)
@export var wall_probe_distance: float = 12.0

@export_group("공격권 기다리기")
## 공격권이 없어 맴돌 때, 맴도는 거리(stats.wait_distance)에서 이만큼 벗어나도 그대로 돈다 (픽셀, 임시값)
@export var wait_band: float = 8.0

var _attack_timer: float = 0.0
var _winding_up: bool = false
var _windup_left: float = 0.0
var _phase: Phase = Phase.CLOSE_IN
var _phase_timer: float = 0.0
var _back_off_origin: Vector2
var _back_off_direction: Vector2 = Vector2.ZERO
## 옆으로 도는 쪽: 1 또는 -1. 물 때마다 정한다
var _side: float = 1.0


func update(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)


func is_winding_up() -> bool:
	return _winding_up


func get_phase() -> Phase:
	return _phase


func act(body: CharacterBody2D, stats: CombatStats, target: Node2D, delta: float) -> void:
	if hit_and_run:
		match _phase:
			Phase.BACK_OFF:
				_back_off(body)
				return
			Phase.PAUSE:
				body.velocity = Vector2.ZERO
				_phase_timer += delta
				if _phase_timer >= pause_time:
					_phase = Phase.CLOSE_IN
				return
	var to_target: Vector2 = target.global_position - body.global_position
	var distance: float = to_target.length()
	# 맴도는 거리 + wait_band × 2 안에 들어오면 공격권을 묻는다. 그보다 멀면 묻지 않고 다가온다 (공격권 시간 제한에 다가오는 시간이 들지 않게).
	# 맴도는 띠(± wait_band)보다 한 띠 더 밖에서부터 묻는다 (맴돌다 띠 밖으로 조금 밀려나도 계속 기다리게).
	# 공격권이 없으면 들어오지 않고 대상 둘레를 맴돌며 기다린다 (하던 물기 직전 멈춤은 이어 간다).
	if not _winding_up and distance <= stats.wait_distance + wait_band * 2.0 and not may_attack(body, target):
		_wait_around(body, stats, target)
		return
	if distance > stats.attack_range:
		_winding_up = false
		var direction: Vector2 = move_direction(body, target.global_position)
		if hit_and_run and distance < circle_range and has_clear_line(body, target):
			direction = (direction + direction.orthogonal() * _side * circle_strength).normalized()
		body.velocity = direction * stats.move_speed
		return
	if _attack_timer == 0.0:
		body.velocity = Vector2.ZERO
		# 물기 직전 잠깐 멈춘다. 그사이 대상이 공격 거리 밖으로 나가면 위에서 다시 다가가며 물지 않는다.
		if attack_windup > 0.0:
			if not _winding_up:
				_winding_up = true
				_windup_left = attack_windup
				return
			_windup_left -= delta
			if _windup_left > 0.0:
				return
			_winding_up = false
		_attack_timer = stats.attack_cooldown
		# 네크로맨서·언데드·몬스터는 서로 다른 클래스라서 이름으로 부른다.
		target.call(&"take_damage", stats.contact_damage, body)
		# 문 것으로 공격 한 번이 끝난다 (공격권 반납).
		attack_done(body)
		if hit_and_run:
			_begin_back_off(body, target)
		return
	# 공격 간격을 기다리는 동안: 치고 빠지는 몬스터는 대상 곁을 돌고, 붙어 싸우는 몬스터는 그대로 선다.
	body.velocity = to_target.normalized().orthogonal() * _side * circle_speed if hit_and_run and distance > 0.0 else Vector2.ZERO


## 공격권이 없을 때: 대상에게서 stats.wait_distance(± wait_band)를 두고 옆으로 돌며 기다린다.
## 멀면 다가가고, 가까우면 물러나고, 그 사이면 circle_speed로 돈다. 도는 쪽이 벽에 막히면 반대로 돈다.
func _wait_around(body: CharacterBody2D, stats: CombatStats, target: Node2D) -> void:
	var to_target: Vector2 = target.global_position - body.global_position
	var distance: float = to_target.length()
	if distance > stats.wait_distance + wait_band:
		body.velocity = move_direction(body, target.global_position) * stats.move_speed
	elif distance <= 0.0:
		body.velocity = Vector2.ZERO
	elif distance < stats.wait_distance - wait_band:
		body.velocity = free_direction(body, -to_target / distance, wall_probe_distance, _side) * back_off_speed
	else:
		var around: Vector2 = free_direction(body, (to_target / distance).orthogonal() * _side, wall_probe_distance, _side)
		if around == Vector2.ZERO:
			_side = -_side
		body.velocity = around * circle_speed


## 물러나는 방향은 문 순간에 한 번만 정한다 (두 대상 사이에서 노리는 대상이 바뀌어도 방향이 튀지 않게).
func _begin_back_off(body: CharacterBody2D, target: Node2D) -> void:
	_phase = Phase.BACK_OFF
	_back_off_origin = body.global_position
	_back_off_direction = target.global_position.direction_to(body.global_position)
	_side = 1.0 if randf() < 0.5 else -1.0


func _back_off(body: CharacterBody2D) -> void:
	var away: Vector2 = free_direction(body, _back_off_direction, wall_probe_distance, _side)
	if away == Vector2.ZERO or body.global_position.distance_to(_back_off_origin) >= back_off_distance:
		body.velocity = Vector2.ZERO
		_phase = Phase.PAUSE
		_phase_timer = 0.0
		return
	body.velocity = away * back_off_speed
