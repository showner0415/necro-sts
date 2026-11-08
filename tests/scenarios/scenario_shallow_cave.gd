extends ScenarioTest
## 시나리오: 얕은 굴 그레이박스. 배치 PNG(art_src/maps/shallow_cave.png)와 만든 씬(regions/shallow_cave.tscn)을 같이 본다.
## 1. 씬이 PNG(를 다듬은 결과)와 같다 (PNG를 고치고 tools/map_from_png.gd를 다시 돌리지 않았으면 실패). 바닥은 최소 2칸, 모든 물건에 걸어서 닿음. 몬스터·상자·탈출 지점 수
## 2. 굴 역할을 찾고, 굴마다 입구 수와 이어진 굴이 설계 문서(docs/maps/shallow_cave_design.md 배치도)와 같다. 2칸 길목은 "좁은 길목 8곳" 표의 통로에만 있다
## 3. 쥐가 사는 굴들이 고리로 이어져 있다 (입구 굴·쥐 둥지·물웅덩이 굴과 그 사이를 잇는 작은 굴 사이에 돌아오는 길이 있다)
## 4. 상자가 있고 굴 하나에만 이어진 굴(막다른 굴, 둥지 뒷굴)은 입구가 하나다
## 5. 전망 바위의 전망 자리(tools/screenshot_setups/view_rock.gd)에 서면 박쥐가 모두 화면 안에 보이고, 박쥐 둥지까지 바로 가는 길은 없다 (벽을 돌아가야 한다)
## 5-1. 박쥐 길 (tests/bat_nest_paths.gd, 박쥐의 처음 자리 기준): 갈림 굴 쪽 입구에서 합류 굴 쪽 출구까지 가장 짧은 길(기본 길)은
##    박쥐에게 감지되고, 감지되는 곳은 입구에서 BAT_DETECT_DEPTH칸 이상 들어선 뒤다. 감지 범위보다 BAT_SNEAK_MARGIN 더 떨어져 지나는 길(몰래 가는 길)이 있다. 두 길의 길이·걷는 시간을 출력한다
## 5-2. 빛 드는 굴의 합류 굴 쪽 입구에 서면 가장 가까운 멧돼지(처음 자리)가 화면 안에 보이고, 입구 칸은 모두 멧돼지 감지 거리 밖이다
## 6. 다듬은 뒤에도 박쥐 둥지가 유일한 넓은 방이다: 박쥐가 도는 반경(+ 몸)의 원이 벽에 닿지 않는 자리가 가장 많고, 가장 큰 원도 가장 크다
## 7. 멧돼지가 사는 굴마다 돌진(돌진 최대 거리 + 지나치는 거리)보다 긴 곧고 트인 길(3칸 폭)이 있고, 가장 긴 것도 BOAR_LANE_MAX칸을 넘지 않는다 (바위가 긴 직선을 끊어 돌진을 피할 곳이 있게)
## 8. 구간별 걷기 시간 (걷기, 몬스터는 없앰): 도착 지점 → 입구 굴, 입구 굴 → 갈림 굴, 갈림 굴 → 합류 굴(박쥐 길, 거미 길),
##    합류 굴 → 동굴 입구, 도착 지점 → 동굴 입구 전체. 문서 기준값과 함께 출력한다
## 9. 쥐 언데드 2마리를 데리고, 이어진 두 굴 사이를 모두 한 번씩 오간다 (순서는 PNG의 굴 연결에서 만든다). 굴에 닿을 때마다 2마리 모두 따라와 곁에 모인다 (휘어진 통로에서 걸리지 않음)
## 10. 굴 안의 바위마다: 다듬은 씬에서도 바위 칸이 모두 벽이고, 네크로맨서가 바위 한쪽에서 반대쪽으로 가면 언데드 2마리가 바위를 돌아 따라와 곁에 모인다
## 11. 갈림 굴에서 갈림길 하나(박쥐 길, 거미 길 각각)를 넘어 합류 굴의 탈출 B로 거점에 간다. 그동안 멧돼지는 아무도 노리지 않는다 (멧돼지만 남긴다)
## 12. 지역을 나갔다 다시 들어오면 몬스터가 처음 상태로 다시 놓인다 (임시 규칙)

