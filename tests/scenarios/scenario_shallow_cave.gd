extends ShallowCaveScenario
## 시나리오: 얕은 굴 그레이박스(앞·뒤 절반 모두)의 구조. 배치 PNG(art_src/maps/shallow_cave.png)와 만든 씬(regions/shallow_cave.tscn)을 같이 본다. 걷기는 scenario_shallow_cave_walk.gd, 언데드는 scenario_shallow_cave_undead.gd.
## 1. 씬이 PNG와 같다 (PNG를 고치고 tools/map_from_png.gd를 다시 돌리지 않았으면 실패). 바닥은 최소 2칸, 모든 물건에 걸어서 닿음. 몬스터·상자·탈출 지점 수
## 1-1. 길찾기 격자: 벽 타일에서 바로 계산한 막힌 칸이 물리 질의로 잰 것과 같다 (두 방법의 시간 출력)
## 2. 굴 역할을 찾고, 굴마다 입구 수와 이어진 굴이 설계 문서(docs/maps/shallow_cave_design.md 배치도)와 같다. 2칸 길목은 "좁은 길목 8곳" 표의 통로에만 있다
## 3. 쥐가 사는 굴들이 고리로 이어져 있다 (입구 굴·쥐 둥지·물웅덩이 굴과 그 사이를 잇는 작은 굴 사이에 돌아오는 길이 있다)
## 4. 상자가 있고 굴 하나에만 이어진 굴(막다른 굴, 둥지 뒷굴)은 입구가 하나다
## 5. 전망 바위의 전망 자리(tools/screenshot_setups/view_rock.gd)에서 박쥐 둥지로 바로 가는 길이 없다. 박쥐가 화면 안인지는 출력만 한다 (2배 맵, 3D 이전 때 다시 정함)
## 5-1. 박쥐 길 (tests/bat_nest_paths.gd, 박쥐의 처음 자리 기준): 갈림 굴 쪽 입구에서 합류 굴 쪽 출구까지 가장 짧은 길(기본 길)은
##    박쥐에게 감지되고, 감지되는 곳은 입구에서 BAT_DETECT_DEPTH칸 이상 들어선 뒤다. 감지 범위보다 BAT_SNEAK_MARGIN 더 떨어져 지나는 길(몰래 가는 길)이 있다. 두 길의 길이·걷는 시간을 출력한다
## 5-2. 빛 드는 굴의 합류 굴 쪽 입구에 서면 가장 가까운 멧돼지(처음 자리, 무리면 무리 자리)가 화면 안에 보이고, 입구 칸은 모두 멧돼지 감지 거리 밖이다
##    (무리 자리면 흩어 놓기 범위 PACK_SPREAD만큼 더 떨어져야 한다)
## 6. 박쥐 둥지에 박쥐가 돌 공간(도는 반경 + 몸의 원이 벽에 닿지 않는 자리)이 있다. 2배 맵은 다른 큰 굴도 넓어서 "유일"은 보지 않는다 (사용자 결정, 2026-11-10)
## 7. 멧돼지가 사는 굴마다 돌진(돌진 최대 거리 + 지나치는 거리)보다 긴 곧고 트인 길(3칸 폭)이 있고. 가장 긴 것이 BOAR_LANE_MAX칸을 넘는지는 출력만 한다 (바위가 긴 직선을 끊어 돌진을 피할 곳이 있게).
##    굴 안만, 가로·세로만 잰다 (통로까지 이어 재지 않음, 대각선과 문을 지나는 줄은 기준에서 뺌)

