extends RefCounted
## 윤곽이 있는 지역의 실제 바닥을 칸 글자로 옮긴다. 칸 가운데가 바위면 벽, 아니면 바닥이다.
## 칸으로 지형을 재는 검사(scenario_shallow_cave.gd)와 칸을 따라 걷는 봇 경로(run_map_route.gd)가 쓴다. 윤곽이 없으면 칸 그대로다.

const NEIGHBORS_8: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const WALL_CHAR: String = "#"
const DEFAULT_FLOOR: String = "."


static func of(walls: PlaceholderWalls) -> PackedStringArray:
	if walls.outline == null:
		return walls.layout
	var rows: PackedStringArray = PackedStringArray()
	for y: int in walls.layout.size():
		var line: String = ""
		for x: int in walls.layout[y].length():
			var cell: Vector2i = Vector2i(x, y)
			if walls.outline.is_rock_at((Vector2(cell) + Vector2(0.5, 0.5)) * walls.tile_size):
				line += WALL_CHAR
			elif not walls.is_wall(cell):
				line += walls.layout[y][x]
			else:
				line += _neighbor_floor(walls, cell)
		rows.append(line)
	return rows


## 윤곽이 물러나서 바닥이 된 벽 칸: 이웃 바닥의 종류를 잇는다.
static func _neighbor_floor(walls: PlaceholderWalls, cell: Vector2i) -> String:
	for offset: Vector2i in NEIGHBORS_8:
		var next: String = walls.get_char(cell + offset)
		if not next.is_empty() and not walls.wall_chars.contains(next):
			return next
	return DEFAULT_FLOOR