const MAP_PNG: String = "res://art_src/maps/shallow_cave.png"
const CAVE_SCENE: String = "res://regions/shallow_cave.tscn"
const BASE_SCENE: String = "res://regions/base.tscn"
const CAVE_REGION: String = "res://data/regions/shallow_cave.tres"
const BASE_REGION: String = "res://data/regions/base.tres"
const VIEW_ROCK_SETUP: String = "res://tools/screenshot_setups/view_rock.gd"
const BAT_PATH: String = "res://data/monsters/bat.tres"
const DIVE_PATH: String = "res://data/behaviors/dive.tres"
const CHARGE_PATH: String = "res://data/behaviors/charge.tres"
## 문서(docs/maps/shallow_cave_design.md 4장)의 걷기 시간 기준 (초)
const TARGET_TO_ENTRANCE: float = 10.0
const TARGET_TO_FORK: float = 40.0
const TARGET_FORK_TO_JUNCTION: float = 60.0
const TARGET_JUNCTION_TO_MOUTH: float = 25.0
const TARGET_TOTAL: float = 120.0
## 굴 역할마다 [입구 수, 이어진 굴 역할들] (배치도 그대로)
const EXPECTED_ROOMS: Dictionary = {
	"base": [1, ["entrance"]],
	"entrance": [3, ["base", "rat_nest", "puddle"]],
	"rat_nest": [4, ["entrance", "view_rock", "side", "fork"]],
	"view_rock": [1, ["rat_nest"]],
	"side": [2, ["rat_nest", "puddle"]],
	"puddle": [4, ["entrance", "side", "fork", "dead_end"]],
	"dead_end": [1, ["puddle"]],
	"fork": [4, ["rat_nest", "puddle", "bat_nest", "spider_gate"]],
	"bat_nest": [3, ["fork", "nest_back", "junction"]],
	"nest_back": [1, ["bat_nest"]],
	"spider_gate": [2, ["fork", "web"]],
	"web": [2, ["spider_gate", "egg"]],
	"egg": [2, ["web", "junction"]],
	"junction": [4, ["bat_nest", "egg", "light_room", "cave_mouth"]],
	"light_room": [2, ["junction", "cave_mouth"]],
	"cave_mouth": [2, ["junction", "light_room"]],
}
## 설계 문서 "좁은 길목 8곳": 2칸 길목이 있어야 하는 통로 (양 끝 굴 역할). 다른 통로에는 길목이 없어야 한다
const CHOKE_PAIRS: Array = [
	["puddle", "dead_end"], ["fork", "bat_nest"], ["fork", "spider_gate"], ["web", "egg"],
	["egg", "junction"], ["bat_nest", "junction"], ["junction", "light_room"], ["junction", "cave_mouth"],
]
## 굴 가운데에서 이 거리 안이면 닿은 것으로 본다 (픽셀)
const ARRIVE_DISTANCE: float = 16.0
## 한 구간을 걷는 최대 시간 (프레임). 도착 지점 → 동굴 입구 전체도 한 구간이다
const WALK_TIMEOUT_FRAMES: int = 60 * 200
const SETTLE_FRAMES: int = 6
const SCENE_TIMEOUT_FRAMES: int = 300
const TILE: float = 32.0
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 20
## 굴에 닿은 뒤 언데드가 모여야 하는 시간 (프레임)과 거리 (픽셀). 시험 통로 시나리오(scenario_pathfinding.gd)와 같다
const GATHER_FRAMES: int = 300
const GATHER_DISTANCE: float = 40.0
## 오래 걷는 동안 쥐 2마리의 유지비로 마나가 바닥나 해제되지 않게 올려 두는 자연 회복 (초당)
const TEST_MANA_REGEN: float = 10.0
## 10. 바위 양쪽의 서는 자리: 바위 가장자리에서 이만큼(칸) 떨어진 곳 (먼 것부터 해 본다). 그 자리가 2×2 바닥에 들어야 한다
const ROCK_SIDE_GAPS: Array[float] = [2.0, 1.0]
## 10. 바위를 가로지르는 방향 후보 (가로, 세로, 대각선 둘)
const ROCK_DIRECTIONS: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1), Vector2(0.7071, 0.7071), Vector2(0.7071, -0.7071)]
## 5. 전망 자리에 선 뒤 카메라가 자리 잡기를 기다리는 프레임
const VIEW_SETTLE_FRAMES: int = 10
## 5. 바로 가는 길이 없다고 보려면, 전망 자리에서 박쥐 둥지까지 걷는 걸음 수가 곧은 거리의 이 배 이상이어야 한다
const VIEW_DETOUR_RATIO: float = 3.0
## 5-1. 기본 길에서 박쥐가 처음 감지하는 곳이 둥지 입구에서 적어도 이만큼(칸) 들어선 뒤여야 한다 (길목을 나서자마자 걸리지 않게)
const BAT_DETECT_DEPTH: float = 3.0
## 5-1. 몰래 가는 길은 박쥐 감지 범위보다 이만큼(픽셀) 더 떨어져 지나야 한다. 박쥐는 싸우지 않을 때 배회하므로(초당 15px), 둥지에 닿기까지 옮겨 간 만큼의 여유
const BAT_SNEAK_MARGIN: float = 96.0
const BAT_PATHS = preload("res://tests/bat_nest_paths.gd")
## 5-2. 멧돼지가 화면 가장자리에서 이만큼(픽셀) 안쪽에 있어야 보인다고 본다
const BOAR_VIEW_MARGIN: float = 16.0
const BOAR_PATH: String = "res://data/monsters/boar.tres"
## 7. 멧돼지 굴의 가장 긴 3칸 폭 곧은 길이 이보다 길면 안 된다 (칸, 제안값)
const BOAR_LANE_MAX: float = 13.0
## 11. 탈출 지점에 선 뒤 거점에 가기를 기다리는 최대 프레임 (탈출 3초 + 여유)
const ESCAPE_WAIT_FRAMES: int = 60 * 5
## 8방향 (곧은 길 찾기)
const DIRECTIONS_8: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

var _layout: MapLayout
## 굴 역할 → 굴 번호 (_find_roles)
var _roles: Dictionary = {}


func get_start_scene() -> String:
	return CAVE_SCENE


func _on_scene_ready() -> void:
	_run()


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
		finish(false)
	return ok


func _rooms_with(object: String) -> Array[int]:
	var result: Array[int] = []
	for cell: Vector2i in _layout.cells_of(object):
		var room: int = _layout.room_at(cell)
		if room >= 0 and not result.has(room):
			result.append(room)
	return result


func _room_center(room: int) -> Vector2:
	return (_layout.rooms[room].center + Vector2(0.5, 0.5)) * TILE


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func _run() -> void:
	_layout = MapLayout.from_file(MAP_PNG)
	await wait_frames(SETTLE_FRAMES)
	if not await _matches_png():
		return
	if not _find_roles():
		return
	if not _connections():
		return
	if not _ring(_roles.entrance):
		return
	if not _dead_end():
		return
	if not await _view_rock():
		return
	if not _bat_path():
		return
	if not _boar_seen_first():
		return
	if not _wide_bat_nest():
		return
	if not _boar_lanes():
		return
	if not await _walk_times():
		return
	if not await _undead_follow():
		return
	if not await _around_rocks():
		return
	if not await _escape_without_boars():
		return
	if not await _monsters_reset():
		return
	finish(true)


# --- 1. 씬이 PNG와 같다 ---

func _monster_cells() -> int:
	var count: int = 0
	for object: String in ["rat", "boar", "bat", "goblin_slinger", "spider"]:
		count += _layout.cells_of(object).size()
	return count


func _matches_png() -> bool:
	var walls: PlaceholderWalls = current_scene.get_node("Walls")
	# 씬의 벽·바닥은 PNG를 기본 씨앗으로 다듬은 결과와 같아야 한다 (tools/map_from_png.gd).
	var smoothed: PackedStringArray = MapSmoother.smooth(_layout, MapSmoother.DEFAULT_SEED)
	var same_layout: bool = walls.layout == smoothed
	var narrow: Array[Vector2i] = MapSmoother.narrow_cells(walls.layout)
	var reach: Dictionary = MapSmoother.reachable(walls.layout, _layout.cells_of("spawn")[0])
	var unreachable: int = _layout.objects.filter(func(o: Dictionary) -> bool: return not reach.has(o.cell)).size()
	var changed: int = 0
	for y: int in smoothed.size():
		for x: int in smoothed[y].length():
			if MapLayout.WALL_CHARS.contains(smoothed[y][x]) != _layout.is_wall(Vector2i(x, y)):
				changed += 1
	var monsters: int = get_nodes_in_group(&"monsters").size()
	var chests: int = current_scene.find_children("*", "LootChest", true, false).size()
	var escapes: int = current_scene.find_children("*", "EscapePoint", true, false).size()
	var nav: NavigationGrid = current_scene.get_node("NavigationGrid")
	var ok: bool = _layout.errors.is_empty() and same_layout and changed > 0 and narrow.is_empty() and unreachable == 0 and monsters == _monster_cells() and chests == _layout.cells_of("chest").size() and escapes == _layout.cells_of("escape").size() and nav.has_walls()
	return _check("씬이 배치 PNG와 같음", ok, "PNG %d×%d칸, 읽기 문제 %s, 벽·바닥이 PNG를 다듬은 결과와 같음 %s (다듬어 바뀐 칸 %d), 2칸보다 좁은 바닥 %s, 도착 지점에서 닿지 않는 물건 %d, 몬스터 %d (PNG %d), 상자 %d (PNG %d), 탈출 지점 %d (PNG %d), 길찾기 벽 있음 %s" % [
		_layout.size.x, _layout.size.y, _layout.errors, same_layout, changed, narrow, unreachable, monsters, _monster_cells(), chests, _layout.cells_of("chest").size(), escapes, _layout.cells_of("escape").size(), nav.has_walls()])


