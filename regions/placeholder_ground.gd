extends Node2D
## 타일 그림이 생기기 전까지 쓰는 임시 바닥. 움직임이 눈에 보이도록 체크무늬를 그린다.

@export var tile_size: int = 32
## 원점을 가운데로 하는 바닥 크기 (타일 수)
@export var size_in_tiles: Vector2i = Vector2i(30, 30)
@export var color_a: Color = Color(0.24313726, 0.15294118, 0.19215687, 1)
@export var color_b: Color = Color(0.14901961, 0.16862746, 0.26666668, 1)


func _draw() -> void:
	var start: Vector2i = -size_in_tiles / 2
	for y: int in size_in_tiles.y:
		for x: int in size_in_tiles.x:
			var color: Color = color_a if (x + y) % 2 == 0 else color_b
			var tile_position: Vector2 = Vector2((start + Vector2i(x, y)) * tile_size)
			draw_rect(Rect2(tile_position, Vector2(tile_size, tile_size)), color)
