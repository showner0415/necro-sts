extends SceneTree
## PNG 여러 장을 한 장으로 붙인다. 크기가 다르면 칸을 가장 큰 크기로 잡고 그림을 칸 위쪽 가운데에 두며, 남는 곳은 간격 색으로 채운다.
## 실행: bash tools/godot.sh --headless --path . -s tools/contact_sheet.gd -- --out=<a.png> --columns=2 <1.png> <2.png> ...
## 사용자 인자:
##   --out=<a.png>     저장할 PNG (꼭 준다)
##   --columns=<수>    한 줄의 칸 수 (기본 2)
##   --numbers         칸마다 번호표를 붙인다 (넘긴 PNG 순서로 1부터). 숫자는 이 파일의 작은 비트맵 글꼴로 그려서 헤드리스에서도 된다
##   --labels=<a.txt>  칸마다 안 이름이 든 UTF-8 글 파일. 한 줄에 하나, PNG 순서대로 (빈 줄과 #로 시작하는 줄은 건너뛴다).
##                     주면 번호표를 붙이고 "<번호>: <줄>" 범례를 <out 이름>_legend.txt로 저장한다. 한글을 명령 인자로 넘기지 않으려고 파일로 받는다
## 번호표는 칸 위에 띠를 더해 그림의 왼쪽 위에 붙여 그린다. 그림을 가리지 않고, 어두운 그림 위에서도 띠의 나머지는 간격 색이라 경계가 보인다.
## 색은 팔레트 색만 쓴다. 여러 안의 비교판은 tools/compare_variants.sh sheet가 이것으로 만든다.

const GAP: int = 4
## 사이 간격 색 (ffffff). 번호 띠의 번호표 밖도 이 색이다
const GAP_COLOR: Color = Color.WHITE
## 번호표 바탕색 (181425)
const BADGE_COLOR: Color = Color(0.09411765, 0.078431375, 0.14509805, 1)
## 숫자 색 (ffffff)
const DIGIT_COLOR: Color = Color.WHITE
## 숫자 글꼴: 한 글자가 가로 3칸 × 세로 5칸. 0부터 9까지, 위 줄부터 왼쪽에서 오른쪽으로 1이 칠할 칸이다
const DIGIT_SIZE: Vector2i = Vector2i(3, 5)
const DIGIT_PIXELS: Array[String] = [
	"111101101101111",
	"010110010010111",
	"111001111100111",
	"111001111001111",
	"101101111001001",
	"111100111001111",
	"111100111101111",
	"111001001001001",
	"111101111101111",
	"111101111001111",
]
## 숫자 높이 = 칸 높이 × 이 비율. 글꼴 한 칸은 가장 작아도 MIN_DIGIT_SCALE 픽셀이다 (640×360이면 5픽셀, 숫자 높이 25픽셀)
const DIGIT_HEIGHT_RATIO: float = 0.07
const MIN_DIGIT_SCALE: int = 2
## 범례 파일 이름: <out 이름> + 이것
const LEGEND_SUFFIX: String = "_legend.txt"