# --- 2. 굴 역할과 연결 ---

## 굴마다 역할을 내용물과 연결로 찾는다. 못 찾은 역할이 있으면 실패
func _find_roles() -> bool:
	_roles.clear()
	var base: int = _layout.room_at(_layout.cells_of("spawn")[0])
	_roles.base = base
	for room: int in _rooms_with("escape"):
		if _layout.rooms[base].neighbors.has(room):
			_roles.entrance = room
		else:
			_roles.junction = room
	if _roles.has("entrance"):
		_roles.fork = _find_fork(_roles.entrance)
	var bat_rooms: Array[int] = _rooms_with("bat")
	if not bat_rooms.is_empty():
		_roles.bat_nest = bat_rooms[0]
	var view: Vector2i = load(VIEW_ROCK_SETUP).spot(_layout)
	if view.x >= 0:
		_roles.view_rock = _layout.room_at(view)
	if _roles.has("entrance") and _roles.has("view_rock"):
		for room: int in _layout.rooms[_roles.entrance].neighbors:
			if room == base:
				continue
			if _layout.rooms[room].neighbors.has(_roles.view_rock):
				_roles.rat_nest = room
			else:
				_roles.puddle = room
	if _roles.has("rat_nest") and _roles.has("puddle"):
		for room: int in _layout.rooms[_roles.rat_nest].neighbors:
			if _layout.rooms[_roles.puddle].neighbors.has(room) and _layout.rooms[room].entrances == 2:
				_roles.side = room
	var chest_rooms: Array[int] = _rooms_with("chest")
	for room: int in chest_rooms:
		if _layout.rooms[room].neighbors.size() == 1:
			var only: int = _layout.rooms[room].neighbors[0]
			if only == _roles.get("puddle", -1):
				_roles.dead_end = room
			elif only == _roles.get("bat_nest", -1):
				_roles.nest_back = room
	var spider_rooms: Array[int] = _rooms_with("spider")
	for room: int in spider_rooms:
		if _layout.rooms[room].neighbors.has(_roles.get("fork", -1)):
			_roles.spider_gate = room
		elif _layout.rooms[room].neighbors.has(_roles.get("junction", -1)):
			_roles.egg = room
		else:
			_roles.web = room
	var mouth_rooms: Array[int] = _rooms_with("light")
	if not mouth_rooms.is_empty():
		_roles.cave_mouth = mouth_rooms[0]
	for room: int in _rooms_with("boar"):
		if room != _roles.get("cave_mouth", -1):
			_roles.light_room = room
	var missing: PackedStringArray = []
	for role: String in EXPECTED_ROOMS:
		if not _roles.has(role) or _roles[role] < 0:
			missing.append(role)
	return _check("굴 역할 찾기", missing.is_empty(), "찾은 역할 %s, 못 찾은 역할 %s" % [_roles, missing])


func _connections() -> bool:
	var wrong: PackedStringArray = []
	var role_of: Dictionary = {}
	for role: String in _roles:
		role_of[_roles[role]] = role
	for role: String in EXPECTED_ROOMS:
		var room: Dictionary = _layout.rooms[_roles[role]]
		var neighbors: Array = []
		for n: int in room.neighbors:
			neighbors.append(role_of.get(n, "굴 %d" % n))
		neighbors.sort()
		var expected: Array = EXPECTED_ROOMS[role][1].duplicate()
		expected.sort()
		if room.entrances != EXPECTED_ROOMS[role][0] or neighbors != expected:
			wrong.append("%s: 입구 %d (설계 %d), 이어진 굴 %s (설계 %s)" % [role, room.entrances, EXPECTED_ROOMS[role][0], neighbors, expected])
	if not _check("굴마다 입구 수와 연결이 설계와 같음", wrong.is_empty() and _layout.rooms.size() == EXPECTED_ROOMS.size(), "굴 %d개 (설계 %d), 다른 곳 %s" % [_layout.rooms.size(), EXPECTED_ROOMS.size(), wrong]):
		return false
	# 통로마다 이어 주는 두 굴과 2칸 길목(3×3 바닥에 들지 못하는 칸) 수
	var chokes: Dictionary = {}
	var touched: Dictionary = {}
	for y: int in _layout.size.y:
		for x: int in _layout.size.x:
			var cell: Vector2i = Vector2i(x, y)
			var segment: String = _layout.segment_at(cell)
			if not segment.begins_with("p"):
				continue
			if not touched.has(segment):
				touched[segment] = []
				chokes[segment] = 0
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var room: int = _layout.room_at(cell + offset)
				if room >= 0 and not touched[segment].has(role_of.get(room, str(room))):
					touched[segment].append(role_of.get(room, str(room)))
			if not _in_floor_block(cell, 3):
				chokes[segment] += 1
	var lines: PackedStringArray = []
	var bad: PackedStringArray = []
	for segment: String in touched:
		var pair: Array = touched[segment].duplicate()
		pair.sort()
		var listed: bool = false
		for expected: Array in CHOKE_PAIRS:
			var sorted: Array = expected.duplicate()
			sorted.sort()
			listed = listed or sorted == pair
		lines.append("%s %d칸" % ["-".join(PackedStringArray(pair)), chokes[segment]])
		if listed != (chokes[segment] > 0):
			bad.append("%s (길목 %d칸, 표에 %s)" % ["-".join(PackedStringArray(pair)), chokes[segment], "있음" if listed else "없음"])
	return _check("2칸 길목은 좁은 길목 표의 통로에만", bad.is_empty(), "통로마다 길목 칸: %s / 어긋난 통로 %s" % [", ".join(lines), bad])


