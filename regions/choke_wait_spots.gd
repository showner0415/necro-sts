class_name ChokeWaitSpots
extends RefCounted
## 길목 입구의 대기 자리를 몬스터마다 나눠 준다 (계획 4b). 노드에 의존하지 않고 몸은 Object로만 기억한다.
## - 같은 입구에서 이미 받은 자리가 있으면 그 자리를 그대로 준다
## - 빈 자리 중 near에 가장 가까운 자리를 준다. 빈 자리가 없으면 가장 가까운 자리를 함께 쓴다 (남는 몸은 그 근처에 간격 밀기로 모인다, 사용자 결정 2026-11-14)
## - 사라진 몸의 자리는 다음에 자리를 줄 때 비운다

## 몸 → {"key": "길목:입구", "index": 자리 번호}
var _taken: Dictionary = {}


## member에게 choke 길목 entrance 입구의 자리(spots 중 하나)를 준다. spots가 비었으면 INF
func claim(member: Object, choke: int, entrance: int, spots: PackedVector2Array, near: Vector2) -> Vector2:
	if spots.is_empty():
		return Vector2.INF
	var key: String = "%d:%d" % [choke, entrance]
	if _taken.has(member) and _taken[member]["key"] == key:
		return spots[_taken[member]["index"]]
	release(member)
	var used: Dictionary = {}
	for holder: Variant in _taken.keys():
		if not is_instance_valid(holder):
			_taken.erase(holder)
		elif _taken[holder]["key"] == key:
			used[_taken[holder]["index"]] = true
	var best: int = -1
	var closest: int = 0
	for i: int in spots.size():
		if spots[i].distance_squared_to(near) < spots[closest].distance_squared_to(near):
			closest = i
		if not used.has(i) and (best < 0 or spots[i].distance_squared_to(near) < spots[best].distance_squared_to(near)):
			best = i
	var index: int = best if best >= 0 else closest
	_taken[member] = {"key": key, "index": index}
	return spots[index]


func release(member: Object) -> void:
	_taken.erase(member)


## 테스트·디버그용: member가 받은 자리 번호 (없으면 -1)
func spot_index(member: Object) -> int:
	return _taken[member]["index"] if _taken.has(member) else -1
