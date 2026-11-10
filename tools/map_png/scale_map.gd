extends SceneTree
## 맵 배치 PNG를 정수 배로 키운다 (굴·바위·통로는 길이와 폭 모두 배수만큼, 좁은 길목만 원래 폭으로). 색 규칙은 docs/maps/map_png_rules.md.
## - 칸마다 factor×factor 덩어리로 키운다. 굴·바위·벽·통로는 그대로 커진다 (통로 폭도 배수만큼, 사용자 결정 2026-11-08)
## - 원래 맵에서 좁은 길목이던 통로 칸(3×3 바닥 덩어리에 들지 못하는 칸 = 폭 2칸 이하)만 원래 폭으로 되돌린다:
##   그 칸의 단면(가로·세로 중 통로 칸이 이어진 짧은 쪽)의 가운데 절반(내림) 밖이면 깎는다 (2배일 때 4칸 → 2칸)
##   - 굴에 바로 닿은 통로 칸(입구)은 깎지 않는다 (입구가 갈라지지 않게)
##   - 한 칸씩 깎되, 깎은 뒤에도 둘레 바닥이 모두 2×2 바닥 덩어리에 들 때만 깎는다 (1칸 길·끊김이 생기지 않게). 깎다가 떨어져 나간 통로 조각은 메운다
## - 물건은 덩어리의 왼쪽 위 한 칸에 둔다. 붙어 있는 박쥐(한 무리)는 무리 안의 상대 위치를 그대로 두어 키운 뒤에도 붙어 있게 한다
## 결과 PNG는 변환(tools/map_from_png.gd)으로 확인한다: 2칸보다 좁은 바닥, 굴마다 입구 수·연결.
##
## 실행: bash tools/godot.sh --headless --path . -s tools/map_png/scale_map.gd -- --in=res://art_src/maps/shallow_cave.png --out=<결과 PNG> --factor=2

const DEFAULT_FACTOR: int = 2
## 단면을 재는 방향. 대각선까지 넣으면 이웃한 칸끼리 다른 방향을 골라 통로가 들쭉날쭉하게 깎여서 가로·세로만 쓴다
const SECTION_DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
const NEIGHBORS_4: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const NEIGHBORS_8: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
## 칸 글자 → PNG 색 (MapLayout.LEGEND의 반대)
const CHAR_COLORS: Dictionary = {"#": "181425", "x": "68386c", ".": "3a4466", "1": "265c42", "2": "733e39", "b": "124e89"}

var _size: Vector2i
var _chars: Array[PackedStringArray] = []
## 원래 맵에서 좁은 길목이던 통로 칸 (원래 칸 좌표)
var _original_narrow: Dictionary = {}
var _factor: int = 1


func _initialize() -> void:
	var args: Dictionary = {"in": "res://art_src/maps/shallow_cave.png", "out": "", "factor": str(DEFAULT_FACTOR)}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	if args.out.is_empty():
		printerr("문제: --out=<결과 PNG>가 필요함")
		quit(1)
		return
	var layout: MapLayout = MapLayout.from_file(args.in)
	if not layout.errors.is_empty():
		printerr("문제: ", layout.errors)
		quit(1)
		return
	var factor: int = int(args.factor)
	_factor = factor
	_find_original_narrow(layout)
	_scale(layout, factor)
	var result: Vector2i = _thin_corridors()
	var stubs: int = _fill_stubs()
	var image: Image = _to_image(_place_objects(layout, factor))
	image.save_png(ProjectSettings.globalize_path(args.out))
	print("키움: %s → %s칸 (%d배), 통로 바깥쪽 깎음 %d칸 (깎으면 1칸 길이 생겨 남긴 칸 %d), 떨어져 나간 통로 조각 메움 %d칸. 저장: %s" % [layout.size, _size, factor, result.x, result.y, stubs, args.out])
	quit()


func _scale(layout: MapLayout, factor: int) -> void:
	_size = layout.size * factor
	for y: int in _size.y:
		var line: PackedStringArray = PackedStringArray()
		for x: int in _size.x:
			line.append(layout.rows[y / factor][x / factor])
		_chars.append(line)


func _char_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= _size.x or cell.y >= _size.y:
		return "#"
	return _chars[cell.y][cell.x]