func _in_floor_block(cell: Vector2i, block: int) -> bool:
	for oy: int in block:
		for ox: int in block:
			var corner: Vector2i = cell - Vector2i(ox, oy)
			var open: bool = true
			for by: int in block:
				for bx: int in block:
					if _layout.is_wall(corner + Vector2i(bx, by)):
						open = false
			if open:
				return true
	return false


# --- 3. 쥐 굴 고리 ---

func _ring(entrance: int) -> bool:
	var rat_rooms: Array[int] = _rooms_with("rat")
	# 입구 굴과 바로 이어진 쥐 굴들(쥐 둥지, 물웅덩이 굴)
	var ring: Array[int] = [entrance]
	for room: int in rat_rooms:
		if room != entrance and _layout.rooms[entrance].neighbors.has(room):
			ring.append(room)
	# 그 쥐 굴들 사이를 잇는 작은 굴(입구 둘, 고리 안의 두 굴과 이어짐)도 고리에 든다
	var linked: Array[int] = ring.duplicate()
	for i: int in _layout.rooms.size():
		var touching: int = 0
		for room: int in linked:
			if _layout.rooms[i].neighbors.has(room):
				touching += 1
		if not ring.has(i) and _layout.rooms[i].entrances == 2 and touching >= 2:
			ring.append(i)
	var ok: bool = ring.size() >= 3 and _layout.has_cycle(ring)
	return _check("쥐 굴들이 고리로 이어짐", ok, "쥐가 사는 굴 %s, 입구 굴(%d)과 이어진 쥐 굴까지 %s 사이에 고리 %s / %s" % [
		rat_rooms, entrance, ring, _layout.has_cycle(ring), " | ".join(_layout.describe_rooms())])


# --- 4. 막다른 굴 ---

func _dead_end() -> bool:
	var found: Array[String] = []
	for room: int in _rooms_with("chest"):
		if _layout.rooms[room].neighbors.size() == 1:
			found.append("굴 %d: 입구 %d, 이어진 굴 %s" % [room, _layout.rooms[room].entrances, _layout.rooms[room].neighbors])
			if _layout.rooms[room].entrances != 1:
				return _check("막다른 굴 입구가 하나", false, found[-1])
	return _check("막다른 굴 입구가 하나", found.size() >= 1, ", ".join(found) if not found.is_empty() else "상자가 있고 굴 하나에만 이어진 굴이 없음")


# --- 5. 전망 바위에서 박쥐 둥지가 보임 ---

func _view_rock() -> bool:
	var spot: Vector2i = load(VIEW_ROCK_SETUP).spot(_layout)
	var necromancer: Necromancer = find_necromancer()
	necromancer.global_position = _cell_center(spot)
	await wait_frames(VIEW_SETTLE_FRAMES)
	var view: Rect2 = _visible_world_rect()
	var bats: Array[Node2D] = []
	for node: Node in get_nodes_in_group(&"monsters"):
		if (node as Monster).data.id == &"bat":
			bats.append(node as Node2D)
	var seen: int = bats.filter(func(b: Node2D) -> bool: return view.has_point(b.global_position)).size()
	# 전망 자리에서 박쥐 둥지의 가장 가까운 칸까지, 다듬은 바닥을 따라 걷는 걸음 수와 곧은 거리
	var rows: PackedStringArray = (current_scene.get_node("Walls") as PlaceholderWalls).layout
	var steps: Dictionary = _steps_from(rows, spot)
	var nearest: Vector2i = Vector2i(-1, -1)
	var nearest_steps: int = 0
	for cell: Vector2i in steps:
		if _layout.room_at(cell) == _roles.bat_nest and (nearest.x < 0 or Vector2(cell).distance_to(Vector2(spot)) < Vector2(nearest).distance_to(Vector2(spot))):
			nearest = cell
			nearest_steps = steps[cell]
	var straight: float = Vector2(nearest).distance_to(Vector2(spot))
	var blocked: bool = nearest.x >= 0 and nearest_steps >= straight * VIEW_DETOUR_RATIO and not _layout.rooms[_roles.view_rock].neighbors.has(_roles.bat_nest)
	await wait_frames(1)
	return _check("전망 바위에서 박쥐 둥지가 보임", bats.size() > 0 and seen == bats.size() and blocked, "전망 자리 칸 %s, 화면 %s 안의 박쥐 %d / %d, 박쥐 둥지 가장 가까운 칸 %s까지 곧은 거리 %.0f칸, 걸어서 %d걸음 (%.0f배 이상이어야 바로 못 감), 두 굴이 이어지지 않음 %s" % [
		spot, view, seen, bats.size(), nearest, straight, nearest_steps, VIEW_DETOUR_RATIO, not _layout.rooms[_roles.view_rock].neighbors.has(_roles.bat_nest)])


