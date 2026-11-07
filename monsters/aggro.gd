class_name Aggro
extends RefCounted
## 몬스터 타게팅 중 "감지 범위 밖에서 맞으면 공격한 대상을 쫓고, 보던 대상을 놓쳐도 쫓는" 규칙. 노드에 의존하지 않고 위치만 받는다.
## - IDLE: 평소. 감지 범위 안의 가장 가까운 대상을 노린다 (그 판단은 쓰는 쪽이 한다)
## - CHASING: 감지 범위에 아무도 없을 때 맞았거나, 보던 대상을 놓쳤다(start_chase). 그 대상(attacker)을 쫓는다
##   감지 범위에 누가 들어오면 IDLE로 (그때부터 가장 가까운 대상)
##   다음이면 포기하고 RETURNING으로:
##   - 쫓는 대상과 attacker_limit보다 멀어짐 (보이든 안 보이든. 걸어서 도망칠 수 있게)
##   - 대상이 보이는 동안: 쫓기 시작한 자리(origin)에서 visible_home_limit보다 멀어짐 (몬스터를 맵 끝까지 끌고 가지 못하게)
##   - 대상이 보이지 않는 동안: lost_time초가 지남 (다시 보면 처음부터 잰다). 꺾인 길이 길어도 모퉁이 하나는 돌아온다
## - RETURNING: 맞기 시작한 자리로 돌아간다. 다 돌아갈 때까지 감지·피격을 무시한다

enum State { IDLE, CHASING, RETURNING }

var attacker_limit: float
var visible_home_limit: float
var lost_time: float
## 이 거리 안이면 다 돌아온 것으로 본다
var arrive_distance: float

var state: State = State.IDLE
## 쫓는 공격자. 쓰는 쪽이 위치를 넘겨주므로 여기서는 누구인지만 기억한다.
var attacker: Object
## 쫓기 시작한 자리 (맞기 시작한 자리, 또는 처음 대상을 본 자리)
var origin: Vector2
## 대상이 보이지 않게 된 뒤 지난 시간 (초)
var _lost_elapsed: float = 0.0


func _init(attacker_distance_limit: float, visible_home_distance_limit: float, lost_seconds: float, arrive: float) -> void:
	attacker_limit = attacker_distance_limit
	visible_home_limit = visible_home_distance_limit
	lost_time = lost_seconds
	arrive_distance = arrive


## 맞았을 때 부른다. someone_in_detect는 지금 감지 범위 안에 누가 있는지.
## 평소(IDLE)이고 감지 범위에 아무도 없을 때만 공격자를 쫓기 시작한다. 쫓는 중에 다시 맞으면 공격자만 바꾼다.
func on_hit(source: Object, position: Vector2, someone_in_detect: bool) -> void:
	if source == null or state == State.RETURNING or someone_in_detect:
		return
	if state == State.IDLE:
		origin = position
		_lost_elapsed = 0.0
	state = State.CHASING
	attacker = source


## 보던 대상을 놓쳤을 때 부른다 (벽 뒤로 숨었거나 감지 범위를 벗어남). 평소(IDLE)일 때만 그 대상을 쫓기 시작한다.
## home은 싸움을 시작한 자리다 (처음 대상을 본 자리). 쫓는 한계와 포기하면 돌아갈 곳은 맞았을 때와 같다.
func start_chase(target: Object, home: Vector2) -> void:
	if target == null or state != State.IDLE:
		return
	state = State.CHASING
	attacker = target
	origin = home
	_lost_elapsed = 0.0


## 물리 프레임마다 부른다. attacker_alive가 false면 공격자가 사라진 것으로 보고 돌아간다.
## attacker_visible은 쫓는 대상이 지금 보이는지(벽이 가리지 않는지), delta는 지난 시간(초).
func update(position: Vector2, someone_in_detect: bool, attacker_alive: bool, attacker_position: Vector2, attacker_visible: bool = true, delta: float = 0.0) -> void:
	match state:
		State.CHASING:
			_lost_elapsed = 0.0 if attacker_visible else _lost_elapsed + delta
			if someone_in_detect:
				_reset()
			elif not attacker_alive or position.distance_to(attacker_position) > attacker_limit \
					or (attacker_visible and position.distance_to(origin) > visible_home_limit) \
					or (not attacker_visible and _lost_elapsed > lost_time):
				state = State.RETURNING
				attacker = null
		State.RETURNING:
			if position.distance_to(origin) <= arrive_distance:
				_reset()


## home으로 돌아가기 시작한다 (무리가 함께 포기했을 때). 다 돌아갈 때까지 감지·피격을 무시하는 것은 같다.
func start_return(home: Vector2) -> void:
	state = State.RETURNING
	origin = home
	attacker = null


func _reset() -> void:
	state = State.IDLE
	attacker = null
