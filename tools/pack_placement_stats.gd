extends ScenarioTest
## 무리 자리(PackSpawn)마다 무리원을 흩어 놓은 결과를 여러 던전 시드로 센다 (봇 측정 계획 5a-2). 판정 없이 출력만 한다.
## 지역 씬을 한 번 불러온 뒤, 시드마다 게임과 같은 길로 놓는다: DungeonRun.start(시드) → 씬 안의 무리 자리 차례대로
## PackSpawn.spawn(던전 난수, 지역의 _is_free_floor) (Region._apply_dungeon_state와 같은 차례, 퀘스트 확정 대장 없음).
## 놓은 무리원의 위치를 읽고 바로 없앤다 (물리 프레임이 돌지 않아 간격 밀기 전 자리다).
## 시드는 BASE_SEED + 번호라서, run_map_route의 같은 판 번호와 처음 배치가 같다 (씬을 첫 시드로 불러와 견준 결과를 [확인] 줄에 찍는다).
##
## bash tools/godot.sh --headless --path . -s tools/pack_placement_stats.gd [-- --seeds=50 --scene=res://regions/shallow_cave.tscn]
##
## 자리마다 한 줄 ([자리]):
## - 둘레 바닥: 자리에서 spread_radius 안을 2px 격자로 찍어 바닥(_is_free_floor)인 점의 비율. 가운데: 자리 한가운데가 바닥인지
## - 가장 가까운 벽: 자리에서 바닥이 아닌 점(벽에서 spawn_floor_margin 안)까지 거리 (72방향, 2px씩, 320px까지)
## - 한가운데: 30번(place_tries) 안에 놓을 곳을 못 골라 자리 한가운데에 놓인 무리원 수 (시드당 평균·최대, 한 마리라도 간 시드 비율)
## - 가장 가까운 사이: 시드마다 무리원끼리 가장 가까운 거리의 최소·평균 (한가운데에 둘 이상 가면 0)
## 마지막 두 줄: "합계: 한가운데로 간 무리원 <수>/<전체> (<비율>%), 한 마리라도 간 자리·시드 <수>/<전체>"와 "결과: 통과"
## ([확인] 줄이 "다르다"면 "결과: 실패"이고 종료 코드 1이다: 그 씬에서는 도구의 배치 차례가 게임과 달라 표를 믿을 수 없다)

const DEFAULT_SCENE: String = "res://regions/shallow_cave.tscn"
const DEFAULT_SEEDS: int = 50
## run_map_route의 BASE_SEED와 같게 둔다 (같은 판 번호면 처음 배치가 같다)
const BASE_SEED: int = 2000
## 둘레 바닥 비율을 잴 때 찍는 점 간격 (픽셀)
const FLOOR_SAMPLE_STEP: float = 2.0
## 가장 가까운 벽을 찾을 방향 수와 최대 거리 (픽셀)
const WALL_SEARCH_DIRECTIONS: int = 72
const WALL_SEARCH_LIMIT: float = 320.0

var _scene_path: String = DEFAULT_SCENE
var _seeds: int = DEFAULT_SEEDS


## 씬을 불러오기 전에 던전을 첫 시드로 시작해 둔다. 그래야 씬이 처음 만든 배치를 도구의 첫 시드 배치와 견줄 수 있다 ([확인] 줄)
func _initialize() -> void:
	get_start_scene()
	var game_state: Node = root.get_node_or_null(^"GameState")
	if game_state != null:
		(game_state.get(&"dungeon") as DungeonRun).start(BASE_SEED)
	super._initialize()


func get_start_scene() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--seeds="):
			_seeds = int(arg.trim_prefix("--seeds="))
	return _scene_path


