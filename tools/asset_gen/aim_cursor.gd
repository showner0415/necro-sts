extends SceneTree
## 조준점 커서 그림을 만든다. 게임 화면 위에서 시스템 커서로 쓴다 (ui/aim_cursor.gd).
## 십자 모양(가운데 빔)을 밝은 색으로 그리고, 둘레 1px에 어두운 테두리를 두른다.
## 시스템 커서는 창의 실제 픽셀로 그려지므로, 창 배율(정수)마다 한 게임 픽셀을 배율만큼 키운 그림을 따로 만든다.
##
## 실행: bash tools/godot.sh --headless --path . -s tools/asset_gen/aim_cursor.gd
## 결과: assets/ui/aim_cursor/aim_cursor_x<배율>.png (배율 1 ~ MAX_SCALE)

const PALETTE_PATH: String = "res://assets/palette/endesga-32.hex"
const OUT_DIR: String = "res://assets/ui/aim_cursor"

## 팔레트 파일의 몇 번째 색(0부터)인지. 색 값은 팔레트 파일에서 읽는다.
## 밝은 색: ffffff (20번째 줄)
const FILL_PALETTE_INDEX: int = 19
## 테두리: 181425 (26번째 줄, 외곽선 전용 색)
const OUTLINE_PALETTE_INDEX: int = 25

## 십자 크기 (게임 픽셀). 테두리를 빼고 가로세로 길이
const CROSS_SIZE: int = 9
## 가운데 빈 칸의 가로세로 길이 (홀수). 팔 길이 = (CROSS_SIZE - CENTER_GAP) / 2
const CENTER_GAP: int = 3
## 팔 두께 (게임 픽셀)
const ARM_THICKNESS: int = 1
## 테두리 두께 (게임 픽셀)
const OUTLINE: int = 1
## 만들 창 배율. 1280×720(2배)부터 3840×2160(6배)까지
const MAX_SCALE: int = 6


func _initialize() -> void:
	var palette: PackedColorArray = _load_palette()
	if palette.size() <= maxi(FILL_PALETTE_INDEX, OUTLINE_PALETTE_INDEX):
		printerr("팔레트 색이 모자랍니다: %d개" % palette.size())
		quit(1)
		return
	var base: Image = _draw_base(palette[FILL_PALETTE_INDEX], palette[OUTLINE_PALETTE_INDEX])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for scale: int in range(1, MAX_SCALE + 1):
		var image: Image = base.duplicate()
		image.resize(base.get_width() * scale, base.get_height() * scale, Image.INTERPOLATE_NEAREST)
		var path: String = OUT_DIR.path_join("aim_cursor_x%d.png" % scale)
		var error: Error = image.save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			printerr("저장 실패 (%s): %s" % [error_string(error), path])
			quit(1)
			return
		print("저장: %s (%d×%d)" % [path, image.get_width(), image.get_height()])
	quit(0)


func _load_palette() -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray()
	for line: String in FileAccess.get_file_as_string(PALETTE_PATH).split("\n"):
		var hex: String = line.strip_edges()
		if not hex.is_empty():
			colors.append(Color.html(hex))
	return colors


## 배율 1의 그림: 십자 + 둘레 테두리. 가운데 픽셀이 그림의 정가운데에 오도록 크기는 홀수다.
func _draw_base(fill: Color, outline: Color) -> Image:
	var size: int = CROSS_SIZE + OUTLINE * 2
	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center: int = size / 2
	var half_gap: int = CENTER_GAP / 2
	var half_thickness: int = ARM_THICKNESS / 2
	var reach: int = CROSS_SIZE / 2
	var filled: Dictionary[Vector2i, bool] = {}
	for offset: int in range(half_gap + 1, reach + 1):
		for side: int in range(-half_thickness, ARM_THICKNESS - half_thickness):
			for point: Vector2i in [Vector2i(center + side, center - offset), Vector2i(center + side, center + offset), Vector2i(center - offset, center + side), Vector2i(center + offset, center + side)]:
				filled[point] = true
	# 테두리: 채운 픽셀에서 OUTLINE 안(8방향)에 있는 빈 픽셀. 가운데 빈 칸은 비워 둔다 (테두리로 메우면 가운데가 막혀 보인다).
	for point: Vector2i in filled:
		for dy: int in range(-OUTLINE, OUTLINE + 1):
			for dx: int in range(-OUTLINE, OUTLINE + 1):
				var around: Vector2i = point + Vector2i(dx, dy)
				var in_gap: bool = absi(around.x - center) <= half_gap and absi(around.y - center) <= half_gap
				if not filled.has(around) and not in_gap:
					image.set_pixelv(around, outline)
	for point: Vector2i in filled:
		image.set_pixelv(point, fill)
	return image
