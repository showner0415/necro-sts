extends SceneTree
## 좁은 길목마다 세 가지 벽(맵 PNG의 칸, 실제 충돌인 씬의 칸, 화면인 윤곽선)에서 지나갈 수 있는 폭과 몸마다 지나가는지를 잰다.
## 기하 계산이다 (실제로 걷게 하지 않는다). 몸은 충돌 모양 그대로 원 또는 가로로 눕힌 캡슐이다.
##
## 실행: bash tools/godot.sh --headless --path . -s tools/map_png/measure_chokes.gd
## 다른 맵: -- --scene=res://regions/<맵>.tscn --in=res://art_src/maps/<맵>.png --outline=res://regions/<맵>_outline.res
## 어긋난 길목 둘레의 칸 그림도 보려면 -- --map=1

const DEFAULT_SCENE: String = "res://regions/shallow_cave.tscn"
const DEFAULT_IN: String = "res://art_src/maps/shallow_cave.png"
const DEFAULT_OUTLINE: String = "res://regions/shallow_cave_outline.res"
const NECROMANCER_SCENE: String = "res://necromancer/necromancer.tscn"
const MONSTERS: Array[String] = ["rat", "goblin_slinger", "bat", "boar"]
## 표본 간격 (픽셀)
const STEP: int = 1
## 폭을 찾을 때 반지름의 위쪽 끝과 찾는 횟수 (픽셀)
const RADIUS_LIMIT: float = 64.0
const SEARCH_STEPS: int = 8
const FAR: float = 1.0e12
## 가장 좁은 자리를 찾을 때 반지름에 더하는 여유 (픽셀)와 양쪽 덩어리를 넓혀 보는 칸 수 (표본)
const PINCH_MARGIN: float = 2.0
const PINCH_REACH: int = 6
## 칸 그림에서 가장 좁은 자리 둘레로 보여줄 칸 수
const MAP_MARGIN: Vector2i = Vector2i(9, 6)
## 이 폭보다 좁은 PNG 길목을 "어긋난 길목"으로 본다 (픽셀)
const OFFSET_WIDTH: float = 48.0

var _png: CaveOutline
var _scene_cells: CaveOutline
var _data: CaveOutlineData
var _uses_outline: bool = false
var _bodies: Array[Dictionary] = []


func _initialize() -> void:
	var args: Dictionary = {"scene": DEFAULT_SCENE, "in": DEFAULT_IN, "outline": DEFAULT_OUTLINE, "map": "0"}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var scene: Node = (load(args.scene) as PackedScene).instantiate()
	_data = load(args.outline)
	_png = CaveOutline.new(MapLayout.from_file(args["in"]).rows, _data.settings)
	_scene_cells = CaveOutline.new((scene.get_node("Walls") as PlaceholderWalls).layout, _data.settings)
	_uses_outline = (scene.get_node("Walls") as PlaceholderWalls).outline != null
	print("실제 충돌: ", "윤곽" if _uses_outline else "칸")
	scene.free()
	_read_bodies()
	var names: PackedStringArray = PackedStringArray()
	for body: Dictionary in _bodies:
		names.append("%s %s" % [body.name, body.label])
	print("몸: ", ", ".join(names))
	print("표: 폭은 지나갈 수 있는 원의 지름 (픽셀). 몸은 ○ 지나감, × 막힘. 순서는 PNG 칸 / 실제 충돌 / 화면")
	var seen: Dictionary = {}
	var size: Vector2i = _data.cell_count
	for y: int in size.y:
		for x: int in size.x:
			if not seen.has(Vector2i(x, y)) and _png.is_narrow_cell(x, y):
				_measure(_png._flood_narrow(Vector2i(x, y), seen), args.map == "1")
	quit(0)


