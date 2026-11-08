class_name ChargeBehavior
extends MonsterBehavior
## 행동 조각 "돌진하기". 돌진 거리 밖이면 대상에게 다가가기만 하고(공격하지 않음), 안이면 예고 → 돌진 → 멈칫을 반복한다.
## - 예고: 제자리에 멈춰 깜빡이고 바닥에 돌진 방향 선을 그린다. 선은 대상을 따라 돌다가 끝나기 lock_time초 전에 고정된다
## - 돌진: 고정된 방향으로, 돌진을 시작할 때 노린 대상이 있던 자리를 지나 overshoot_distance만큼 더 달린다 (최대 charge_distance).
##   벽(world_collision_mask)에 부딪히면 그 자리에서 끝난다. 돌진 방향으로 벽까지 min_charge_room도 못 가면 예고·돌진을 시작하지 않고, 대상에게서 멀어지는 쪽으로 물러나 거리를 벌린다
##   돌진하는 동안 몸끼리는 부딪히지 않고 지나간다 (자기 충돌층을 비워서 상대도 이 몸에 밀리지 않는다). 닿은 상대마다 한 번만 피해(stats.contact_damage)를 주고 밀쳐낸다
## - 멈칫: recover_time초 동안 멈춘다 (때릴 기회)
## 노리는 대상은 다가가는 중에만 바뀐다. 예고를 시작할 때의 대상을 멈칫이 끝날 때까지 유지한다.
## 칠 수 있는 상대는 쓰는 쪽의 get_hostiles()가 정한다 (적 멧돼지: 네크로맨서·언데드, 언데드 멧돼지: 몬스터).

enum State { APPROACH, WINDUP, CHARGE, RECOVER }

## 물러날 방향을 고를 때 살펴보는 방향 수와, 이보다 짧게만 갈 수 있는 방향은 고르지 않는 거리 (픽셀)
const BACK_OFF_DIRECTIONS: int = 8
const BACK_OFF_MIN_ROOM: float = 2.0

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
## 돌진 방향으로 벽(world_collision_mask)에 닿기까지 이 거리(픽셀)도 못 가면 돌진하지 않는다.
## 예고를 시작할 때와 돌진을 시작할 때 실제 몸 모양으로 잰다. 길목에 끼여 제자리 돌진으로 붙어 있는 상대를 치지 않게 한다.
@export var min_charge_room: float = 64.0
## 돌진할 거리가 모자라 물러나기 시작하면, 대상과 이 거리(픽셀)만큼 떨어질 때까지 물러난다
@export var back_off_distance: float = 96.0
## 돌진이 끝난 뒤 멈춰 있는 시간 (초)
@export var recover_time: float = 1.2
## 상대의 발밑이 이 거리 안에 들어오면 돌진에 맞는다 (픽셀)
@export var hit_radius: float = 12.0
## 켜면 돌진 방향 앞쪽(몸 가운데에서 돌진 방향 쪽 반)에 있는 상대만 맞는다. 끄면 방향과 상관없이 hit_radius 안이면 맞는다.
## 기본은 끔 (사용자 결정 2026-11-08: 쥐 언데드 공격 거리 24만 채택하고 이 규칙은 넣지 않음. 측정해 보니 결과가 거의 같았다)
@export var front_only_hit: bool = false
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
## 돌진할 거리가 모자라 물러나는 중인지 (back_off_distance까지 이어 간다)
var _backing_off: bool = false


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
	var distance: float = body.global_position.distance_to(target.global_position)
	# 물러나기 시작했으면 back_off_distance만큼 멀어질 때까지 이어 간다 (64px 경계에서 물러나기·다가가기를 번갈아 하며 흔들리지 않게).
	if _backing_off:
		var away: Vector2 = _back_off_direction(body, target)
		if distance < back_off_distance and away != Vector2.ZERO:
			body.velocity = away * stats.move_speed
			return
		_backing_off = false
	if distance > charge_range:
		body.velocity = move_direction(body, target.global_position) * stats.move_speed
		return
	var clear: bool = has_clear_line(body, target)
	# 대상이 돌진할 최소 거리보다 가까운데 "벽이 가로막음"으로 나오면, 몸이 벽에 닿아 있는 것이다 (그 거리에 벽이 끼어 있을 수 없다).
	# 돌아서 다가가면 대상 쪽으로 밀기만 하므로, 돌진할 거리가 모자란 경우로 보고 물러난다.
	if not clear and distance < min_charge_room:
		_back_off(body, target, stats)
		return
	# 돌진 거리 안이어도 벽이 가로막으면 돌진하지 않고 돌아서 다가간다.
	if not clear:
		body.velocity = move_direction(body, target.global_position) * stats.move_speed
		return
	# 벽에 막혀 돌진할 거리가 너무 짧으면 돌진하지 않고, 대상에게서 멀어지는 쪽으로 물러나 거리를 벌린다 (길목에 끼여 길만 막고 있지 않게).
	if get_room(body, body.global_position.direction_to(target.global_position)) < min_charge_room:
		_back_off(body, target, stats)
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
		# 고정된 방향이 벽에 막혀 거리가 너무 짧으면 돌진하지 않고 다시 다가간다 (멈칫도 없다).
		if get_room(body, _direction) < min_charge_room:
			_state = State.APPROACH
			_locked_target = null
			return
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