## 실제 게임 화면(내부 해상도 640×360)에 보이는 월드 영역. 헤드리스 실행은 창이 달라 화면 가운데만 빌리고 크기는 내부 해상도로 잰다
func _visible_world_rect() -> Rect2:
	var viewport: Viewport = current_scene.get_viewport()
	var inverse: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var center: Vector2 = inverse * (viewport.get_visible_rect().size * 0.5)
	var size: Vector2 = inverse.basis_xform(Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height")))
	return Rect2(center - size * 0.5, size)


## start에서 4방향으로 걸어 닿는 바닥 칸마다 걸음 수
func _steps_from(rows: PackedStringArray, start: Vector2i) -> Dictionary:
	var steps: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cell + offset
			if not steps.has(n) and n.y >= 0 and n.y < rows.size() and n.x >= 0 and n.x < rows[n.y].length() and not MapLayout.WALL_CHARS.contains(rows[n.y][n.x]):
				steps[n] = steps[cell] + 1
				queue.append(n)
	return steps


# --- 5-1. 박쥐 길: 들어선 뒤 감지, 몰래 가는 길 ---

func _bat_path() -> bool:
	var rows: PackedStringArray = (current_scene.get_node("Walls") as PlaceholderWalls).layout
	var nav: NavigationGrid = current_scene.get_node("NavigationGrid")
	var detect_range: float = (load(BAT_PATH) as MonsterData).detect_range
	var fork_cell: Vector2i = Vector2i(_layout.rooms[_roles.fork].center.round())
	var junction_cell: Vector2i = Vector2i(_layout.rooms[_roles.junction].center.round())
	var result: Dictionary = BAT_PATHS.measure(rows, _layout.objects, nav, detect_range, fork_cell, junction_cell, BAT_SNEAK_MARGIN)
	var speed: float = find_necromancer().move_speed
	var entrance_seen: Array = result.entrance.filter(func(cell: Vector2i) -> bool: return result.detected.has(cell))
	var ok: bool = result.first_detect >= BAT_DETECT_DEPTH and entrance_seen.is_empty() and result.sneak_length > 0.0
	return _check("박쥐 길: 둥지에 들어선 뒤 감지, 몰래 가는 길 있음", ok, "박쥐 처음 자리 기준, 감지 %.0fpx, 감지하는 칸 %d. 입구 칸 %s 중 감지 %s. 기본 길 %.1f칸(%s) 중 처음 감지는 %.1f칸 들어선 곳 (%.0f칸 이상이어야 함, -1은 감지 안 됨). 몰래 가는 길(감지 범위 + 여유 %.0fpx 밖) %.1f칸(%s, +%.1f초, -1은 없음). 걷기 %.0f/초" % [
		detect_range, result.detected.size(), result.entrance, entrance_seen, result.default_length, _seconds(result.default_length * TILE / speed),
		result.first_detect, BAT_DETECT_DEPTH, BAT_SNEAK_MARGIN, result.sneak_length, _seconds(result.sneak_length * TILE / speed), (result.sneak_length - result.default_length) * TILE / speed, speed])


# --- 5-2. 빛 드는 굴의 멧돼지를 입구에서 먼저 본다 ---

func _boar_seen_first() -> bool:
	var entrance: Array[Vector2i] = BAT_PATHS.doorway(_layout, _roles.light_room, _roles.junction)
	var middle: Vector2 = Vector2.ZERO
	for cell: Vector2i in entrance:
		middle += _cell_center(cell)
	middle /= maxf(entrance.size(), 1)
	var boars: Array[Vector2i] = _layout.cells_of("boar").filter(func(cell: Vector2i) -> bool: return _layout.room_at(cell) == _roles.light_room)
	boars.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cell_center(a).distance_to(middle) < _cell_center(b).distance_to(middle))
	if entrance.is_empty() or boars.is_empty():
		return _check("빛 드는 굴 멧돼지를 입구에서 먼저 봄", false, "입구 칸 %s, 멧돼지 %s" % [entrance, boars])
	var boar: Vector2 = _cell_center(boars[0])
	var half: Vector2 = Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height")) * 0.5 - Vector2(BOAR_VIEW_MARGIN, BOAR_VIEW_MARGIN)
	var offset: Vector2 = (boar - middle).abs()
	var visible: bool = offset.x <= half.x and offset.y <= half.y
	var detect_range: float = (load(BOAR_PATH) as MonsterData).detect_range
	var nearest: float = INF
	for cell: Vector2i in entrance:
		nearest = minf(nearest, _cell_center(cell).distance_to(boar))
	var ok: bool = visible and nearest > detect_range
	return _check("빛 드는 굴 멧돼지를 입구에서 먼저 봄", ok, "멧돼지 처음 자리 칸 %s, 입구 칸 %s 가운데에서 떨어진 정도 %s px (화면 반 %s - 여유 %.0f 안이어야 보임: %s), 입구 칸에서 가장 가까운 거리 %.0f (감지 %.0f보다 멀어야 함, %.1f칸 더 들어가야 걸림)" % [
		boars[0], entrance, offset.round(), half + Vector2(BOAR_VIEW_MARGIN, BOAR_VIEW_MARGIN), BOAR_VIEW_MARGIN, visible, nearest, detect_range, (nearest - detect_range) / TILE])


# --- 6. 박쥐 둥지가 유일한 넓은 방 ---

func _wide_bat_nest() -> bool:
	var rows: PackedStringArray = (current_scene.get_node("Walls") as PlaceholderWalls).layout
	var smoothed: MapLayout = MapLayout.from_rows(rows, _layout.objects)
	var dive: Resource = load(DIVE_PATH)
	var bat_half: Vector2 = (load(BAT_PATH) as MonsterData).get_placeholder_half_size()
	var need: float = (dive.orbit_radius_max + maxf(bat_half.x, bat_half.y)) / TILE
	var open_cells: Dictionary = {}
	var widest: Dictionary = {}
	for y: int in smoothed.size.y:
		for x: int in smoothed.size.x:
			var room: int = smoothed.room_at(Vector2i(x, y))
			if room < 0:
				continue
			var clear: float = _clear_radius(smoothed, Vector2i(x, y))
			widest[room] = maxf(widest.get(room, 0.0), clear)
			if clear >= need:
				open_cells[room] = open_cells.get(room, 0) + 1
	var nest: int = smoothed.room_at(_layout.cells_of("bat")[0])
	var role_of: Dictionary = {}
	for role: String in _roles:
		role_of[_roles[role]] = role
	var ok: bool = open_cells.get(nest, 0) > 0
	var others: PackedStringArray = []
	for room: int in widest:
		if room == nest:
			continue
		ok = ok and widest[room] < widest[nest] and open_cells.get(room, 0) < open_cells.get(nest, 0)
		others.append("%s %d칸/%.1f" % [role_of.get(room, str(room)), open_cells.get(room, 0), widest[room]])
	return _check("박쥐 둥지가 유일한 넓은 방", ok, "다듬은 뒤, 반지름 %.1f칸(도는 반경 최대 %.0f + 박쥐 몸 %.0f px) 원이 벽에 닿지 않는 자리 / 가장 큰 원 반지름(칸): 박쥐 둥지 %d칸/%.1f, 다른 굴 %s" % [
		need, dive.orbit_radius_max, maxf(bat_half.x, bat_half.y), open_cells.get(nest, 0), widest[nest], ", ".join(others)])


## 칸 가운데에서 가장 가까운 벽 칸(정사각형)까지 거리 (칸)
func _clear_radius(layout: MapLayout, cell: Vector2i) -> float:
	var best: float = 8.0
	for oy: int in range(-8, 9):
		for ox: int in range(-8, 9):
			if layout.is_wall(cell + Vector2i(ox, oy)):
				best = minf(best, Vector2(maxf(absf(ox) - 0.5, 0.0), maxf(absf(oy) - 0.5, 0.0)).length())
	return best


# --- 7. 멧돼지 굴의 곧고 트인 길 ---

