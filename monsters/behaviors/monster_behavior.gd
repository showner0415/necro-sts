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


## 몸 색. 깜빡임 같은 표시가 있으면 바꿔서 돌려준다.
func get_body_color(base: Color) -> Color:
	return base


## 쓰는 쪽의 _draw()에서 몸보다 먼저 부른다 (바닥에 그리는 예고 표시 등). indicator_color는 적·아군을 구별하는 색이다.
func draw_overlay(_canvas: CanvasItem, _indicator_color: Color) -> void:
	pass
