extends ShallowCaveScenario
## 시나리오: 얕은 굴에서 언데드가 따라오기. 구조는 scenario_shallow_cave.gd, 걷기는 scenario_shallow_cave_walk.gd.
## 9. 쥐 언데드 2마리를 데리고, 이어진 두 굴 사이를 모두 한 번씩 오간다 (순서는 PNG의 굴 연결에서 만든다). 굴에 닿을 때마다 2마리 모두 따라와 곁에 모인다 (휘어진 통로에서 걸리지 않음)
## 10. 굴 안의 바위마다: 윤곽에서도 바위가 남고, 네크로맨서가 바위 한쪽에서 반대쪽으로 가면 언데드 2마리가 바위를 돌아 따라와 곁에 모인다
## 몬스터를 없애고 동굴 입구에서 출발한다 (굴 사이를 오가는 순서가 출발 굴에서 정해진다).

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


func _run_steps() -> void:
	if not _find_roles():
		return
	for node: Node in get_nodes_in_group(&"monsters"):
		node.queue_free()
	await wait_frames(2)
	find_necromancer().global_position = _room_center(_roles.cave_mouth)
	await wait_frames(2)
	if not await _undead_follow():
		return
	if not await _around_rocks():
		return
	finish(true)


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
	var outline: CaveOutlineData = (current_scene.get_node("Walls") as PlaceholderWalls).outline
	var carved: Array[Rect2i] = []
	for rock: Dictionary in _layout.rocks:
		var remains: bool = false
		for cell: Vector2i in rock.cells:
			remains = remains or outline.is_rock_at((Vector2(cell) + Vector2(0.5, 0.5)) * TILE)
		if not remains:
			carved.append(rock.rect)
	if not _check("윤곽에도 바위가 남음", not _layout.rocks.is_empty() and carved.is_empty(), "바위 %d개, 윤곽에서 사라진 바위 %s" % [_layout.rocks.size(), carved]):
		return false
	var necromancer: Necromancer = find_necromancer()
	var results: PackedStringArray = []
	for rock: Dictionary in _layout.rocks:
		var sides: Array[Vector2] = _rock_sides(rock, _layout.rows)
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
