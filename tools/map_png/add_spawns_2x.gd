extends SceneTree
## 2배로 키운 얕은 굴 PNG에 몬스터·상자를 더한다 (몬스터 21 → 42, 상자 6 → 12. docs/maps/shallow_cave_design.md 6-6).
## 굴마다 더할 수(ROOMS)만 적고, 칸은 스크립트가 고른다: 굴 안의 5×5가 트인 칸 중, 굴의 입구와 이미 있는 물건에서 가장 먼 칸을 하나씩 고른다 (같은 PNG면 결과가 늘 같다).
## 한 번만 쓴다: 이미 더한 PNG(쥐가 RATS_BEFORE마리가 아님)면 아무것도 하지 않고 멈춘다.
##
## 실행: bash tools/godot.sh --headless --path . -s tools/map_png/add_spawns_2x.gd
## 그다음 씬을 다시 만든다: bash tools/godot.sh --headless --path . -s tools/map_from_png.gd

const MAP_PNG: String = "res://art_src/maps/shallow_cave.png"
const RATS_BEFORE: int = 10
## 굴의 가운데 칸(변환 출력의 굴 목록) → 더할 물건. 박쥐는 붙은 3칸이 한 무리다
const ROOMS: Array[Dictionary] = [
	{"name": "쥐 둥지", "center": Vector2i(125, 61), "add": {"rat": 2}},
	{"name": "물웅덩이 굴", "center": Vector2i(119, 185), "add": {"rat": 2}},
	{"name": "갈림 굴", "center": Vector2i(201, 124), "add": {"rat": 2}},
	{"name": "버섯 굴", "center": Vector2i(40, 44), "add": {"rat": 3, "chest": 1}},
	{"name": "쥐 둥지와 물웅덩이 사이 작은 굴", "center": Vector2i(129, 125), "add": {"rat": 1}},
	{"name": "빛 드는 굴", "center": Vector2i(422, 51), "add": {"boar": 1}},
	{"name": "동굴 입구", "center": Vector2i(428, 149), "add": {"boar": 1}},
	{"name": "진흙 굴", "center": Vector2i(418, 205), "add": {"boar": 2, "chest": 1}},
	{"name": "박쥐 아래 굴", "center": Vector2i(258, 105), "add": {"bat_pack": 1, "chest": 1}},
	{"name": "알 굴", "center": Vector2i(345, 168), "add": {"spider": 2}},
	{"name": "거미 입구", "center": Vector2i(248, 168), "add": {"spider": 1}},
	{"name": "거미줄 굴", "center": Vector2i(296, 201), "add": {"spider": 1}},
	{"name": "무너진 굴", "center": Vector2i(112, 18), "add": {"chest": 1}},
	{"name": "합류 곁굴", "center": Vector2i(342, 52), "add": {"chest": 1}},
	{"name": "거미 샛굴", "center": Vector2i(296, 165), "add": {"chest": 1}},
]
const NEIGHBORS_4: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
## 고른 칸 둘레로 이만큼(칸) 안이 모두 바닥이어야 한다 (5×5)
const OPEN_RADIUS: int = 2

var _layout: MapLayout
var _image: Image
var _taken: Array[Vector2i] = []


func _initialize() -> void:
	_image = Image.load_from_file(ProjectSettings.globalize_path(MAP_PNG))
	_layout = MapLayout.from_image(_image)
	if not _layout.errors.is_empty() or _layout.cells_of("rat").size() != RATS_BEFORE:
		printerr("문제: PNG를 읽지 못했거나 이미 더한 PNG임 (쥐 %d마리, 오류 %s)" % [_layout.cells_of("rat").size(), _layout.errors])
		quit(1)
		return
	for o: Dictionary in _layout.objects:
		_taken.append(o.cell)
	for entry: Dictionary in ROOMS:
		var room: int = _layout.room_at(entry.center)
		if room < 0:
			printerr("문제: 가운데 칸 %s가 굴이 아님 (%s)" % [entry.center, entry.name])
			quit(1)
			return
		for object: String in entry.add:
			for i: int in entry.add[object]:
				if not _place(room, object):
					printerr("문제: %s에 %s 놓을 자리 없음" % [entry.name, object])
					quit(1)
					return
	_image.save_png(ProjectSettings.globalize_path(MAP_PNG))
	print("저장: %s (물건 %d개)" % [MAP_PNG, _taken.size()])
	quit(0)


func _place(room: int, object: String) -> bool:
	var obstacles: Array[Vector2i] = _entrances(room)
	for cell: Vector2i in _taken:
		if _layout.room_at(cell) == room:
			obstacles.append(cell)
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -1.0
	for y: int in _layout.size.y:
		for x: int in _layout.size.x:
			var cell: Vector2i = Vector2i(x, y)
			if _layout.room_at(cell) != room or not _is_open(cell):
				continue
			var score: float = INF
			for other: Vector2i in obstacles:
				score = minf(score, Vector2(cell).distance_to(Vector2(other)))
			if score > best_score:
				best_score = score
				best = cell
	if best.x < 0:
		return false
	if object == "bat_pack":
		for cell: Vector2i in [best, best + Vector2i.RIGHT, best + Vector2i.DOWN]:
			_put(cell, "bat")
	else:
		_put(best, object)
	return true


func _put(cell: Vector2i, object: String) -> void:
	for hex: String in MapLayout.LEGEND:
		if MapLayout.LEGEND[hex].get("object", "") == object:
			_image.set_pixelv(cell, Color.html(hex))
	_taken.append(cell)
	print("%s: 칸 %s" % [object, cell])


func _is_open(cell: Vector2i) -> bool:
	for y: int in range(-OPEN_RADIUS, OPEN_RADIUS + 1):
		for x: int in range(-OPEN_RADIUS, OPEN_RADIUS + 1):
			var other: Vector2i = cell + Vector2i(x, y)
			if _layout.is_wall(other) or _taken.has(other):
				return false
	return true


## 굴 칸 중 다른 바닥(통로·다른 굴)과 맞닿은 칸
func _entrances(room: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in _layout.size.y:
		for x: int in _layout.size.x:
			var cell: Vector2i = Vector2i(x, y)
			if _layout.room_at(cell) != room:
				continue
			for offset: Vector2i in NEIGHBORS_4:
				var other: Vector2i = cell + offset
				if not _layout.is_wall(other) and _layout.room_at(other) != room:
					result.append(cell)
					break
	return result