func _is_wall(cell: Vector2i) -> bool:
	return MapLayout.WALL_CHARS.contains(_char_at(cell))


## 통로 바깥쪽을 깎는다. (깎은 칸 수, 깎으면 1칸 길이 생겨 남긴 칸 수)
## 칸마다 그 자리의 단면(가로·세로·두 대각선 중 벽에서 벽까지 가장 짧은 줄, 대각선은 √2배로 잼)을 찾고, 단면의 가운데 절반 밖이면 깎는다.
## 2배로 키운 통로는 단면이 원래 폭의 2배라, 가운데 절반을 남기면 원래 폭이 된다 (2칸 길목 → 4칸 → 2칸).
func _thin_corridors() -> Vector2i:
	var candidates: Array[Vector2i] = []
	for y: int in _size.y:
		for x: int in _size.x:
			var cell: Vector2i = Vector2i(x, y)
			if _char_at(cell) != ".":
				continue
			var touches_room: bool = false
			for offset: Vector2i in NEIGHBORS_4:
				touches_room = touches_room or MapLayout.ROOM_CHARS.contains(_char_at(cell + offset))
			if touches_room or not _original_narrow.has(cell / _factor):
				continue
			var section: Vector2i = _cross_section(cell)
			# section.x: 단면의 칸 수, section.y: 이 칸이 단면에서 몇 번째인지 (1부터)
			# 내림이라 원래 폭보다 좁아지지 않는다 (단면 4 → 2, 6 → 4, 8 → 4, 12 → 6)
			var quarter: int = section.x / 4
			if section.y <= quarter or section.y > section.x - quarter:
				candidates.append(cell)
	var cut: int = 0
	var kept: int = 0
	for cell: Vector2i in candidates:
		_chars[cell.y][cell.x] = "#"
		if _neighbors_keep_blocks(cell):
			cut += 1
		else:
			_chars[cell.y][cell.x] = "."
			kept += 1
	return Vector2i(cut, kept)


## cell 둘레 3×3의 바닥 칸이 모두 2×2 바닥 덩어리에 드는지 (MapSmoother.narrow_cells와 같은 규칙)
func _neighbors_keep_blocks(cell: Vector2i) -> bool:
	for oy: int in range(-1, 2):
		for ox: int in range(-1, 2):
			var n: Vector2i = cell + Vector2i(ox, oy)
			if _is_wall(n):
				continue
			var in_block: bool = false
			for cy: int in range(-1, 1):
				for cx: int in range(-1, 1):
					var corner: Vector2i = n + Vector2i(cx, cy)
					if not _is_wall(corner) and not _is_wall(corner + Vector2i(1, 0)) and not _is_wall(corner + Vector2i(0, 1)) and not _is_wall(corner + Vector2i(1, 1)):
						in_block = true
			if not in_block:
				return false
	return true


## 물건마다 키운 맵의 칸. 붙어 있는 박쥐는 무리 안의 상대 위치를 그대로 둔다.
func _place_objects(layout: MapLayout, factor: int) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	var bats: Array[Vector2i] = layout.cells_of("bat")
	var anchor_of: Dictionary = {}
	for bat: Vector2i in bats:
		if anchor_of.has(bat):
			continue
		var pack: Array[Vector2i] = [bat]
		var head: int = 0
		while head < pack.size():
			for offset: Vector2i in NEIGHBORS_8:
				var n: Vector2i = pack[head] + offset
				if bats.has(n) and not pack.has(n):
					pack.append(n)
			head += 1
		var anchor: Vector2i = pack[0]
		for cell: Vector2i in pack:
			anchor = Vector2i(mini(anchor.x, cell.x), mini(anchor.y, cell.y))
		for cell: Vector2i in pack:
			anchor_of[cell] = anchor
	for o: Dictionary in layout.objects:
		var cell: Vector2i = o.cell * factor
		if o.object == "bat":
			cell = anchor_of[o.cell] * factor + (o.cell - anchor_of[o.cell])
		placed.append({"object": o.object, "cell": cell})
	return placed


