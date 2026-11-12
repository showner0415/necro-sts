class_name ShallowCaveUndeadScenario
extends ShallowCaveScenario
## 얕은 굴 언데드 시나리오의 공용 부분: 쥐 언데드 2마리 소환, 굴 사이 통로 따라오기, 바위 돌아 따라오기.
## 한 파일이 시간 제한(tests/run_all.sh)에 가까워서 scenario_shallow_cave_undead.gd(앞)와 scenario_shallow_cave_undead_2.gd(뒤)로 나눴다.
## 통로 구간은 앞뒤 절반씩, 바위는 앞 ROCKS_IN_FIRST_PART개 / 나머지로 나눈다. 두 파일을 합치면 검사 범위는 나누기 전과 같다.
## 굴 사이를 오가는 순서는 PNG의 굴 연결에서 동굴 입구를 출발 굴로 만든다. 두 파일이 같은 순서를 쓰고, 뒤 파일은 앞 절반이 끝난 굴에서 출발한다.

const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 20
## 굴에 닿은 뒤 언데드가 모여야 하는 시간 (프레임)과 거리 (픽셀). 시험 통로 시나리오(scenario_pathfinding.gd)와 같다
const GATHER_FRAMES: int = 300
const GATHER_DISTANCE: float = 40.0
## 오래 걷는 동안 쥐 2마리의 유지비로 마나가 바닥나 해제되지 않게 올려 두는 자연 회복 (초당)
const TEST_MANA_REGEN: float = 10.0
## 바위 양쪽의 서는 자리: 바위 가장자리에서 이만큼(칸) 떨어진 곳 (먼 것부터 해 본다). 그 자리가 2×2 바닥에 들어야 한다
const ROCK_SIDE_GAPS: Array[float] = [2.0, 1.0]
## 바위를 가로지르는 방향 후보 (가로, 세로, 대각선 둘)
const ROCK_DIRECTIONS: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1), Vector2(0.7071, 0.7071), Vector2(0.7071, -0.7071)]
## 앞 파일이 맡는 바위 수 (PNG 위→아래 순서). 시간 대부분이 바위 사이를 오가는 걸음이라(바위가 맵 끝과 끝을 오감)
## 두 파일의 실행 시간이 비슷해지는 곳에서 자른다 (2026-11-12 측정: 바위 단계 약 115초 중 앞 16개가 약 52초, 통로 58구간 전체는 약 36초)
const ROCKS_IN_FIRST_PART: int = 16


## 동굴 입구에서 출발해 이어진 두 굴 사이를 모두 한 번씩 오가는 굴 순서 (출발 굴은 빼고 도착하는 굴들)
func _full_route() -> Array[int]:
	var route: Array[int] = []
	_visit_links(_roles.cave_mouth, route, {})
	return route


## 앞 절반이 맡는 구간 수 (나머지는 뒤 절반)
func _split_index(route: Array[int]) -> int:
	return route.size() / 2


## 몬스터를 없애고 네크로맨서를 room 가운데에 둔 뒤 쥐 언데드 2마리를 소환한다
func _start_at(room: int) -> bool:
	for node: Node in get_nodes_in_group(&"monsters"):
		node.queue_free()
	await wait_frames(2)
	var necromancer: Necromancer = find_necromancer()
	necromancer.global_position = _room_center(room)
	await wait_frames(2)
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
	return _check("쥐 언데드 2마리 소환", undead.size() == 2, "굴 %d에서 언데드 %d마리" % [room, undead.size()])


# --- 9. 언데드 2마리가 통로를 따라옴 ---

## route[from, to) 구간을 걷는다. 굴에 닿을 때마다 2마리 모두 따라와 곁에 모여야 한다 (휘어진 통로에서 걸리지 않음)
func _undead_follow(route: Array[int], from: int, to: int, part: String) -> bool:
	var necromancer: Necromancer = find_necromancer()
	var step_name: String = "언데드 2마리가 통로를 따라옴 (%s)" % part
	if not _check("굴 사이를 모두 오가는 순서", route.size() >= 2 and from < to, "출발 굴 %d, 전체 %d구간 %s, 이 파일은 %d~%d번째" % [_roles.cave_mouth, route.size(), route, from + 1, to]):
		return false
	var legs: PackedStringArray = []
	var worst_gather: int = 0
	for index: int in range(from, to):
		var room: int = route[index]
		var center: Vector2 = _layout.rooms[room].center.round()
		var walked: float = await _walk_to(necromancer, _room_center(room))
		if walked < 0.0:
			return _check(step_name, false, "굴 %d(칸 %s)에 닿지 못함 (지난 구간 %s)" % [room, center, ", ".join(legs)])
		var gathered: int = -1
		for frame: int in GATHER_FRAMES:
			if get_nodes_in_group(&"undead").all(func(u: Node) -> bool: return (u as Node2D).global_position.distance_to(necromancer.global_position) <= GATHER_DISTANCE):
				gathered = frame
				break
			await wait_frames(1)
		var count: int = get_nodes_in_group(&"undead").size()
		if gathered < 0 or count != 2:
			return _check(step_name, false, "칸 %s에서 %d프레임 안에 모이지 않음: 언데드 %d마리, 거리 %s (지난 구간 %s)" % [center, GATHER_FRAMES, count, _undead_distances(necromancer), ", ".join(legs)])
		worst_gather = maxi(worst_gather, gathered)
		legs.append("굴 %d %.1f초/%d프레임" % [room, walked, gathered])
	return _check(step_name, true, "전체 %d구간 중 %d~%d번째를 오감, 굴마다 (걷기 / 멈춘 뒤 모두 %.0f 안에 모이기까지): %s, 가장 늦게 모인 것 %d프레임" % [route.size(), from + 1, to, GATHER_DISTANCE, ", ".join(legs), worst_gather])


