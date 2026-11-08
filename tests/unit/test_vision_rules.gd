extends TestCase
## VisionRules (플레이어 시야 규칙): 부채꼴·가장자리 단계·둘레 원·거리·벽 뒤 가림.

const TILE: float = 32.0

var rules: VisionRules


func before_each() -> void:
	rules = VisionRules.new()
	rules.full_angle = 23.0
	rules.total_angle = 35.0
	rules.edge_steps = 2
	rules.near_radius = 48.0
	rules.view_range = 400.0


## 8×4칸 격자에 벽 칸들을 놓는다. 타일 (0, 0)은 월드 (0, 0)
func _set_walls(cells: Array[Vector2i]) -> void:
	var size: Vector2i = Vector2i(8, 4)
	var grid: PackedByteArray = PackedByteArray()
	grid.resize(size.x * size.y)
	for cell: Vector2i in cells:
		grid[cell.y * size.x + cell.x] = 1
	rules.set_walls(grid, size, TILE, Vector2.ZERO)


func _at(angle_deg: float, distance: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(angle_deg)) * distance


func test_full_inside_23_degrees() -> void:
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, _at(0.0, 200.0)), 0, "정면")
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, _at(22.0, 200.0)), 0, "22도")
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, _at(-22.0, 200.0)), 0, "반대쪽 22도")


func test_edge_steps_between_23_and_35_degrees() -> void:
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, _at(26.0, 200.0)), 1, "23~29도는 1단계")
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, _at(32.0, 200.0)), 2, "29~35도는 2단계")
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, _at(-32.0, 200.0)), 2, "반대쪽도 같다")


func test_outside_35_degrees_hidden() -> void:
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, _at(36.0, 200.0)), rules.hidden_level(), "36도는 안 보임")
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, _at(180.0, 200.0)), rules.hidden_level(), "뒤는 안 보임")


func test_near_radius_visible_any_direction() -> void:
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, _at(180.0, 40.0)), 0, "뒤라도 둘레 원 안은 보임")
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, _at(90.0, 48.0)), 0, "반지름 경계까지 보임")


func test_range_limit() -> void:
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, _at(0.0, 401.0)), rules.hidden_level(), "보이는 거리 밖")


func test_wall_blocks_behind() -> void:
	# 네크로맨서는 타일 (0,0) 가운데, 오른쪽 타일 (3,0)에 벽
	_set_walls([Vector2i(3, 0)])
	var origin: Vector2 = Vector2(16, 16)
	var wall_face: Vector2 = Vector2(3.5, 0.5) * TILE
	var behind: Vector2 = Vector2(6.5, 0.5) * TILE
	assert_eq(rules.level_with_walls(origin, Vector2.RIGHT, wall_face), 0, "벽 면은 보임")
	assert_eq(rules.level_with_walls(origin, Vector2.RIGHT, behind), rules.hidden_level(), "벽 뒤는 안 보임")
	assert_eq(rules.level_with_walls(origin, Vector2.RIGHT, Vector2(6.5, 2.5) * TILE), 0, "벽 옆으로 비껴간 줄은 보임")


func test_wall_blocks_even_inside_near_radius() -> void:
	_set_walls([Vector2i(1, 0)])
	var origin: Vector2 = Vector2(16, 16)
	assert_eq(rules.level_with_walls(origin, Vector2.LEFT, Vector2(2.5, 0.5) * TILE), rules.hidden_level(), "둘레 원 안이어도 벽 뒤는 안 보임")

