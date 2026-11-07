class_name MapLayout
extends RefCounted
## 맵 배치 PNG(픽셀 하나 = 타일 한 칸)를 읽어 칸 종류·물건 위치·굴 연결을 정리한다. 색 규칙은 docs/maps/map_png_rules.md.
## 노드에 의존하지 않는다. tools/map_from_png.gd(지역 씬 만들기)와 테스트가 같이 쓴다.
## - 칸 종류는 한 글자다: 벽 "#", 막아 둔 길목 "x"(벽), 통로 ".", 1등급 굴 "1", 2등급 굴 "2", 거점 동굴 "b"
## - 물건(몬스터·상자·탈출 지점·도착 지점) 픽셀의 칸은 바닥이다. 그 칸의 바닥 종류는 이웃 바닥 칸 중 가장 많은 종류다
## - 투명한 픽셀은 벽이다 (Aseprite에서 지운 곳)
## - 굴은 굴 바닥("1", "2", "b") 칸이 이어진 덩어리, 통로는 통로 칸이 이어진 덩어리다
## - 굴의 입구 수는 굴 테두리 바로 바깥의 뚫린 칸(통로·다른 종류의 굴)이 붙어 있는 덩어리 수다. 이어진 굴은 같은 통로 덩어리에 닿은 굴들이다

enum Kind { WALL, FLOOR, OBJECT }

## 색(소문자 hex) → 뜻. kind가 WALL·FLOOR면 char가 그 칸의 글자다. OBJECT면 object가 물건 이름이다.
const LEGEND: Dictionary = {
	"181425": {"kind": Kind.WALL, "char": "#", "name": "벽"},
	"68386c": {"kind": Kind.WALL, "char": "x", "name": "막아 둔 길목"},
	"3a4466": {"kind": Kind.FLOOR, "char": ".", "name": "통로"},
	"265c42": {"kind": Kind.FLOOR, "char": "1", "name": "1등급 굴"},
	"733e39": {"kind": Kind.FLOOR, "char": "2", "name": "2등급 굴"},
	"124e89": {"kind": Kind.FLOOR, "char": "b", "name": "거점 동굴"},
	"63c74d": {"kind": Kind.OBJECT, "object": "spawn", "name": "도착 지점"},
	"2ce8f5": {"kind": Kind.OBJECT, "object": "escape", "name": "탈출 지점"},
	"feae34": {"kind": Kind.OBJECT, "object": "chest", "name": "상자"},
	"c0cbdc": {"kind": Kind.OBJECT, "object": "rat", "name": "쥐"},
	"f77622": {"kind": Kind.OBJECT, "object": "boar", "name": "멧돼지"},
	"b55088": {"kind": Kind.OBJECT, "object": "bat", "name": "박쥐"},
	"e4a672": {"kind": Kind.OBJECT, "object": "goblin_slinger", "name": "고블린 투석병"},
}
## 굴 바닥 글자 (통로가 아닌 바닥)
const ROOM_CHARS: String = "12b"
const WALL_CHARS: String = "#x"
## 물건 칸의 바닥 종류를 정할 이웃이 없을 때
const DEFAULT_FLOOR: String = "."

var size: Vector2i
## 줄마다 칸 글자
var rows: PackedStringArray = PackedStringArray()
## 물건들: {"object": 이름, "cell": Vector2i}
var objects: Array[Dictionary] = []
## 읽다가 생긴 문제 (모르는 색 등). 비어 있으면 문제없다.
var errors: PackedStringArray = PackedStringArray()
## 굴들: {"cells": 칸 수, "center": Vector2 (칸 좌표), "char": 바닥 글자, "neighbors": Array[int] (이어진 굴 번호), "entrances": int}
var rooms: Array[Dictionary] = []

## 칸마다 굴 번호 (굴이 아니면 -1)
var _room_of: PackedInt32Array = PackedInt32Array()


static func from_image(image: Image) -> MapLayout:
	var layout: MapLayout = MapLayout.new()
	layout._parse(image)
	layout._find_rooms()
	return layout


static func from_file(path: String) -> MapLayout:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		var failed: MapLayout = MapLayout.new()
		failed.errors.append("PNG를 읽지 못함: %s" % path)
		return failed
	return from_image(image)


