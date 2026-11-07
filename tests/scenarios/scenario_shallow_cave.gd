extends ScenarioTest
## 시나리오: 얕은 굴(앞쪽 절반) 그레이박스. 배치 PNG(art_src/maps/shallow_cave.png)와 만든 씬(regions/shallow_cave.tscn)을 같이 본다.
## 1. 씬이 PNG(를 다듬은 결과)와 같다 (PNG를 고치고 tools/map_from_png.gd를 다시 돌리지 않았으면 실패). 바닥은 최소 2칸, 모든 물건에 걸어서 닿음. 쥐·상자·탈출 지점 수
## 2. 쥐가 사는 굴들이 고리로 이어져 있다 (입구 굴·쥐 둥지·물웅덩이 굴 사이에 돌아오는 길이 있다)
## 3. 막다른 굴(상자가 있고 입구가 하나인 굴)이 있고, 입구가 하나다
## 4. 구간별 걷기 시간: 도착 지점 → 입구 굴, 입구 굴 → 갈림 굴 (걷기, 몬스터는 없앰). 문서 기준값(약 10초, 약 30초)과 함께 출력한다
## 5. 지역을 나갔다 다시 들어오면 몬스터가 처음 상태로 다시 놓인다 (임시 규칙)
## 굴 찾기: 입구 굴 = 탈출 지점이 있는 굴, 갈림 굴 = 입구 굴에서 굴 두 개 건너에 있는, 입구가 셋 이상인 굴.

const MAP_PNG: String = "res://art_src/maps/shallow_cave.png"
const CAVE_SCENE: String = "res://regions/shallow_cave.tscn"
const BASE_SCENE: String = "res://regions/base.tscn"
const CAVE_REGION: String = "res://data/regions/shallow_cave.tres"
const BASE_REGION: String = "res://data/regions/base.tres"
## 문서(docs/maps/shallow_cave_design.md 4장)의 걷기 시간 기준 (초)
const TARGET_TO_ENTRANCE: float = 10.0
const TARGET_TO_FORK: float = 30.0
## 굴 가운데에서 이 거리 안이면 닿은 것으로 본다 (픽셀)
const ARRIVE_DISTANCE: float = 16.0
## 한 구간을 걷는 최대 시간 (프레임)
const WALK_TIMEOUT_FRAMES: int = 60 * 90
const SETTLE_FRAMES: int = 6
const SCENE_TIMEOUT_FRAMES: int = 300
const TILE: float = 32.0

var _layout: MapLayout


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


func _room_with(object: String) -> int:
	for o: Dictionary in _layout.objects:
		if o.object == object:
			return _layout.room_at(o.cell)
	return -1


func _room_center(room: int) -> Vector2:
	return (_layout.rooms[room].center + Vector2(0.5, 0.5)) * TILE


func _run() -> void:
	_layout = MapLayout.from_file(MAP_PNG)
	await wait_frames(SETTLE_FRAMES)
	if not await _matches_png():
		return
	var entrance: int = _room_with("escape")
	if not _ring(entrance):
		return
	if not _dead_end():
		return
	if not await _walk_times(entrance):
		return
	if not await _monsters_reset():
		return
	finish(true)


# --- 1. 씬이 PNG와 같다 ---

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
	var rats: int = 0
	for node: Node in get_nodes_in_group(&"monsters"):
		if (node as Monster).data.id == &"rat":
			rats += 1
	var chests: int = current_scene.find_children("*", "LootChest", true, false).size()
	var escapes: int = current_scene.find_children("*", "EscapePoint", true, false).size()
	var nav: NavigationGrid = current_scene.get_node("NavigationGrid")
	var ok: bool = _layout.errors.is_empty() and same_layout and changed > 0 and narrow.is_empty() and unreachable == 0 and rats == _layout.cells_of("rat").size() and chests == 2 and escapes == 1 and nav.has_walls()
	return _check("씬이 배치 PNG와 같음", ok, "PNG %d×%d칸, 읽기 문제 %s, 벽·바닥이 PNG를 다듬은 결과와 같음 %s (다듬어 바뀐 칸 %d), 2칸보다 좁은 바닥 %s, 도착 지점에서 닿지 않는 물건 %d, 쥐 %d (PNG %d), 상자 %d, 탈출 지점 %d, 길찾기 벽 있음 %s" % [
		_layout.size.x, _layout.size.y, _layout.errors, same_layout, changed, narrow, unreachable, rats, _layout.cells_of("rat").size(), chests, escapes, nav.has_walls()])


