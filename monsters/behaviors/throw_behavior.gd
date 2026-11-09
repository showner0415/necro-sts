class_name ThrowBehavior
extends MonsterBehavior
## 행동 조각 "거리 두고 던지기" (고블린 투석병). 대상과 거리를 두고 돌(Stone)을 곧게 던진다. 예고는 없다.
## - 대상이 던지는 거리(stats.attack_range) 밖이면 다가간다 (stats.move_speed)
## - 대상이 retreat_distance보다 가까우면 대상 반대쪽으로 물러난다 (retreat_speed, 느리게). 물러나면서도 던진다
## - 그 사이면 옆으로 걷는다 (strafe_speed, 0이면 멈춰 선다). 도는 쪽은 던질 때마다 정한다
## - 돌을 던지면 throw_pause_time초 동안 멈춘다. 물러나거나 옆으로 걷는 쪽이 벽에 막히면 벽을 따라 미끄러지지 않고 방향을 틀거나 멈춘다
## - 던지는 거리 안이면 공격 간격(stats.attack_cooldown)마다, 던지는 순간 대상이 있던 쪽으로 돌을 던진다.
##   돌의 피해는 stats.contact_damage, 날아가는 거리는 stats.attack_range다
## 돌은 쓰는 쪽의 적(get_hostile_groups())에게 피해를 주고, 지나가는 그룹(get_stone_pass_groups())은 지나가며, 다른 몸과 벽에는 막힌다 (Stone).

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

@export_group("싸울 때 움직임")
## 돌을 던지고 멈춰 있는 시간 (초). 이 틈이 다가가서 때릴 기회다
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


func update(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_pause_left = maxf(_pause_left - delta, 0.0)


func allows_spacing() -> bool:
	return _pause_left <= 0.0


func is_paused_after_throw() -> bool:
	return _pause_left > 0.0


func act(body: CharacterBody2D, stats: CombatStats, target: Node2D, _delta: float) -> void:
	if _pause_left > 0.0:
		body.velocity = Vector2.ZERO
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
		_attack_timer = stats.attack_cooldown
		throw_stone(body, stats, target)
		_side = 1.0 if randf() < 0.5 else -1.0
		if throw_pause_time > 0.0:
			_pause_left = throw_pause_time
			body.velocity = Vector2.ZERO


## 대상이 지금 있는 쪽으로 돌을 하나 던진다. 던진 돌을 돌려준다 (테스트용).
func throw_stone(body: CharacterBody2D, stats: CombatStats, target: Node2D) -> Stone:
	var origin: Vector2 = body.global_position + Vector2(0, -throw_height)
	var aim: Vector2 = target.global_position + Vector2(0, -throw_height)
	var stone: Stone = stone_scene.instantiate()
	stone.direction = origin.direction_to(aim) if origin != aim else Vector2.RIGHT
	stone.speed = stone_speed
	stone.damage = stats.contact_damage
	stone.max_distance = stats.attack_range
	stone.thrower = body
	stone.hostile_groups = body.call(&"get_hostile_groups")
	stone.pass_groups = body.call(&"get_stone_pass_groups")
	body.get_parent().add_child(stone)
	stone.global_position = origin
	return stone
