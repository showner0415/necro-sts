class_name Monster
extends CharacterBody2D
## MonsterData 하나로 움직이는 몬스터.
## 배회하다가 네크로맨서나 언데드가 감지 범위에 들어오면 그중 가장 가까운 대상을 노린다.
## 감지 범위에 아무도 없을 때 맞으면 공격한 대상을 쫓고, 종별 추격 포기 조건을 넘으면 포기한다 (Aggro). 포기해도 돌아가지 않고 그 자리에서 배회한다.
## 무리(MonsterPack)에 속해 있으면 무리가 정한 대상(set_pack_target)을 자기 판단보다 먼저 노린다. 무리에 알리는 신호 중(set_alarm_signal)에는 멈춰 깜빡인다.
## 대상과 어떻게 싸울지는 데이터의 행동 조각(data.behavior)이 정하고, 수치는 적일 때의 값(data.get_enemy_stats())을 쓴다.
## 죽으면 드랍 목록(data.drops)의 확률을 굴려 나온 것을 담은 시체(Corpse)를 남긴다. 네크로맨서가 시체에서 채집한다.

@export var data: MonsterData
## 죽을 때 남길 시체 씬
@export var corpse_scene: PackedScene
## 맞았을 때 하얗게 번쩍이는 시간 (초)
@export var hit_flash_duration: float = 0.1
## 날아다니는 몬스터(data.flying)가 쓰는 충돌층과, 부딪히는 대상(벽)
@export_flags_2d_physics var flying_layer: int = 32
@export_flags_2d_physics var flying_mask: int = 1
## 행동 조각이 바닥에 그리는 예고 표시(돌진 방향 선 등)의 색. 적은 위험 표시 색(e43b44)이다.
@export var indicator_color: Color = Color(0.89411765, 0.23137255, 0.26666668, 1)
## 네크로맨서에게 맞은 뒤 이 시간(초) 동안, 대상이 없는 언데드가 고를 수 있는 몬스터가 된다 (임시값)
@export var necromancer_mark_duration: float = 5.0
## 몸끼리 비켜 서는 세기가 이보다 약하면 밀지 않는다 (거의 떨어졌을 때 떨리지 않게)
@export var spacing_deadband: float = 0.05
## 무리에 알리는 신호 중에 깜빡일 때의 밝기 배율과 깜빡이는 간격 (초). 밝기는 modulate의 색에 곱하므로 그림과 임시 도형 모두 밝아진다
@export var alarm_blink_brightness: float = 2.0
@export var alarm_blink_interval: float = 0.1

## 맞았을 때 (source는 때린 쪽). 무리가 이것으로 무리 대상을 정한다.
signal hit_by(source: Node2D)

