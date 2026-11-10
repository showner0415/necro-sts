class_name TerrainCells
extends RefCounted
## 3D 지형을 만들 칸 정보. 임시 벽(PlaceholderWalls)과 임시 바닥(PlaceholderGround)을 2D에서 그리는 색 그대로 읽어 온다.

## 칸 수 (가로, 세로)
var size: Vector2i = Vector2i.ZERO
## 첫 칸의 왼쪽 위 (월드 좌표)
var origin: Vector2 = Vector2.ZERO
var tile_size: int = 32
## 칸마다 1 = 벽, 0 = 그 밖 (가로 size.x칸씩 줄 순서)
var walls: PackedByteArray = PackedByteArray()
## 칸마다 윗면 색. 알파가 0이면 그 칸은 그리지 않는다 (2D에서도 칠하지 않는 칸)
var top_colors: PackedColorArray = PackedColorArray()
## 벽 앞면 색
var face_color: Color = Color.WHITE


static func from_walls(source: PlaceholderWalls) -> TerrainCells:
	var cells: TerrainCells = TerrainCells.new()
	cells.size = source.grid_size()
	cells.origin = source.global_position
	cells.tile_size = source.tile_size
	cells.face_color = source.face_color
	cells._allocate()
	for y: int in cells.size.y:
		for x: int in cells.size.x:
			var cell: Vector2i = Vector2i(x, y)
			var c: String = source.get_char(cell)
			var index: int = cells.index_of(x, y)
			if source.is_wall(cell):
				cells.walls[index] = 1
				cells.top_colors[index] = source.wall_colors.get(c, source.top_color)
			elif source.floor_colors.has(c):
				var pair: PackedColorArray = source.floor_colors[c]
				cells.top_colors[index] = pair[(x + y) % pair.size()]
	return cells


static func from_ground(source: PlaceholderGround) -> TerrainCells:
	var cells: TerrainCells = TerrainCells.new()
	cells.size = source.size_in_tiles
	cells.tile_size = source.tile_size
	cells.origin = source.global_position + Vector2(-source.size_in_tiles / 2 * source.tile_size)
	cells._allocate()
	for y: int in cells.size.y:
		for x: int in cells.size.x:
			cells.top_colors[cells.index_of(x, y)] = source.color_a if (x + y) % 2 == 0 else source.color_b
	return cells


func index_of(x: int, y: int) -> int:
	return y * size.x + x


## 칸(열, 줄)이 벽인지. 칸 밖은 벽이 아니다.
func is_wall(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size.x and y < size.y and walls[index_of(x, y)] == 1


func _allocate() -> void:
	walls.resize(size.x * size.y)
	walls.fill(0)
	top_colors.resize(size.x * size.y)
	top_colors.fill(Color.TRANSPARENT)
