extends SceneTree
## 맵 PNG → 동굴 벽 윤곽 파일. 지금은 화면(3D 층)에서만 쓴다. 지역 씬과 map_from_png.gd는 건드리지 않는다.
## 출력: 걸린 시간, 윤곽선 수, 바위가 PNG 바닥을 덮는 가장 깊은 곳, 좁은 바닥마다 지나갈 수 있는 폭.
##
## 실행 (기본값은 얕은 굴): bash tools/godot.sh --headless --path . -s tools/map_png/make_cave_outline.gd
## 다른 맵: -- --in=res://art_src/maps/<맵>.png --out=res://regions/<맵>_outline.res --settings=res://data/terrain/<값>.tres

const DEFAULT_IN: String = "res://art_src/maps/shallow_cave.png"
const DEFAULT_OUT: String = "res://regions/shallow_cave_outline.res"
const DEFAULT_SETTINGS: String = "res://data/terrain/shallow_cave_outline_settings.tres"
## 폭이 좁은 순서로 몇 곳까지 출력할지
const REPORT_TAIL: int = 12


func _initialize() -> void:
	var args: Dictionary = {"in": DEFAULT_IN, "out": DEFAULT_OUT, "settings": DEFAULT_SETTINGS}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var layout: MapLayout = MapLayout.from_file(args.in)
	if not layout.errors.is_empty():
		for error: String in layout.errors:
			printerr("문제: ", error)
		quit(1)
		return
	var started: int = Time.get_ticks_msec()
	var outline: CaveOutline = CaveOutline.new(layout.rows, load(args.settings))
	var data: CaveOutlineData = outline.build()
	print("윤곽 계산: %dms, 격자 점 %s, 윤곽선 %d개, 윤곽선 점 %d개" % [Time.get_ticks_msec() - started, data.nodes(), data.loops.size(), _points(data)])
	var states: Array[int] = [0, 0, 0]
	for state: int in data.cell_states:
		states[state] += 1
	print("칸: 바닥뿐 %d, 윤곽이 지남 %d, 바위뿐 %d" % states)
	var error: int = ResourceSaver.save(data, args.out, ResourceSaver.FLAG_COMPRESS)
	print("저장: %s (%s), 파일 %d KB" % [args.out, error_string(error), FileAccess.get_file_as_bytes(args.out).size() / 1024])
	print("바위가 PNG 바닥을 덮는 가장 깊은 곳: 맵 전체 %.1fpx, 좁은 길목 보호 구역 안 %.1fpx" % [outline.deepest_cover_px(), outline.deepest_cover_px(true)])
	var chokes: Array[Dictionary] = outline.choke_widths()
	chokes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.width < b.width)
	print("양쪽 끝이 있는 좁은 바닥 %d곳. 지나갈 수 있는 폭이 좁은 순서:" % chokes.size())
	for entry: Dictionary in chokes.slice(0, REPORT_TAIL):
		print("  칸 %s: %.0fpx" % [entry.cell, entry.width])
	quit(0 if error == OK else 1)


func _points(data: CaveOutlineData) -> int:
	var total: int = 0
	for line: PackedVector2Array in data.loops:
		total += line.size()
	return total
