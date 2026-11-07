extends SceneTree
## 맵 배치 PNG(픽셀 하나 = 타일 한 칸)를 읽어 지역 씬(.tscn)을 만든다. 색 규칙은 docs/maps/map_png_rules.md.
## 만든 씬에는 벽(충돌 포함)·바닥 색 칸(PlaceholderWalls), 길찾기(NavigationGrid), 네크로맨서(도착 지점), 몬스터, 상자, 탈출 지점,
## HUD·인벤토리·상자 화면이 들어간다. PNG를 고친 뒤 다시 실행하면 씬을 통째로 새로 쓴다 (씬을 손으로 고치지 않는다).
## 벽 가장자리는 MapSmoother로 동굴처럼 다듬는다 (좁은 길목·굴 중심·물건 둘레는 그대로, 바닥은 최소 2칸). 끄려면 --smooth=0, 다른 모양은 --seed=<수>.
## 다 만든 뒤 굴 목록(입구 수, 이어진 굴, 안의 물건)과 문제(모르는 색 등)를 출력한다. 문제가 있으면 씬을 쓰지 않고 종료 코드 1.
##
## 실행 (기본값은 얕은 굴):
##   bash tools/godot.sh --headless --path . -s tools/map_from_png.gd
##   bash tools/godot.sh --headless --path . -s tools/map_from_png.gd -- --in=res://art_src/maps/<맵>.png --out=res://regions/<맵>.tscn --region=res://data/regions/<맵>.tres --name=<루트 노드 이름>

const DEFAULT_IN: String = "res://art_src/maps/shallow_cave.png"
const DEFAULT_OUT: String = "res://regions/shallow_cave.tscn"
const DEFAULT_REGION: String = "res://data/regions/shallow_cave.tres"
const DEFAULT_NAME: String = "ShallowCave"
## 죽거나 탈출하면 가는 곳
const BASE_REGION: String = "res://data/regions/base.tres"
## 상자의 내용물 데이터 (지금은 모든 상자가 같다, 임시)
const CHEST_DATA: String = "res://data/chests/test_chest.tres"
const TILE_SIZE: int = 32
## 길찾기 칸 크기 (픽셀). 8이면 큰 맵에서 몸 크기마다 칸 계산이 0.6초쯤 걸려서 16으로 둔다. 16이면 한 칸(32px) 길목은 멧돼지 크기가 지나가지 못할 수 있으니 길목은 두 칸 이상으로 그린다.
const NAV_CELL_SIZE: float = 16.0
## 물건 이름 → 몬스터 데이터 (몬스터가 아닌 물건은 없음)
const MONSTER_DATA: Dictionary = {
	"rat": "res://data/monsters/rat.tres",
	"boar": "res://data/monsters/boar.tres",
	"bat": "res://data/monsters/bat.tres",
	"goblin_slinger": "res://data/monsters/goblin_slinger.tres",
	## 거미 자리: 동굴 거미가 아직 없어 임시로 고블린 투석병을 둔다 (사용자 결정). 거미를 만들면 이 줄만 바꾼다
	"spider": "res://data/monsters/goblin_slinger.tres",
}
## 이 몬스터의 픽셀끼리 붙어 있으면(대각선 포함) 한 무리(MonsterPack)다
const PACK_MONSTERS: Array[String] = ["bat"]
## 노드 이름에 쓰는 물건 이름
const NODE_NAMES: Dictionary = {"rat": "Rat", "boar": "Boar", "bat": "Bat", "goblin_slinger": "Goblin", "spider": "SpiderSpot"}
## 바깥의 빛 표지: 그 칸 바닥 위에 이 색을 반투명하게 덮는다 (Endesga 32, 그림이 생기기 전까지)
const LIGHT_COLOR: String = "fee761"
const LIGHT_ALPHA: float = 0.45
## 바닥 글자마다 체크무늬 두 색 (첫 색이 PNG의 색), 벽 글자마다 윗면 색. 모두 Endesga 32.
const FLOOR_COLORS: Dictionary = {
	".": ["3a4466", "262b44"],
	"1": ["265c42", "193c3e"],
	"2": ["733e39", "3e2731"],
	"b": ["124e89", "262b44"],
}
const WALL_COLORS: Dictionary = {"x": "68386c"}

var _ext: Array[String] = []
var _ext_ids: Dictionary = {}


