class_name Stamina
extends RefCounted
## 스태미나 계산 규칙: 뛰기와 구르기에만 쓴다.
## - 뛰는 동안 초당 run_cost_per_second만큼 줄고, 구르기는 시작할 때 비용을 한 번에 쓴다
## - 구르기 비용은 roll_costs 순서로 커진다. 구르기가 끝난 뒤 roll_chain_window 안에 다시 구르면 다음 값,
##   그보다 오래 쉬면 첫 값으로 돌아간다. 목록 끝을 넘으면 마지막 값을 계속 쓴다
## - 뛰거나 구르는 동안은 회복되지 않는다. 뛰기는 끝나면 바로, 구르기는 끝나고 roll_regen_delay가 지나야
##   regen_per_second로 다시 찬다
## - 0이 될 때까지 뛰면 지쳐서(exhausted), 뛰기 키를 뗐다가 다시 누를 때까지 뛸 수 없다
##   (0 근처에서 회복 한 번, 뛰기 한 번이 번갈아 일어나 걸음이 떨리는 것을 막는다)
## 노드에 의존하지 않으므로 씬 없이 따로 만들어 쓰고 확인할 수 있다. 값이 바뀌면 changed로 알린다.

signal changed(current: float, maximum: float)

var maximum: float
var current: float
var regen_per_second: float
var run_cost_per_second: float
## 연속으로 구를 때 차례대로 쓰는 비용. 첫 값이 한 번 구를 때의 비용이다.
var roll_costs: Array[float]
## 구르기가 끝나고 이 시간(초) 안에 다시 구르면 연속으로 본다.
var roll_chain_window: float
## 구르기가 끝나고 이 시간(초) 동안은 회복하지 않는다.
var roll_regen_delay: float
## 0이 될 때까지 뛰었는지. 뛰기 키를 떼면(release_run) 풀린다.
var exhausted: bool = false
## 지금까지 연속으로 구른 횟수. 다음 구르기 비용은 roll_costs[이 값]이다 (끝을 넘으면 마지막 값).
var _roll_chain: int = 0
## 마지막 구르기가 끝나고 지난 시간 (구르는 중에는 0). 구른 적이 없으면 INF.
var _since_roll: float = INF


func _init(max_stamina: float, regen: float, run_cost: float, rolls: Array[float], chain_window: float = 0.0, regen_delay: float = 0.0) -> void:
	maximum = max_stamina
	current = max_stamina
	regen_per_second = regen
	run_cost_per_second = run_cost
	roll_costs = rolls
	roll_chain_window = chain_window
	roll_regen_delay = regen_delay


func is_full() -> bool:
	return current >= maximum


func get_ratio() -> float:
	return current / maximum if maximum > 0.0 else 0.0


## 지금 뛸 수 있는지: 남은 스태미나가 있고 지치지 않았어야 한다.
func can_run() -> bool:
	return current > 0.0 and not exhausted


## 지금 구르면 쓰는 비용 (연속으로 구른 횟수에 따라 커진다).
func get_roll_cost() -> float:
	if roll_costs.is_empty():
		return 0.0
	return roll_costs[mini(_roll_chain, roll_costs.size() - 1)]


## 연속으로 구른 횟수 (쉬어서 끊기면 0).
func get_roll_chain() -> int:
	return _roll_chain


## 구르기 비용만큼 남아 있는지.
func can_roll() -> bool:
	return current >= get_roll_cost()


## 구를 수 있으면 비용을 쓰고 true, 모자라면 아무것도 하지 않고 false.
## 구르면 연속 횟수가 하나 늘어난다.
func try_roll() -> bool:
	if not can_roll():
		return false
	_set_current(current - get_roll_cost())
	_roll_chain += 1
	_since_roll = 0.0
	return true


## 뛰기 키를 뗐을 때 부른다. 지친 상태가 풀린다.
func release_run() -> void:
	exhausted = false


## 물리 프레임마다 부른다. 뛰는 중이면 줄고, 구르는 중이거나 구른 직후(roll_regen_delay 동안)면 그대로,
## 둘 다 아니면 회복한다. 뛰다가 0이 되면 지친 상태가 된다.
## 구르기가 끝나고 roll_chain_window보다 오래 지나면 연속 횟수가 0으로 돌아간다.
func process(delta: float, running: bool, rolling: bool) -> void:
	if rolling:
		_since_roll = 0.0
	else:
		_since_roll += delta
		if _since_roll > roll_chain_window:
			_roll_chain = 0
	if running:
		_set_current(maxf(current - run_cost_per_second * delta, 0.0))
		if current <= 0.0:
			exhausted = true
	elif not rolling and _since_roll >= roll_regen_delay and current < maximum:
		_set_current(minf(current + regen_per_second * delta, maximum))


func _set_current(value: float) -> void:
	if value == current:
		return
	current = value
	changed.emit(current, maximum)
