class_name BodySpacing
extends RefCounted
## 몸끼리 한 점에 겹치지 않게 비켜 서는 방향을 계산하는 규칙. 언데드가 따라갈 때와 몬스터가 싸울 때 함께 쓴다.


## position에서 others(자기 자신 제외) 중 limit보다 가까운 것들에게서 비켜 서는 방향과 세기 (가까울수록 세다, 길이 최대 1).
## tie_id는 같은 자리에 겹쳐 있을 때 서로 반대쪽으로 비키기 위한 번호이고, other_ids는 others와 같은 순서의 번호다.
## 제곱근으로 해서 거의 다 떨어졌을 때도 너무 느려지지 않게 한다.
static func push(position: Vector2, tie_id: int, others: Array[Vector2], other_ids: Array[int], limit: float) -> Vector2:
	var result: Vector2 = Vector2.ZERO
	for i: int in others.size():
		var away: Vector2 = position - others[i]
		var gap: float = away.length()
		if gap >= limit:
			continue
		if gap == 0.0:
			away = Vector2.RIGHT if tie_id > other_ids[i] else Vector2.LEFT
		result += away.normalized() * sqrt((limit - gap) / limit)
	return result.limit_length(1.0)