func _boar_lanes() -> bool:
	var rows: PackedStringArray = (current_scene.get_node("Walls") as PlaceholderWalls).layout
	var smoothed: MapLayout = MapLayout.from_rows(rows, _layout.objects)
	var charge: Resource = load(CHARGE_PATH)
	var need: float = (charge.charge_distance + charge.overshoot_distance) / TILE
	var results: PackedStringArray = []
	var ok: bool = true
	for room: int in _rooms_with("boar"):
		var room_after: int = smoothed.room_at(Vector2i(_layout.rooms[room].center.round()))
		var best: float = 0.0
		for y: int in smoothed.size.y:
			for x: int in smoothed.size.x:
				if smoothed.room_at(Vector2i(x, y)) != room_after:
					continue
				for direction: Vector2i in DIRECTIONS_8:
					best = maxf(best, _lane_length(smoothed, Vector2i(x, y), direction))
		ok = ok and best >= need and best <= BOAR_LANE_MAX
		results.append("굴 %d 가장 긴 곧은 길 %.1f칸" % [room, best])
	return _check("멧돼지 굴에 곧고 트인 길", ok and not results.is_empty(), "3칸 폭(가운데 칸 둘레 3×3이 바닥)으로 곧게 이어지는 길, 돌진 최대 %.0f + 지나치는 %.0f px = %.1f칸 이상, %.0f칸 이하여야 함: %s" % [
		charge.charge_distance, charge.overshoot_distance, need, BOAR_LANE_MAX, ", ".join(results)])


## start에서 direction으로, 칸 둘레 3×3이 모두 바닥인 칸이 이어지는 길이 (칸, 대각선은 √2배)
func _lane_length(layout: MapLayout, start: Vector2i, direction: Vector2i) -> float:
	var count: int = 0
	var cell: Vector2i = start
	while _open_3x3(layout, cell):
		count += 1
		cell += direction
	return maxf(count - 1, 0) * Vector2(direction).length()


func _open_3x3(layout: MapLayout, cell: Vector2i) -> bool:
	for oy: int in range(-1, 2):
		for ox: int in range(-1, 2):
			if layout.is_wall(cell + Vector2i(ox, oy)):
				return false
	return true


# --- 8. 걷기 시간 ---

func _walk_times() -> bool:
	for node: Node in get_nodes_in_group(&"monsters"):
		node.queue_free()
	await wait_frames(2)
	var necromancer: Necromancer = find_necromancer()
	var spawn: Vector2 = _cell_center(_layout.cells_of("spawn")[0])
	necromancer.global_position = spawn
	await wait_frames(2)
	var nav: NavigationGrid = current_scene.get_node("NavigationGrid")
	var started: int = Time.get_ticks_msec()
	nav.get_grid(Vector2(necromancer.body_radius, necromancer.body_radius))
	var grid_ms: int = Time.get_ticks_msec() - started
	var to_entrance: float = await _walk_to(necromancer, _room_center(_roles.entrance))
	var to_fork: float = await _walk_to(necromancer, _room_center(_roles.fork))
	var bat_path: float = await _walk_rooms(necromancer, ["bat_nest", "junction"])
	var to_mouth: float = await _walk_rooms(necromancer, ["cave_mouth"])
	await _walk_to(necromancer, _room_center(_roles.junction))
	# 거미 길은 합류 굴에서 거꾸로 걸어 잰다 (같은 길이다)
	var spider_path: float = await _walk_rooms(necromancer, ["egg", "web", "spider_gate", "fork"])
	necromancer.global_position = spawn
	await wait_frames(2)
	var total: float = await _walk_to(necromancer, _room_center(_roles.cave_mouth))
	var ok: bool = to_entrance > 0.0 and to_fork > 0.0 and bat_path > 0.0 and spider_path > 0.0 and to_mouth > 0.0 and total > 0.0
	return _check("구간별 걷기 시간", ok, "도착 지점 → 입구 굴 %s (기준 약 %.0f초), 입구 굴 → 갈림 굴 %s (기준 약 %.0f초), 갈림 굴 → 합류 굴 박쥐 길 %s · 거미 길 %s (기준 약 %.0f초, 굴 가운데를 지나며), 합류 굴 → 동굴 입구 %s (기준 약 %.0f초), 도착 지점 → 동굴 입구 전체 %s (가장 짧은 길, 기준 약 %.0f초), 걷기 %.0f/초, 네크로맨서 크기 길찾기 칸 계산 %dms" % [
		_seconds(to_entrance), TARGET_TO_ENTRANCE, _seconds(to_fork), TARGET_TO_FORK, _seconds(bat_path), _seconds(spider_path), TARGET_FORK_TO_JUNCTION,
		_seconds(to_mouth), TARGET_JUNCTION_TO_MOUTH, _seconds(total), TARGET_TOTAL, necromancer.move_speed, grid_ms])


## 굴 역할 순서대로 굴 가운데를 지나 걷는다. 걸린 시간 합(초), 하나라도 못 가면 -1
func _walk_rooms(necromancer: Necromancer, roles: Array) -> float:
	var total: float = 0.0
	for role: String in roles:
		var walked: float = await _walk_to(necromancer, _room_center(_roles[role]))
		if walked < 0.0:
			return -1.0
		total += walked
	return total


func _seconds(value: float) -> String:
	return "%.1f초" % value if value > 0.0 else "닿지 못함"


func _find_fork(entrance: int) -> int:
	for first: int in _layout.rooms[entrance].neighbors:
		for second: int in _layout.rooms[first].neighbors:
			if second != entrance and not _layout.rooms[entrance].neighbors.has(second) and _layout.rooms[second].entrances >= 3:
				return second
	return -1


## 네크로맨서를 길찾기 방향으로 걸려서 goal까지 간다. 걸린 시간(초), 못 가면 -1.
func _walk_to(necromancer: Necromancer, goal: Vector2) -> float:
	var follower: PathFollower = PathFollower.new(Vector2(necromancer.body_radius, necromancer.body_radius), Vector2(0, -necromancer.body_radius))
	var frames: int = 0
	while necromancer.global_position.distance_to(goal) > ARRIVE_DISTANCE and frames < WALK_TIMEOUT_FRAMES:
		press_moves(follower.get_direction(necromancer, goal))
		await wait_frames(1)
		frames += 1
	press_moves(Vector2.ZERO)
	await wait_frames(2)
	if frames >= WALK_TIMEOUT_FRAMES:
		return -1.0
	return frames / float(Engine.physics_ticks_per_second)


# --- 9. 언데드 2마리가 통로를 따라옴 ---

