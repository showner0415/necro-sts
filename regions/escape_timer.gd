class_name EscapeTimer
extends RefCounted
## 탈출 게이지 규칙. 탈출 지점 안에 있는 동안 시간이 쌓이고, duration초가 되면 탈출한다.
## 다 차기 전에 벗어나면 처음(0)으로 돌아간다. 피해를 받아도 끊기지 않는다 (피해는 여기서 다루지 않는다).
## 노드에 의존하지 않으므로 씬 없이 확인할 수 있다.

## 탈출에 필요한 시간 (초)
var duration: float
var _elapsed: float = 0.0
var _done: bool = false


func _init(seconds: float) -> void:
	duration = seconds


## delta초가 지났을 때 부른다. inside는 지금 탈출 지점 안에 있는지. 이번에 다 찼으면 true (한 번만).
func update(delta: float, inside: bool) -> bool:
	if _done:
		return false
	if not inside:
		_elapsed = 0.0
		return false
	_elapsed += delta
	if _elapsed >= duration:
		_elapsed = duration
		_done = true
		return true
	return false


## 0~1. 게이지에 보여줄 비율.
func get_progress() -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(_elapsed / duration, 0.0, 1.0)


func is_done() -> bool:
	return _done