const BAT_PATH: String = "res://data/monsters/bat.tres"
const DIVE_PATH: String = "res://data/behaviors/dive.tres"
const CHARGE_PATH: String = "res://data/behaviors/charge.tres"
## 설계 문서 "좁은 길목 8곳": 2칸 길목이 있어야 하는 통로 (양 끝 굴 역할). 다른 통로에는 길목이 없어야 한다
const CHOKE_PAIRS: Array = [
	["puddle", "dead_end"], ["fork", "bat_nest"], ["fork", "spider_gate"], ["web", "egg"],
	["egg", "junction"], ["bat_nest", "junction"], ["junction", "light_room"], ["junction", "cave_mouth"],
]
## 5. 전망 자리에 선 뒤 카메라가 자리 잡기를 기다리는 프레임
const VIEW_SETTLE_FRAMES: int = 10
## 5. 바로 가는 길이 없다고 보려면, 전망 자리에서 박쥐 둥지까지 걷는 걸음 수가 곧은 거리의 이 배 이상이어야 한다
const VIEW_DETOUR_RATIO: float = 3.0
## 5-1. 기본 길에서 박쥐가 처음 감지하는 곳이 둥지 입구에서 적어도 이만큼(칸) 들어선 뒤여야 한다 (길목을 나서자마자 걸리지 않게)
const BAT_DETECT_DEPTH: float = 3.0
## 5-1. 몰래 가는 길은 박쥐 감지 범위보다 이만큼(픽셀) 더 떨어져 지나야 한다. 박쥐는 싸우지 않을 때 배회하므로(초당 15px), 둥지에 닿기까지 옮겨 간 만큼의 여유
const BAT_SNEAK_MARGIN: float = 96.0
const BAT_PATHS = preload("res://tests/bat_nest_paths.gd")
const OUTLINE_ROWS = preload("res://tests/outline_rows.gd")
const NAV_GRID_CHECK = preload("res://tests/nav_grid_check.gd")
## 5-2. 멧돼지가 화면 가장자리에서 이만큼(픽셀) 안쪽에 있어야 보인다고 본다
const BOAR_VIEW_MARGIN: float = 16.0
## 무리 자리에서 무리원을 흩어 놓는 범위 (PackSpawn.spread_radius 기본값, 사용자 결정 2026-11-14 임시값)
const PACK_SPREAD: float = 48.0
const BOAR_PATH: String = "res://data/monsters/boar.tres"
## 7. 멧돼지 굴의 가장 긴 3칸 폭 곧은 길의 기준 (칸). 윤곽으로 바꾼 뒤 넘는 굴이 있어 멧돼지 밸런스 조정 때까지 출력만 한다 (사용자 결정, 2026-11-11)
const BOAR_LANE_MAX: float = 13.0
## 7. 멧돼지 굴 곧은 길은 가로·세로만 본다 (대각선은 기준에서 뺌, 사용자 결정 2026-11-08)
const LANE_DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
## 7. 곧은 길과 직각으로 트인 폭이 이 이하인 칸은 문으로 보고 줄을 끊는다 (칸)
const LANE_DOOR_SPAN: int = 5


func _run_steps() -> void:
	if not await _matches_png():
		return
	if not _tile_grid_matches():
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
	finish(true)


# --- 1. 씬이 PNG와 같다 ---

func _matches_png() -> bool:
	var walls: PlaceholderWalls = current_scene.get_node("Walls")
	var same_layout: bool = walls.layout == _layout.rows
	var narrow: Array[Vector2i] = MapLayout.narrow_cells(walls.layout)
	var reach: Dictionary = MapLayout.reachable(walls.layout, _layout.cells_of("spawn")[0])
	var unreachable: int = _layout.objects.filter(func(o: Dictionary) -> bool: return not reach.has(o.cell)).size()
	var monsters: int = get_nodes_in_group(&"monsters").size()
	var chests: int = current_scene.find_children("*", "LootChest", true, false).size()
	var escapes: int = current_scene.find_children("*", "EscapePoint", true, false).size()
	var nav: NavigationGrid = current_scene.get_node("NavigationGrid")
	var ok: bool = _layout.errors.is_empty() and same_layout and narrow.is_empty() and unreachable == 0 and monsters == _expected_monsters() and chests == _layout.cells_of("chest").size() and escapes == _layout.cells_of("escape").size() and nav.has_walls()
	return _check("씬이 배치 PNG와 같음", ok, "PNG %d×%d칸, 읽기 문제 %s, 벽·바닥이 PNG와 같음 %s, 2칸보다 좁은 바닥 %s, 도착 지점에서 닿지 않는 물건 %d, 몬스터 %d (PNG 한 마리 + 무리원 %d), 상자 %d (PNG %d), 탈출 지점 %d (PNG %d), 길찾기 벽 있음 %s" % [
		_layout.size.x, _layout.size.y, _layout.errors, same_layout, narrow, unreachable, monsters, _expected_monsters(), chests, _layout.cells_of("chest").size(), escapes, _layout.cells_of("escape").size(), nav.has_walls()])