func _read_bodies() -> void:
	var necromancer: Necromancer = (load(NECROMANCER_SCENE) as PackedScene).instantiate()
	_bodies.append({"name": "네크로맨서", "label": "원 지름 %.0f" % (necromancer.body_radius * 2.0), "radius": necromancer.body_radius, "reach": 0.0})
	necromancer.free()
	for id: String in MONSTERS:
		var data: MonsterData = load("res://data/monsters/%s.tres" % id)
		var half: Vector2 = data.get_placeholder_half_size()
		var capsule: bool = data.placeholder_shape == MonsterData.PlaceholderShape.ELLIPSE
		_bodies.append({"name": id, "label": ("캡슐 %.0f×%.0f" % [half.x * 2.0, half.y * 2.0]) if capsule else ("원 지름 %.0f" % (half.x * 2.0)), "radius": half.y, "reach": half.x - half.y if capsule else 0.0})


func _measure(group: Array[Vector2i], show_map: bool) -> void:
	var low: Vector2i = group[0]
	var high: Vector2i = group[0]
	var in_group: Dictionary = {}
	for cell: Vector2i in group:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
		in_group[cell] = true
	var margin: int = 3
	var window: Rect2i = Rect2i(low - Vector2i.ONE * margin, high - low + Vector2i.ONE * (margin * 2 + 1)).intersection(Rect2i(Vector2i.ZERO, _data.cell_count))
	var ends: Array[Dictionary] = _png._window_ends(window, in_group)
	if ends.size() < 2 or ends[1].size() < CaveOutline.MIN_END_CELLS:
		return
	var area: _Area = _Area.new(window, _data.cell_px, ends[0], ends[1])
	var png: Dictionary = area.measure(area.cell_solid(_png), _bodies)
	var actual: Dictionary = area.measure(area.loop_solid(_data.loops) if _uses_outline else area.cell_solid(_scene_cells), _bodies)
	var view: Dictionary = area.measure(area.loop_solid(_data.loops), _bodies)
	var marks: PackedStringArray = PackedStringArray()
	for index: int in _bodies.size():
		marks.append("%s %s/%s/%s" % [_bodies[index].name, _mark(png, index), _mark(actual, index), _mark(view, index)])
	print("칸 %s, 가장 좁은 칸 (충돌) %s (화면) %s: 폭 PNG %.0f / 충돌 %.0f / 화면 %.0f, 곁길 %s | %s" % [group[0], actual.pinch, view.pinch, png.width, actual.width, view.width, "있음" if ends.size() > 2 else "없음", " · ".join(marks)])
	if show_map and png.width < OFFSET_WIDTH:
		_print_map(actual.pinch)


func _mark(result: Dictionary, index: int) -> String:
	return "○" if result.passes[index] else "×"


## 가장 좁은 자리 둘레의 칸. 왼쪽은 PNG, 오른쪽은 실제 충돌. # 벽, . 바닥
func _print_map(center: Vector2i) -> void:
	print("  칸 (%d, %d)부터. 왼쪽 PNG, 오른쪽 실제 충돌" % [center.x - MAP_MARGIN.x, center.y - MAP_MARGIN.y])
	for y: int in range(center.y - MAP_MARGIN.y, center.y + MAP_MARGIN.y + 1):
		var left: String = ""
		var right: String = ""
		for x: int in range(center.x - MAP_MARGIN.x, center.x + MAP_MARGIN.x + 1):
			left += "#" if _png.is_wall_cell(x, y) else "."
			right += "#" if _scene_cells.is_wall_cell(x, y) else "."
		print("  %s   %s" % [left, right])