## 물러나기를 시작한다 (이번 프레임부터 물러나고, back_off_distance까지 이어 간다). 물러날 곳이 없으면 그 자리에 선다.
func _back_off(body: CharacterBody2D, target: Node2D, stats: CombatStats) -> void:
	var away: Vector2 = _back_off_direction(body, target)
	_backing_off = away != Vector2.ZERO
	body.velocity = away * stats.move_speed


## 돌진할 거리가 모자랄 때 물러날 방향: 8방향 중 대상 쪽이 아닌(대상 방향과 90도 이상) 방향에서 벽까지 가장 멀리 갈 수 있는 쪽.
## 어느 쪽으로도 갈 수 없으면 ZERO (그 자리에 선다).
func _back_off_direction(body: CharacterBody2D, target: Node2D) -> Vector2:
	var to_target: Vector2 = body.global_position.direction_to(target.global_position)
	var best: Vector2 = Vector2.ZERO
	var best_room: float = BACK_OFF_MIN_ROOM
	for i: int in BACK_OFF_DIRECTIONS:
		var direction: Vector2 = Vector2.from_angle(i * TAU / BACK_OFF_DIRECTIONS)
		if direction.dot(to_target) > 0.0:
			continue
		var room: float = get_room(body, direction)
		if room > best_room:
			best_room = room
			best = direction
	return best


## body가 direction으로 곧장 갈 때 벽(world_collision_mask)에 닿기 전까지 갈 수 있는 거리 (최대 charge_distance).
## 몸의 실제 충돌 모양(자식 CollisionShape2D)으로 잰다. 트리 밖이거나 모양이 없으면 charge_distance.
## direction이 영(0) 벡터면(대상과 같은 자리에 겹쳐 있음) 돌진할 방향이 없으므로 0이다.
func get_room(body: CharacterBody2D, direction: Vector2) -> float:
	var shape_node: CollisionShape2D = body.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if not body.is_inside_tree() or shape_node == null or shape_node.shape == null:
		return charge_distance
	if direction == Vector2.ZERO:
		return 0.0
	# 몸이 이미 벽에 살짝 닿아 있어도 0이 되지 않게, 겹친 것을 먼저 떼어 내고 재는 test_move를 쓴다. 벽만 보도록 잠깐 충돌 마스크를 바꾼다.
	var saved_mask: int = body.collision_mask
	body.collision_mask = world_collision_mask
	var collision: KinematicCollision2D = KinematicCollision2D.new()
	var hit: bool = body.test_move(body.global_transform, direction.normalized() * charge_distance, collision)
	body.collision_mask = saved_mask
	return collision.get_travel().length() if hit else charge_distance


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
		# front_only_hit를 켜면 돌진 방향 앞쪽(몸 가운데에서 돌진 방향 쪽 반)에 있는 상대만 맞는다.
		if front_only_hit and (hostile.global_position - body.global_position).dot(_direction) <= 0.0:
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
