extends TestCase
## GridPath(칸으로 나눈 바닥의 길찾기) 단위 테스트. 칸 8px, 10×10칸 바닥 (0, 0)~(80, 80).

const CELL: float = 8.0
const BOUNDS: Rect2 = Rect2(0, 0, 80, 80)

var grid: GridPath


func before_each() -> void:
	grid = GridPath.new(BOUNDS, CELL)


## 세로 벽: 열 5, 줄 0~7 (줄 8·9는 뚫려 있음)
func _wall_with_gap_at_bottom() -> void:
	for row: int in 8:
		grid.set_solid(Vector2i(5, row))


func test_cells_and_world_positions() -> void:
	assert_eq(grid.get_size(), Vector2i(10, 10))
	assert_eq(grid.world_to_cell(Vector2(12, 3)), Vector2i(1, 0))
	assert_eq(grid.cell_to_world(Vector2i(1, 0)), Vector2(12, 4), "칸 가운데")
	assert_eq(grid.world_to_cell(Vector2(-50, 500)), Vector2i(0, 9), "바닥 밖은 가장 가까운 가장자리 칸")


func test_has_solid_counts_cells() -> void:
	assert_false(grid.has_solid(), "처음엔 막힌 칸이 없다")
	grid.set_solid(Vector2i(2, 2))
	grid.set_solid(Vector2i(2, 2))
	assert_true(grid.has_solid())
	grid.set_solid(Vector2i(2, 2), false)
	assert_false(grid.has_solid(), "같은 칸을 두 번 막아도 한 번 푼 것으로 비어진다")


func test_path_goes_around_wall() -> void:
	_wall_with_gap_at_bottom()
	var path: PackedVector2Array = grid.find_path(grid.cell_to_world(Vector2i(2, 2)), grid.cell_to_world(Vector2i(8, 2)))
	assert_true(path.size() > 2, "곧장 갈 수 없어 여러 점을 지난다")
	assert_eq(path[0], grid.cell_to_world(Vector2i(2, 2)), "첫 점은 출발 칸")
	assert_eq(path[path.size() - 1], grid.cell_to_world(Vector2i(8, 2)), "마지막 점은 목표 칸")
	var lowest_row: int = 0
	for point: Vector2 in path:
		assert_false(grid.is_solid(grid.world_to_cell(point)), "막힌 칸을 지나지 않는다: %s" % point)
		lowest_row = maxi(lowest_row, grid.world_to_cell(point).y)
	assert_true(lowest_row >= 8, "아래쪽 뚫린 곳으로 돌아간다 (가장 아래 줄 %d)" % lowest_row)


func test_no_diagonal_through_wall_corner() -> void:
	# 대각선 양옆 중 하나라도 막혀 있으면 대각선으로 가지 않는다.
	grid.set_solid(Vector2i(1, 0))
	var path: PackedVector2Array = grid.find_path(grid.cell_to_world(Vector2i(0, 0)), grid.cell_to_world(Vector2i(1, 1)))
	assert_eq(path.size(), 3, "모퉁이를 깎지 않고 두 번에 간다")


func test_blocked_start_uses_nearest_open_cell() -> void:
	_wall_with_gap_at_bottom()
	# 벽 칸 안에서 출발 (벽에 붙어 서 있음)
	var path: PackedVector2Array = grid.find_path(grid.cell_to_world(Vector2i(5, 2)), grid.cell_to_world(Vector2i(2, 2)))
	assert_true(path.size() > 0, "길이 있다")
	assert_false(grid.is_solid(grid.world_to_cell(path[0])), "가장 가까운 빈 칸에서 출발한다")


func test_unreachable_goal_gives_partial_path() -> void:
	# 목표 칸 (8, 8)을 둘러싼다.
	for cell: Vector2i in [Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7), Vector2i(7, 8), Vector2i(7, 9)]:
		grid.set_solid(cell)
	var goal: Vector2 = grid.cell_to_world(Vector2i(8, 8))
	var path: PackedVector2Array = grid.find_path(grid.cell_to_world(Vector2i(1, 1)), goal)
	assert_true(path.size() > 0, "닿을 수 없어도 가까운 곳까지의 길이 있다")
	assert_ne(path[path.size() - 1], goal, "목표 칸까지는 가지 못한다")


func test_fill_solid_run_blocks_cells_in_row() -> void:
	grid.fill_solid_run(3, 2, 6)
	for x: int in 10:
		assert_eq(grid.is_solid(Vector2i(x, 3)), x >= 2 and x < 6, "줄 3의 칸 %d" % x)
	assert_false(grid.is_solid(Vector2i(2, 2)), "다른 줄은 그대로")
	assert_true(grid.has_solid(), "막힌 칸이 생김")
	grid.fill_solid_run(4, 5, 5)
	assert_false(grid.is_solid(Vector2i(5, 4)), "빈 구간은 아무것도 막지 않음")
