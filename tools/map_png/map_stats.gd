extends SceneTree
## 맵 배치 PNG의 바닥 통계를 출력한다 (docs/maps/map_png_rules.md의 "굴과 통로" 기준을 확인할 때).
## - 바닥 중 굴과 통로의 칸 수·비율. PNG 그대로와, 변환할 때처럼 벽 가장자리를 다듬은 뒤(MapSmoother, 기본 씨앗) 둘 다
## - 통로 덩어리마다: 칸 수, 이어 주는 굴, 가장 넓은 곳의 폭, 길목(3×3 바닥에 들지 못하는 칸 = 폭 2칸 이하) 칸 수
##   폭은 그 자리에 들어가는 가장 큰 원의 지름이다 (가장 가까운 벽 칸까지 거리 × 2). 굴에서 2칸 안의 칸은 굴 쪽으로 넓어 보이므로 뺀다.
##
## 실행 (기본값은 얕은 굴):
##   bash tools/godot.sh --headless --path . -s tools/map_png/map_stats.gd
##   bash tools/godot.sh --headless --path . -s tools/map_png/map_stats.gd -- --in=res://art_src/maps/<맵>.png

const DEFAULT_IN: String = "res://art_src/maps/shallow_cave.png"
## 폭을 잴 때 벽을 찾는 거리 (칸)
const WIDTH_SEARCH: int = 8
## 굴에서 이 거리(칸) 안의 통로 칸은 폭을 재지 않는다
const ROOM_MARGIN: float = 2.0


func _initialize() -> void:
	var path: String = DEFAULT_IN
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--in="):
			path = arg.trim_prefix("--in=")
	var layout: MapLayout = MapLayout.from_file(path)
	if not layout.errors.is_empty():
		printerr("문제: ", layout.errors)
		quit(1)
		return
	print("PNG: ", path)
	print("바닥 (PNG 그대로): ", _ratio(layout))
	var smoothed: MapLayout = MapLayout.from_rows(MapSmoother.smooth(layout, MapSmoother.DEFAULT_SEED), layout.objects)
	print("바닥 (다듬은 뒤): ", _ratio(smoothed))
	for line: String in _passages(layout):
		print(line)
	quit()


func _ratio(layout: MapLayout) -> String:
	var room_cells: int = 0
	var passage_cells: int = 0
	for y: int in layout.size.y:
		for x: int in layout.size.x:
			var c: String = layout.rows[y][x]
			if MapLayout.ROOM_CHARS.contains(c):
				room_cells += 1
			elif c == ".":
				passage_cells += 1
	var total: int = room_cells + passage_cells
	return "%d칸 중 굴 %d칸 (%.0f%%), 통로 %d칸 (%.0f%%)" % [total, room_cells, 100.0 * room_cells / total, passage_cells, 100.0 * passage_cells / total]


func _passages(layout: MapLayout) -> PackedStringArray:
	var groups: Dictionary = {}
	for y: int in layout.size.y:
		for x: int in layout.size.x:
			var cell: Vector2i = Vector2i(x, y)
			var segment: String = layout.segment_at(cell)
			if segment.begins_with("p"):
				if not groups.has(segment):
					groups[segment] = []
				groups[segment].append(cell)
	var lines: PackedStringArray = []
	for segment: String in groups:
		var cells: Array = groups[segment]
		var touched: Dictionary = {}
		var widest: float = 0.0
		var choke: int = 0
		for cell: Vector2i in cells:
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var room: int = layout.room_at(cell + offset)
				if room >= 0:
					touched[room] = true
			if not _in_floor_block(layout, cell, 3):
				choke += 1
			if _room_distance(layout, cell) >= ROOM_MARGIN:
				widest = maxf(widest, _wall_distance(layout, cell) * 2.0)
		var rooms: Array = touched.keys()
		rooms.sort()
		lines.append("통로 %s: %d칸, 굴 %s를 이음, 가장 넓은 곳 %.1f칸, 길목(폭 2칸 이하) %d칸" % [segment, cells.size(), rooms, widest, choke])
	return lines


## 칸 가운데에서 가장 가까운 벽 칸(정사각형)까지 거리
func _wall_distance(layout: MapLayout, cell: Vector2i) -> float:
	var best: float = WIDTH_SEARCH
	for oy: int in range(-WIDTH_SEARCH, WIDTH_SEARCH + 1):
		for ox: int in range(-WIDTH_SEARCH, WIDTH_SEARCH + 1):
			if layout.is_wall(cell + Vector2i(ox, oy)):
				best = minf(best, Vector2(maxf(absf(ox) - 0.5, 0.0), maxf(absf(oy) - 0.5, 0.0)).length())
	return best


func _room_distance(layout: MapLayout, cell: Vector2i) -> float:
	var reach: int = ceili(ROOM_MARGIN)
	var best: float = INF
	for oy: int in range(-reach, reach + 1):
		for ox: int in range(-reach, reach + 1):
			if layout.room_at(cell + Vector2i(ox, oy)) >= 0:
				best = minf(best, Vector2(ox, oy).length())
	return best


func _in_floor_block(layout: MapLayout, cell: Vector2i, block: int) -> bool:
	for oy: int in block:
		for ox: int in block:
			var corner: Vector2i = cell - Vector2i(ox, oy)
			var all_floor: bool = true
			for by: int in block:
				for bx: int in block:
					if layout.is_wall(corner + Vector2i(bx, by)):
						all_floor = false
			if all_floor:
				return true
	return false