func _to_image(objects: Array[Dictionary]) -> Image:
	var image: Image = Image.create(_size.x, _size.y, false, Image.FORMAT_RGBA8)
	for y: int in _size.y:
		for x: int in _size.x:
			image.set_pixel(x, y, Color.html(CHAR_COLORS[_chars[y][x]]))
	var object_colors: Dictionary = {}
	for hex: String in MapLayout.LEGEND:
		if MapLayout.LEGEND[hex].kind == MapLayout.Kind.OBJECT:
			object_colors[MapLayout.LEGEND[hex].object] = hex
	for o: Dictionary in objects:
		image.set_pixel(o.cell.x, o.cell.y, Color.html(object_colors[o.object]))
	return image


## cell을 지나는 단면: 가로·세로·두 대각선 중, 통로 칸만 이어진 줄(굴이나 벽에서 끊김)이 가장 짧은 방향 (대각선은 칸 수에 √2를 곱해 비교).
## (줄의 칸 수, cell이 줄의 한쪽 끝에서 몇 번째인지)
func _cross_section(cell: Vector2i) -> Vector2i:
	var best: Vector2i = Vector2i(1 << 20, 1)
	var best_length: float = INF
	for direction: Vector2i in SECTION_DIRECTIONS:
		var before: int = 0
		var backward: Vector2i = cell - direction
		while _char_at(backward) == ".":
			before += 1
			backward -= direction
		var after: int = 0
		var forward: Vector2i = cell + direction
		while _char_at(forward) == ".":
			after += 1
			forward += direction
		var run: int = before + after + 1
		var length: float = run * Vector2(direction).length()
		if length < best_length:
			best_length = length
			best = Vector2i(run, before + 1)
	return best


## 깎다가 떨어져 나간 통로 조각(굴 둘 이상과 이어지지 않은 통로 덩어리)을 벽으로 메운다. 메운 칸 수
func _fill_stubs() -> int:
	var seen: Dictionary = {}
	var filled: int = 0
	for y: int in _size.y:
		for x: int in _size.x:
			var start: Vector2i = Vector2i(x, y)
			if _char_at(start) != "." or seen.has(start):
				continue
			var piece: Array[Vector2i] = [start]
			seen[start] = true
			var rooms: Dictionary = {}
			var head: int = 0
			while head < piece.size():
				var cell: Vector2i = piece[head]
				head += 1
				for offset: Vector2i in NEIGHBORS_4:
					var n: Vector2i = cell + offset
					var c: String = _char_at(n)
					if c == "." and not seen.has(n):
						seen[n] = true
						piece.append(n)
					elif MapLayout.ROOM_CHARS.contains(c):
						rooms[_room_mark(n)] = true
			if rooms.size() < 2:
				for cell: Vector2i in piece:
					_chars[cell.y][cell.x] = "#"
				filled += piece.size()
	return filled


## 굴 칸이 든 굴을 가리키는 표시: 그 굴에서 가장 위·왼쪽 칸 (같은 굴이면 같다)
var _room_marks: Dictionary = {}


func _room_mark(cell: Vector2i) -> Vector2i:
	if _room_marks.has(cell):
		return _room_marks[cell]
	var c: String = _char_at(cell)
	var room: Array[Vector2i] = [cell]
	var seen: Dictionary = {cell: true}
	var head: int = 0
	var mark: Vector2i = cell
	while head < room.size():
		var current: Vector2i = room[head]
		head += 1
		if current.y < mark.y or (current.y == mark.y and current.x < mark.x):
			mark = current
		for offset: Vector2i in NEIGHBORS_4:
			var n: Vector2i = current + offset
			if not seen.has(n) and _char_at(n) == c:
				seen[n] = true
				room.append(n)
	for member: Vector2i in room:
		_room_marks[member] = mark
	return mark


## 원래 맵에서 3×3 바닥 덩어리에 들지 못하는 통로 칸 (폭 2칸 이하인 좁은 길목)
func _find_original_narrow(layout: MapLayout) -> void:
	for y: int in layout.size.y:
		for x: int in layout.size.x:
			var cell: Vector2i = Vector2i(x, y)
			if layout.get_char(cell) != ".":
				continue
			var in_block: bool = false
			for cy: int in range(-2, 1):
				for cx: int in range(-2, 1):
					var all_floor: bool = true
					for by: int in 3:
						for bx: int in 3:
							all_floor = all_floor and not layout.is_wall(cell + Vector2i(cx + bx, cy + by))
					in_block = in_block or all_floor
			if not in_block:
				_original_narrow[cell] = true