var health: float
## 지금 노리는 대상 (네크로맨서 또는 언데드). take_damage(amount, source)가 있어야 한다.
var _target: Node2D
## 무리 대상과 상관없이 스스로 노렸을 대상 (감지·공격자 쫓기)
var _own_target: Node2D
## 무리(MonsterPack)가 정한 대상. 있으면 _own_target 대신 이것을 노린다.
var _pack_target: Node2D
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
## 평소에 감지해서 보던 대상 (놓치면 그 대상을 쫓는다)
var _seen_target: Node2D
## 감지 범위 밖에서 맞았을 때 공격자를 쫓는 규칙
var _aggro: Aggro
## 평소 → 발견 → 싸움 → 찾기
var _ai: MonsterAiState = MonsterAiState.new()
## 그림이 있는 몬스터(data.has_sprite())의 8방향 그림. 없으면 null이고 임시 도형으로 그린다
var _sprite: FacingSprite
## 이보다 느리게 움직이면(벽에 미끄러질 때의 아주 작은 속도 등) 그림 방향을 바꾸지 않는다 (픽셀/초)
const SPRITE_TURN_SPEED: float = 1.0
## 무리에 알리는 신호를 내는 중인지 (MonsterPack이 정한다), 신호를 시작하고 흐른 시간, 깜빡임이 밝기를 바꿔 놓았는지 (신호가 끝나면 되돌린다)
var _alarm_signalling: bool = false
var _signal_elapsed: float = 0.0
var _blink_on: bool = false

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	health = data.max_health
	_behavior = data.make_enemy_behavior()
	_aggro = Aggro.new(data.chase_attacker_limit, data.chase_lost_time, data.chase_time_limit)
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
	# 쫓다가 포기하면(Aggro가 평소로 돌아가면) 그 자리에서 감지 범위 안의 대상만 다시 본다.
	_own_target = _aggro.attacker as Node2D if _aggro.state == Aggro.State.CHASING else nearest
	# 무리에 대상이 있으면 자기 판단과 상관없이 그 대상을 노린다.
	_target = _pack_target if _is_alive_node(_pack_target) else _own_target
	var target_visible: bool = _target != null and _path_follower.can_see(self, _target.global_position)
	_ai.update(_target != null, _behavior.is_busy(), target_visible)
	# 하던 동작(돌진 예고 등)은 대상이 사라져도 이어 간다. 찾기(대상이 벽 뒤)는 지금은 길을 따라 쫓는 것을 그대로 쓴다.
	# 무리에 알리는 신호 중에는 멈춰 깜빡인다 (밀려나는 것은 그대로).
	if _alarm_signalling:
		velocity = Vector2.ZERO
	elif _ai.is_fighting():
		_behavior.act(self, data.get_enemy_stats(), _target, delta)
		_apply_spacing()
	else:
		_wander(delta)
	_update_signal_blink(delta)
	if _knockback.is_active():
		velocity = _knockback.get_velocity()
	move_and_slide()
	_knockback.update(delta)
	_update_sprite()
	# 예고 표시(깜빡임, 방향 선)가 프레임마다 바뀐다.
	queue_redraw()


## 싸우는 동안 다른 몬스터와 한 점에 겹치지 않게 속도를 민다 (data.combat_spacing이 0이면 하지 않는다). 날아다니는 몸은 겹쳐 지나간다.
func _apply_spacing() -> void:
	if data.combat_spacing <= 0.0 or data.flying or not _behavior.allows_spacing():
		return
	var others: Array[Vector2] = []
	var ids: Array[int] = []
	for node: Node in get_tree().get_nodes_in_group(&"monsters"):
		var other: Monster = node as Monster
		if other == null or other == self or other.is_queued_for_deletion() or other.data.flying:
			continue
		others.append(other.global_position)
		ids.append(other.get_instance_id())
	var push: Vector2 = BodySpacing.push(global_position, get_instance_id(), others, ids, data.combat_spacing)
	if push.length() >= spacing_deadband:
		velocity = (velocity + push * data.move_speed).limit_length(maxf(velocity.length(), data.move_speed))


## 테스트·디버그용: 지금 노리는 대상 (없으면 null)
func get_target() -> Node2D:
	return _target


## 테스트·디버그용: 지금 상태 (평소·발견·싸움·찾기)
func get_ai_state() -> MonsterAiState.State:
	return _ai.state


## 행동 조각이 부른다: goal(발밑 좌표)로 가려면 움직일 방향. 벽이 가로막으면 돌아가는 방향이다.
func get_move_direction(goal: Vector2) -> Vector2:
	return _path_follower.get_direction(self, goal)


## 행동 조각이 부른다: goal(발밑 좌표)까지 벽이 가로막지 않는지.
func has_clear_line_to(goal: Vector2) -> bool:
	return _path_follower.is_line_clear(self, goal)


## 테스트·디버그용: 길찾기 (지금 따라가는 길)
func get_path_follower() -> PathFollower:
	return _path_follower


## 테스트·디버그용: 공격자 추격 상태 (Aggro.State)
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
func set_pack_target(target: Node2D) -> void:
	_pack_target = target


## 무리가 함께 포기했을 때 부른다. 돌아가지 않고 그 자리에서 평소 행동(배회)을 한다. 스스로 쫓던 것도 그만둔다.
func clear_pack_target() -> void:
	_pack_target = null
	_aggro.give_up()


## 무리(MonsterPack)가 정해 준다: 지금 무리에 알리는 신호를 내는 중인지. 신호 중에는 멈춰 깜빡인다.
func set_alarm_signal(signalling: bool) -> void:
	if signalling and not _alarm_signalling:
		_signal_elapsed = 0.0
	_alarm_signalling = signalling


