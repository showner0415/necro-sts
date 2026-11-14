class_name SpacingGrid
extends RefCounted
## 몸끼리 간격 밀기(BodySpacing)에 쓸 이웃을 빨리 찾는 칸 묶음. 노드에 의존하지 않고 넣은 것은 Object로만 기억한다.
## - 넣을 때의 자리로 cell_size 칸에 묶는다. nearby()는 그 자리가 든 칸과 둘레 8칸에 든 것을 모두 돌려준다
## - 그래서 cell_size가 찾을 거리 이상이면 그 거리 안의 것은 빠지지 않는다 (먼 것이 섞일 수 있으니 거리는 쓰는 쪽이 다시 잰다)

var cell_size: float
## 칸 → [넣은 것들]
var _cells: Dictionary = {}


func _init(size: float) -> void:
	cell_size = size


func insert(item: Object, position: Vector2) -> void:
	var cell: Vector2i = _cell_of(position)
	if not _cells.has(cell):
		_cells[cell] = []
	_cells[cell].append(item)


## position이 든 칸과 둘레 8칸에 넣은 것들
func nearby(position: Vector2) -> Array:
	var result: Array = []
	var center: Vector2i = _cell_of(position)
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var cell: Vector2i = center + Vector2i(dx, dy)
			if _cells.has(cell):
				result.append_array(_cells[cell])
	return result


func _cell_of(position: Vector2) -> Vector2i:
	return Vector2i((position / cell_size).floor())
