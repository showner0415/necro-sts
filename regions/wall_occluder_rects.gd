class_name WallOccluderRects
extends RefCounted
## 시야 빛의 벽 그림자 모양(사각형)을 벽 격자에서 계산한다. 노드에 의존하지 않는다.
## - 바닥에서 depth칸(가로·세로·대각) 안의 벽 칸만 쓴다. 더 깊은 벽은 앞의 벽 그림자에 가려 필요 없다
## - 칸마다 바닥과 닿은 변을 inset픽셀 안쪽으로 줄인다. 그래서 바닥 쪽 벽 가장자리 띠는 빛을 받아 밝게 보인다
## - 한 줄에서 위아래 끝이 같고 맞닿은 칸끼리는 사각형 하나로 합친다
## 격자 값: 0 = 바닥, 1 = 벽, 2 = 배치 밖. 사각형은 타일 (0, 0)의 왼쪽 위를 원점으로 한 픽셀 좌표다.

const FLOOR: int = 0
const WALL: int = 1

## 합치기 전 칸 수 (마지막 build)
var tile_count: int = 0


func build(grid: PackedByteArray, size: Vector2i, tile_size: float, inset: float, depth: int) -> Array[Rect2]:
	var near: PackedByteArray = _near_floor(grid, size, depth)
	var rects: Array[Rect2] = []
	tile_count = 0
	for y: int in size.y:
		var current: Rect2 = Rect2()
		var has_current: bool = false
		for x: int in size.x:
			var i: int = y * size.x + x
			if grid[i] != WALL or near[i] == 0:
				if has_current:
					rects.append(current)
					has_current = false
				continue
			tile_count += 1
			var rect: Rect2 = _inset_rect(grid, size, Vector2i(x, y), tile_size, inset)
			if has_current and is_equal_approx(rect.position.y, current.position.y) and is_equal_approx(rect.end.y, current.end.y) and is_equal_approx(rect.position.x, current.end.x):
				current = current.merge(rect)
			else:
				if has_current:
					rects.append(current)
				current = rect
				has_current = true
		if has_current:
			rects.append(current)
	return rects


func _is_floor(grid: PackedByteArray, size: Vector2i, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y and grid[cell.y * size.x + cell.x] == FLOOR


func _inset_rect(grid: PackedByteArray, size: Vector2i, cell: Vector2i, t: float, inset: float) -> Rect2:
	var left: float = cell.x * t + (inset if _is_floor(grid, size, cell + Vector2i.LEFT) else 0.0)
	var right: float = (cell.x + 1) * t - (inset if _is_floor(grid, size, cell + Vector2i.RIGHT) else 0.0)
	var top: float = cell.y * t + (inset if _is_floor(grid, size, cell + Vector2i.UP) else 0.0)
	var bottom: float = (cell.y + 1) * t - (inset if _is_floor(grid, size, cell + Vector2i.DOWN) else 0.0)
	return Rect2(left, top, right - left, bottom - top)


## 칸마다 depth칸 안에 바닥이 있으면 1. 가로로 한 번, 세로로 한 번 넓힌다 (누적 합).
func _near_floor(grid: PackedByteArray, size: Vector2i, depth: int) -> PackedByteArray:
	var across: PackedByteArray = PackedByteArray()
	across.resize(grid.size())
	var sums: PackedInt32Array = PackedInt32Array()
	sums.resize(size.x + 1)
	for y: int in size.y:
		for x: int in size.x:
			sums[x + 1] = sums[x] + (1 if grid[y * size.x + x] == FLOOR else 0)
		for x: int in size.x:
			across[y * size.x + x] = 1 if sums[mini(x + depth + 1, size.x)] - sums[maxi(x - depth, 0)] > 0 else 0
	var near: PackedByteArray = PackedByteArray()
	near.resize(grid.size())
	sums.resize(size.y + 1)
	for x: int in size.x:
		for y: int in size.y:
			sums[y + 1] = sums[y] + across[y * size.x + x]
		for y: int in size.y:
			near[y * size.x + x] = 1 if sums[mini(y + depth + 1, size.y)] - sums[maxi(y - depth, 0)] > 0 else 0
	return near
