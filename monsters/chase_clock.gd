class_name ChaseClock
extends RefCounted
## 쫓다가 포기하는 조건(종마다 다르다, docs/game-design.md "몬스터 타게팅")을 재는 시계. 노드에 의존하지 않는다.
## 몬스터 하나의 추격(Aggro)과 무리(MonsterPack)가 하나씩 갖는다. 무리는 무리원 모두의 눈을 합쳐서 넣는다.
## - 못 본 시간: 대상이 보이지 않는(벽이 가린) 동안 흐른다. 다시 보면 처음부터 잰다
## - 추격 시간: 대상이 감지 범위 밖이거나 안 보이는 동안 흐른다. 감지 범위 안에서 보이면(싸우는 중) 처음부터 재고, 맞아도 처음부터 잰다
## 포기 조건의 값은 몸마다(종마다) 다르므로 gives_up()에 그 몸의 값을 넣어 묻는다. 값이 0인 조건은 쓰지 않는다.

## 대상을 못 본 시간 (초)
var unseen_elapsed: float = 0.0
## 감지 범위 밖의(또는 안 보이는) 대상을 쫓은 시간 (초)
var chase_elapsed: float = 0.0


## 새 추격을 시작할 때 부른다.
func reset() -> void:
	unseen_elapsed = 0.0
	chase_elapsed = 0.0


## 쫓는 쪽이 맞았다. 추격 시간을 처음부터 다시 잰다 (건드리는 동안은 계속 쫓는다).
func on_hit() -> void:
	chase_elapsed = 0.0


## 물리 프레임마다 부른다. seen: 대상이 보이는지 (벽이 가리지 않는지), detected: 감지 범위 안에서 보이는지.
func update(delta: float, seen: bool, detected: bool) -> void:
	unseen_elapsed = 0.0 if seen else unseen_elapsed + delta
	chase_elapsed = 0.0 if detected else chase_elapsed + delta


## 이 몸의 포기 조건을 넘었는지. distance: 대상까지의 거리, distance_limit: 이보다 멀면 포기,
## lost_time: 이 시간(초) 넘게 못 보면 포기, chase_time_limit: 이 시간(초) 넘게 쫓으면 포기. 0인 조건은 쓰지 않는다.
func gives_up(distance: float, distance_limit: float, lost_time: float, chase_time_limit: float) -> bool:
	if distance_limit > 0.0 and distance > distance_limit:
		return true
	if lost_time > 0.0 and unseen_elapsed > lost_time:
		return true
	return chase_time_limit > 0.0 and chase_elapsed > chase_time_limit