# --- 2. 굴 연결 ---

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
	var bats: Array[Node2D] = []
	for node: Node in get_nodes_in_group(&"monsters"):
		# 두 번째 무리(박쥐 아래 굴)는 전망 바위에서 보는 대상이 아니다.
		if (node as Monster).data.id == &"bat" and _layout.room_at(Vector2i(((node as Node2D).global_position / TILE).floor())) == _roles.bat_nest:
			bats.append(node as Node2D)
	var half_screen: Vector2 = _half_screen()
	var seen: int = bats.filter(func(b: Node2D) -> bool:
		var offset: Vector2 = _screen_offset(necromancer.global_position, b.global_position).abs()
		return offset.x <= half_screen.x and offset.y <= half_screen.y).size()
	# 전망 자리에서 박쥐 둥지의 가장 가까운 칸까지, 바닥을 따라 걷는 걸음 수와 곧은 거리
	var rows: PackedStringArray = OUTLINE_ROWS.of(current_scene.get_node("Walls") as PlaceholderWalls)
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
	# 2배 맵에서는 전망 자리에서 박쥐가 보이는 자리와 박쥐 길 규칙을 맞는 자리가 겹치지 않는다. 박쥐가 화면 안인지는 출력만 하고 3D 이전 때 맵과 함께 다시 정한다 (사용자 결정, 2026-11-10).
	return _check("전망 바위에서 박쥐 둥지로 바로 못 감", bats.size() > 0 and blocked, "전망 자리 칸 %s, 3D 화면 안의 박쥐 %d / %d (판정 안 함), 박쥐 둥지 가장 가까운 칸 %s까지 곧은 거리 %.0f칸, 걸어서 %d걸음 (%.0f배 이상이어야 바로 못 감), 두 굴이 이어지지 않음 %s" % [
		spot, seen, bats.size(), nearest, straight, nearest_steps, VIEW_DETOUR_RATIO, not _layout.rooms[_roles.view_rock].neighbors.has(_roles.bat_nest)])


## 실제 게임 화면(내부 해상도 640×360)의 반 크기
func _half_screen() -> Vector2:
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height")) * 0.5


## feet에 섰을 때(앞서 가기 없이) point가 3D 화면 가운데에서 떨어진 정도 (내부 해상도 픽셀)
func _screen_offset(feet: Vector2, point: Vector2) -> Vector2:
	var view: RegionView3D = RegionView3D.new()
	var offset: Vector2 = ViewSpace.screen_offset(feet, point, 0.0, view.pitch_degrees, view.yaw_degrees, view.fov_degrees, ProjectSettings.get_setting("display/window/size/viewport_height"))
	view.free()
	return offset


