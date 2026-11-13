extends TestCase
## 코드·씬·데이터(.gd, .tscn, .tres)에 적힌 색이 팔레트(assets/palette/*.hex) 안의 색인지 검사한다.
## 그림이 생기기 전의 임시 도형 색도 팔레트에서 가져온다는 아트 규칙(docs/art-direction.md)을 지키는지 본다.
## 에셋 PNG는 tools/check_palette.gd가 검사한다.
##
## 찾는 모양: Color(r, g, b[, a]) 숫자 값, Color.WHITE 같은 이름 있는 색, Color("…") 문자열.
## - 성분이 1보다 큰 값(피격 번쩍임 modulate 같은 밝기 배율)은 색이 아니라서 넘어간다
## - 완전히 투명한 색(알파 0)은 넘어간다. 그 밖에는 RGB만 비교한다

const PALETTE_DIR: String = "res://assets/palette"
const SEARCH_ROOT: String = "res://"
## 검사하지 않는 폴더 이름 (Godot 캐시, git, Claude 설정과 그 안의 worktree 사본, 에셋 원본, 플러그인).
## Windows에서는 점으로 시작하는 폴더도 목록에 나오므로 적어 둔다.
const SKIP_DIRS: PackedStringArray = [".godot", ".git", ".claude", "art_src", "addons"]
## 검사하지 않는 폴더 (경로가 똑같을 때만): 비교판 작업 폴더. 안마다 쓴 setup과 코드 안의 worktree 사본이 있다 (tools/compare_variants.sh).
## .gdignore가 있는 폴더를 모두 넘기지 않고 경로로 적는다 (게임 폴더에 .gdignore가 잘못 생겨도 그 폴더는 검사하게).
const SKIP_PATHS: PackedStringArray = ["res://compare"]
const EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]

var _palette: Dictionary[String, bool] = {}
var _number_pattern: RegEx
var _named_pattern: RegEx
var _string_pattern: RegEx


func before_each() -> void:
	_palette = _load_palette()
	_number_pattern = RegEx.create_from_string("Color\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*(?:,\\s*([0-9.]+)\\s*)?\\)")
	_named_pattern = RegEx.create_from_string("Color\\.([A-Z][A-Z_]+)\\b")
	_string_pattern = RegEx.create_from_string("Color\\(\\s*\"([^\"]+)\"\\s*\\)")


func _load_palette() -> Dictionary[String, bool]:
	var colors: Dictionary[String, bool] = {}
	for file_name: String in DirAccess.get_files_at(PALETTE_DIR):
		if file_name.get_extension() != "hex":
			continue
		for line: String in FileAccess.get_file_as_string(PALETTE_DIR.path_join(file_name)).split("\n"):
			var hex: String = line.strip_edges().to_lower()
			if not hex.is_empty():
				colors[hex] = true
	return colors


func _collect_files(dir: String, result: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		var path: String = dir.path_join(sub)
		if not SKIP_DIRS.has(sub) and not SKIP_PATHS.has(path):
			_collect_files(path, result)
	for file_name: String in DirAccess.get_files_at(dir):
		if EXTENSIONS.has(file_name.get_extension()):
			result.append(dir.path_join(file_name))


## 한 줄에서 찾은 색들. 검사하지 않는 값(밝기 배율, 투명)은 빼고 돌려준다.
func _colors_in_line(line: String) -> Array[Color]:
	var colors: Array[Color] = []
	for match: RegExMatch in _number_pattern.search_all(line):
		var alpha: float = float(match.get_string(4)) if not match.get_string(4).is_empty() else 1.0
		colors.append(Color(float(match.get_string(1)), float(match.get_string(2)), float(match.get_string(3)), alpha))
	for match: RegExMatch in _named_pattern.search_all(line):
		# 이름 있는 색이 아니면(Color.from_string이 실패하면) 넘어간다.
		var named: Color = Color.from_string(match.get_string(1).to_lower(), Color(-1, -1, -1))
		if named.r >= 0.0:
			colors.append(named)
	for match: RegExMatch in _string_pattern.search_all(line):
		colors.append(Color.from_string(match.get_string(1), Color(-1, -1, -1)))
	return colors.filter(func(color: Color) -> bool:
		return color.a > 0.0 and color.r >= 0.0 and maxf(color.r, maxf(color.g, color.b)) <= 1.0)


func test_palette_is_loaded() -> void:
	assert_true(_palette.size() > 0, "%s에서 팔레트를 읽었다 (%d색)" % [PALETTE_DIR, _palette.size()])


func test_code_colors_are_in_palette() -> void:
	var files: PackedStringArray = []
	_collect_files(SEARCH_ROOT, files)
	var checked: int = 0
	var outside: PackedStringArray = []
	for path: String in files:
		# 이 파일은 "잡아내는지" 확인하려고 팔레트 밖의 색을 일부러 적어 두었다.
		if path == get_script().resource_path:
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			for color: Color in _colors_in_line(lines[i]):
				checked += 1
				var hex: String = color.to_html(false).to_lower()
				if not _palette.has(hex):
					outside.append("%s:%d %s" % [path, i + 1, hex])
	assert_true(checked > 0, "검사한 색이 있다 (%d개)" % checked)
	assert_true(outside.is_empty(), "팔레트 밖의 색: %s" % ", ".join(outside))


func test_detects_outside_color() -> void:
	# 검사가 실제로 잡아내는지: 팔레트에 없는 순수 빨강(ff0000)과 이름 있는 색 BLACK(000000).
	var found: Array[String] = []
	for color: Color in _colors_in_line("var a := Color(1, 0, 0, 1) ; var b := Color.BLACK ; var c := Color(3, 3, 3)"):
		found.append(color.to_html(false).to_lower())
	assert_eq(found, ["ff0000", "000000"] as Array[String], "숫자·이름 있는 색은 찾고, 밝기 배율(3,3,3)은 넘어간다")
	assert_false(_palette.has("ff0000"))
	assert_false(_palette.has("000000"))
