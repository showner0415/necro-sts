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


func _set_current(value: float) -> void:
	current = value
	changed.emit(current, maximum)
