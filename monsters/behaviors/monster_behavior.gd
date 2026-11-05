class_name MonsterBehavior
extends Resource
## 몬스터·언데드가 대상과 싸우는 방식 하나 (행동 조각). 예: 다가가기, 돌진하기, 거리 두고 쏘기.
## 대상을 고르는 일(감지 범위, 배회, 언데드의 따라다니기·추격 한계)은 쓰는 쪽(Monster, Undead)이 하고,
## 조각은 정해진 대상과 어떻게 싸울지만 정한다. 수치는 쓰는 쪽이 CombatStats로 넣어 준다.
## 조각은 상태(공격 간격 등)를 가지므로, 쓰는 쪽은 make_instance()로 한 마리에 하나씩 복사해서 쓴다.


## 한 마리가 쓸 복사본
func make_instance() -> MonsterBehavior:
	return duplicate()


## 물리 프레임마다 부른다 (대상이 없을 때도). 공격 간격 같은 시간을 줄인다.
func update(_delta: float) -> void:
	pass


## target과 싸운다. body.velocity를 정한다 (move_and_slide는 쓰는 쪽이 부른다).
## target은 take_damage(amount)가 있어야 한다.
func act(_body: CharacterBody2D, _stats: CombatStats, _target: Node2D) -> void:
	pass
