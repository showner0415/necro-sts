class_name PackPlacer
extends RefCounted
## 무리원을 무리 자리 둘레에 흩어 놓을 곳을 고른다 (계획 5b). 노드에 의존하지 않는다.
## 자리에서 radius 안의 마구 자리를 고르되, 바닥이 아니거나(is_free가 false) 이미 고른 곳과 spacing보다 가까우면 다시 고른다 (tries번까지).
## 끝내 못 고르면 그 몸은 자리 한가운데에 둔다 (몸끼리 간격 밀기가 곧 떨어뜨린다).


static func place(center: Vector2, count: int, radius: float, spacing: float, rng: RandomNumberGenerator, is_free: Callable, tries: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in count:
		var chosen: Vector2 = center
		for attempt: int in tries:
			# 원 안에 고르게 (반지름은 제곱근으로)
			var candidate: Vector2 = center + Vector2.from_angle(rng.randf() * TAU) * radius * sqrt(rng.randf())
			if not is_free.call(candidate):
				continue
			var crowded: bool = false
			for point: Vector2 in points:
				if point.distance_to(candidate) < spacing:
					crowded = true
					break
			if not crowded:
				chosen = candidate
				break
		points.append(chosen)
	return points
