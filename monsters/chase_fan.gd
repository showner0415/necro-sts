class_name ChaseFan
extends RefCounted
## 한 대상을 쫓는 몬스터들이 한 줄로 서지 않게, 대상 둘레의 다가갈 자리를 부채꼴로 나누는 규칙 (줄 서기 고치기, 2026-11-18).
## 모두가 대상의 지금 자리 한 점을 향하면 지나온 길 위에 한 줄로 모인다. 그래서 몸마다 다른 점(자리)을 향하게 한다.
## - 기준 방향(axis_back): 대상에서 본 쫓는 몸들의 가운데 쪽. 쫓는 몸들의 가운데가 대상과 거의 겹치면(이미 둘러쌈) 자리를 나누지 않는다 (valid가 false)
## - 순서: 쫓는 몸들을 대상에서 본 방향으로 줄 세워, 지금 왼쪽에 있는 몸이 왼쪽 자리를 받는다 (서로 길이 엇갈리지 않게)
## - 자리: 기준 방향에서 좌우로 step씩 벌린 각도, 대상에서 radius만큼 떨어진 점. 전체 폭이 ±max_half를 넘으면 그 안에 고르게 줄인다
## - 예측(predict): 대상이 움직이는 쪽을 조금 앞질러 겨눈다. 대상이 옆으로 꺾을 때 지나온 길을 따라가지 않고 질러간다
## 프레임마다 지금 자리만으로 다시 계산하므로 기억하는 상태가 없다. 노드에 의존하지 않아 씬 없이 확인할 수 있다.

## 대상에서 본 쫓는 몸들의 가운데 방향 (라디안)
var axis_back: float = 0.0
## 자리를 나눌 수 있는지 (쫓는 몸이 있고, 그 가운데가 대상에서 충분히 떨어져 있다)
var valid: bool = false
## 쫓는 몸 수
var count: int = 0
## 몸 번호 → 왼쪽부터의 순서 (0부터)
var _ranks: Dictionary = {}


## target_position을 쫓는 몸들(번호 ids, 자리 positions는 같은 순서)로 부채꼴을 만든다.
## 몸들의 가운데가 대상에서 min_axis_distance보다 가까우면 기준 방향을 정할 수 없어 valid가 false다.
static func create(target_position: Vector2, ids: Array[int], positions: Array[Vector2], min_axis_distance: float) -> ChaseFan:
	var fan: ChaseFan = ChaseFan.new()
	fan.count = ids.size()
	if ids.is_empty():
		return fan
	var center: Vector2 = Vector2.ZERO
	for position: Vector2 in positions:
		center += position
	center /= positions.size()
	var back: Vector2 = center - target_position
	if back.length() < min_axis_distance:
		return fan
	fan.valid = true
	fan.axis_back = back.angle()
	var order: Array[int] = []
	var sides: Array[float] = []
	for i: int in ids.size():
		order.append(i)
		sides.append(wrapf((positions[i] - target_position).angle() - fan.axis_back, -PI, PI))
	# 방향이 똑같으면(완전히 한 줄) 번호로 가른다 (프레임마다 순서가 뒤집히지 않게).
	order.sort_custom(func(a: int, b: int) -> bool:
		return sides[a] < sides[b] if sides[a] != sides[b] else ids[a] < ids[b])
	for rank: int in order.size():
		fan._ranks[ids[order[rank]]] = rank
	return fan


## 이 부채꼴에 든 몸인지
func has(id: int) -> bool:
	return _ranks.has(id)


## 몸의 순서 (왼쪽부터 0). 없는 몸이면 -1
func rank_of(id: int) -> int:
	return _ranks.get(id, -1)


## 몸 id가 다가갈 자리: aim(겨누는 점, 보통 예측한 대상 자리) 둘레 radius 거리, 기준 방향에서 이 몸의 순서만큼 벌린 각도.
## 자리를 나눌 수 없거나(valid가 false) 없는 몸이면 aim 그대로다.
func slot_for(id: int, aim: Vector2, step: float, max_half: float, radius: float) -> Vector2:
	if not valid or not _ranks.has(id):
		return aim
	return aim + Vector2.from_angle(axis_back + slot_offset(_ranks[id], count, step, max_half)) * radius


## rank번째(0부터) 자리가 기준 방향에서 벗어난 각 (라디안). count마리가 가운데를 기준으로 step씩 벌리고,
## 양 끝이 ±max_half를 넘으면 ±max_half 안에 고르게 나눈다. 한 마리면 0 (기준 방향 그대로).
static func slot_offset(rank: int, count: int, step: float, max_half: float) -> float:
	if count <= 1:
		return 0.0
	var half: float = minf((count - 1) * step / 2.0, max_half)
	return lerpf(-half, half, float(rank) / (count - 1))


## 예측해서 겨눌 점: 대상이 지금 속도로 lead_time초 뒤에 있을 자리.
## lead_time = (쫓는 몸이 대상까지 가는 시간, 최대 max_time) × lead_ratio. 앞지르는 거리는 대상까지의 거리를 넘지 않는다.
## lead_ratio가 0이거나 쫓는 몸이 서 있으면 대상의 지금 자리다.
static func predict(target_position: Vector2, target_velocity: Vector2, chaser_position: Vector2, chaser_speed: float, lead_ratio: float, max_time: float) -> Vector2:
	if lead_ratio <= 0.0 or chaser_speed <= 0.0:
		return target_position
	var distance: float = chaser_position.distance_to(target_position)
	var lead: Vector2 = target_velocity * minf(distance / chaser_speed, max_time) * lead_ratio
	return target_position + lead.limit_length(distance)
