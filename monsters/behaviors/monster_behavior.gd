class_name MonsterBehavior
extends Resource
## 몬스터·언데드가 대상과 싸우는 방식 하나 (행동 조각). 예: 다가가기, 돌진하기, 거리 두고 쏘기.
## 대상을 고르는 일(감지 범위, 배회, 언데드의 따라다니기·추격 한계)은 쓰는 쪽(Monster, Undead)이 하고,
## 조각은 정해진 대상과 어떻게 싸울지만 정한다. 수치는 쓰는 쪽이 CombatStats로 넣어 준다.
## 조각은 상태(공격 간격 등)를 가지므로, 쓰는 쪽은 make_instance()로 한 마리에 하나씩 복사해서 쓴다.
## 여러 대상을 치는 조각(돌진 등)은 쓰는 쪽의 get_hostiles()로 칠 수 있는 상대를 받는다.


## 한 마리가 쓸 복사본
func make_instance() -> MonsterBehavior:
	return duplicate()


## 물리 프레임마다 부른다 (대상이 없을 때도). 공격 간격 같은 시간을 줄인다.
func update(_delta: float) -> void:
	pass


## 대상이 없어도 하던 동작(예고, 돌진 등)을 이어 가야 하면 true. 그동안 쓰는 쪽은 배회·따라다니기 대신 act()를 계속 부른다.
func is_busy() -> bool:
	return false


## target과 싸운다. body.velocity를 정한다 (move_and_slide는 쓰는 쪽이 부른다).
## target은 take_damage(amount, source)가 있어야 한다 (source는 때린 쪽, 곧 body). is_busy()인 동안에는 target이 null일 수 있다.
func act(_body: CharacterBody2D, _stats: CombatStats, _target: Node2D, _delta: float) -> void:
	pass


## 이 조각의 공격 반경: 이 거리 안이면 공격을 시작한다 (다가가기·던지기는 공격 거리). 언데드가 대상을 고정하는 거리로 쓴다.
func get_engage_range(stats: CombatStats) -> float:
	return stats.attack_range


## 공격 예고 중인지 (돌진 전 깜빡임 등). 밸런스 측정 봇이 피할 때를 고르는 데 쓴다.
func is_telegraphing() -> bool:
	return false


## 예고 중인 공격이 향하는 방향. 아직 정해지지 않았으면 Vector2.ZERO.
func get_attack_direction() -> Vector2:
	return Vector2.ZERO


## 예고 중인 공격 방향이 고정되었는지 (고정 전에 피하면 다시 겨눈다).
func is_attack_locked() -> bool:
	return false


## 예고 중인 공격이 무리 동시 공격인지 (밸런스 측정 봇이 구별하는 데 쓴다).
func is_group_attack() -> bool:
	return false


## 무리 동시 공격 규칙을 만든다 (MonsterPack이 첫 멤버에게 부른다). 지원하지 않으면 null.
func make_pack_attack() -> PackAttack:
	return null


## 무리의 동시 공격 규칙을 받는다. 지원하지 않으면 무시한다.
func join_pack(_pack: PackAttack) -> void:
	pass


## 무리가 프레임마다 알려 주는 자리: 번호(0부터), 싸우는 마리 수(0이면 자리 없음), 자기를 뺀 동료들의 위치. 쓰지 않으면 무시한다.
func set_pack_slot(_index: int, _count: int, _mates: Array[Vector2]) -> void:
	pass


## 지금 무리 동시 공격에 들어갈 수 있는지 (자기 공격 중이 아님). 지원하지 않으면 true (기다리게 하지 않는다).
func can_join_pack_attack() -> bool:
	return true


## 몸 색. 깜빡임 같은 표시가 있으면 바꿔서 돌려준다.
func get_body_color(base: Color) -> Color:
	return base


## 쓰는 쪽의 _draw()에서 몸보다 먼저 부른다 (바닥에 그리는 예고 표시 등). indicator_color는 적·아군을 구별하는 색이다.
func draw_overlay(_canvas: CanvasItem, _indicator_color: Color) -> void:
	pass