func _initialize() -> void:
	var args: Dictionary = {"in": DEFAULT_IN, "out": DEFAULT_OUT, "region": DEFAULT_REGION, "name": DEFAULT_NAME, "smooth": "1", "seed": str(MapSmoother.DEFAULT_SEED)}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var layout: MapLayout = MapLayout.from_file(args.in)
	for line: String in layout.describe_rooms():
		print(line)
	if not layout.errors.is_empty():
		for error: String in layout.errors:
			printerr("문제: ", error)
		quit(1)
		return
	# 그릴 때 지킬 것: 1칸짜리 길은 그리지 않는다 (docs/maps/map_png_rules.md).
	var narrow: Array[Vector2i] = MapSmoother.narrow_cells(layout.rows)
	if not narrow.is_empty():
		printerr("문제: PNG에 2칸보다 좁은 바닥이 있음 (칸 좌표): ", narrow)
		quit(1)
		return
	var rows: PackedStringArray = layout.rows
	if args.smooth != "0":
		rows = MapSmoother.smooth(layout, int(args.seed))
		if not _check_smoothed(layout, rows):
			quit(1)
			return
	var text: String = _build(layout, rows, args.region, args.name)
	var file: FileAccess = FileAccess.open(args.out, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("저장: %s (%d×%d칸, 몬스터 %d, 상자 %d, 탈출 지점 %d)" % [args.out, layout.size.x, layout.size.y,
		layout.objects.filter(func(o: Dictionary) -> bool: return MONSTER_DATA.has(o.object)).size(),
		layout.cells_of("chest").size(), layout.cells_of("escape").size()])
	quit(0)


func _id(path: String, type: String) -> String:
	if not _ext_ids.has(path):
		var id: String = "%d_%s" % [_ext.size() + 1, path.get_file().get_basename()]
		_ext_ids[path] = id
		_ext.append('[ext_resource type="%s" path="%s" id="%s"]' % [type, path, id])
	return 'ExtResource("%s")' % _ext_ids[path]


func _center(cell: Vector2i) -> String:
	var p: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_SIZE
	return "Vector2(%s, %s)" % [p.x, p.y]


## PackedColorArray 안에 쓰는 색 (씬 파일에서는 숫자만 늘어놓는다)
func _components(hex: String) -> String:
	var c: Color = Color(hex)
	return "%s, %s, %s, 1" % [c.r, c.g, c.b]


func _color(hex: String) -> String:
	var c: Color = Color(hex)
	return "Color(%s, %s, %s, 1)" % [c.r, c.g, c.b]


func _build(layout: MapLayout, rows: PackedStringArray, region_path: String, root_name: String) -> String:
	var nodes: PackedStringArray = []
	nodes.append('[node name="%s" type="Node2D"]\nscript = %s\ndata = %s\ndeath_destination = %s\n' % [
		root_name, _id("res://regions/region.gd", "Script"), _id(region_path, "Resource"), _id(BASE_REGION, "Resource")])

	var quoted: PackedStringArray = []
	for row: String in rows:
		quoted.append('"%s"' % row)
	var floors: PackedStringArray = []
	for c: String in FLOOR_COLORS:
		floors.append('"%s": PackedColorArray(%s, %s)' % [c, _components(FLOOR_COLORS[c][0]), _components(FLOOR_COLORS[c][1])])
	var walls: PackedStringArray = []
	for c: String in WALL_COLORS:
		walls.append('"%s": %s' % [c, _color(WALL_COLORS[c])])
	nodes.append('[node name="Walls" type="Node2D" parent="."]\nscript = %s\nlayout = PackedStringArray(%s)\nwall_chars = "%s"\nwall_colors = Dictionary[String, Color]({%s})\nfloor_colors = Dictionary[String, PackedColorArray]({%s})\n' % [
		_id("res://regions/placeholder_walls.gd", "Script"), ", ".join(quoted), MapLayout.WALL_CHARS, ", ".join(walls), ", ".join(floors)])
	nodes.append('[node name="NavigationGrid" type="Node" parent="."]\nscript = %s\nbounds = Rect2(0, 0, %d, %d)\ncell_size = %s\n' % [
		_id("res://regions/navigation_grid.gd", "Script"), layout.size.x * TILE_SIZE, layout.size.y * TILE_SIZE, NAV_CELL_SIZE])

	var escapes: Array[Vector2i] = layout.cells_of("escape")
	for i: int in escapes.size():
		nodes.append('[node name="EscapePoint%d" parent="." instance=%s]\nposition = %s\ndestination = %s\n' % [
			i + 1, _id("res://regions/escape_point.tscn", "PackedScene"), _center(escapes[i]), _id(BASE_REGION, "Resource")])
	var chests: Array[Vector2i] = layout.cells_of("chest")
	for i: int in chests.size():
		nodes.append('[node name="Chest%d" parent="." instance=%s]\nposition = %s\ndata = %s\n' % [
			i + 1, _id("res://regions/loot_chest.tscn", "PackedScene"), _center(chests[i]), _id(CHEST_DATA, "Resource")])

	var lights: Array[Vector2i] = layout.cells_of("light")
	if not lights.is_empty():
		var c: Color = Color(LIGHT_COLOR)
		nodes.append('[node name="OutsideLight" type="Node2D" parent="."]\n')
		for i: int in lights.size():
			var corner: Vector2 = Vector2(lights[i] * TILE_SIZE)
			nodes.append('[node name="Light%d" type="Polygon2D" parent="OutsideLight"]\ncolor = Color(%s, %s, %s, %s)\npolygon = PackedVector2Array(%s, %s, %s, %s, %s, %s, %s, %s)\n' % [
				i + 1, c.r, c.g, c.b, LIGHT_ALPHA, corner.x, corner.y, corner.x + TILE_SIZE, corner.y, corner.x + TILE_SIZE, corner.y + TILE_SIZE, corner.x, corner.y + TILE_SIZE])

	nodes.append('[node name="Actors" type="Node2D" parent="."]\ny_sort_enabled = true\n')
	nodes.append('[node name="Necromancer" parent="Actors" instance=%s]\nposition = %s\n' % [
		_id("res://necromancer/necromancer.tscn", "PackedScene"), _center(layout.cells_of("spawn")[0])])
	var counts: Dictionary = {}
	var packs: Array[PackedStringArray] = []
	for object: String in MONSTER_DATA:
		var cells: Array[Vector2i] = layout.cells_of(object)
		var names: Dictionary = {}
		for cell: Vector2i in cells:
			counts[object] = counts.get(object, 0) + 1
			var node_name: String = "%s%d" % [NODE_NAMES[object], counts[object]]
			names[cell] = node_name
			nodes.append('[node name="%s" parent="Actors" instance=%s]\nposition = %s\ndata = %s\n' % [
				node_name, _id("res://monsters/monster.tscn", "PackedScene"), _center(cell), _id(MONSTER_DATA[object], "Resource")])
		if PACK_MONSTERS.has(object):
			packs.append_array(_group_packs(cells, names))
	for i: int in packs.size():
		var members: PackedStringArray = []
		for node_name: String in packs[i]:
			members.append('NodePath("../Actors/%s")' % node_name)
		nodes.append('[node name="Pack%d" type="Node" parent="."]\nscript = %s\nmembers = Array[NodePath]([%s])\n' % [
			i + 1, _id("res://monsters/monster_pack.gd", "Script"), ", ".join(members)])

	nodes.append('[node name="HUD" parent="." instance=%s]\n' % _id("res://ui/hud.tscn", "PackedScene"))
	nodes.append('[node name="InventoryScreen" parent="." instance=%s]\n' % _id("res://ui/inventory_screen.tscn", "PackedScene"))
	nodes.append('[node name="ChestScreen" parent="." instance=%s]\n' % _id("res://ui/storage_screen.tscn", "PackedScene"))

	return "[gd_scene format=3]\n\n%s\n\n%s" % ["\n".join(_ext), "\n".join(nodes)]


## 붙어 있는(대각선 포함) 칸끼리 묶은 노드 이름들. 한 마리뿐인 묶음은 무리가 아니다.
func _group_packs(cells: Array[Vector2i], names: Dictionary) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var seen: Dictionary = {}
	for start: Vector2i in cells:
		if seen.has(start):
			continue
		var group: PackedStringArray = []
		var stack: Array[Vector2i] = [start]
		seen[start] = true
		while not stack.is_empty():
			var cell: Vector2i = stack.pop_back()
			group.append(names[cell])
			for other: Vector2i in cells:
				if not seen.has(other) and absi(other.x - cell.x) <= 1 and absi(other.y - cell.y) <= 1:
					seen[other] = true
					stack.append(other)
		if group.size() > 1:
			result.append(group)
	return result


## 다듬은 결과가 규칙을 지키는지 확인하고 요약을 출력한다: 바닥이 모두 2칸 너비, 도착 지점에서 모든 물건에 걸어서 닿음.
func _check_smoothed(layout: MapLayout, rows: PackedStringArray) -> bool:
	var carved: int = 0
	var filled: int = 0
	for y: int in rows.size():
		for x: int in rows[y].length():
			var before: bool = layout.is_wall(Vector2i(x, y))
			var after: bool = MapLayout.WALL_CHARS.contains(rows[y][x])
			if before and not after:
				carved += 1
			elif after and not before:
				filled += 1
	# 굴 가운데가 조금 옮겨질 수 있어 가운데 칸 대신 입구 수와 이어진 굴로 비교한다.
	var after: MapLayout = MapLayout.from_rows(rows, layout.objects)
	var same_connections: bool = after.rooms.size() == layout.rooms.size()
	if same_connections:
		for i: int in layout.rooms.size():
			var a: Array = layout.rooms[i].neighbors.duplicate()
			var b: Array = after.rooms[i].neighbors.duplicate()
			a.sort()
			b.sort()
			same_connections = same_connections and a == b and layout.rooms[i].entrances == after.rooms[i].entrances
	var narrow: Array[Vector2i] = MapSmoother.narrow_cells(rows)
	var reach: Dictionary = MapSmoother.reachable(rows, layout.cells_of("spawn")[0])
	var unreachable: Array[Vector2i] = []
	for o: Dictionary in layout.objects:
		if not reach.has(o.cell):
			unreachable.append(o.cell)
	print("다듬기: 벽 → 바닥 %d칸, 바닥 → 벽 %d칸, 2칸보다 좁은 바닥 %s, 도착 지점에서 닿지 않는 물건 %s, 굴 입구 수·연결 그대로 %s" % [carved, filled, narrow, unreachable, same_connections])
	if not same_connections:
		print("  전: ", layout.connection_summary())
		print("  후: ", after.connection_summary())
	if not narrow.is_empty() or not unreachable.is_empty() or not same_connections:
		printerr("문제: 다듬은 맵이 규칙을 어김 (위 출력). PNG에 1칸 길이 있는지 확인한다")
		return false
	return true
