extends SceneTree
## 같은 크기의 PNG 여러 장을 한 장으로 붙인다.
## 실행: bash tools/godot.sh --headless --path . -s tools/contact_sheet.gd -- --out=<a.png> --columns=2 <1.png> <2.png> ...

const GAP: int = 4
## 사이 간격 색 (ffffff)
const GAP_COLOR: Color = Color.WHITE


func _initialize() -> void:
	var out: String = ""
	var columns: int = 2
	var paths: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--columns="):
			columns = arg.trim_prefix("--columns=").to_int()
		else:
			paths.append(arg)
	if out.is_empty() or paths.is_empty():
		printerr("사용법: -- --out=<a.png> --columns=2 <1.png> <2.png> ...")
		quit(1)
		return
	var first: Image = Image.load_from_file(paths[0])
	var size: Vector2i = first.get_size()
	var rows: int = ceili(float(paths.size()) / columns)
	var sheet: Image = Image.create_empty(columns * size.x + (columns - 1) * GAP, rows * size.y + (rows - 1) * GAP, false, Image.FORMAT_RGBA8)
	sheet.fill(GAP_COLOR)
	for index: int in paths.size():
		var image: Image = Image.load_from_file(paths[index])
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, size), Vector2i(index % columns, index / columns) * (size + Vector2i.ONE * GAP))
	var error: int = sheet.save_png(out)
	print("저장: %s (%s), %d장" % [out, error_string(error), paths.size()])
	quit(0 if error == OK else 1)
