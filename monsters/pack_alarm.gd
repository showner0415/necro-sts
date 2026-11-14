class_name PackAlarm
extends RefCounted
## 무리 경보 규칙 (박쥐처럼 대상 하나를 함께 노리는 무리는 쓰지 않는다, docs/game-design.md "몬스터 무리"). 노드에 의존하지 않는다.
## - CALM (평소) → 무리원이 맞거나 적을 감지하면(trigger) SIGNAL: 그 무리원이 signal_time초 멈춰 깜빡인다 → ALERT (경보)
##   신호 시간이 0이면 바로 경보다. 신호 중에 다른 계기가 생겨도 신호를 다시 시작하지 않는다
## - 경보 중에는 네크로맨서 편 전체가 무리의 적이다 (누가 적인지는 쓰는 쪽이 정한다)
## - 포기: 쓰는 쪽이 종별 추격 포기 조건(ChaseClock)으로 판단해 give_up()을 부른다 → CALM

enum State { CALM, SIGNAL, ALERT }

var state: State = State.CALM
## 신호를 내는 무리원 (신호 중이 아니면 null)
var signaller: Object = null
var _signal_left: float = 0.0


## member가 맞거나 적을 감지해서 무리에 알린다. signal_time은 그 무리원의 신호 시간 (초).
func trigger(member: Object, signal_time: float) -> void:
	if state != State.CALM:
		return
	if signal_time <= 0.0:
		state = State.ALERT
		return
	state = State.SIGNAL
	signaller = member
	_signal_left = signal_time


## 물리 프레임마다 부른다. 이번에 경보가 되었으면 true.
func update(delta: float) -> bool:
	if state != State.SIGNAL:
		return false
	_signal_left -= delta
	if _signal_left > 0.0:
		return false
	end_signal()
	return true


## 신호를 바로 끝내고 경보로 간다 (신호를 내던 무리원이 죽었을 때 등).
func end_signal() -> void:
	if state != State.SIGNAL:
		return
	state = State.ALERT
	signaller = null


func is_alert() -> bool:
	return state == State.ALERT


func is_signalling(member: Object) -> bool:
	return state == State.SIGNAL and member == signaller


## 무리가 함께 포기한다: 평소로 돌아간다.
func give_up() -> void:
	state = State.CALM
	signaller = null
	_signal_left = 0.0
