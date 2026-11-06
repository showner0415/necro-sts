extends SceneTree
## 에셋 PNG가 팔레트 밖의 색을 쓰는지 검사한다.
##
## 사용 예:
##   bash tools/godot.sh --headless --path . -s tools/check_palette.gd
##   bash tools/godot.sh --headless --path . -s tools/check_palette.gd -- assets/monsters
##
## 인자가 없으면 assets/ 전체를 검사한다. 인자로 파일이나 폴더를 줄 수 있다.
## 팔레트는 assets/palette/ 안의 .hex 파일 하나를 읽는다 (한 줄에 색 하나, 예: be4a2f).
## 완전히 투명한 픽셀(알파 0)은 검사하지 않는다. 그 외 픽셀은 RGB만 비교한다.
## 위반이 있으면 종료 코드 1, 팔레트를 읽지 못하면 2로 끝난다.

const PALETTE_DIR: String = "res://assets/palette"
const DEFAULT_TARGET: String = "res://assets"
const MAX_COLORS_PER_FILE: int = 5


func _init() -> void:
	var palette: Dictionary = _load_palette()
	if palette.is_empty():
		quit(2)
		return

	var targets: PackedStringArray = OS.get_cmdline_user_args()
	if targets.is_empty():
		targets = PackedStringArray([DEFAULT_TARGET])

	var files: PackedStringArray = PackedStringArray()
	for target: String in targets:
		_collect_pngs(_to_res_path(target), files)

	var bad_files: int = 0
	for path: String in files:
		if not _check_file(path, palette):
			bad_files += 1

	print("검사한 PNG: %d개, 팔레트 밖의 색이 있는 파일: %d개" % [files.size(), bad_files])
	quit(1 if bad_files > 0 else 0)


func _load_palette() -> Dictionary:
	var hex_files: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(PALETTE_DIR):
		if file_name.get_extension() == "hex":
			hex_files.append(file_name)
	if hex_files.size() != 1:
		printerr("%s 안에 .hex 팔레트 파일이 정확히 하나 있어야 합니다. 찾은 개수: %d" % [PALETTE_DIR, hex_files.size()])
		return {}

	var palette_path: String = PALETTE_DIR.path_join(hex_files[0])
	var palette: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(palette_path).split("\n", false):
		var hex: String = line.strip_edges().to_lower()
		if hex.is_empty():
			continue
		if not hex.is_valid_hex_number() or hex.length() != 6:
			printerr("팔레트에 잘못된 줄이 있습니다: '%s' (%s)" % [hex, palette_path])
			return {}
		palette[hex] = true
	print("팔레트: %s (%d색)" % [palette_path, palette.size()])
	return palette


func _to_res_path(target: String) -> String:
	if target.begins_with("res://") or target.is_absolute_path():
		return target
	return "res://" + target.trim_prefix("./")


func _collect_pngs(path: String, out: PackedStringArray) -> void:
	if DirAccess.dir_exists_absolute(path):
		if path.trim_suffix("/") == PALETTE_DIR:
			return
		for file_name: String in DirAccess.get_files_at(path):
			if file_name.get_extension().to_lower() == "png":
				out.append(path.path_join(file_name))
		for dir_name: String in DirAccess.get_directories_at(path):
			_collect_pngs(path.path_join(dir_name), out)
	elif FileAccess.file_exists(path) and path.get_extension().to_lower() == "png":
		out.append(path)
	else:
		printerr("PNG 파일이나 폴더가 아닙니다: %s" % path)


## 팔레트 밖의 색이 없으면 true를 돌려준다.
func _check_file(path: String, palette: Dictionary) -> bool:
	var image: Image = Image.new()
	# res:// 경로로 읽으면 Godot가 "내보내면 동작하지 않는다"는 경고를 내므로 실제 경로로 읽는다.
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		printerr("이미지를 읽지 못했습니다: %s" % path)
		return false
	image.convert(Image.FORMAT_RGBA8)

	# 색 -> [픽셀 수, 처음 나온 좌표]
	var off_colors: Dictionary = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a8 == 0:
				continue
			var hex: String = color.to_html(false)
			if palette.has(hex):
				continue
			if off_colors.has(hex):
				off_colors[hex][0] += 1
			else:
				off_colors[hex] = [1, Vector2i(x, y)]

	if off_colors.is_empty():
		return true

	var pixel_count: int = 0
	for hex: String in off_colors:
		pixel_count += off_colors[hex][0]
	print("[팔레트 밖] %s: %d색, %d픽셀" % [path, off_colors.size(), pixel_count])
	var shown: int = 0
	for hex: String in off_colors:
		if shown >= MAX_COLORS_PER_FILE:
			print("    ... 외 %d색" % (off_colors.size() - shown))
			break
		print("    #%s  %d픽셀, 처음 위치 %s" % [hex, off_colors[hex][0], off_colors[hex][1]])
		shown += 1
	return false
