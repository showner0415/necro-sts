extends SceneTree
## 무리 자리 시험 맵 PNG(art_src/maps/pack_test.png)를 만든다 (계획 5b-2). 24×16칸 1등급 굴 하나에 도착 지점·탈출 지점과 무리 색 다섯을 하나씩 찍는다.
## 맵 PNG는 보통 Aseprite로 그리지만, 이 시험 맵은 무리 색 변환을 확인하려는 것이라 코드로 만든다. 고치려면 아래 값을 바꿔 다시 돌린다.
##   bash tools/godot.sh --headless --path . -s tools/map_png/make_pack_test_png.gd
## 그다음 씬으로 바꾼다:
##   bash tools/godot.sh --headless --path . -s tools/map_from_png.gd -- --in=res://art_src/maps/pack_test.png --out=res://tests/pack_test_map.tscn --region=res://data/regions/pack_test.tres --name=PackTestMap

const OUT: String = "res://art_src/maps/pack_test.png"
const SIZE: Vector2i = Vector2i(24, 16)
const WALL: String = "181425"
const FLOOR: String = "265c42"
## 칸 → 색 (도착 지점, 탈출 지점, 무리 자리 다섯)
const MARKS: Dictionary = {
	Vector2i(3, 8): "63c74d",
	Vector2i(3, 12): "2ce8f5",
	Vector2i(10, 4): "ead4aa",
	Vector2i(18, 4): "e8b796",
	Vector2i(10, 11): "d77643",
	Vector2i(18, 11): "c28569",
	Vector2i(14, 8): "b86f50",
}


func _initialize() -> void:
	var image: Image = Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(WALL))
	for y: int in range(1, SIZE.y - 1):
		for x: int in range(1, SIZE.x - 1):
			image.set_pixel(x, y, Color(FLOOR))
	for cell: Vector2i in MARKS:
		image.set_pixelv(cell, Color(MARKS[cell]))
	var error: int = image.save_png(OUT)
	print("저장: %s (%s)" % [OUT, error_string(error)])
	quit(0 if error == OK else 1)
