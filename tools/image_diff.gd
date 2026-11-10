class_name ImageDiff
extends RefCounted
## 같은 크기의 두 이미지에서 달라진 픽셀을 찾는다. 노드에 의존하지 않는다.


## 색이 다른 픽셀의 위치들 (위 줄부터). rect의 크기가 0이면 이미지 전체를 본다.
static func changed_pixels(a: Image, b: Image, rect: Rect2i = Rect2i()) -> Array[Vector2i]:
	var area: Rect2i = rect if rect.has_area() else Rect2i(Vector2i.ZERO, a.get_size())
	var changed: Array[Vector2i] = []
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				changed.append(Vector2i(x, y))
	return changed


## 점들을 감싸는 사각형. 점이 없으면 빈 사각형.
static func bounds(points: Array[Vector2i]) -> Rect2i:
	if points.is_empty():
		return Rect2i()
	var result: Rect2i = Rect2i(points[0], Vector2i.ONE)
	for point: Vector2i in points:
		result = result.expand(point).expand(point + Vector2i.ONE)
	return result