## 길목 둘레 창 하나의 표본 격자
class _Area:
	var size: Vector2i
	var origin: Vector2
	var _window: Rect2i
	var _cell_px: int
	var _from: Dictionary
	var _to: Dictionary

	func _init(window: Rect2i, cell_px: int, from: Dictionary, to: Dictionary) -> void:
		_window = window
		_cell_px = cell_px
		_from = from
		_to = to
		origin = Vector2(window.position * cell_px)
		size = window.size * cell_px / STEP

	func _point(x: int, y: int) -> Vector2:
		return origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * STEP

	func _cell(index: int) -> Vector2i:
		return Vector2i(_point(index % size.x, index / size.x) / _cell_px)

	func cell_solid(cells: CaveOutline) -> PackedByteArray:
		var solid: PackedByteArray = PackedByteArray()
		solid.resize(size.x * size.y)
		for index: int in solid.size():
			var cell: Vector2i = _cell(index)
			solid[index] = 1 if cells.is_wall_cell(cell.x, cell.y) else 0
		return solid

	## 윤곽선은 닫혀 있고 맵 밖은 바위다: 왼쪽에서 선을 홀수 번 넘으면 바닥이다.
	func loop_solid(loops: Array[PackedVector2Array]) -> PackedByteArray:
		var solid: PackedByteArray = PackedByteArray()
		solid.resize(size.x * size.y)
		solid.fill(1)
		for y: int in size.y:
			var line: float = _point(0, y).y
			var crossings: Array[float] = []
			for loop: PackedVector2Array in loops:
				for index: int in loop.size():
					var a: Vector2 = loop[index]
					var b: Vector2 = loop[(index + 1) % loop.size()]
					if (a.y <= line) != (b.y <= line):
						crossings.append(a.x + (line - a.y) / (b.y - a.y) * (b.x - a.x))
			crossings.sort()
			for pair: int in range(0, crossings.size() - 1, 2):
				var start: int = maxi(ceili((crossings[pair] - origin.x) / STEP - 0.5), 0)
				var end: int = mini(floori((crossings[pair + 1] - origin.x) / STEP - 0.5), size.x - 1)
				for x: int in range(start, end + 1):
					solid[y * size.x + x] = 0
		return solid

	## 벽까지의 거리 (픽셀, 정확한 제곱 거리 변환). 창 밖은 모른다고 본다.
	func _distances(solid: PackedByteArray) -> PackedFloat32Array:
		var squared: PackedFloat32Array = PackedFloat32Array()
		squared.resize(solid.size())
		for index: int in solid.size():
			squared[index] = 0.0 if solid[index] == 1 else FAR
		for x: int in size.x:
			_transform(squared, x, size.x, size.y)
		for y: int in size.y:
			_transform(squared, y * size.x, 1, size.x)
		var result: PackedFloat32Array = PackedFloat32Array()
		result.resize(solid.size())
		for index: int in solid.size():
			# 표본 가운데에서 잰 거리라서 벽 표본의 반 칸만큼 뺀다.
			result[index] = maxf(sqrt(squared[index]) * STEP - STEP * 0.5, 0.0)
		return result

	## 한 줄의 1차원 제곱 거리 변환 (Felzenszwalb)
	func _transform(values: PackedFloat32Array, start: int, stride: int, count: int) -> void:
		var source: PackedFloat32Array = PackedFloat32Array()
		source.resize(count)
		for index: int in count:
			source[index] = values[start + index * stride]
		var hull: PackedInt32Array = PackedInt32Array()
		hull.resize(count)
		var bounds: PackedFloat32Array = PackedFloat32Array()
		bounds.resize(count + 1)
		var top: int = 0
		bounds[0] = -FAR
		bounds[1] = FAR
		for q: int in range(1, count):
			var crossing: float = _crossing(source, q, hull[top])
			while crossing <= bounds[top]:
				top -= 1
				crossing = _crossing(source, q, hull[top])
			top += 1
			hull[top] = q
			bounds[top] = crossing
			bounds[top + 1] = FAR
		top = 0
		for q: int in count:
			while bounds[top + 1] < q:
				top += 1
			values[start + q * stride] = (q - hull[top]) * (q - hull[top]) + source[hull[top]]

	func _crossing(source: PackedFloat32Array, q: int, p: int) -> float:
		return ((source[q] + q * q) - (source[p] + p * p)) / (2.0 * q - 2.0 * p)

	## 폭, 가장 좁은 칸, 몸마다 지나가는지
	func measure(solid: PackedByteArray, bodies: Array[Dictionary]) -> Dictionary:
		var distances: PackedFloat32Array = _distances(solid)
		var low: float = 0.0
		var high: float = RADIUS_LIMIT
		for step: int in SEARCH_STEPS:
			var radius: float = (low + high) * 0.5
			if _joins(_free_circle(distances, radius)):
				low = radius
			else:
				high = radius
		var passes: Array[bool] = []
		for body: Dictionary in bodies:
			passes.append(_joins(_free_body(distances, body.radius, body.reach)))
		return {"width": low * 2.0, "pinch": _pinch(distances, low), "passes": passes}

	func _free_circle(distances: PackedFloat32Array, radius: float) -> PackedByteArray:
		var free: PackedByteArray = PackedByteArray()
		free.resize(distances.size())
		for index: int in distances.size():
			free[index] = 1 if distances[index] >= radius else 0
		return free

	## 가로로 눕힌 캡슐: 가운데 선 위의 모든 표본이 벽에서 radius 넘게 떨어져야 한다.
	func _free_body(distances: PackedFloat32Array, radius: float, reach: float) -> PackedByteArray:
		var free: PackedByteArray = _free_circle(distances, radius)
		var samples: int = ceili(reach / STEP)
		if samples == 0:
			return free
		var result: PackedByteArray = PackedByteArray()
		result.resize(free.size())
		for y: int in size.y:
			for x: int in size.x:
				var ok: bool = x - samples >= 0 and x + samples < size.x
				var offset: int = -samples
				while ok and offset <= samples:
					ok = free[y * size.x + x + offset] == 1
					offset += 1
				result[y * size.x + x] = 1 if ok else 0
		return result

	func _flood(free: PackedByteArray, cells: Dictionary) -> PackedByteArray:
		var seen: PackedByteArray = PackedByteArray()
		seen.resize(free.size())
		var stack: Array[int] = []
		for index: int in free.size():
			if free[index] == 1 and cells.has(_cell(index)):
				seen[index] = 1
				stack.append(index)
		while not stack.is_empty():
			var current: int = stack.pop_back()
			var x: int = current % size.x
			var y: int = current / size.x
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var nx: int = x + step.x
				var ny: int = y + step.y
				if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
					continue
				var next: int = ny * size.x + nx
				if seen[next] == 0 and free[next] == 1:
					seen[next] = 1
					stack.append(next)
		return seen

	func _joins(free: PackedByteArray) -> bool:
		var reached: PackedByteArray = _flood(free, _from)
		for index: int in reached.size():
			if reached[index] == 1 and _to.has(_cell(index)):
				return true
		return false

	## 조금 더 큰 몸이면 끊어지는 자리의 가운데 칸: 양쪽 덩어리에 모두 가깝거나(짧은 길목), 둘 다에서 멀리 떨어진(긴 길목) 표본들
	func _pinch(distances: PackedFloat32Array, radius: float) -> Vector2i:
		var tighter: PackedByteArray = _free_circle(distances, radius + PINCH_MARGIN)
		var near_from: PackedByteArray = _grown(_flood(tighter, _from))
		var near_to: PackedByteArray = _grown(_flood(tighter, _to))
		var reached: PackedByteArray = _flood(_free_circle(distances, radius), _from)
		var total: Vector2 = Vector2.ZERO
		var count: int = 0
		for index: int in reached.size():
			if reached[index] == 1 and near_from[index] == near_to[index]:
				total += _point(index % size.x, index / size.x)
				count += 1
		return Vector2i((total / count / _cell_px).floor()) if count > 0 else Vector2i(-1, -1)

	func _grown(marks: PackedByteArray) -> PackedByteArray:
		var result: PackedByteArray = marks.duplicate()
		for round_index: int in PINCH_REACH:
			var previous: PackedByteArray = result.duplicate()
			for y: int in range(1, size.y - 1):
				for x: int in range(1, size.x - 1):
					var index: int = y * size.x + x
					if previous[index] == 0 and (previous[index - 1] == 1 or previous[index + 1] == 1 or previous[index - size.x] == 1 or previous[index + size.x] == 1):
						result[index] = 1
		return result