# --- 2. 쥐 굴 고리 ---

func _ring(entrance: int) -> bool:
	var rat_rooms: Array[int] = []
	for cell: Vector2i in _layout.cells_of("rat"):
		var room: int = _layout.room_at(cell)
		if room >= 0 and not rat_rooms.has(room):
			rat_rooms.append(room)
	# 입구 굴과 바로 이어진 쥐 굴들(쥐 둥지, 물웅덩이 굴)
	var ring: Array[int] = [entrance]
	for room: int in rat_rooms:
		if room != entrance and _layout.rooms[entrance].neighbors.has(room):
			ring.append(room)
	var ok: bool = ring.size() >= 3 and _layout.has_cycle(ring)
	return _check("쥐 굴들이 고리로 이어짐", ok, "쥐가 사는 굴 %s, 입구 굴(%d)과 이어진 쥐 굴까지 %s 사이에 고리 %s / %s" % [
		rat_rooms, entrance, ring, _layout.has_cycle(ring), " | ".join(_layout.describe_rooms())])


# --- 3. 막다른 굴 ---

func _dead_end() -> bool:
	var found: Array[String] = []
	for i: int in _layout.rooms.size():
		var has_chest: bool = false
		for cell: Vector2i in _layout.cells_of("chest"):
			has_chest = has_chest or _layout.room_at(cell) == i
		if has_chest and _layout.rooms[i].neighbors.size() == 1:
			found.append("굴 %d: 입구 %d, 이어진 굴 %s" % [i, _layout.rooms[i].entrances, _layout.rooms[i].neighbors])
			if _layout.rooms[i].entrances != 1:
				return _check("막다른 굴 입구가 하나", false, found[-1])
	return _check("막다른 굴 입구가 하나", found.size() == 1, ", ".join(found) if not found.is_empty() else "상자가 있고 굴 하나에만 이어진 굴이 없음")


# --- 4. 걷기 시간 ---

func _walk_times(entrance: int) -> bool:
	var fork: int = _find_fork(entrance)
	if not _check("갈림 굴 찾기", fork >= 0, "입구 굴 %d에서 두 칸 건너 입구 셋 이상인 굴 %d" % [entrance, fork]):
		return false
	for node: Node in get_nodes_in_group(&"monsters"):
		node.queue_free()
	await wait_frames(2)
	var necromancer: Necromancer = find_necromancer()
	var nav: NavigationGrid = current_scene.get_node("NavigationGrid")
	var started: int = Time.get_ticks_msec()
	nav.get_grid(Vector2(necromancer.body_radius, necromancer.body_radius))
	var grid_ms: int = Time.get_ticks_msec() - started
	var to_entrance: float = await _walk_to(necromancer, _room_center(entrance))
	var to_fork: float = await _walk_to(necromancer, _room_center(fork))
	var ok: bool = to_entrance > 0.0 and to_fork > 0.0
	return _check("구간별 걷기 시간", ok, "도착 지점 → 입구 굴 %s (기준 약 %.0f초), 입구 굴 → 갈림 굴 %s (기준 약 %.0f초), 걷기 %.0f/초, 네크로맨서 크기 길찾기 칸 계산 %dms" % [
		_seconds(to_entrance), TARGET_TO_ENTRANCE, _seconds(to_fork), TARGET_TO_FORK, necromancer.move_speed, grid_ms])


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


# --- 5. 다시 들어오면 몬스터가 다시 놓임 ---

func _monsters_reset() -> bool:
	current_scene.call(&"travel_to", load(BASE_REGION))
	if not await _wait_scene(BASE_SCENE):
		return _check("거점으로", false, "거점에 가지 못함")
	current_scene.call(&"travel_to", load(CAVE_REGION))
	if not await _wait_scene(CAVE_SCENE):
		return _check("얕은 굴로", false, "얕은 굴에 다시 들어가지 못함")
	await wait_frames(SETTLE_FRAMES)
	var count: int = get_nodes_in_group(&"monsters").size()
	return _check("다시 들어오면 몬스터가 처음대로", count == _layout.cells_of("rat").size(), "걷기 시간을 잴 때 몬스터를 모두 없앤 뒤 거점에 갔다 오니 몬스터 %d마리 (PNG의 쥐 %d)" % [count, _layout.cells_of("rat").size()])


func _wait_scene(path: String) -> bool:
	for i: int in SCENE_TIMEOUT_FRAMES:
		await wait_frames(1)
		if current_scene != null and current_scene.scene_file_path == path and current_scene.is_node_ready():
			return true
	return false