## 1-1. 길찾기 격자: 막힌 칸을 벽 타일에서 바로 계산하고(빠름), 그 결과가 물리 질의로 잰 것과 같다. 두 방법에 걸린 시간을 출력한다.
func _tile_grid_matches() -> bool:
	var nav: NavigationGrid = current_scene.get_node("NavigationGrid")
	var same: Dictionary = NAV_GRID_CHECK.compare(nav, current_scene.get_node("Walls") as PlaceholderWalls, find_necromancer().body_radius)
	return _check("길찾기 격자: 타일로 잰 막힌 칸이 물리 질의와 같음", same.ok and not nav.wall_tiles.is_empty(), "wall_tiles %s, 몸 크기 %d가지 합계 타일 %dms / 물리 %dms: %s" % [
		nav.wall_tiles, same.lines.size(), same.tile_ms, same.physics_ms, ", ".join(same.lines)])


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
	var rows: PackedStringArray = OUTLINE_ROWS.of(current_scene.get_node("Walls") as PlaceholderWalls)
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
	var boars: Array[Vector2i] = _cells_with("boar").filter(func(cell: Vector2i) -> bool: return _layout.room_at(cell) == _roles.light_room)
	boars.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cell_center(a).distance_to(middle) < _cell_center(b).distance_to(middle))
	if entrance.is_empty() or boars.is_empty():
		return _check("빛 드는 굴 멧돼지를 입구에서 먼저 봄", false, "입구 칸 %s, 멧돼지 %s" % [entrance, boars])
	var boar: Vector2 = _cell_center(boars[0])
	var half: Vector2 = _half_screen() - Vector2(BOAR_VIEW_MARGIN, BOAR_VIEW_MARGIN)
	var offset: Vector2 = _screen_offset(middle, boar).abs()
	var visible: bool = offset.x <= half.x and offset.y <= half.y
	var detect_range: float = (load(BOAR_PATH) as MonsterData).detect_range
	var nearest: float = INF
	for cell: Vector2i in entrance:
		nearest = minf(nearest, _cell_center(cell).distance_to(boar))
	# 무리 자리면 무리원이 자리에서 흩어 놓기 범위(PackSpawn.spread_radius)만큼 입구 쪽으로 나와 있을 수 있다
	var spread: float = 0.0 if _layout.cells_of("boar").has(boars[0]) else PACK_SPREAD
	var ok: bool = visible and nearest - spread > detect_range
	return _check("빛 드는 굴 멧돼지를 입구에서 먼저 봄", ok, "멧돼지 처음 자리 칸 %s, 입구 칸 %s 가운데에서 떨어진 정도 %s px (화면 반 %s - 여유 %.0f 안이어야 보임: %s), 입구 칸에서 가장 가까운 거리 %.0f - 흩어 놓기 %.0f (감지 %.0f보다 멀어야 함, %.1f칸 더 들어가야 걸림)" % [
		boars[0], entrance, offset.round(), half + Vector2(BOAR_VIEW_MARGIN, BOAR_VIEW_MARGIN), BOAR_VIEW_MARGIN, visible, nearest, spread, detect_range, (nearest - spread - detect_range) / TILE])


# --- 6. 박쥐 둥지가 유일한 넓은 방 ---

