class_name ChokePasses
extends RefCounted
## 길목 통행 자리 규칙 (docs/game-design.md "몬스터 무리"의 좁은 길목, 봇 측정 5b). 노드에 의존하지 않고 몸·대상은 Object로만 기억한다.
## - 대상 하나당 동시에 길목을 지나는 수를 종(kind)마다 둔다. 공격권(AttackTokens)과 따로 센다 (길목을 지나는 동안 대상의 공격권 칸을 비우려고)
## - 길목 입구에서 기다리는 몸이 프레임마다 request()로 묻는다. 자리가 있으면 주고, 없으면 그냥 false다 (기다리는 몸 목록·추가 자리는 없다)
## - 반납: release (길목을 나옴, 죽음, 대상이 바뀌거나 놓침, 멀리 밀려남), 시간 제한(hold_time_limit초). 시간 제한으로 반납한 뒤 막기는 없다
## - pause_hold(member)를 알린 프레임에는 그 몸의 시간 제한이 흐르지 않는다 (길목 안에서 움직이는 동안). 멈춘 곳부터 이어서 센다

var hold_time_limit: float
## 몸 → {"target": 대상, "kind": 종, "held": 들고 있은 시간}
var _holders: Dictionary = {}
## 이번 프레임에 시간 제한을 멈출 몸 (pause_hold로 알린다. update마다 비운다)
var _paused: Dictionary = {}


func _init(hold_limit: float) -> void:
	hold_time_limit = hold_limit


## member가 target 쪽 길목을 지나도 되는지 묻는다. kind는 종(자리를 따로 세는 단위), limit은 그 종의 대상 하나당 수.
## 이미 그 대상의 통행 자리를 들고 있으면 true. 다른 대상의 것을 들고 있으면 먼저 반납한다.
func request(member: Object, target: Object, kind: StringName, limit: int) -> bool:
	if _holders.has(member):
		if _holders[member]["target"] == target:
			return true
		release(member)
	if count(target, kind) >= limit:
		return false
	_holders[member] = {"target": target, "kind": kind, "held": 0.0}
	return true


## 통행 자리를 반납한다. 들고 있지 않으면 아무것도 하지 않는다.
func release(member: Object) -> void:
	_holders.erase(member)


## 이번 프레임에는 member의 시간 제한을 멈춘다 (update 전에 부른다. 다음 update 뒤에는 풀린다).
func pause_hold(member: Object) -> void:
	_paused[member] = true


## 물리 프레임마다 한 번, 몸들이 request()를 다 부른 뒤에 부른다. 시간 제한을 넘은 통행 자리를 반납한다.
func update(delta: float) -> void:
	for member: Variant in _holders.keys():
		if not is_instance_valid(member) or not is_instance_valid(_holders[member]["target"]):
			_holders.erase(member)
			continue
		if not _paused.has(member):
			_holders[member]["held"] += delta
		if hold_time_limit > 0.0 and _holders[member]["held"] > hold_time_limit:
			_holders.erase(member)
	_paused.clear()


## target의 kind 종 통행 자리를 든 몸 수
func count(target: Object, kind: StringName) -> int:
	var total: int = 0
	for holder: Dictionary in _holders.values():
		if holder["target"] == target and holder["kind"] == kind:
			total += 1
	return total


func is_holding(member: Object) -> bool:
	return _holders.has(member)


## member가 통행 자리를 든 대상 (없으면 null)
func held_target(member: Object) -> Object:
	if not _holders.has(member) or not is_instance_valid(_holders[member]["target"]):
		return null
	return _holders[member]["target"]
