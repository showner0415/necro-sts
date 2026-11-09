class_name MonsterAiState
extends RefCounted
## 몬스터의 상태 흐름: 평소 → 발견 → 싸움 → 찾기 → 돌아가기. 노드에 의존하지 않고 판단 재료만 받는다.
## 대상을 고르는 일(감지, 공격자 쫓기, 무리)은 쓰는 쪽(Monster·Aggro)이 그대로 하고, 여기서는 지금 어느 상태인지만 정한다.
## - IDLE (평소): 대상이 없고 하던 동작도 없다. 지금은 배회 (3단계에서 채운다)
## - ALERT (발견): 대상이 없다가 생긴 그 프레임. 지금은 지연 없이 싸움과 똑같이 움직인다
## - COMBAT (싸움): 대상이 보이거나, 하던 동작(돌진 등)을 이어 간다. 행동 조각(MonsterBehavior)이 움직임을 정한다
## - SEARCH (찾기): 쫓던 대상이 벽 뒤로 사라졌다. 지금은 길을 따라 쫓던 것을 그대로 이어 간다 (2단계에서 채운다)
## - RETURNING (돌아가기): 포기하고 시작한 자리로 돌아간다

enum State { IDLE, ALERT, COMBAT, SEARCH, RETURNING }

var state: State = State.IDLE


## 물리 프레임마다 부른다. has_target: 지금 노리는 대상이 있는지, busy: 대상이 없어도 하던 동작을 이어 가는지(행동 조각의 is_busy),
## returning: Aggro가 돌아가는 중인지, target_visible: 노리는 대상이 벽에 가리지 않는지.
func update(has_target: bool, busy: bool, returning: bool, target_visible: bool) -> State:
	if not has_target and not busy:
		state = State.RETURNING if returning else State.IDLE
	elif has_target and (state == State.IDLE or state == State.RETURNING):
		state = State.ALERT
	elif has_target and not target_visible:
		state = State.SEARCH
	else:
		state = State.COMBAT
	return state


## 행동 조각에게 움직임을 맡기는 상태인지
func is_fighting() -> bool:
	return state == State.ALERT or state == State.COMBAT or state == State.SEARCH