func _wide_bat_nest() -> bool:
	var rows: PackedStringArray = OUTLINE_ROWS.of(current_scene.get_node("Walls") as PlaceholderWalls)
	var scene_layout: MapLayout = MapLayout.from_rows(rows, _layout.objects)
	var dive: Resource = load(DIVE_PATH)
	var bat_half: Vector2 = (load(BAT_PATH) as MonsterData).get_placeholder_half_size()
	var need: float = (dive.orbit_radius_max + maxf(bat_half.x, bat_half.y)) / TILE
	var open_cells: Dictionary = {}
	var widest: Dictionary = {}
	for y: int in scene_layout.size.y:
		for x: int in scene_layout.size.x:
			var room: int = scene_layout.room_at(Vector2i(x, y))
			if room < 0:
				continue
			var clear: float = _clear_radius(scene_layout, Vector2i(x, y))
			widest[room] = maxf(widest.get(room, 0.0), clear)
			if clear >= need:
				open_cells[room] = open_cells.get(room, 0) + 1
	var nest: int = scene_layout.room_at(_layout.cells_of("bat")[0])
	var role_of: Dictionary = {}
	for role: String in _roles:
		role_of[_roles[role]] = role
	var ok: bool = open_cells.get(nest, 0) > 0
	var others: PackedStringArray = []
	for room: int in widest:
		if room == nest:
			continue
		others.append("%s %d칸/%.1f" % [role_of.get(room, str(room)), open_cells.get(room, 0), widest[room]])
	return _check("박쥐 둥지에 박쥐가 돌 공간이 있음", ok, "반지름 %.1f칸(도는 반경 최대 %.0f + 박쥐 몸 %.0f px) 원이 벽에 닿지 않는 자리 / 가장 큰 원 반지름(칸): 박쥐 둥지 %d칸/%.1f, 다른 굴 %s" % [
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
	var rows: PackedStringArray = OUTLINE_ROWS.of(current_scene.get_node("Walls") as PlaceholderWalls)
	var scene_layout: MapLayout = MapLayout.from_rows(rows, _layout.objects)
	var charge: Resource = load(CHARGE_PATH)
	var need: float = (charge.charge_distance + charge.overshoot_distance) / TILE
	var results: PackedStringArray = []
	var ok: bool = true
	for room: int in _rooms_with("boar"):
		var room_after: int = scene_layout.room_at(Vector2i(_layout.rooms[room].center.round()))
		var best: float = 0.0
		for y: int in scene_layout.size.y:
			for x: int in scene_layout.size.x:
				if scene_layout.room_at(Vector2i(x, y)) != room_after:
					continue
				for direction: Vector2i in LANE_DIRECTIONS:
					best = maxf(best, _lane_length(scene_layout, Vector2i(x, y), direction, room_after))
		ok = ok and best >= need
		results.append("굴 %d 가장 긴 곧은 길 %.1f칸" % [room, best])
	return _check("멧돼지 굴에 곧고 트인 길", ok and not results.is_empty(), "3칸 폭(가운데 칸 둘레 3×3이 바닥)으로 곧게 이어지는 길, 돌진 최대 %.0f + 지나치는 %.0f px = %.1f칸 이상이어야 함 (기준 %.0f칸을 넘는지는 판정하지 않고 출력만 한다, 멧돼지 밸런스 조정 때 다시 본다): %s" % [
		charge.charge_distance, charge.overshoot_distance, need, BOAR_LANE_MAX, ", ".join(results)])


## start에서 direction으로, 칸 둘레 3×3이 모두 바닥인 칸이 이어지는 길이 (칸, 대각선은 √2배)
## 문(길과 직각으로 트인 폭이 LANE_DOOR_SPAN칸 이하인 곳)을 만나면 끊는다. 방 나누기의 3~4칸 문을 지나는 줄은 기준에서 뺀다 (사용자 결정).
func _lane_length(layout: MapLayout, start: Vector2i, direction: Vector2i, room: int) -> float:
	var count: int = 0
	var cell: Vector2i = start
	var across: Vector2i = Vector2i(direction.y, direction.x)
	while _open_3x3(layout, cell) and layout.room_at(cell) == room and _open_span(layout, cell, across, room) > LANE_DOOR_SPAN:
		count += 1
		cell += direction
	return maxf(count - 1, 0) * Vector2(direction).length()


## cell에서 direction 양쪽으로, 같은 굴의 벽 아닌 칸이 이어진 수
func _open_span(layout: MapLayout, cell: Vector2i, direction: Vector2i, room: int) -> int:
	var count: int = 1
	for sign: int in [1, -1]:
		var p: Vector2i = cell + direction * sign
		while not layout.is_wall(p) and layout.room_at(p) == room:
			count += 1
			p += direction * sign
	return count


func _open_3x3(layout: MapLayout, cell: Vector2i) -> bool:
	for oy: int in range(-1, 2):
		for ox: int in range(-1, 2):
			if layout.is_wall(cell + Vector2i(ox, oy)):
				return false
	return true
