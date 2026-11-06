class_name PackAggro
extends RefCounted
## 무리의 공동 대상 규칙. 무리(MonsterPack)가 하나 갖고, 멤버 모두가 이 대상을 노리게 한다.
## - 멤버 중 하나라도 어그로가 끌리면(맞음, 또는 대상이 없다가 새로 감지함) on_aggro()로 알린다.
##   한 프레임에 여러 번 알리면 마지막 것이, 프레임이 다르면 가장 최근 것이 무리 대상이 된다
## - 무리 대상이 사라지거나, 멤버 아무도 그 대상을 원하지 않으면(give_up) 무리가 함께 포기한다
## 노드에 의존하지 않고 대상은 Object로만 기억한다. 사라졌는지와 "원하는지"는 쓰는 쪽이 판단해 넘긴다.

## 지금 무리 대상 (없으면 null)
var target: Object = null
## 이번 프레임에 알려진 가장 최근 어그로 (resolve에서 대상이 된다)
var _pending: Object = null


## 멤버 하나가 source에게 어그로가 끌렸다.
func on_aggro(source: Object) -> void:
	if source != null:
		_pending = source


## 프레임마다 한 번, 이번 프레임의 어그로를 반영한다. 대상이 바뀌었으면 true.
func resolve() -> bool:
	if _pending == null:
		return false
	var changed: bool = _pending != target
	target = _pending
	_pending = null
	return changed


## 무리가 함께 포기한다 (대상이 사라졌거나 아무도 원하지 않음).
func give_up() -> void:
	target = null
	_pending = null
