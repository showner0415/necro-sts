class_name ThrowBehavior
extends MonsterBehavior
## 행동 조각 "거리 두고 던지기" (고블린 투석병). 대상과 거리를 두고 돌(Stone)을 곧게 던진다. 예고는 없다.
## - 대상이 던지는 거리(stats.attack_range) 밖이면 다가간다 (stats.move_speed)
## - 대상이 retreat_distance보다 가까우면 대상 반대쪽으로 물러난다 (retreat_speed, 느리게). 물러나면서도 던진다
## - 그 사이면 멈춰 선다
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

var _attack_timer: float = 0.0


func update(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)


func act(body: CharacterBody2D, stats: CombatStats, target: Node2D, _delta: float) -> void:
	var to_target: Vector2 = target.global_position - body.global_position
	var distance: float = to_target.length()
	if distance > stats.attack_range:
		body.velocity = to_target.normalized() * stats.move_speed
		return
	if distance < retreat_distance and distance > 0.0:
		body.velocity = -to_target.normalized() * retreat_speed
	else:
		body.velocity = Vector2.ZERO
	if _attack_timer == 0.0:
		_attack_timer = stats.attack_cooldown
		throw_stone(body, stats, target)


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