func _on_scene_ready() -> void:
	var region: Node = current_scene
	var is_free: Callable = Callable(region, &"_is_free_floor")
	var spawns: Array[PackSpawn] = []
	for node: Node in region.find_children("*", "", true, false):
		if node is PackSpawn and (node as PackSpawn).pack != null:
			spawns.append(node as PackSpawn)
	if spawns.is_empty():
		fail_step("준비", "%s에 무리 자리가 없다" % _scene_path)
		return
	# 씬을 불러올 때 만든 무리는 위치만 적어 두고 치운다 (자리의 무리원 목록에 남지 않게)
	var loaded: Array[PackedVector2Array] = []
	for spawn: PackSpawn in spawns:
		var points: PackedVector2Array = PackedVector2Array()
		for monster: Node2D in spawn.get_members():
			points.append(monster.global_position)
		loaded.append(points)
		_free_members(spawn)
		_free_new_packs(spawn.get_parent(), [])
	var actors: Node2D = Node2D.new()
	actors.name = "PlacementActors"
	region.add_child(actors)

	print("지역 씬: %s, 무리 자리 %d곳, 시드 %d개 (%d~%d)" % [_scene_path, spawns.size(), _seeds, BASE_SEED, BASE_SEED + _seeds - 1])
	# 자리마다 모은 값
	var stats: Array[Dictionary] = []
	for spawn: PackSpawn in spawns:
		stats.append({"counts": [], "center": [], "nearest": []})
	for i: int in _seeds:
		var run: DungeonRun = DungeonRun.new()
		run.start(BASE_SEED + i)
		for index: int in spawns.size():
			var spawn: PackSpawn = spawns[index]
			var before: Array[Node] = spawn.get_parent().get_children()
			spawn.spawn(actors, run.rng, is_free, false)
			var points: PackedVector2Array = PackedVector2Array()
			for monster: Node2D in spawn.get_members():
				points.append(monster.global_position)
			_free_members(spawn)
			_free_new_packs(spawn.get_parent(), before)
			var at_center: int = 0
			for point: Vector2 in points:
				if point == spawn.global_position:
					at_center += 1
			if i == 0:
				stats[index]["first"] = points
			stats[index]["counts"].append(points.size())
			stats[index]["center"].append(at_center)
			stats[index]["nearest"].append(_nearest_gap(points))

	var same: bool = true
	for index: int in spawns.size():
		if loaded[index] != stats[index]["first"]:
			same = false
	print("[확인] 씬이 시드 %d로 처음 만든 배치와 도구의 첫 시드 배치가 %s" % [BASE_SEED, "같다" if same else "다르다 (게임의 배치 차례가 도구와 다름)"])

	var total_members: int = 0
	var total_center: int = 0
	var hit_pairs: int = 0
	for index: int in spawns.size():
		var spawn: PackSpawn = spawns[index]
		var counts: Array = stats[index]["counts"]
		var centers: Array = stats[index]["center"]
		var nearest: Array = stats[index]["nearest"]
		var members_sum: int = 0
		var center_sum: int = 0
		var center_max: int = 0
		var center_seeds: int = 0
		for i: int in counts.size():
			members_sum += counts[i]
			center_sum += centers[i]
			center_max = maxi(center_max, centers[i])
			if centers[i] > 0:
				center_seeds += 1
		var nearest_min: float = INF
		var nearest_sum: float = 0.0
		for gap: float in nearest:
			nearest_min = minf(nearest_min, gap)
			nearest_sum += gap
		total_members += members_sum
		total_center += center_sum
		hit_pairs += center_seeds
		var cell: Vector2i = _cell_of(region, spawn.global_position)
		var wall: float = _nearest_wall(spawn.global_position, is_free)
		print("[자리] %s (%s, 칸 %d,%d): 무리원 %.1f마리 (%d~%d), 둘레 바닥 %.0f%% (반지름 %.0fpx), 가운데 %s, 가장 가까운 벽 %s, 한가운데 평균 %.2f·최대 %d·간 시드 %d%%, 가장 가까운 사이 최소 %.1f·평균 %.1fpx" % [
			spawn.name, spawn.pack.id, cell.x, cell.y,
			float(members_sum) / counts.size(), counts.min(), counts.max(),
			_floor_ratio(spawn.global_position, spawn.spread_radius, is_free) * 100.0, spawn.spread_radius,
			"바닥" if is_free.call(spawn.global_position) else "벽 가까움",
			("%.0fpx" % wall) if wall < INF else ("%.0fpx 밖" % WALL_SEARCH_LIMIT),
			float(center_sum) / counts.size(), center_max, roundi(100.0 * center_seeds / counts.size()),
			nearest_min, nearest_sum / nearest.size()])
	print("합계: 한가운데로 간 무리원 %d/%d (%.1f%%), 한 마리라도 간 자리·시드 %d/%d" % [
		total_center, total_members, 100.0 * total_center / maxi(total_members, 1), hit_pairs, spawns.size() * _seeds])
	# 배치 차례가 게임과 어긋나면 표를 믿을 수 없으므로 실패로 끝낸다
	finish(same)


func _free_members(spawn: PackSpawn) -> void:
	for monster: Node in spawn.get_members():
		monster.free()


## parent의 자식 중 before에 없던 무리(MonsterPack)를 없앤다. before가 비면 무리 자리가 만든 무리를 모두 없앤다.
func _free_new_packs(parent: Node, before: Array[Node]) -> void:
	for child: Node in parent.get_children():
		if child is MonsterPack and not before.has(child):
			child.free()


## 무리원끼리 가장 가까운 거리 (한 마리면 0)
func _nearest_gap(points: PackedVector2Array) -> float:
	if points.size() < 2:
		return 0.0
	var best: float = INF
	for a: int in points.size():
		for b: int in range(a + 1, points.size()):
			best = minf(best, points[a].distance_to(points[b]))
	return best


## 자리에서 가장 가까운 "바닥이 아닌" 점까지 거리 (WALL_SEARCH_DIRECTIONS 방향으로 2px씩, WALL_SEARCH_LIMIT까지. 못 찾으면 INF)
func _nearest_wall(center: Vector2, is_free: Callable) -> float:
	var distance: float = 0.0
	while distance <= WALL_SEARCH_LIMIT:
		for i: int in WALL_SEARCH_DIRECTIONS:
			if not is_free.call(center + Vector2.from_angle(TAU * i / WALL_SEARCH_DIRECTIONS) * distance):
				return distance
		distance += FLOOR_SAMPLE_STEP
	return INF


## 자리에서 radius 안을 격자로 찍어 바닥인 점의 비율 (0~1)
func _floor_ratio(center: Vector2, radius: float, is_free: Callable) -> float:
	var inside: int = 0
	var free_count: int = 0
	var y: float = -radius
	while y <= radius:
		var x: float = -radius
		while x <= radius:
			var offset: Vector2 = Vector2(x, y)
			if offset.length() <= radius:
				inside += 1
				if is_free.call(center + offset):
					free_count += 1
			x += FLOOR_SAMPLE_STEP
		y += FLOOR_SAMPLE_STEP
	return float(free_count) / maxi(inside, 1)


## 지역 벽의 칸 (벽이 없으면 32px 칸으로 어림)
func _cell_of(region: Node, point: Vector2) -> Vector2i:
	var walls: Node = region.get_node_or_null(^"Walls")
	if walls != null and walls.has_method(&"world_to_cell"):
		return walls.call(&"world_to_cell", point)
	return Vector2i((point / 32.0).floor())
