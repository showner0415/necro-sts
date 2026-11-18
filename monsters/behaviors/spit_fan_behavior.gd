class_name SpitFanBehavior
extends MonsterBehavior
## 행동 조각 "부채꼴 뱉기" (동굴 두꺼비, 제안 2026-11-15). 대상에게 느리게 다가가 멈춰 서서, 예고 뒤 침 여러 개를 부채꼴로 한꺼번에 뱉는다.
## - 대상이 뱉는 거리(stats.attack_range) 밖이거나 벽이 가리면 다가간다 (stats.move_speed). 안이면 멈춰 선다. 물러나지 않는다 (투석병과 다른 점)
## - 공격 간격(stats.attack_cooldown)이 지났으면 예고를 시작한다: windup_time초 동안 멈춰 깜빡이고, 바닥에 부채꼴 줄을 그린다
##   (spit_count줄, 줄 사이 spread_degrees도, 길이 spit_range). 줄은 예고를 시작할 때 고른 대상을 따라 돌다가, 끝나기 lock_time초 전에 고정된다 (멧돼지 예고와 같은 말)
## - 예고가 끝나면 고정된 줄마다 침(Stone)을 하나씩 한꺼번에 뱉는다. 예고를 시작하면 대상이 거리 밖으로 나가거나 사라져도 끝까지 뱉는다.
##   가운데 줄은 고정될 때 대상이 있던 쪽이다 (앞을 내다보지 않는다)
## - 뱉은 뒤 recover_time초 동안 멈춰 있다 (때릴 기회)
## - 침은 투석병 돌(Stone)과 같은 규칙이다: 처음 닿는 몸에서 멈춘다. 쓰는 쪽의 적(get_hostile_groups())이면 피해(stats.contact_damage),
##   다른 몸(다른 몬스터)이나 벽이면 피해 없이 멈추고, 지나가는 그룹(get_stone_pass_groups())은 지나간다. 떨어질 곳(그림자 원)은 없고 spit_range를 다 날면 사라진다
## 공격권(Monster.request_attack)이 없으면 예고를 시작하지 않고 대상에게서 맴도는 거리(stats.wait_distance)를 두고 돌며 기다린다. 침을 뱉으면 공격 한 번이 끝난다(공격권 반납).
## 예고 중에는 노리는 대상이 바뀌어도 공격권을 든다 (keeps_token_on_target_change, 멧돼지와 같다).
## 적과 언데드가 같은 조각을 쓴다 (예고 시간도 같다. docs/game-design.md "언데드 능력치와 타게팅": 행동의 타이밍은 원래 몬스터와 같다).

enum State { MOVE, WINDUP, RECOVER }

## 뱉을 침 씬 (Stone을 쓰는 씬)
@export var spit_scene: PackedScene
## 한 번에 뱉는 침 수 (줄 수)
@export var spit_count: int = 3
## 줄 사이 각도 (도). 가운데 줄이 대상 쪽이고 양옆으로 이만큼씩 벌어진다
@export var spread_degrees: float = 18.0
## 침 속도 (픽셀/초)
@export var spit_speed: float = 240.0
## 침이 날아가는 거리 (픽셀). 바닥 줄의 길이이기도 하다
@export var spit_range: float = 220.0
## 침을 뱉는 높이 (발밑에서 몸 가운데까지, 픽셀)
@export var spit_height: float = 6.0

@export_group("예고")
## 예고 시간 (초). 그동안 멈춰 깜빡이고 바닥에 줄을 그린다
@export var windup_time: float = 0.7
## 예고가 끝나기 이 시간 전에 줄이 고정된다 (초)
@export var lock_time: float = 0.3
## 뱉은 뒤 멈춰 있는 시간 (초)
@export var recover_time: float = 0.6
## 깜빡일 때의 몸 색과, 한 번 켜지거나 꺼지는 시간 (초)
@export var blink_color: Color = Color(1, 1, 1, 1)
@export var blink_interval: float = 0.1
## 바닥 줄의 두께 (픽셀)
@export var line_width: float = 1.0

var _state: State = State.MOVE
## 예고·멈춤을 시작하고 흐른 시간 (초)
var _timer: float = 0.0
## 다음 예고까지 남은 공격 간격 (초)
var _attack_timer: float = 0.0
## 가운데 줄의 방향
var _direction: Vector2 = Vector2.RIGHT
## 예고를 시작할 때 고른 대상. 줄이 고정될 때까지 이 대상을 따라 돈다
var _locked_target: Node2D


func update(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)


## 예고 중에는 대상이 사라져도 act를 불러서 끝까지 뱉는다.
func is_busy() -> bool:
	return _state == State.WINDUP


func allows_spacing() -> bool:
	return _state == State.MOVE


## 예고를 시작한 대상을 뱉을 때까지 노리므로, 노리는 대상이 바뀌어도 그 대상의 공격권을 든다 (멧돼지와 같다).
func keeps_token_on_target_change() -> bool:
	return _state == State.WINDUP


func get_state() -> State:
	return _state