func get_char(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return "#"
	return rows[cell.y][cell.x]


func is_wall(cell: Vector2i) -> bool:
	return WALL_CHARS.contains(get_char(cell))


## 이름이 object인 물건들의 칸
func cells_of(object: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for o: Dictionary in objects:
		if o.object == object:
			result.append(o.cell)
	return result


## 칸이 든 굴 번호 (굴이 아니면 -1)
func room_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return -1
	return _room_of[cell.y * size.x + cell.x]


## 굴 연결에 고리(같은 굴로 돌아오는 길)가 있는지. among을 주면 그 굴들끼리만 본다.
func has_cycle(among: Array[int] = []) -> bool:
	var allowed: Array[int] = among.duplicate()
	if allowed.is_empty():
		for i: int in rooms.size():
			allowed.append(i)
	var visited: Dictionary = {}
	for start: int in allowed:
		if visited.has(start):
			continue
		# 나무(고리 없음)면 간선 수 = 꼭짓점 수 - 1이다.
		var component: Array[int] = []
		var stack: Array[int] = [start]
		visited[start] = true
		while not stack.is_empty():
			var room: int = stack.pop_back()
			component.append(room)
			for next: int in rooms[room].neighbors:
				if allowed.has(next) and not visited.has(next):
					visited[next] = true
					stack.append(next)
		var edges: int = 0
		for room: int in component:
			for next: int in rooms[room].neighbors:
				if allowed.has(next):
					edges += 1
		if edges / 2 >= component.size():
			return true
	return false


## 사람이 읽는 굴 목록 (변환할 때 출력한다)
func describe_rooms() -> PackedStringArray:
	var lines: PackedStringArray = []
	for i: int in rooms.size():
		var room: Dictionary = rooms[i]
		var contents: PackedStringArray = []
		var counts: Dictionary = {}
		for o: Dictionary in objects:
			if room_at(o.cell) == i:
				counts[o.object] = counts.get(o.object, 0) + 1
		for object: String in counts:
			contents.append("%s %d" % [_object_name(object), counts[object]])
		lines.append("굴 %d (%s, 가운데 칸 %s, %d칸): 입구 %d, 이어진 굴 %s, 안에 %s" % [
			i, LEGEND_NAME_BY_CHAR.get(room.char, room.char), room.center.round(), room.cells, room.entrances, room.neighbors, ", ".join(contents) if not contents.is_empty() else "없음"])
	return lines


const LEGEND_NAME_BY_CHAR: Dictionary = {"1": "1등급 굴", "2": "2등급 굴", "b": "거점 동굴"}


func _object_name(object: String) -> String:
	for hex: String in LEGEND:
		if LEGEND[hex].get("object", "") == object:
			return LEGEND[hex].name
	return object


func _parse(image: Image) -> void:
	size = image.get_size()
	var chars: Array[Array] = []
	var object_cells: Array[Vector2i] = []
	for y: int in size.y:
		var line: Array[String] = []
		for x: int in size.x:
			var color: Color = image.get_pixel(x, y)
			if color.a < 0.5:
				line.append("#")
				continue
			var hex: String = color.to_html(false).to_lower()
			if not LEGEND.has(hex):
				errors.append("모르는 색 %s (칸 %d, %d)" % [hex, x, y])
				line.append("#")
				continue
			var entry: Dictionary = LEGEND[hex]
			if entry.kind == Kind.OBJECT:
				objects.append({"object": entry.object, "cell": Vector2i(x, y)})
				object_cells.append(Vector2i(x, y))
				line.append("?")
			else:
				line.append(entry.char)
		chars.append(line)
	# 물건 칸의 바닥은 이웃 바닥 중 가장 많은 종류 (물건끼리 붙어 있으면 몇 번 돌려서 채운다).
	for pass_index: int in 3:
		for cell: Vector2i in object_cells:
			if chars[cell.y][cell.x] != "?":
				continue
			var counts: Dictionary = {}
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = cell + offset
				if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
					continue
				var c: String = chars[n.y][n.x]
				if c != "?" and not WALL_CHARS.contains(c):
					counts[c] = counts.get(c, 0) + 1
			if counts.is_empty():
				continue
			var best: String = counts.keys()[0]
			for c: String in counts:
				if counts[c] > counts[best]:
					best = c
			chars[cell.y][cell.x] = best
	for y: int in size.y:
		rows.append("".join(PackedStringArray(chars[y])).replace("?", DEFAULT_FLOOR))
	if cells_of("spawn").size() != 1:
		errors.append("도착 지점이 하나여야 함 (지금 %d개)" % cells_of("spawn").size())


func _find_rooms() -> void:
	_room_of.resize(size.x * size.y)
	_room_of.fill(-1)
	# 통로 덩어리 번호도 같은 방식으로 붙인다.
	var passage_of: PackedInt32Array = PackedInt32Array()
	passage_of.resize(size.x * size.y)
	passage_of.fill(-1)
	var passage_count: int = 0
	for y: int in size.y:
		for x: int in size.x:
			var c: String = rows[y][x]
			if ROOM_CHARS.contains(c) and _room_of[y * size.x + x] < 0:
				var cells: Array[Vector2i] = _flood(Vector2i(x, y), c, _room_of, rooms.size())
				var sum: Vector2 = Vector2.ZERO
				for cell: Vector2i in cells:
					sum += Vector2(cell)
				rooms.append({"cells": cells.size(), "center": sum / cells.size(), "char": c, "neighbors": [] as Array[int], "entrances": 0})
			elif c == "." and passage_of[y * size.x + x] < 0:
				_flood(Vector2i(x, y), c, passage_of, passage_count)
				passage_count += 1
	# 통로마다 닿은 굴들, 굴마다 닿은 통로·다른 굴
	var passage_rooms: Array[Dictionary] = []
	for i: int in passage_count:
		passage_rooms.append({})
	var room_entrances: Array[Dictionary] = []
	for i: int in rooms.size():
		room_entrances.append({})
	for y: int in size.y:
		for x: int in size.x:
			var room: int = _room_of[y * size.x + x]
			if room < 0:
				continue
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = Vector2i(x, y) + offset
				if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
					continue
				var passage: int = passage_of[n.y * size.x + n.x]
				if passage >= 0:
					passage_rooms[passage][room] = true
					room_entrances[room][n] = true
				var other: int = _room_of[n.y * size.x + n.x]
				if other >= 0 and other != room:
					room_entrances[room][n] = true
					_link(room, other)
	for touched: Dictionary in passage_rooms:
		var list: Array = touched.keys()
		for i: int in list.size():
			for j: int in range(i + 1, list.size()):
				_link(list[i], list[j])
	for i: int in rooms.size():
		rooms[i].entrances = _count_clusters(room_entrances[i].keys())


func _link(a: int, b: int) -> void:
	if not rooms[a].neighbors.has(b):
		rooms[a].neighbors.append(b)
	if not rooms[b].neighbors.has(a):
		rooms[b].neighbors.append(a)


## start에서 같은 글자 c로 이어진 칸들에 번호 id를 붙이고 그 칸들을 돌려준다.
func _flood(start: Vector2i, c: String, marks: PackedInt32Array, id: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start]
	marks[start.y * size.x + start.x] = id
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		cells.append(cell)
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cell + offset
			if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
				continue
			if marks[n.y * size.x + n.x] < 0 and rows[n.y][n.x] == c:
				marks[n.y * size.x + n.x] = id
				stack.append(n)
	return cells


## 칸들을 붙어 있는(대각선 포함) 덩어리로 나눈 수. 굴 테두리 바깥의 뚫린 칸들에 쓰면 입구 수다.
func _count_clusters(cells: Array) -> int:
	var seen: Dictionary = {}
	var count: int = 0
	for start: Vector2i in cells:
		if seen.has(start):
			continue
		count += 1
		var stack: Array[Vector2i] = [start]
		seen[start] = true
		while not stack.is_empty():
			var cell: Vector2i = stack.pop_back()
			for other: Vector2i in cells:
				if not seen.has(other) and absi(other.x - cell.x) <= 1 and absi(other.y - cell.y) <= 1:
					seen[other] = true
					stack.append(other)
	return count