func _visit_links(room: int, route: Array[int], used: Dictionary) -> void:
	for next: int in _layout.rooms[room].neighbors:
		var key: Vector2i = Vector2i(mini(room, next), maxi(room, next))
		if used.has(key):
			continue
		used[key] = true
		route.append(next)
		_visit_links(next, route, used)
		route.append(room)


func _undead_distances(necromancer: Necromancer) -> String:
	var distances: PackedStringArray = []
	for u: Node in get_nodes_in_group(&"undead"):
		distances.append("%.0f (칸 %s)" % [(u as Node2D).global_position.distance_to(necromancer.global_position), ((u as Node2D).global_position / TILE).snapped(Vector2(0.1, 0.1))])
	return ", ".join(distances)


# --- 10. 언데드가 바위를 돌아 따라옴 ---

## _layout.rocks[from, to)의 바위마다: 네크로맨서가 바위 한쪽에서 반대쪽으로 가면 언데드 2마리가 바위를 돌아 따라와 곁에 모인다.
## from이 0이면 먼저 모든 바위가 윤곽에서도 남는지 본다
func _around_rocks(from: int, to: int, part: String) -> bool:
	var outline: CaveOutlineData = (current_scene.get_node("Walls") as PlaceholderWalls).outline
	var carved: Array[Rect2i] = []
	for rock: Dictionary in _layout.rocks:
		var remains: bool = false
		for cell: Vector2i in rock.cells:
			remains = remains or outline.is_rock_at((Vector2(cell) + Vector2(0.5, 0.5)) * TILE)
		if not remains:
			carved.append(rock.rect)
	if from == 0 and not _check("윤곽에도 바위가 남음", not _layout.rocks.is_empty() and carved.is_empty(), "바위 %d개, 윤곽에서 사라진 바위 %s" % [_layout.rocks.size(), carved]):
		return false
	var step_name: String = "언데드가 바위를 돌아 따라옴 (%s)" % part
	var rocks: Array = _layout.rocks.slice(from, to)
	if rocks.is_empty():
		return _check(step_name, false, "바위 %d개 중 %d~%d번째가 없음" % [_layout.rocks.size(), from + 1, to])
	var necromancer: Necromancer = find_necromancer()
	var results: PackedStringArray = []
	for rock: Dictionary in rocks:
		var sides: Array[Vector2] = _rock_sides(rock, _layout.rows)
		var rect: Rect2i = rock.rect
		if sides.is_empty():
			return _check(step_name, false, "굴 %d의 바위 %s 양쪽에 설 자리가 없음" % [rock.room, rect])
		if await _walk_to(necromancer, sides[0]) < 0.0:
			return _check(step_name, false, "굴 %d의 바위 %s 한쪽(%s)에 닿지 못함" % [rock.room, rect, sides[0] / TILE])
		var start_gather: int = await _gather_frames(necromancer)
		var walked: float = await _walk_to(necromancer, sides[1])
		var gathered: int = await _gather_frames(necromancer)
		if start_gather < 0 or walked < 0.0 or gathered < 0:
			return _check(step_name, false, "굴 %d의 바위 %s: 처음 모임 %d프레임, 반대쪽까지 걷기 %.1f초, 반대쪽에서 모임 %d프레임 (%d프레임 안), 거리 %s" % [rock.room, rect, start_gather, walked, gathered, GATHER_FRAMES, _undead_distances(necromancer)])
		results.append("굴 %d %d×%d %.1f초/%d프레임" % [rock.room, rect.size.x, rect.size.y, walked, gathered])
	return _check(step_name, true, "바위 %d개 중 %d~%d번째 모두 한쪽에서 모은 뒤 바위 너머 반대쪽으로 감 (두 자리를 잇는 직선이 바위를 지남), 바위마다 (반대쪽까지 걷기 / 멈춘 뒤 모두 %.0f 안에 모이기까지): %s" % [_layout.rocks.size(), from + 1, from + rocks.size(), GATHER_DISTANCE, ", ".join(results)])


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