func _initialize() -> void:
	var out: String = ""
	var columns: int = 2
	var numbers: bool = false
	var labels_path: String = ""
	var paths: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--columns="):
			columns = arg.trim_prefix("--columns=").to_int()
		elif arg == "--numbers":
			numbers = true
		elif arg.begins_with("--labels="):
			labels_path = arg.trim_prefix("--labels=")
			numbers = true
		else:
			paths.append(arg)
	if out.is_empty() or paths.is_empty() or columns < 1:
		printerr("사용법: -- --out=<a.png> --columns=2 [--numbers] [--labels=<a.txt>] <1.png> <2.png> ...")
		quit(1)
		return
	var labels: PackedStringArray = PackedStringArray()
	if not labels_path.is_empty():
		if not FileAccess.file_exists(labels_path):
			printerr("범례 파일이 없습니다: %s" % labels_path)
			quit(1)
			return
		labels = _read_labels(labels_path)
		if labels.size() != paths.size():
			printerr("범례 줄 수(%d)가 PNG 수(%d)와 다릅니다: %s" % [labels.size(), paths.size(), labels_path])
			quit(1)
			return
	var images: Array[Image] = []
	var cell: Vector2i = Vector2i.ZERO
	for path: String in paths:
		var image: Image = Image.load_from_file(path)
		if image == null or image.is_empty():
			printerr("PNG를 읽지 못했습니다: %s" % path)
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
		cell = Vector2i(maxi(cell.x, image.get_width()), maxi(cell.y, image.get_height()))
	var scale: int = maxi(MIN_DIGIT_SCALE, roundi(cell.y * DIGIT_HEIGHT_RATIO / DIGIT_SIZE.y))
	# 번호 띠의 높이: 숫자 위아래로 글꼴 한 칸씩 띄운다
	var band: int = (DIGIT_SIZE.y + 2) * scale if numbers else 0
	var pitch: Vector2i = Vector2i(cell.x, cell.y + band) + Vector2i.ONE * GAP
	var rows: int = ceili(float(paths.size()) / columns)
	var sheet: Image = Image.create_empty(columns * pitch.x - GAP, rows * pitch.y - GAP, false, Image.FORMAT_RGBA8)
	sheet.fill(GAP_COLOR)
	for index: int in images.size():
		var image: Image = images[index]
		# 그림의 왼쪽 위 (칸 위쪽 가운데). 같은 크기면 칸의 왼쪽 위다
		var left_top: Vector2i = Vector2i(index % columns, index / columns) * pitch + Vector2i((cell.x - image.get_width()) / 2, 0)
		if numbers:
			# 번호표: 숫자 둘레로 글꼴 한 칸씩 띄운 바탕. 띠 아래 끝까지 칠해서 그림에 붙인다
			sheet.fill_rect(Rect2i(left_top, Vector2i(_number_width(index + 1, scale) + 2 * scale, band)), BADGE_COLOR)
			_draw_number(sheet, index + 1, left_top + Vector2i.ONE * scale, scale)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), left_top + Vector2i(0, band))
	var error: int = sheet.save_png(out)
	print("저장: %s (%s), %d장, %d×%d" % [out, error_string(error), paths.size(), sheet.get_width(), sheet.get_height()])
	if error == OK and not labels.is_empty():
		error = _write_legend(out, labels)
	quit(0 if error == OK else 1)


## 범례 파일의 줄들. 앞뒤 공백(Windows 줄바꿈의 \r 포함)을 떼고, 빈 줄과 #로 시작하는 줄은 뺀다.
func _read_labels(path: String) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var label: String = line.strip_edges()
		if not label.is_empty() and not label.begins_with("#"):
			labels.append(label)
	return labels


## 범례를 <out 이름>_legend.txt로 저장하고 같은 줄을 출력한다.
func _write_legend(out: String, labels: PackedStringArray) -> int:
	var path: String = out.get_basename() + LEGEND_SUFFIX
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var error: int = FileAccess.get_open_error()
		printerr("범례 저장 실패 (%s): %s" % [error_string(error), path])
		return error
	for i: int in labels.size():
		var line: String = "%d: %s" % [i + 1, labels[i]]
		file.store_line(line)
		print(line)
	file.close()
	print("범례: %s" % path)
	return OK


## 숫자를 그렸을 때의 가로 픽셀 수 (글자 사이 한 칸 포함)
func _number_width(number: int, scale: int) -> int:
	return (str(number).length() * (DIGIT_SIZE.x + 1) - 1) * scale


## 숫자를 그린다. at은 첫 글자의 왼쪽 위, scale은 글꼴 한 칸의 픽셀 수다. 글자 사이는 한 칸 띄운다.
func _draw_number(image: Image, number: int, at: Vector2i, scale: int) -> void:
	var text: String = str(number)
	for i: int in text.length():
		var pixels: String = DIGIT_PIXELS[text[i].to_int()]
		var left: int = at.x + i * (DIGIT_SIZE.x + 1) * scale
		for y: int in DIGIT_SIZE.y:
			for x: int in DIGIT_SIZE.x:
				if pixels[y * DIGIT_SIZE.x + x] == "1":
					image.fill_rect(Rect2i(left + x * scale, at.y + y * scale, scale, scale), DIGIT_COLOR)
