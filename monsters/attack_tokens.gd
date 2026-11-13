class_name AttackTokens
extends RefCounted
## 공격권 규칙 (docs/game-design.md "몬스터 무리"). 노드에 의존하지 않고 몸·대상은 Object로만 기억한다.
## - 대상 하나당 동시에 공격할 수 있는 수를 종(kind)마다 둔다. 대상마다 모든 몬스터가 함께 센다 (무리가 달라도, 무리가 없어도)
## - 공격하려는 몸은 프레임마다 request()로 묻는다. 자리가 있으면 공격권을 주고, 없으면 그 대상을 기다리는 몸으로 적어 둔다
## - 대상의 공격권이 쓰이는 동안 extra_interval초마다, 그때 공격권이 다 차서 기다리는 몸이 있으면 그중 하나를 무작위로 골라 추가 공격권을 준다.
##   추가 공격권은 한 대상에 동시에 하나뿐이고, 공격 한 번에 쓰고 반납한다
## - 반납: 공격이 끝남(finish_attack), 그 밖의 반납(release: 죽음, 대상이 바뀌거나 놓침, 멀리 밀려남), 시간 제한(hold_time_limit초)
## - 기다리는 몸 목록은 update()마다 비운다 (그 프레임에 다시 묻지 않은 몸은 기다리지 않는 것이다)
## 무작위는 넣어 준 난수(RandomNumberGenerator)를 쓴다 (시드로 재현할 수 있게).

var extra_interval: float
var hold_time_limit: float
var _rng: RandomNumberGenerator
## 몸 → {"target": 대상, "kind": 종, "extra": 추가 공격권인지, "held": 들고 있은 시간}
var _holders: Dictionary = {}
## 대상 → [기다리는 몸들] (이번 프레임에 물었는데 자리가 없던 몸)
var _waiting: Dictionary = {}
## 대상 → 추가 공격권 시간 (기다리는 몸이 있는 동안 흐른다)
var _extra_timers: Dictionary = {}
## 지금까지 준 추가 공격권 수 (테스트·디버그용)
var extra_granted: int = 0


func _init(extra_seconds: float, hold_limit: float, rng: RandomNumberGenerator) -> void:
	extra_interval = extra_seconds
	hold_time_limit = hold_limit
	_rng = rng


## member가 target을 공격해도 되는지 묻는다. kind는 종(공격권을 따로 세는 단위), limit은 그 종의 대상 하나당 수.
## 이미 그 대상의 공격권을 들고 있으면 true. 다른 대상의 것을 들고 있으면 먼저 반납한다.
func request(member: Object, target: Object, kind: StringName, limit: int) -> bool:
	if _holders.has(member):
		if _holders[member]["target"] == target:
			return true
		release(member)
	if count_normal(target, kind) < limit:
		_holders[member] = {"target": target, "kind": kind, "extra": false, "held": 0.0}
		return true
	var waiting: Array = _waiting.get(target, [])
	if not waiting.has(member):
		waiting.append(member)
	_waiting[target] = waiting
	return false


## 공격 한 번이 끝났다. 들고 있던 공격권(보통·추가 모두)을 반납한다.
func finish_attack(member: Object) -> void:
	release(member)


## 공격권을 반납한다 (죽음, 대상이 바뀌거나 놓침, 멀리 밀려남). 들고 있지 않으면 아무것도 하지 않는다.
func release(member: Object) -> void:
	_holders.erase(member)


## 물리 프레임마다 한 번, 몸들이 request()를 다 부른 뒤에 부른다.
## 시간 제한을 넘은 공격권을 반납하고, 기다리는 몸이 있는 대상마다 추가 공격권 시간을 재서 줄 때가 되면 준다.
func update(delta: float) -> void:
	for member: Variant in _holders.keys():
		if not is_instance_valid(member) or not is_instance_valid(_holders[member]["target"]):
			_holders.erase(member)
			continue
		_holders[member]["held"] += delta
		if hold_time_limit > 0.0 and _holders[member]["held"] > hold_time_limit:
			_holders.erase(member)
	# 추가 공격권 시간은 대상의 공격권이 쓰이는 동안(누가 들고 있거나 기다리는 동안) 흐르고, extra_interval마다 한 번 그때 기다리는 몸 중 하나에게 준다.
	var busy: Dictionary = {}
	for holder: Dictionary in _holders.values():
		busy[holder["target"]] = true
	for target: Variant in _waiting.keys():
		busy[target] = true
	for target: Variant in _extra_timers.keys():
		if not busy.has(target):
			_extra_timers.erase(target)
	for target: Variant in busy.keys():
		if not is_instance_valid(target):
			continue
		var timer: float = _extra_timers.get(target, 0.0) + delta
		if timer >= extra_interval:
			timer -= extra_interval
			var waiting: Array = _waiting.get(target, []).filter(func(member: Variant) -> bool: return is_instance_valid(member) and not _holders.has(member))
			if not waiting.is_empty() and extra_holder(target) == null:
				var chosen: Variant = waiting[_rng.randi_range(0, waiting.size() - 1)]
				_holders[chosen] = {"target": target, "kind": &"", "extra": true, "held": 0.0}
				extra_granted += 1
		_extra_timers[target] = timer
	_waiting.clear()


## target의 kind 종 보통 공격권을 들고 있는 몸 수
func count_normal(target: Object, kind: StringName) -> int:
	var count: int = 0
	for holder: Dictionary in _holders.values():
		if holder["target"] == target and holder["kind"] == kind and not holder["extra"]:
			count += 1
	return count


## target의 추가 공격권을 든 몸 (없으면 null)
func extra_holder(target: Object) -> Object:
	for member: Variant in _holders.keys():
		var holder: Dictionary = _holders[member]
		if holder["target"] == target and holder["extra"]:
			return member
	return null


func is_holding(member: Object) -> bool:
	return _holders.has(member)


func holds_extra(member: Object) -> bool:
	return _holders.has(member) and _holders[member]["extra"]


## member가 공격권을 든 대상 (없으면 null)
func held_target(member: Object) -> Object:
	if not _holders.has(member) or not is_instance_valid(_holders[member]["target"]):
		return null
	return _holders[member]["target"]


## target의 공격권(보통·추가)을 든 몸들 (테스트·디버그용)
func holders_of(target: Object) -> Array:
	var result: Array = []
	for member: Variant in _holders.keys():
		if is_instance_valid(member) and _holders[member]["target"] == target:
			result.append(member)
	return result
