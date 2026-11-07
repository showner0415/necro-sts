class_name PlaceholderWalls
extends Node2D
## 타일 그림이 생기기 전까지 쓰는 임시 벽. 글자 줄(layout)로 벽 칸을 적으면 그 칸에 충돌하는 벽을 만들고 색 칸으로 그린다.
## - layout의 한 글자가 한 칸이다. wall_char는 벽, 나머지는 바닥이다. 첫 줄 첫 글자 칸의 왼쪽 위가 이 노드의 위치다
## - 벽은 충돌층 world(wall_layer)에 있는 StaticBody2D 하나다. 한 줄에서 이어진 벽 칸은 사각형 하나로 합친다
## - 아래가 바닥인 벽 칸에는 아래 가장자리에 밝은 띠를 그려서 벽의 앞면처럼 보이게 한다 (3/4 시점)

## 벽 칸 배치. 줄마다 같은 길이로 적는다.
@export var layout: PackedStringArray = PackedStringArray()
@export var wall_char: String = "#"
@export var tile_size: int = 32
@export_flags_2d_physics var wall_layer: int = 1
@export_group("임시 도형")
## 벽 윗면 색 (5a6988)과 앞면 띠 색 (8b9bb4), 띠 두께 (픽셀)
@export var top_color: Color = Color(0.3529412, 0.4117647, 0.53333336, 1)
@export var face_color: Color = Color(0.54509807, 0.60784316, 0.7058824, 1)
@export var face_height: float = 6.0


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


## 칸(열, 줄)이 벽인지. layout 밖은 벽이 아니다.
func is_wall(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= layout.size() or cell.x < 0 or cell.x >= layout[cell.y].length():
		return false
	return layout[cell.y][cell.x] == wall_char


## 칸 가운데의 월드 좌표 (시험·배치용)
func cell_center(cell: Vector2i) -> Vector2:
	return global_position + (Vector2(cell) + Vector2(0.5, 0.5)) * tile_size


func _draw() -> void:
	for row: int in layout.size():
		for column: int in layout[row].length():
			var cell: Vector2i = Vector2i(column, row)
			if not is_wall(cell):
				continue
			var rect: Rect2 = Rect2(Vector2(cell * tile_size), Vector2(tile_size, tile_size))
			draw_rect(rect, top_color)
			if row + 1 < layout.size() and not is_wall(cell + Vector2i(0, 1)):
				draw_rect(Rect2(rect.position + Vector2(0, tile_size - face_height), Vector2(tile_size, face_height)), face_color)
