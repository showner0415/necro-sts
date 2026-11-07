class_name PlaceholderWalls
extends Node2D
## 타일 그림이 생기기 전까지 쓰는 임시 벽(과 바닥). 글자 줄(layout)로 칸을 적으면 벽 칸에 충돌하는 벽을 만들고 색 칸으로 그린다.
## - layout의 한 글자가 한 칸이다. wall_chars에 든 글자는 벽, 나머지는 바닥이다. 첫 줄 첫 글자 칸의 왼쪽 위가 이 노드의 위치다
## - 벽은 충돌층 world(wall_layer)에 있는 StaticBody2D 하나다. 한 줄에서 이어진 벽 칸은 사각형 하나로 합친다
## - 벽 칸은 윗면 색(wall_colors에 그 글자가 있으면 그 색, 없으면 top_color)으로 칠하고,
##   아래가 바닥인 벽 칸에는 아래 가장자리에 밝은 띠를 그려서 벽의 앞면처럼 보이게 한다 (3/4 시점)
## - floor_colors에 든 글자의 바닥 칸은 그 두 색을 번갈아 체크무늬로 칠한다 (움직임이 보이게). 없는 글자의 바닥은 칠하지 않는다
##   (시험 통로처럼 바닥을 따로 그리는 씬). 맵 PNG에서 만든 지역(tools/map_from_png.gd)은 바닥도 여기서 그린다

## 칸 배치. 줄마다 같은 길이로 적는다.
@export var layout: PackedStringArray = PackedStringArray()
## 벽으로 보는 글자들
@export var wall_chars: String = "#"
@export var tile_size: int = 32
@export_flags_2d_physics var wall_layer: int = 1
@export_group("임시 도형")
## 벽 윗면 색 (5a6988)과 앞면 띠 색 (8b9bb4), 띠 두께 (픽셀)
@export var top_color: Color = Color(0.3529412, 0.4117647, 0.53333336, 1)
@export var face_color: Color = Color(0.54509807, 0.60784316, 0.7058824, 1)
@export var face_height: float = 6.0
## 벽 글자마다 따로 쓸 윗면 색 (예: 막아 둔 길목). 없는 글자는 top_color.
@export var wall_colors: Dictionary[String, Color] = {}
## 바닥 글자마다 체크무늬 두 색
@export var floor_colors: Dictionary[String, PackedColorArray] = {}


func _ready() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = wall_layer
	body.collision_mask = 0
	for row: int in layout.size():
		var line: String = layout[row]
		var column: int = 0
		while column < line.length():
			if not is_wall(Vector2i(column, row)):
				column += 1
				continue
			var run_start: int = column
			while column < line.length() and is_wall(Vector2i(column, row)):
				column += 1
			var shape: RectangleShape2D = RectangleShape2D.new()
			shape.size = Vector2((column - run_start) * tile_size, tile_size)
			var collision: CollisionShape2D = CollisionShape2D.new()
			collision.shape = shape
			collision.position = Vector2(run_start * tile_size, row * tile_size) + shape.size / 2.0
			body.add_child(collision)
	add_child(body)


## 칸(열, 줄)의 글자. layout 밖이면 빈 글자.
func get_char(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= layout.size() or cell.x < 0 or cell.x >= layout[cell.y].length():
		return ""
	return layout[cell.y][cell.x]


## 칸(열, 줄)이 벽인지. layout 밖은 벽이 아니다.
func is_wall(cell: Vector2i) -> bool:
	var c: String = get_char(cell)
	return not c.is_empty() and wall_chars.contains(c)


## 칸 가운데의 월드 좌표 (시험·배치용)
func cell_center(cell: Vector2i) -> Vector2:
	return global_position + (Vector2(cell) + Vector2(0.5, 0.5)) * tile_size


## 월드 좌표가 든 칸
func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(((point - global_position) / tile_size).floor())


func _draw() -> void:
	for row: int in layout.size():
		for column: int in layout[row].length():
			var cell: Vector2i = Vector2i(column, row)
			var c: String = layout[row][column]
			var rect: Rect2 = Rect2(Vector2(cell * tile_size), Vector2(tile_size, tile_size))
			if not wall_chars.contains(c):
				if floor_colors.has(c):
					var pair: PackedColorArray = floor_colors[c]
					draw_rect(rect, pair[(column + row) % pair.size()])
				continue
			draw_rect(rect, wall_colors.get(c, top_color))
			if row + 1 < layout.size() and not is_wall(cell + Vector2i(0, 1)):
				draw_rect(Rect2(rect.position + Vector2(0, tile_size - face_height), Vector2(tile_size, face_height)), face_color)
