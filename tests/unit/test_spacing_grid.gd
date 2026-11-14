extends TestCase
## SpacingGrid(간격 밀기 이웃 칸 묶음) 단위 테스트.

const CELL: float = 48.0

var grid: SpacingGrid
var items: Array[RefCounted] = []


func before_each() -> void:
	grid = SpacingGrid.new(CELL)
	items.clear()
	for i: int in 4:
		items.append(RefCounted.new())


func test_finds_items_within_cell_size_in_any_direction() -> void:
	var center: Vector2 = Vector2(100, 100)
	grid.insert(items[0], center + Vector2(CELL - 1.0, 0))
	grid.insert(items[1], center + Vector2(0, -(CELL - 1.0)))
	grid.insert(items[2], center + Vector2(-30, 30))
	var found: Array = grid.nearby(center)
	for i: int in 3:
		assert_true(found.has(items[i]), "칸 크기 안의 것은 빠지지 않는다 (%d)" % i)


func test_skips_items_two_cells_away() -> void:
	grid.insert(items[0], Vector2(10, 10))
	grid.insert(items[3], Vector2(10 + CELL * 3.0, 10))
	var found: Array = grid.nearby(Vector2(10, 10))
	assert_true(found.has(items[0]))
	assert_false(found.has(items[3]), "둘레 칸보다 먼 칸의 것은 돌려주지 않는다")


func test_negative_positions() -> void:
	grid.insert(items[0], Vector2(-5, -5))
	assert_true(grid.nearby(Vector2(5, 5)).has(items[0]), "0을 사이에 둔 이웃도 찾는다")
	assert_eq(grid.nearby(Vector2(-1000, -1000)).size(), 0, "아무것도 없는 곳은 빈 배열")
