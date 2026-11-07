class_name UndeadTargeting
extends RefCounted
## 언데드 한 마리가 싸울 몬스터를 정하는 규칙 (docs/game-design.md "언데드 능력치와 타게팅").
## - 이유 없이 먼저 공격하지 않는다. 계기가 생긴 몬스터를 대상으로 정한다. 계기는 "조건에 새로 맞게 된 순간"과 "네크로맨서에게 맞은 순간"이다.
##   조건: 네크로맨서를 노리며 네크로맨서의 공격 반경 안 / 이 언데드를 노리며 언데드의 공격 반경 안 / 네크로맨서가 최근에 맞힘
## - 대상이 언데드의 공격 반경에 들어오면 고정한다. 고정 전에는 가장 최근 계기로 바꾸고, 고정 뒤에는 바꾸지 않는다
## - 대상이 죽거나(후보에서 빠짐) leash 밖으로 나가면 풀린다. 그때 조건에 맞는 몬스터가 있으면 가장 가까운 것을 바로 고른다
## 노드에 의존하지 않도록, 쓰는 쪽(Undead)이 프레임마다 살아 있는 몬스터들의 정보(Candidate)를 넣어 준다.


## 후보 몬스터 하나의 이번 프레임 정보
class Candidate:
	var monster: Object
	## 언데드에서의 거리
	var distance: float = 0.0
	## 지금 계기 조건에 맞는지
	var qualified: bool = false
	## 지난 프레임 뒤로 네크로맨서에게 맞았는지
	var hit_by_necromancer: bool = false
	## 언데드의 공격 반경 안인지
	var in_engage_range: bool = false
	## 네크로맨서에게서 leash 안인지
	var within_leash: bool = true


## 지금 대상 (없으면 null)
var target: Object = null
## 대상이 고정되었는지
var locked: bool = false
## 지난 프레임에 조건에 맞던 몬스터들 (새로 맞게 된 것만 계기로 본다)
var _last_qualified: Dictionary = {}


## 이번 프레임의 대상을 정해 돌려준다. candidates에는 살아 있는 몬스터만 넣는다.
func update(candidates: Array[Candidate]) -> Object:
	# 대상이 노드째 지워졌으면(밸런스 측정이 싸움마다 몬스터를 지우는 경우 등) 죽은 것과 같이 본다.
	if not is_instance_valid(target):
		target = null
	var current: Candidate = _find(candidates, target)
	if current == null or not current.within_leash:
		target = null
		locked = false
		current = null
	if not locked:
		var triggered: Candidate = _nearest(candidates, func(c: Candidate) -> bool:
			return c.hit_by_necromancer or (c.qualified and not _last_qualified.has(c.monster)))
		if triggered != null:
			current = triggered
	if current == null:
		current = _nearest(candidates, func(c: Candidate) -> bool: return c.qualified)
	target = current.monster if current != null else null
	if current != null and current.in_engage_range:
		locked = true
	_last_qualified.clear()
	for c: Candidate in candidates:
		if c.qualified:
			_last_qualified[c.monster] = true
	return target


## filter에 맞고 leash 안인 후보 중 가장 가까운 것. 없으면 null.
func _nearest(candidates: Array[Candidate], filter: Callable) -> Candidate:
	var best: Candidate = null
	for c: Candidate in candidates:
		if not c.within_leash or not filter.call(c):
			continue
		if best == null or c.distance < best.distance:
			best = c
	return best


func _find(candidates: Array[Candidate], monster: Object) -> Candidate:
	if monster == null:
		return null
	for c: Candidate in candidates:
		if c.monster == monster:
			return c
	return null
