extends TestCase
## WallOccluderRects (시야 빛의 벽 그림자 모양): 바닥 쪽 변만 줄이기, 깊은 벽 빼기, 한 줄에서 합치기.

const TILE: float = 32.0
const INSET: float = 7.0

var rects: WallOccluderRects


func before_each() -> void:
	rects = WallOccluderRects.new()


## 글자 줄로 격자를 만든다: "#" 벽, "." 바닥, " " 배치 밖
func _grid(lines: Array[String]) -> Array:
	var size: Vector2i = Vector2i(lines[0].length(), lines.size())
	var grid: PackedByteArray = PackedByteArray()
	for line: String in lines:
		for c: String in line:
			grid.append(WallOccluderRects.WALL if c == "#" else (WallOccluderRects.FLOOR if c == "." else 2))
	return [grid, size]


func test_floor_side_inset_only() -> void:
	var g: Array = _grid(["###", "#.#", "###"])
	var result: Array[Rect2] = rects.build(g[0], g[1], TILE, INSET, 1)
	# 가운데 바닥 위 칸 (1, 0): 아래 변만 줄어든다
	var top_middle: Array = result.filter(func(r: Rect2) -> bool: return r.has_point(Vector2(48, 10)))
	assert_eq(top_middle.size(), 1, "위 가운데 칸을 덮는 사각형 하나")
	assert_almost_eq((top_middle[0] as Rect2).end.y, 32.0 - INSET, 0.001, "바닥 쪽(아래) 변만 7px 줄어든다")
	assert_false(result.any(func(r: Rect2) -> bool: return r.has_point(Vector2(48, 32 - INSET / 2.0))), "줄어든 띠는 빛을 받는다")


func test_merges_same_height_in_row() -> void:
	var g: Array = _grid(["#####", ".....", "#####"])
	var result: Array[Rect2] = rects.build(g[0], g[1], TILE, INSET, 1)
	assert_eq(rects.tile_count, 10, "바닥과 닿은 벽 칸 10개")
	assert_eq(result.size(), 2, "위·아래 줄이 각각 하나로 합쳐진다")
	assert_eq(result[0], Rect2(0, 0, 160, 32 - INSET), "위 줄: 아래 변만 줄어든 긴 사각형")


func test_deep_walls_skipped() -> void:
	var g: Array = _grid(["#######", "#######", "#######", "......."])
	rects.build(g[0], g[1], TILE, INSET, 2)
	assert_eq(rects.tile_count, 14, "바닥에서 2칸 안의 벽 줄(두 줄)만 쓴다")


func test_outside_layout_not_floor() -> void:
	var g: Array = _grid(["## ", "#. "])
	var result: Array[Rect2] = rects.build(g[0], g[1], TILE, INSET, 1)
	assert_false(result.any(func(r: Rect2) -> bool: return r.has_point(Vector2(80, 5))), "배치 밖 칸에는 그림자 모양이 없다")
	assert_eq(rects.tile_count, 3, "바닥과 닿은 벽 칸 3개")
