class_name ManaPool
extends RefCounted
## 마나 계산 규칙: 최대치, 자연 회복, 소모.
## 노드에 의존하지 않으므로 씬 없이 따로 만들어 쓰고 확인할 수 있다.
## 값이 바뀌면 changed로 알린다.

signal changed(current: float, maximum: float)

var maximum: float
var current: float
## 초당 자연 회복량
var regen_per_second: float


func _init(max_mana: float, regen: float) -> void:
	maximum = max_mana
	current = max_mana
	regen_per_second = regen


## delta초 동안 자연 회복한다. 최대치를 넘지 않는다.
func regenerate(delta: float) -> void:
	if current >= maximum or regen_per_second <= 0.0:
		return
	_set_current(minf(current + regen_per_second * delta, maximum))


func can_spend(amount: float) -> bool:
	return amount <= current


## 마나가 충분하면 쓰고 true, 부족하면 쓰지 않고 false를 돌려준다. 비용 0은 항상 성공한다.
func try_spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not can_spend(amount):
		return false
	_set_current(current - amount)
	return true


## 언데드 유지처럼 계속 빠져나가는 마나. 있는 만큼만 빠지고 0 밑으로 내려가지 않는다.
func drain(amount: float) -> void:
	if amount <= 0.0 or current <= 0.0:
		return
	_set_current(maxf(current - amount, 0.0))


## 계속 일어나는 변화(자연 회복 - 유지비)의 초당 양. 소환처럼 한 번에 쓰는 마나는 넣지 않는다.
## 가득 차 있어도 회복 - 유지비 계산값을 그대로 돌려준다 (언데드를 더 띄워도 되는지 보이게).
func get_change_per_second(drain_per_second: float) -> float:
	return regen_per_second - drain_per_second


## 초당 변화량을 보여줄지. 변화가 없을 때는 숨긴다:
## - 가득 차 있고 유지비도 없을 때 (회복할 것이 없음)
## - 회복과 유지비가 딱 맞아 계산값이 0일 때
func has_change(drain_per_second: float) -> bool:
	if current >= maximum and drain_per_second <= 0.0:
		return false
	return not is_zero_approx(get_change_per_second(drain_per_second))


func is_empty() -> bool:
	return current <= 0.0


func _set_current(value: float) -> void:
	current = value
	changed.emit(current, maximum)
