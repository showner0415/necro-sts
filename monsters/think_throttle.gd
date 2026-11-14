class_name ThinkThrottle
extends RefCounted
## 먼 몬스터의 판단 줄이기 규칙 (계획 3b). 노드에 의존하지 않는다.
## - 네크로맨서에게서 far_distance보다 먼 몸은 interval 프레임에 한 번만 판단한다 (행동·시야·대상 찾기). 이동·간격 밀기·그림은 쓰는 쪽이 매 프레임 한다
## - 몸마다 slot(번호)으로 판단하는 프레임을 엇갈려 한 프레임에 몰리지 않게 한다
## - 공격 중(busy)이거나 가까우면, 또는 interval이 1 이하면 매 프레임 판단한다


static func should_think(frame: int, slot: int, interval: int, distance: float, far_distance: float, busy: bool) -> bool:
	if busy or interval <= 1 or distance <= far_distance:
		return true
	return posmod(frame + slot, interval) == 0