## 지금(또는 마지막으로) 정해진 가운데 줄의 방향
func get_direction() -> Vector2:
	return _direction


## 예고 중 줄이 고정되었는지
func is_direction_locked() -> bool:
	return _state == State.WINDUP and _timer >= windup_time - lock_time


func is_telegraphing() -> bool:
	return _state == State.WINDUP


func get_attack_direction() -> Vector2:
	return _direction if _state == State.WINDUP else Vector2.ZERO


func is_attack_locked() -> bool:
	return is_direction_locked()


## 줄마다의 방향 (가운데 줄을 사이에 두고 spread_degrees씩 벌어진다). 줄이 짝수면 가운데 줄 없이 양쪽으로 반씩 벌어진다.
func get_spit_directions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i: int in spit_count:
		var offset: float = (i - (spit_count - 1) / 2.0) * spread_degrees
		result.append(_direction.rotated(deg_to_rad(offset)))
	return result


func act(body: CharacterBody2D, stats: CombatStats, target: Node2D, delta: float) -> void:
	match _state:
		State.WINDUP:
			_windup(body, stats, delta)
		State.RECOVER:
			body.velocity = Vector2.ZERO
			_timer += delta
			if _timer >= recover_time:
				_state = State.MOVE
		_:
			_move(body, stats, target)


func _move(body: CharacterBody2D, stats: CombatStats, target: Node2D) -> void:
	if target == null:
		body.velocity = Vector2.ZERO
		return
	# 공격권을 묻는 거리 안에서 공격권이 없으면 예고를 시작하지 않고 맴도는 거리에서 기다린다.
	if must_wait_for_token(body, stats, target):
		wait_around(body, stats, target)
		return
	var distance: float = body.global_position.distance_to(target.global_position)
	# 뱉는 거리 안이어도 벽이 가로막으면 뱉지 않고 돌아서 다가간다.
	if distance > stats.attack_range or not has_clear_line(body, target):
		body.velocity = chase_direction(body, stats, target) * stats.move_speed
		return
	body.velocity = Vector2.ZERO
	if _attack_timer > 0.0:
		return
	_state = State.WINDUP
	_timer = 0.0
	_locked_target = target
	_aim_at(body, target)


func _windup(body: CharacterBody2D, stats: CombatStats, delta: float) -> void:
	body.velocity = Vector2.ZERO
	# 고정되기 전까지는 예고를 시작할 때의 대상을 따라 돈다. 사라졌으면 마지막 방향 그대로.
	if not is_direction_locked() and is_instance_valid(_locked_target):
		_aim_at(body, _locked_target)
	_timer += delta
	if _timer < windup_time:
		return
	spit(body, stats)
	_attack_timer = stats.attack_cooldown
	_state = State.RECOVER
	_timer = 0.0
	_locked_target = null
	# 침을 뱉으면 공격 한 번이 끝난다 (공격권 반납, docs/game-design.md "몬스터 무리"의 공격권).
	attack_done(body)


func _aim_at(body: CharacterBody2D, target: Node2D) -> void:
	var direction: Vector2 = body.global_position.direction_to(target.global_position)
	if direction != Vector2.ZERO:
		_direction = direction


## 지금 줄들로 침을 한꺼번에 뱉는다. 뱉은 침들을 돌려준다 (테스트용).
func spit(body: CharacterBody2D, stats: CombatStats) -> Array[Stone]:
	var result: Array[Stone] = []
	var origin: Vector2 = body.global_position + Vector2(0, -spit_height)
	var color: Variant = body.get(&"indicator_color")
	for direction: Vector2 in get_spit_directions():
		var stone: Stone = spit_scene.instantiate()
		stone.direction = direction
		stone.speed = spit_speed
		stone.damage = stats.contact_damage
		stone.max_distance = spit_range
		stone.thrower = body
		stone.hostile_groups = body.call(&"get_hostile_groups")
		stone.pass_groups = body.call(&"get_stone_pass_groups")
		# 떨어질 곳이 없는 침이다: 그림자 원을 그리지 않고, 다 날면 아무도 맞히지 않고 사라진다. 포물선도 없다.
		stone.landing_radius = 0.0
		stone.arc_height = 0.0
		stone.ground_offset = spit_height
		if color != null:
			stone.shadow_color = color
		body.get_parent().add_child(stone)
		stone.global_position = origin
		result.append(stone)
	return result


func get_body_color(base: Color) -> Color:
	if _state == State.WINDUP and fmod(_timer, blink_interval * 2.0) < blink_interval:
		return blink_color
	return base


## 3D 화면 층이 예고 앞의 벽을 반투명하게 할 때 쓰는 선: 가운데 줄.
func get_warning_segment(origin: Vector2) -> PackedVector2Array:
	if _state != State.WINDUP:
		return PackedVector2Array()
	return PackedVector2Array([origin, origin + _direction * spit_range])


func draw_overlay(canvas: CanvasItem, indicator_color: Color) -> void:
	if _state != State.WINDUP:
		return
	for direction: Vector2 in get_spit_directions():
		canvas.draw_line(Vector2.ZERO, direction * spit_range, indicator_color, line_width)
