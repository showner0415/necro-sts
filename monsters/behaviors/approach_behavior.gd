class_name ApproachBehavior
extends MonsterBehavior
## 행동 조각 "다가가기": 대상에게 다가가서, 공격 거리 안이면 멈춰 서서 공격 간격마다 몸으로 부딪혀 피해를 준다.

var _attack_timer: float = 0.0


func update(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)


func act(body: CharacterBody2D, stats: CombatStats, target: Node2D, _delta: float) -> void:
	var to_target: Vector2 = target.global_position - body.global_position
	if to_target.length() > stats.attack_range:
		body.velocity = to_target.normalized() * stats.move_speed
		return
	body.velocity = Vector2.ZERO
	if _attack_timer == 0.0:
		_attack_timer = stats.attack_cooldown
		# 네크로맨서·언데드·몬스터는 서로 다른 클래스라서 이름으로 부른다.
		target.call(&"take_damage", stats.contact_damage)
