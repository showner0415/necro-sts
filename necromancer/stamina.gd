class_name Stamina
extends RefCounted
## 스태미나 계산 규칙: 뛰기와 구르기에만 쓴다.
## - 뛰는 동안 초당 run_cost_per_second만큼 줄고, 구르기는 시작할 때 roll_cost를 쓴다
## - 뛰거나 구르는 동안은 회복되지 않고, 끝나면 regen_per_second로 다시 찬다
## - 0이 될 때까지 뛰면 지쳐서(exhausted), 뛰기 키를 뗐다가 다시 누를 때까지 뛸 수 없다
##   (0 근처에서 회복 한 번, 뛰기 한 번이 번갈아 일어나 걸음이 떨리는 것을 막는다)
## 노드에 의존하지 않으므로 씬 없이 따로 만들어 쓰고 확인할 수 있다. 값이 바뀌면 changed로 알린다.

signal changed(current: float, maximum: float)

var maximum: float
var current: float
var regen_per_second: float
var run_cost_per_second: float
var roll_cost: float
## 0이 될 때까지 뛰었는지. 뛰기 키를 떼면(release_run) 풀린다.
var exhausted: bool = false


func _init(max_stamina: float, regen: float, run_cost: float, roll: float) -> void:
	maximum = max_stamina
	current = max_stamina
	regen_per_second = regen
	run_cost_per_second = run_cost
	roll_cost = roll


func is_full() -> bool:
	return current >= maximum


func get_ratio() -> float:
	return current / maximum if maximum > 0.0 else 0.0


## 지금 뛸 수 있는지: 남은 스태미나가 있고 지치지 않았어야 한다.
func can_run() -> bool:
	return current > 0.0 and not exhausted


## 구르기 비용만큼 남아 있는지.
func can_roll() -> bool:
	return current >= roll_cost


## 구를 수 있으면 비용을 쓰고 true, 모자라면 아무것도 하지 않고 false.
func try_roll() -> bool:
	if not can_roll():
		return false
	_set_current(current - roll_cost)
	return true


## 뛰기 키를 뗐을 때 부른다. 지친 상태가 풀린다.
func release_run() -> void:
	exhausted = false


## 물리 프레임마다 부른다. 뛰는 중이면 줄고, 구르는 중이면 그대로, 둘 다 아니면 회복한다.
## 뛰다가 0이 되면 지친 상태가 된다.
func process(delta: float, running: bool, rolling: bool) -> void:
	if running:
		_set_current(maxf(current - run_cost_per_second * delta, 0.0))
		if current <= 0.0:
			exhausted = true
	elif not rolling and current < maximum:
		_set_current(minf(current + regen_per_second * delta, maximum))


func _set_current(value: float) -> void:
	if value == current:
		return
	current = value
	changed.emit(current, maximum)
