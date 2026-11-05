class_name Aggro
extends RefCounted
## 몬스터 타게팅 중 "감지 범위 밖에서 맞으면 공격한 대상을 쫓는" 규칙. 노드에 의존하지 않고 위치만 받는다.
## - IDLE: 평소. 감지 범위 안의 가장 가까운 대상을 노린다 (그 판단은 쓰는 쪽이 한다)
## - CHASING: 감지 범위에 아무도 없을 때 맞았다. 공격자를 쫓는다
##   감지 범위에 누가 들어오면 IDLE로 (그때부터 가장 가까운 대상)
##   공격자와 attacker_limit보다 멀어지거나, 맞기 시작한 자리(origin)에서 home_limit보다 멀어지면 RETURNING으로
## - RETURNING: 맞기 시작한 자리로 돌아간다. 다 돌아갈 때까지 감지·피격을 무시한다

enum State { IDLE, CHASING, RETURNING }

var attacker_limit: float
var home_limit: float
## 이 거리 안이면 다 돌아온 것으로 본다
var arrive_distance: float

var state: State = State.IDLE
## 쫓는 공격자. 쓰는 쪽이 위치를 넘겨주므로 여기서는 누구인지만 기억한다.
var attacker: Object
## 맞기 시작한 자리
var origin: Vector2


func _init(attacker_distance_limit: float, home_distance_limit: float, arrive: float) -> void:
	attacker_limit = attacker_distance_limit
	home_limit = home_distance_limit
	arrive_distance = arrive


## 맞았을 때 부른다. someone_in_detect는 지금 감지 범위 안에 누가 있는지.
## 평소(IDLE)이고 감지 범위에 아무도 없을 때만 공격자를 쫓기 시작한다. 쫓는 중에 다시 맞으면 공격자만 바꾼다.
func on_hit(source: Object, position: Vector2, someone_in_detect: bool) -> void:
	if source == null or state == State.RETURNING or someone_in_detect:
		return
	if state == State.IDLE:
		origin = position
	state = State.CHASING
	attacker = source


## 물리 프레임마다 부른다. attacker_alive가 false면 공격자가 사라진 것으로 보고 돌아간다.
func update(position: Vector2, someone_in_detect: bool, attacker_alive: bool, attacker_position: Vector2) -> void:
	match state:
		State.CHASING:
			if someone_in_detect:
				_reset()
			elif not attacker_alive or position.distance_to(attacker_position) > attacker_limit or position.distance_to(origin) > home_limit:
				state = State.RETURNING
				attacker = null
		State.RETURNING:
			if position.distance_to(origin) <= arrive_distance:
				_reset()


func _reset() -> void:
	state = State.IDLE
	attacker = null
