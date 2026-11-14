class_name ChokeIndex
extends RefCounted
## 구운 길목(ChokeData)을 월드 좌표로 찾는 규칙 (계획 4b). 노드에 의존하지 않는다. NavigationGrid가 하나 든다.
## - 길목 칸은 맵 칸(cell_px) 단위이고, origin은 맵 칸 (0, 0)의 왼쪽 위 월드 좌표다 (벽 노드의 위치)
## - 가려는 길(점들)이 길목 칸을 지나는지는 sample_step 픽셀마다 점을 찍어 본다

var chokes: Array[ChokeData] = []
var cell_px: float
var origin: Vector2
## 길을 따라 길목 칸을 찾을 때 점을 찍는 간격 (픽셀)
var sample_step: float
## 맵 칸 → 길목 번호
var _choke_of: Dictionary = {}


func _init(choke_list: Array[ChokeData], size_px: float, top_left: Vector2, step: float) -> void:
	chokes = choke_list
	cell_px = size_px
	origin = top_left
	sample_step = step
	for i: int in chokes.size():
		for cell: Vector2 in chokes[i].cells:
			_choke_of[Vector2i(cell)] = i


func is_empty() -> bool:
	return chokes.is_empty()


## point(월드)가 든 길목 번호. 길목 밖이면 -1
func choke_at(point: Vector2) -> int:
	return _choke_of.get(Vector2i(((point - origin) / cell_px).floor()), -1)


## 점들을 잇는 길이 처음 지나는 길목 번호 (skip 길목은 건너뛴다). 없으면 -1
func first_choke_on_path(points: PackedVector2Array, skip: int = -1) -> int:
	for i: int in range(1, points.size()):
		var from: Vector2 = points[i - 1]
		var to: Vector2 = points[i]
		var steps: int = maxi(1, ceili(from.distance_to(to) / sample_step))
		for k: int in steps + 1:
			var choke: int = choke_at(from.lerp(to, float(k) / steps))
			if choke >= 0 and choke != skip:
				return choke
	return -1


## point에 가장 가까운 입구 번호
func nearest_entrance(choke: int, point: Vector2) -> int:
	var entrances: PackedVector2Array = chokes[choke].entrances
	var best: int = 0
	for i: int in range(1, entrances.size()):
		if entrances[i].distance_squared_to(point) < entrances[best].distance_squared_to(point):
			best = i
	return best


## from 쪽 입구에서 to 쪽 입구로 길목을 막고 돌아가도 되는지: 우회 비율이 있고 limit 이하
func can_detour(choke: int, from: Vector2, to: Vector2, limit: float) -> bool:
	var a: int = nearest_entrance(choke, from)
	var b: int = nearest_entrance(choke, to)
	if a == b:
		return false
	var ratio: float = chokes[choke].detour_ratio(a, b)
	return ratio > 0.0 and ratio <= limit


## 길목 칸들의 월드 사각형 (길을 찾을 때 잠깐 막는 데 쓴다)
func cell_rects(choke: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for cell: Vector2 in chokes[choke].cells:
		rects.append(Rect2(origin + cell * cell_px, Vector2(cell_px, cell_px)))
	return rects