func _undead_follow() -> bool:
	var necromancer: Necromancer = find_necromancer()
	necromancer.mana.regen_per_second = TEST_MANA_REGEN
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	for i: int in 2:
		var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
		necromancer.inventory.try_add(ItemStack.of_skull(skull))
		hotbar.assign(i, skull)
		hotbar.select(i)
		necromancer.summoner.toggle_selected()
	await wait_frames(SETTLE_FRAMES)
	var undead: Array[Node] = get_nodes_in_group(&"undead")
	if not _check("쥐 언데드 2마리 소환", undead.size() == 2, "언데드 %d마리" % undead.size()):
		return false
	var route: Array[int] = _follow_route(_layout.room_at(Vector2i((necromancer.global_position / TILE).floor())))
	if not _check("굴 사이를 모두 오가는 순서", route.size() >= 2, "출발 굴 %d, 도착할 굴 %s" % [_layout.room_at(Vector2i((necromancer.global_position / TILE).floor())), route]):
		return false
	var legs: PackedStringArray = []
	var worst_gather: int = 0
	for room: int in route:
		var center: Vector2 = _layout.rooms[room].center.round()
		var walked: float = await _walk_to(necromancer, _room_center(room))
		if walked < 0.0:
			return _check("언데드 2마리가 통로를 따라옴", false, "굴 %d(칸 %s)에 닿지 못함 (지난 구간 %s)" % [room, center, ", ".join(legs)])
		var gathered: int = -1
		for frame: int in GATHER_FRAMES:
			if get_nodes_in_group(&"undead").all(func(u: Node) -> bool: return (u as Node2D).global_position.distance_to(necromancer.global_position) <= GATHER_DISTANCE):
				gathered = frame
				break
			await wait_frames(1)
		var count: int = get_nodes_in_group(&"undead").size()
		if gathered < 0 or count != 2:
			var distances: PackedStringArray = []
			for u: Node in get_nodes_in_group(&"undead"):
				distances.append("%.0f (칸 %s)" % [(u as Node2D).global_position.distance_to(necromancer.global_position), ((u as Node2D).global_position / TILE).snapped(Vector2(0.1, 0.1))])
			return _check("언데드 2마리가 통로를 따라옴", false, "칸 %s에서 %d프레임 안에 모이지 않음: 언데드 %d마리, 거리 %s (지난 구간 %s)" % [center, GATHER_FRAMES, count, ", ".join(distances), ", ".join(legs)])
		worst_gather = maxi(worst_gather, gathered)
		legs.append("굴 %d %.1f초/%d프레임" % [room, walked, gathered])
	return _check("언데드 2마리가 통로를 따라옴", true, "굴 사이 통로 %d개를 모두 오감 (%d구간), 굴마다 (걷기 / 멈춘 뒤 모두 %.0f 안에 모이기까지): %s, 가장 늦게 모인 것 %d프레임" % [route.size() / 2, route.size(), GATHER_DISTANCE, ", ".join(legs), worst_gather])


## start에서 이어진 굴로 갔다가 돌아오기를 되풀이해, 이어진 두 굴 사이를 모두 한 번씩 오가는 굴 순서 (start는 빼고 도착하는 굴들)
func _follow_route(start: int) -> Array[int]:
	var route: Array[int] = []
	_visit_links(start, route, {})
	return route


func _visit_links(room: int, route: Array[int], used: Dictionary) -> void:
	for next: int in _layout.rooms[room].neighbors:
		var key: Vector2i = Vector2i(mini(room, next), maxi(room, next))
		if used.has(key):
			continue
		used[key] = true
		route.append(next)
		_visit_links(next, route, used)
		route.append(room)


# --- 10. 언데드가 바위를 돌아 따라옴 ---

func _around_rocks() -> bool:
	var scene_rows: PackedStringArray = (current_scene.get_node("Walls") as PlaceholderWalls).layout
	var carved: Array[Vector2i] = []
	for rock: Dictionary in _layout.rocks:
		for cell: Vector2i in rock.cells:
			if not MapLayout.WALL_CHARS.contains(scene_rows[cell.y][cell.x]):
				carved.append(cell)
	if not _check("다듬어도 바위가 남음", not _layout.rocks.is_empty() and carved.is_empty(), "바위 %d개, 다듬은 씬에서 바닥이 된 바위 칸 %s" % [_layout.rocks.size(), carved]):
		return false
	var necromancer: Necromancer = find_necromancer()
	var results: PackedStringArray = []
	for rock: Dictionary in _layout.rocks:
		var sides: Array[Vector2] = _rock_sides(rock, scene_rows)
		var rect: Rect2i = rock.rect
		if sides.is_empty():
			return _check("언데드가 바위를 돌아 따라옴", false, "굴 %d의 바위 %s 양쪽에 설 자리가 없음" % [rock.room, rect])
		if await _walk_to(necromancer, sides[0]) < 0.0:
			return _check("언데드가 바위를 돌아 따라옴", false, "굴 %d의 바위 %s 한쪽(%s)에 닿지 못함" % [rock.room, rect, sides[0] / TILE])
		var start_gather: int = await _gather_frames(necromancer)
		var walked: float = await _walk_to(necromancer, sides[1])
		var gathered: int = await _gather_frames(necromancer)
		if start_gather < 0 or walked < 0.0 or gathered < 0:
			var distances: PackedStringArray = []
			for u: Node in get_nodes_in_group(&"undead"):
				distances.append("%.0f (칸 %s)" % [(u as Node2D).global_position.distance_to(necromancer.global_position), ((u as Node2D).global_position / TILE).snapped(Vector2(0.1, 0.1))])
			return _check("언데드가 바위를 돌아 따라옴", false, "굴 %d의 바위 %s: 처음 모임 %d프레임, 반대쪽까지 걷기 %.1f초, 반대쪽에서 모임 %d프레임 (%d프레임 안), 거리 %s" % [rock.room, rect, start_gather, walked, gathered, GATHER_FRAMES, ", ".join(distances)])
		results.append("굴 %d %d×%d %.1f초/%d프레임" % [rock.room, rect.size.x, rect.size.y, walked, gathered])
	return _check("언데드가 바위를 돌아 따라옴", true, "바위 %d개 모두 한쪽에서 모은 뒤 바위 너머 반대쪽으로 감 (두 자리를 잇는 직선이 바위를 지남), 바위마다 (반대쪽까지 걷기 / 멈춘 뒤 모두 %.0f 안에 모이기까지): %s" % [_layout.rocks.size(), GATHER_DISTANCE, ", ".join(results)])


