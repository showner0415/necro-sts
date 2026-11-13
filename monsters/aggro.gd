class_name Aggro
extends RefCounted
## 몬스터 타게팅 중 "감지 범위 밖에서 맞으면 공격한 대상을 쫓고, 보던 대상을 놓쳐도 쫓는" 규칙. 노드에 의존하지 않고 위치만 받는다.
## - IDLE: 평소. 감지 범위 안의 가장 가까운 대상을 노린다 (그 판단은 쓰는 쪽이 한다)
## - CHASING: 감지 범위에 아무도 없을 때 맞았거나, 보던 대상을 놓쳤다(start_chase). 그 대상(attacker)을 쫓는다
##   감지 범위에 누가 들어오면 IDLE로 (그때부터 가장 가까운 대상)
##   종별 추격 포기 조건(ChaseClock)을 넘으면 포기한다. 값이 0인 조건은 쓰지 않는다
##   - 쫓는 대상과 attacker_limit보다 멀어짐 (보이든 안 보이든. 걸어서 도망칠 수 있게)
##   - 대상을 lost_time초 넘게 보지 못함 (다시 보면 처음부터 잰다)
##   - chase_time_limit초 넘게 쫓음 (맞으면 처음부터 잰다)
## 포기해도 돌아가지 않는다. 그 자리에서 평소(IDLE)가 된다.

enum State { IDLE, CHASING }

var attacker_limit: float
var lost_time: float
var chase_time_limit: float

var state: State = State.IDLE
## 쫓는 공격자. 쓰는 쪽이 위치를 넘겨주므로 여기서는 누구인지만 기억한다.
var attacker: Object
var _clock: ChaseClock = ChaseClock.new()


func _init(attacker_distance_limit: float, lost_seconds: float, chase_seconds: float = 0.0) -> void:
	attacker_limit = attacker_distance_limit
	lost_time = lost_seconds
	chase_time_limit = chase_seconds


## 맞았을 때 부른다. someone_in_detect는 지금 감지 범위 안에 누가 있는지.
## 감지 범위에 아무도 없을 때만 공격자를 쫓는다. 쫓는 중에 다시 맞으면 공격자를 바꾸고 추격 시간을 처음부터 잰다.
func on_hit(source: Object, someone_in_detect: bool) -> void:
	if source == null or someone_in_detect:
		return
	if state == State.IDLE:
		_clock.reset()
	state = State.CHASING
	attacker = source
	_clock.on_hit()


## 보던 대상을 놓쳤을 때 부른다 (벽 뒤로 숨었거나 감지 범위를 벗어남). 평소(IDLE)일 때만 그 대상을 쫓기 시작한다.
func start_chase(target: Object) -> void:
	if target == null or state != State.IDLE:
		return
	state = State.CHASING
	attacker = target
	_clock.reset()


## 물리 프레임마다 부른다. attacker_alive가 false면 공격자가 사라진 것으로 보고 포기한다.
## attacker_visible은 쫓는 대상이 지금 보이는지(벽이 가리지 않는지), delta는 지난 시간(초).
func update(position: Vector2, someone_in_detect: bool, attacker_alive: bool, attacker_position: Vector2, attacker_visible: bool = true, delta: float = 0.0) -> void:
	if state != State.CHASING:
		return
	# 쫓는 동안 대상은 감지 범위 밖이거나 안 보인다 (감지되면 아래에서 평소로 돌아간다).
	_clock.update(delta, attacker_visible, false)
	if someone_in_detect or not attacker_alive \
			or _clock.gives_up(position.distance_to(attacker_position), attacker_limit, lost_time, chase_time_limit):
		give_up()


## 쫓기를 그만두고 그 자리에서 평소로 돌아간다 (무리가 함께 포기했을 때도 부른다).
func give_up() -> void:
	state = State.IDLE
	attacker = null
