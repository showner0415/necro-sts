class_name Harvest
extends RefCounted
## 채집 한 번의 진행. 시간이 duration초만큼 쌓이면 끝난다. 취소되면 더는 진행하지 않는다.
## 무엇이 취소 조건인지(움직임, 피해)는 네크로맨서가 판단해서 cancel()을 부른다.
## 노드에 의존하지 않으므로 씬 없이 확인할 수 있다.

## 이번에 채집하는 묶음 (시작할 때 고른다)
var stack: ItemStack
## 채집에 필요한 시간 (초)
var duration: float
var _elapsed: float = 0.0
var _done: bool = false
var _cancelled: bool = false


func _init(target_stack: ItemStack, seconds: float) -> void:
	stack = target_stack
	duration = seconds


## delta초가 지났을 때 부른다. 이번에 다 찼으면 true (한 번만). 취소되었거나 이미 끝났으면 false.
func update(delta: float) -> bool:
	if not is_active():
		return false
	_elapsed += delta
	if _elapsed >= duration:
		_elapsed = duration
		_done = true
		return true
	return false


func cancel() -> void:
	if not _done:
		_cancelled = true


## 아직 진행 중인지 (끝나지도 취소되지도 않음)
func is_active() -> bool:
	return not _done and not _cancelled


func is_done() -> bool:
	return _done


func is_cancelled() -> bool:
	return _cancelled


## 0~1. 게이지에 보여줄 비율.
func get_progress() -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(_elapsed / duration, 0.0, 1.0)