## 테스트·디버그용: 무리에 알리는 신호를 내는 중인지
func is_alarm_signalling() -> bool:
	return _alarm_signalling


## 신호 중에는 alarm_blink_interval마다 밝아졌다 돌아온다. 투명도(modulate.a, 시야)는 건드리지 않는다.
## 신호 중에는 프레임마다 밝기를 쓴다: 맞았을 때의 번쩍임(색을 1로 되돌리는 트윈, hit_flash_duration)이 끝난 뒤에도 깜빡임이 보이게 한다.
## 트윈은 물리 프레임 뒤에 돌므로, 맞아서 신호가 나면 처음 hit_flash_duration(0.1초) 동안은 번쩍임이 보이고 그 뒤 깜빡인다.
func _update_signal_blink(delta: float) -> void:
	if not _alarm_signalling:
		if _blink_on:
			_blink_on = false
			_set_brightness(1.0)
		return
	_signal_elapsed += delta
	_blink_on = true
	var on: bool = alarm_blink_interval <= 0.0 or fmod(_signal_elapsed, alarm_blink_interval * 2.0) < alarm_blink_interval
	_set_brightness(alarm_blink_brightness if on else 1.0)


func _set_brightness(value: float) -> void:
	modulate = Color(value, value, value, modulate.a)


## point(발밑 좌표)가 보이는지: 몸 가운데에서 point까지 벽이 가리지 않는지 (거리는 보지 않는다). 무리가 시야를 합칠 때 쓴다.
func can_see_point(point: Vector2) -> bool:
	return _path_follower.can_see(self, point)


## 무리 판단용: 무리 대상과 상관없이 이 몬스터가 스스로 노렸을 대상 (감지·공격자 쫓기 규칙)
func get_own_target() -> Node2D:
	return _own_target


func _is_alive_node(node: Node2D) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion()


## source는 공격한 쪽. 감지 범위에 아무도 없을 때 맞으면 그 대상을 쫓는다. 무리는 hit_by로 알고 무리 전체가 source를 노린다.
func take_damage(amount: float, source: Node2D = null) -> void:
	if health <= 0.0:
		return
	_aggro.on_hit(source, _find_nearest_target() != null)
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


## 임시 도형의 지금 색 (예고 깜빡임 포함). 3D 화면 층이 읽는다.
func get_placeholder_tint() -> Color:
	return _behavior.get_body_color(data.placeholder_color)


## 지금 바닥에 그리는 예고 선의 양 끝 (없으면 빈 배열). 3D 화면 층이 읽는다.
func get_warning_segment() -> PackedVector2Array:
	return _behavior.get_warning_segment(global_position)


## 바닥의 예고 표시를 canvas에 그린다. 2D에서는 자기 자신에, 3D 화면 층에서는 바닥 캔버스에 그린다.
func draw_ground_marks(canvas: CanvasItem) -> void:
	_behavior.draw_overlay(canvas, indicator_color)


func _draw() -> void:
	# 바닥의 예고 표시를 먼저 그리고, 기준점(발밑) 위에 몸을 그린다. 그림이 있으면 몸은 그림(_sprite)이고, 없으면 임시 도형이다.
	draw_ground_marks(self)
	if _sprite == null:
		PlaceholderBody.draw(self, data, get_placeholder_tint(), PlaceholderBody.center(data))


## 평소(IDLE)에 보던 대상을 기억했다가, 놓치면(벽 뒤로 숨거나 감지 범위를 벗어남) 공격자를 쫓을 때와 같은 포기 조건까지 쫓는다.
func _remember_seen_target(nearest: Node2D) -> void:
	if _aggro.state != Aggro.State.IDLE:
		_seen_target = null
		return
	if nearest != null:
		_seen_target = nearest
		return
	# 사라진 객체는 형이 있는 인자로 넘기면 오류이므로 여기서 바로 확인한다.
	if is_instance_valid(_seen_target) and not _seen_target.is_queued_for_deletion():
		_aggro.start_chase(_seen_target)
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