## 바위를 가운데 두고 마주 보는 두 자리 (월드 좌표). 바위 가장자리에서 ROCK_SIDE_GAPS칸(먼 것부터) 떨어지고,
## 둘 다 설 수 있는(2×2 바닥에 드는) 첫 거리·방향을 쓴다. 없으면 빈 배열
func _rock_sides(rock: Dictionary, rows: PackedStringArray) -> Array[Vector2]:
	var rect: Rect2i = rock.rect
	var center: Vector2 = Vector2(rect.position) + Vector2(rect.size) * 0.5
	for gap: float in ROCK_SIDE_GAPS:
		for direction: Vector2 in ROCK_DIRECTIONS:
			var half: float = 0.0
			for cell: Vector2i in rock.cells:
				half = maxf(half, absf((Vector2(cell) + Vector2(0.5, 0.5) - center).dot(direction)) + 0.5 * (absf(direction.x) + absf(direction.y)))
			var sides: Array[Vector2] = []
			for side_sign: float in [-1.0, 1.0]:
				var point: Vector2 = center + direction * side_sign * (half + gap)
				if _open_around(rows, Vector2i(point.floor()), rock.cells):
					sides.append(point * TILE)
			if sides.size() == 2:
				return sides
	return [] as Array[Vector2]


## cell이 바닥이고 2×2 바닥 덩어리에 드는지 (바위 둘레 길 규칙과 같은 기준. 그 바위 칸은 바닥이 아니다)
func _open_around(rows: PackedStringArray, cell: Vector2i, rock_cells: Array) -> bool:
	for corner: Vector2i in [cell, cell - Vector2i(1, 0), cell - Vector2i(0, 1), cell - Vector2i(1, 1)]:
		var open: bool = true
		for c: Vector2i in [corner, corner + Vector2i(1, 0), corner + Vector2i(0, 1), corner + Vector2i(1, 1)]:
			if rock_cells.has(c) or c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= rows[c.y].length() or MapLayout.WALL_CHARS.contains(rows[c.y][c.x]):
				open = false
		if open:
			return true
	return false


## 언데드가 모두 네크로맨서 곁(GATHER_DISTANCE)에 모이기까지 걸린 프레임. GATHER_FRAMES 안에 못 모이거나 2마리가 아니면 -1
func _gather_frames(necromancer: Necromancer) -> int:
	for frame: int in GATHER_FRAMES:
		var undead: Array[Node] = get_nodes_in_group(&"undead")
		if undead.size() == 2 and undead.all(func(u: Node) -> bool: return (u as Node2D).global_position.distance_to(necromancer.global_position) <= GATHER_DISTANCE):
			return frame
		await wait_frames(1)
	return -1


# --- 11. 갈림길 하나를 넘어 멧돼지를 만나지 않고 탈출 B ---

func _escape_without_boars() -> bool:
	var results: PackedStringArray = []
	for route: Array in [["bat_nest", "junction"], ["spider_gate", "web", "egg", "junction"]]:
		current_scene.call(&"travel_to", load(BASE_REGION))
		if not await _wait_scene(BASE_SCENE):
			return _check("탈출 B까지 멧돼지 없이", false, "거점에 가지 못함")
		current_scene.call(&"travel_to", load(CAVE_REGION))
		if not await _wait_scene(CAVE_SCENE):
			return _check("탈출 B까지 멧돼지 없이", false, "얕은 굴에 다시 들어가지 못함")
		await wait_frames(SETTLE_FRAMES)
		var boars: Array[Monster] = []
		for node: Node in get_nodes_in_group(&"monsters"):
			if (node as Monster).data.id == &"boar":
				boars.append(node as Monster)
			else:
				node.queue_free()
		var necromancer: Necromancer = find_necromancer()
		necromancer.global_position = _room_center(_roles.fork)
		await wait_frames(2)
		var goals: Array[Vector2] = []
		for role: String in route:
			goals.append(_room_center(_roles[role]))
		for cell: Vector2i in _layout.cells_of("escape"):
			if _layout.room_at(cell) == _roles.junction:
				goals.append(_cell_center(cell))
		var targeted: PackedStringArray = []
		var frames: int = 0
		var follower: PathFollower = PathFollower.new(Vector2(necromancer.body_radius, necromancer.body_radius), Vector2(0, -necromancer.body_radius))
		for goal: Vector2 in goals:
			while necromancer.global_position.distance_to(goal) > ARRIVE_DISTANCE and frames < WALK_TIMEOUT_FRAMES:
				press_moves(follower.get_direction(necromancer, goal))
				await wait_frames(1)
				frames += 1
				_note_boar_targets(boars, targeted)
		press_moves(Vector2.ZERO)
		var escaped: bool = false
		for i: int in ESCAPE_WAIT_FRAMES:
			await wait_frames(1)
			if current_scene != null and current_scene.scene_file_path == BASE_SCENE:
				escaped = true
				break
			_note_boar_targets(boars, targeted)
		var name: String = "박쥐 길" if route[0] == "bat_nest" else "거미 길"
		results.append("%s: 갈림 굴 → 탈출 B %.1f초, 거점 도착 %s, 멧돼지 %d마리 중 누군가를 노린 멧돼지 %s" % [name, frames / float(Engine.physics_ticks_per_second), escaped, boars.size(), targeted])
		if not escaped or not targeted.is_empty() or boars.is_empty():
			return _check("탈출 B까지 멧돼지 없이", false, " / ".join(results))
	return _check("탈출 B까지 멧돼지 없이", true, "멧돼지만 남긴 채 갈림 굴에서 걸음: " + " / ".join(results))


func _note_boar_targets(boars: Array[Monster], targeted: PackedStringArray) -> void:
	for boar: Monster in boars:
		if is_instance_valid(boar) and boar.get_target() != null and not targeted.has(boar.name):
			targeted.append(boar.name)


# --- 12. 다시 들어오면 몬스터가 다시 놓임 ---

func _monsters_reset() -> bool:
	current_scene.call(&"travel_to", load(BASE_REGION))
	if not await _wait_scene(BASE_SCENE):
		return _check("거점으로", false, "거점에 가지 못함")
	current_scene.call(&"travel_to", load(CAVE_REGION))
	if not await _wait_scene(CAVE_SCENE):
		return _check("얕은 굴로", false, "얕은 굴에 다시 들어가지 못함")
	await wait_frames(SETTLE_FRAMES)
	var count: int = get_nodes_in_group(&"monsters").size()
	return _check("다시 들어오면 몬스터가 처음대로", count == _monster_cells(), "몬스터를 없앤 뒤 거점에 갔다 오니 몬스터 %d마리 (PNG의 몬스터 %d)" % [count, _monster_cells()])


func _wait_scene(path: String) -> bool:
	for i: int in SCENE_TIMEOUT_FRAMES:
		await wait_frames(1)
		if current_scene != null and current_scene.scene_file_path == path and current_scene.is_node_ready():
			return true
	return false
