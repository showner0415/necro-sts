extends ScenarioTest
## 시나리오: 길찾기. 시험 통로(regions/test_corridor.tscn)에서 시작한다.
## 1. 통로의 벽으로 막힌 칸이 정해짐 (멧돼지 크기도 좁은 길목을 지나갈 수 있음). 벽 타일에서 바로 계산한 막힌 칸이 물리 질의로 잰 것과 같음
## 2. 쥐 언데드 2마리를 데리고 모퉁이 5번 꺾이는 통로와 좁은 길목을 지나가면, 2마리 모두 따라와 네크로맨서 곁에 모임. 멈춘 뒤에는 언데드끼리 떨어져 선다
## 3. 막다른 굴의 쥐는 감지 거리 안이어도 벽 너머 네크로맨서를 감지하지 못함
## 4. 쥐가 보던 네크로맨서가 벽 뒤로 숨으면, 놓친 대상을 쫓아 꺾인 길로 돌아서 옴
## 5. 멧돼지가 보던 네크로맨서가 벽 뒤(돌진 거리 안)로 숨으면, 예고하지 않고 돌아서 오고 벽이 없어진 뒤에 예고함
## 6. 멧돼지 돌진이 벽에 막혀 그 자리에서 끝남
## 6-1. 벽 바로 앞의 네크로맨서에게 가까이 붙은 멧돼지는, 돌진 방향으로 벽까지 거리가 min_charge_room보다 짧으면 예고하지 않고 물러나 거리를 벌린 뒤 예고함
## 7. 벽 너머 쥐에게 쏜 탄이 벽에 막혀 사라짐
## 8. 막다른 굴에서 위 통로의 네크로맨서에게 던진 투석병의 돌이 벽에 막혀 사라짐
## 씬에 놓인 몬스터는 처음에 모두 없애고, 단계마다 필요한 몬스터를 새로 놓는다.

const CORRIDOR_SCENE: String = "res://regions/test_corridor.tscn"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const NAV_GRID_CHECK = preload("res://tests/nav_grid_check.gd")
const RAT_PATH: String = "res://data/monsters/rat.tres"
const BOAR_PATH: String = "res://data/monsters/boar.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 20
## 네크로맨서가 죽지 않게 넣어 두는 체력 (몬스터에게 맞아도 단계가 이어지게)
const TEST_HEALTH: float = 1000.0
const SETTLE_FRAMES: int = 6
## 통로 칸 좌표 → 월드 좌표: 벽(Walls)의 왼쪽 위 + 칸 좌표 × 32. 칸 좌표는 소수도 된다 (2칸 너비 통로의 가운데는 정수).
const TILE: float = 32.0
## 2. 네크로맨서가 걸어갈 길 (칸 좌표): 시작 굴 → 오른쪽 → 아래 → 왼쪽 → 아래 → 오른쪽 → 좁은 길목 → 끝 굴 멈춘 뒤에는 언데드끼리 떨어져 선다
const ROUTE: Array[Vector2] = [Vector2(8, 3), Vector2(20, 3), Vector2(20, 9), Vector2(9, 9), Vector2(9, 12), Vector2(22, 11.5), Vector2(25.5, 11.5), Vector2(27, 13)]
## 길의 한 점에 이만큼 가까워지면 다음 점으로 간다 (픽셀)
const ROUTE_ARRIVE: float = 4.0
## 길의 한 점까지 걸을 수 있는 최대 시간 (프레임)
const ROUTE_LEG_FRAMES: int = 600
## 네크로맨서가 멈춘 뒤 언데드가 모여야 하는 시간 (프레임)과 거리 (픽셀)
const GATHER_FRAMES: int = 300
const GATHER_DISTANCE: float = 40.0
## 모인 뒤 언데드끼리 비켜 서기를 기다리는 프레임
const SPACING_SETTLE_FRAMES: int = 90
## 3·7. 막다른 굴(벽 바로 아래)의 쥐와 그 위 통로의 네크로맨서 (감지 거리 80 안, 사이에 벽 한 칸), 막다른 굴 위 벽의 아랫면 (칸 줄)
const POCKET_RAT_TILE: Vector2 = Vector2(14, 5.5)
const POCKET_NECRO_TILE: Vector2 = Vector2(14, 3.5)
const POCKET_WALL_BOTTOM_ROW: float = 5.0
## 3. 벽 너머의 쥐가 감지하지 않는지 지켜보는 시간 (프레임)
const NO_DETECT_FRAMES: int = 60
## 4. 네크로맨서가 처음 보이는 자리(왼쪽 세로 통로 위 끝)와, 숨는 자리(벽 아래 통로)
const SEEN_NECRO_TILE: Vector2 = Vector2(9, 9)
const HIDDEN_NECRO_TILE: Vector2 = Vector2(12, 12)
## 몬스터가 대상을 정하기까지 기다리는 시간 (프레임)
const TARGET_FRAMES: int = 30
## 4. 쥐가 시작하는 자리와, 돌아오는 꺾인 길의 모퉁이 (왼쪽 세로 통로)
const CHASE_RAT_TILE: Vector2 = Vector2(11, 9)
const DETOUR_CORNER_TILE: Vector2 = Vector2(9, 10.5)
## 공격 거리에 이만큼 더한 거리 안이면 다가온 것으로 본다 (픽셀)
const REACH_MARGIN: float = 2.0
const RAT_TIMEOUT_FRAMES: int = 1200
## 5. 멧돼지: 벽 위쪽 통로에서 돌진 거리(140) 밖·감지 거리(150) 안의 네크로맨서를 본 뒤, 네크로맨서가 벽 아래쪽 통로(돌진 거리 안)로 숨는다
const WALL_BOAR_TILE: Vector2 = Vector2(16, 9)
const BOAR_SEEN_NECRO_TILE: Vector2 = Vector2(11.5, 9)
const WALL_NECRO_TILE: Vector2 = Vector2(14, 11.5)
## 이 칸 열보다 왼쪽으로 와야 꺾인 길로 돌아온 것이다
const DETOUR_MAX_COLUMN: float = 10.5
const BOAR_TIMEOUT_FRAMES: int = 1200
## 7. 탄: 마우스를 누르고 있는 시간과 지켜보는 시간 (프레임)
const BOLT_PRESS_FRAMES: int = 10
const BOLT_WATCH_FRAMES: int = 60
## 8. 돌의 피해 (맞으면 체력이 줄어 알 수 있으면 된다)
const STONE_DAMAGE: float = 2.0
const GOBLIN_PATH: String = "res://data/monsters/goblin_slinger.tres"
## 6. 돌진: 끝 굴 위쪽의 멧돼지(감지 거리 150 안)가 아래 벽 바로 앞의 네크로맨서에게 돌진한다 (돌진 거리가 벽 너머까지)
const CHARGE_BOAR_TILE: Vector2 = Vector2(26.5, 12)
const CHARGE_NECRO_TILE: Vector2 = Vector2(26.5, 16.5)
## 끝 굴의 아래 벽 윗면 (칸 줄)
const CHARGE_WALL_ROW: float = 17.0
const CHARGE_TIMEOUT_FRAMES: int = 900
## 벽에 막혔다고 보려면 정한 거리보다 이만큼은 덜 달려야 한다 (픽셀)
const CHARGE_SHORT_MARGIN: float = 8.0
## 6-1. 벽 바로 앞의 네크로맨서 바로 위(돌진 방향으로 벽까지 짧음)에 멧돼지를 두고 지켜보는 프레임
const CRAMPED_BOAR_TILE: Vector2 = Vector2(26.5, 15.3)
const CRAMPED_WATCH_FRAMES: int = 180

var _necromancer: Necromancer
var _walls: Node2D
var _nav: NavigationGrid


func get_start_scene() -> String:
	return CORRIDOR_SCENE


func _on_scene_ready() -> void:
	_run()


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
		finish(false)
	return ok


func _tile(tile: Vector2) -> Vector2:
	return _walls.global_position + tile * TILE


func _tile_of(point: Vector2) -> Vector2:
	return (point - _walls.global_position) / TILE


## data를 주면 data_path 대신 그 데이터(복사본)를 쓴다.
func _spawn(data_path: String, tile: Vector2, data: MonsterData = null) -> Monster:
	var monster: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	monster.data = data if data != null else load(data_path)
	monster.position = _tile(tile)
	current_scene.get_node("Actors").add_child(monster)
	return monster


func _remove_monsters() -> void:
	for node: Node in get_nodes_in_group(&"monsters"):
		node.queue_free()


func _run() -> void:
	_necromancer = find_necromancer()
	_walls = current_scene.get_node("Walls")
	_nav = current_scene.get_node("NavigationGrid")
	_necromancer.health = TEST_HEALTH
	_remove_monsters()
	await wait_frames(SETTLE_FRAMES)
	if not await _grid_ready():
		return
	if not await _undead_follow():
		return
	if not await _no_detect_through_wall():
		return
	if not await _rat_goes_around():
		return
	if not await _boar_goes_around():
		return
	if not await _charge_stops_at_wall():
		return
	if not await _no_cramped_charge():
		return
	if not await _bolt_stops_at_wall():
		return
	if not await _stone_stops_at_wall():
		return
	finish(true)


# --- 1. 막힌 칸 ---

func _grid_ready() -> bool:
	var rat_half: Vector2 = (load(RAT_PATH) as MonsterData).get_placeholder_half_size()
	var boar_half: Vector2 = (load(BOAR_PATH) as MonsterData).get_placeholder_half_size()
	var rat_grid: GridPath = _nav.get_grid(rat_half)
	var boar_grid: GridPath = _nav.get_grid(boar_half)
	var wall_cell: Vector2i = rat_grid.world_to_cell(_tile(Vector2(14.5, 4.5)))
	var floor_cell: Vector2i = rat_grid.world_to_cell(_tile(Vector2(14, 3)))
	# 좁은 길목(한 칸)의 가운데. 몸 가운데는 발밑보다 위에 있지만, 칸 줄 가운데에서 재면 된다.
	var choke_cell: Vector2i = boar_grid.world_to_cell(_tile(Vector2(24, 11.5)))
	# 막힌 칸은 벽 타일에서 바로 계산한다. 물리 질의로 잰 것과 같아야 한다 (칸 8px이라 몸이 타일 경계에 딱 닿는 경우가 있다).
	var same: Dictionary = NAV_GRID_CHECK.compare(_nav, _walls as PlaceholderWalls, _necromancer.body_radius)
	if not _check("타일로 잰 막힌 칸이 물리 질의와 같음", same.ok and not _nav.wall_tiles.is_empty(), "wall_tiles %s, %s" % [_nav.wall_tiles, ", ".join(same.lines)]):
		return false
	return _check("통로의 막힌 칸", _nav.has_walls() and rat_grid.is_solid(wall_cell) and not rat_grid.is_solid(floor_cell) and not boar_grid.is_solid(choke_cell),
			"벽 있음 %s, 쥐: 벽 칸 막힘 %s·통로 칸 막힘 %s, 멧돼지: 좁은 길목 칸 막힘 %s" % [_nav.has_walls(), rat_grid.is_solid(wall_cell), rat_grid.is_solid(floor_cell), boar_grid.is_solid(choke_cell)])


# --- 2. 언데드 2마리가 통로를 따라옴 ---

func _undead_follow() -> bool:
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	for i: int in 2:
		var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
		_necromancer.inventory.try_add(ItemStack.of_skull(skull))
		hotbar.assign(i, skull)
		hotbar.select(i)
		_necromancer.summoner.toggle_selected()
	await wait_frames(SETTLE_FRAMES)
	var undead: Array[Undead] = _all_undead()
	if not _check("쥐 언데드 2마리 소환", undead.size() == 2, "언데드 %d마리" % undead.size()):
		return false
	var start_frame: int = Engine.get_physics_frames()
	var max_gap: Array[float] = [0.0, 0.0]
	for point_tile: Vector2 in ROUTE:
		var point: Vector2 = _tile(point_tile)
		var frames: int = 0
		while _necromancer.global_position.distance_to(point) > ROUTE_ARRIVE and frames < ROUTE_LEG_FRAMES:
			press_moves(_necromancer.global_position.direction_to(point))
			await wait_frames(1)
			frames += 1
			for i: int in undead.size():
				max_gap[i] = maxf(max_gap[i], undead[i].global_position.distance_to(_necromancer.global_position))
		if frames >= ROUTE_LEG_FRAMES:
			press_moves(Vector2.ZERO)
			return _check("네크로맨서가 통로를 지나감", false, "칸 %s에 닿지 못함 (지금 칸 %s)" % [point_tile, _tile_of(_necromancer.global_position)])
	press_moves(Vector2.ZERO)
	var walk_seconds: float = (Engine.get_physics_frames() - start_frame) / float(Engine.physics_ticks_per_second)
	var gathered_frames: int = -1
	for frame: int in GATHER_FRAMES:
		if undead.all(func(u: Undead) -> bool: return u.global_position.distance_to(_necromancer.global_position) <= GATHER_DISTANCE):
			gathered_frames = frame
			break
		await wait_frames(1)
	var distances: PackedStringArray = []
	for u: Undead in undead:
		distances.append("%.0f (칸 %s)" % [u.global_position.distance_to(_necromancer.global_position), _tile_of(u.global_position).snapped(Vector2(0.1, 0.1))])
	var ok: bool = gathered_frames >= 0
	if not _check("언데드 2마리가 통로를 따라옴", ok,
			"네크로맨서 걷기 %.1f초 (모퉁이 5번, 좁은 길목 1곳), 멈춘 뒤 %d프레임에 모두 %.0f 안 (거리 %s), 걷는 동안 가장 멀어진 거리 %.0f / %.0f" % [walk_seconds, gathered_frames, GATHER_DISTANCE, ", ".join(distances), max_gap[0], max_gap[1]]):
		return false
	# 멈춘 뒤 언데드끼리는 비켜 서서 떨어진다 (멧돼지 돌진 한 번에 둘 다 맞지 않게). 비키는 힘이 spacing_deadband보다 작아지면 멈추므로 그만큼은 덜 떨어질 수 있다.
	await wait_frames(SPACING_SETTLE_FRAMES)
	var apart: float = undead[0].global_position.distance_to(undead[1].global_position)
	var need: float = undead[0].spacing_distance * (1.0 - undead[0].spacing_deadband)
	var near: bool = undead.all(func(u: Undead) -> bool: return u.global_position.distance_to(_necromancer.global_position) <= GATHER_DISTANCE)
	if not _check("멈춘 뒤 언데드끼리 떨어져 섬", apart >= need and near, "%d프레임 뒤 언데드 사이 %.0f (%.0f 이상이어야 함, 간격 %.0f), 모두 네크로맨서 %.0f 안 %s" % [
			SPACING_SETTLE_FRAMES, apart, need, undead[0].spacing_distance, GATHER_DISTANCE, near]):
		return false
	# 다음 단계에서 언데드가 몬스터와 싸우지 않게 해제한다.
	for i: int in 2:
		hotbar.select(i)
		_necromancer.summoner.toggle_selected()
	await wait_frames(SETTLE_FRAMES)
	return _check("언데드 해제", _all_undead().is_empty(), "남은 언데드 %d마리" % _all_undead().size())


func _all_undead() -> Array[Undead]:
	var result: Array[Undead] = []
	for node: Node in get_nodes_in_group(&"undead"):
		if not node.is_queued_for_deletion():
			result.append(node as Undead)
	return result


# --- 3. 벽 너머는 감지하지 못함 ---

func _no_detect_through_wall() -> bool:
	_necromancer.global_position = _tile(POCKET_NECRO_TILE)
	var rat: Monster = _spawn(RAT_PATH, POCKET_RAT_TILE)
	await wait_frames(NO_DETECT_FRAMES)
	var distance: float = rat.global_position.distance_to(_necromancer.global_position)
	var ok: bool = distance <= rat.data.detect_range and rat.get_target() == null and rat.get_aggro().state == Aggro.State.IDLE
	var evidence: String = "막다른 굴의 쥐와 위 통로의 네크로맨서 거리 %.0f (감지 %.0f 안, 사이에 벽), %d프레임 뒤 대상 %s, 추격 상태 %d (평소 %d)" % [
		distance, rat.data.detect_range, NO_DETECT_FRAMES, rat.get_target(), rat.get_aggro().state, Aggro.State.IDLE]
	rat.queue_free()
	await wait_frames(2)
	return _check("벽 너머는 감지하지 못함", ok, evidence)


# --- 4. 보던 대상이 벽 뒤로 숨으면 쥐가 돌아서 쫓아옴 ---

func _rat_goes_around() -> bool:
	_necromancer.global_position = _tile(SEEN_NECRO_TILE)
	var rat: Monster = _spawn(RAT_PATH, CHASE_RAT_TILE)
	if await _wait_target(rat) < 0:
		rat.queue_free()
		return _check("쥐가 네크로맨서를 봄", false, "%d프레임 안에 대상을 정하지 않음" % TARGET_FRAMES)
	_necromancer.global_position = _tile(HIDDEN_NECRO_TILE)
	await wait_frames(2)
	var hidden: bool = not rat.get_path_follower().can_see(rat, _necromancer.global_position)
	var chased: bool = false
	var corner: Vector2 = _tile(DETOUR_CORNER_TILE)
	var closest_to_corner: float = INF
	var frames: int = 0
	var reach: float = rat.data.attack_range + REACH_MARGIN
	while frames < RAT_TIMEOUT_FRAMES and rat.global_position.distance_to(_necromancer.global_position) > reach:
		await wait_frames(1)
		frames += 1
		chased = chased or rat.get_aggro().state == Aggro.State.CHASING
		closest_to_corner = minf(closest_to_corner, rat.global_position.distance_to(corner))
	var arrived: bool = frames < RAT_TIMEOUT_FRAMES
	var ok: bool = hidden and chased and arrived and closest_to_corner <= TILE
	var evidence: String = "숨은 뒤 벽이 가림 %s, 놓친 대상을 쫓음 %s, %s, 꺾인 길 모퉁이에 가장 가까이 온 거리 %.0f" % [
		hidden, chased, ("%.1f초 만에 공격 거리 안" % (frames / float(Engine.physics_ticks_per_second))) if arrived else "시간 안에 못 옴 (지금 칸 %s)" % _tile_of(rat.global_position), closest_to_corner]
	rat.queue_free()
	await wait_frames(2)
	return _check("보던 대상이 벽 뒤로 숨으면 쥐가 돌아서 쫓아옴", ok, evidence)


## monster가 네크로맨서를 대상으로 정할 때까지 기다린다. 걸린 프레임 수 (못 정하면 -1).
func _wait_target(monster: Monster) -> int:
	for frame: int in TARGET_FRAMES:
		await wait_frames(1)
		if monster.get_target() == _necromancer:
			return frame
	return -1


# --- 5. 멧돼지가 벽 너머에서 돌진하지 않고 돌아서 옴 ---

func _boar_goes_around() -> bool:
	_necromancer.global_position = _tile(BOAR_SEEN_NECRO_TILE)
	var boar: Monster = _spawn(BOAR_PATH, WALL_BOAR_TILE)
	if await _wait_target(boar) < 0:
		boar.queue_free()
		return _check("멧돼지가 네크로맨서를 봄", false, "%d프레임 안에 대상을 정하지 않음" % TARGET_FRAMES)
	var charge: ChargeBehavior = boar.get_behavior() as ChargeBehavior
	_necromancer.global_position = _tile(WALL_NECRO_TILE)
	await wait_frames(1)
	var straight: float = boar.global_position.distance_to(_necromancer.global_position)
	var blocked_at_start: bool = not boar.has_clear_line_to(_necromancer.global_position)
	var min_column: float = INF
	var frames: int = 0
	while frames < BOAR_TIMEOUT_FRAMES and charge.get_state() == ChargeBehavior.State.APPROACH:
		await wait_frames(1)
		frames += 1
		min_column = minf(min_column, _tile_of(boar.global_position).x)
	var started: bool = charge.get_state() == ChargeBehavior.State.WINDUP
	# 예고를 시작한 순간 벽이 가로막고 있었으면 벽 너머로 돌진하려 한 것이다.
	var windup_through_wall: bool = started and not boar.has_clear_line_to(_necromancer.global_position)
	var ok: bool = blocked_at_start and started and not windup_through_wall and min_column < DETOUR_MAX_COLUMN
	var evidence: String = "숨은 뒤 곧은 거리 %.0f (돌진 거리 %.0f 안, 벽이 가로막음 %s), %s, 가장 왼쪽으로 간 칸 열 %.1f (꺾인 길은 %.1f보다 왼쪽), 예고 때 벽이 가로막음 %s, 예고한 자리 칸 %s" % [
		straight, charge.charge_range, blocked_at_start, ("%.1f초 뒤 예고 시작" % (frames / float(Engine.physics_ticks_per_second))) if started else "예고 안 함 (상태 %d)" % charge.get_state(),
		min_column, DETOUR_MAX_COLUMN, windup_through_wall, _tile_of(boar.global_position).snapped(Vector2(0.1, 0.1))]
	boar.queue_free()
	await wait_frames(2)
	return _check("멧돼지가 벽 너머에서는 돌진하지 않고 돌아서 옴", ok, evidence)


# --- 6. 돌진이 벽에 막힘 ---

func _charge_stops_at_wall() -> bool:
	_necromancer.global_position = _tile(CHARGE_NECRO_TILE)
	var boar: Monster = _spawn(BOAR_PATH, CHARGE_BOAR_TILE)
	await wait_frames(2)
	var charge: ChargeBehavior = boar.get_behavior() as ChargeBehavior
	var frames: int = 0
	while frames < CHARGE_TIMEOUT_FRAMES and charge.get_state() != ChargeBehavior.State.CHARGE:
		await wait_frames(1)
		frames += 1
	var start: Vector2 = boar.global_position
	var planned: float = charge.get_current_charge_length()
	while frames < CHARGE_TIMEOUT_FRAMES and charge.get_state() == ChargeBehavior.State.CHARGE:
		await wait_frames(1)
		frames += 1
	var traveled: float = boar.global_position.distance_to(start)
	var wall_top: float = _tile(Vector2(0, CHARGE_WALL_ROW)).y
	var ended: bool = charge.get_state() == ChargeBehavior.State.RECOVER
	# 벽에 막혔으면 정한 거리를 다 달리지 못하고, 몸(발밑)이 벽 윗면을 넘지 않는다.
	var ok: bool = ended and traveled < planned - CHARGE_SHORT_MARGIN and boar.global_position.y <= wall_top + 1.0
	var evidence: String = "돌진 방향 %s, 정한 거리 %.0f (벽 너머까지), 실제로 달린 거리 %.0f, 멈춘 발밑 y %.0f (벽 윗면 %.0f), 상태 %d (멈칫 %d)" % [
		charge.get_direction().snapped(Vector2(0.01, 0.01)), planned, traveled, boar.global_position.y, wall_top, charge.get_state(), ChargeBehavior.State.RECOVER]
	boar.queue_free()
	return _check("멧돼지 돌진이 벽에 막힘", ok, evidence)


# --- 6-1. 벽에 막혀 짧은 돌진은 하지 않고 물러남 ---

func _no_cramped_charge() -> bool:
	_necromancer.global_position = _tile(CHARGE_NECRO_TILE)
	var boar: Monster = _spawn(BOAR_PATH, CRAMPED_BOAR_TILE)
	await wait_frames(2)
	var charge: ChargeBehavior = boar.get_behavior() as ChargeBehavior
	var start_distance: float = boar.global_position.distance_to(_necromancer.global_position)
	var start_room: float = charge.get_room(boar, boar.global_position.direction_to(_necromancer.global_position))
	var targeted: bool = false
	var farthest: float = start_distance
	var windup_room: float = -1.0
	var windup_frame: int = -1
	for frame: int in CRAMPED_WATCH_FRAMES:
		var room: float = charge.get_room(boar, boar.global_position.direction_to(_necromancer.global_position))
		await wait_frames(1)
		targeted = targeted or boar.get_target() == _necromancer
		if charge.get_state() == ChargeBehavior.State.WINDUP and windup_frame < 0:
			windup_frame = frame
			windup_room = room
			break
		farthest = maxf(farthest, boar.global_position.distance_to(_necromancer.global_position))
	boar.queue_free()
	# 처음에는 벽까지 거리가 짧아 예고하지 않고, 네크로맨서에게서 물러난 뒤 거리가 생기면 예고한다.
	var ok: bool = targeted and start_room < charge.min_charge_room and farthest > start_distance and windup_frame >= 0 and windup_room >= charge.min_charge_room
	return _check("벽에 막혀 짧은 돌진은 하지 않고 물러나 거리를 벌림", ok, "처음 거리 %.0f, 네크로맨서 쪽으로 벽까지 %.0f (기준 %.0f), 노림 %s, 물러난 가장 먼 거리 %.0f, %d프레임에 예고 시작 (그때 벽까지 %.0f, -1은 예고 안 함)" % [
		start_distance, start_room, charge.min_charge_room, targeted, farthest, windup_frame, windup_room])


# --- 7. 탄이 벽에 막힘 ---

func _bolt_stops_at_wall() -> bool:
	_necromancer.global_position = _tile(POCKET_NECRO_TILE)
	# 움직이지도 감지하지도 않는 쥐 (데이터 복사본)
	var rat_data: MonsterData = (load(RAT_PATH) as MonsterData).duplicate()
	rat_data.move_speed = 0.0
	rat_data.wander_speed = 0.0
	rat_data.detect_range = 0.0
	var rat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	rat.data = rat_data
	rat.position = _tile(POCKET_RAT_TILE)
	current_scene.get_node("Actors").add_child(rat)
	await wait_frames(2)
	aim_mouse_at(rat.global_position)
	press_mouse(true)
	var fired: int = 0
	var lowest_bolt: float = -INF
	for frame: int in BOLT_WATCH_FRAMES:
		await wait_frames(1)
		if frame == BOLT_PRESS_FRAMES:
			press_mouse(false)
		for node: Node in current_scene.find_children("*", "Bolt", true, false):
			var bolt: Node2D = node as Node2D
			if not bolt.has_meta(&"counted"):
				bolt.set_meta(&"counted", true)
				fired += 1
			lowest_bolt = maxf(lowest_bolt, bolt.global_position.y)
	var remaining: int = current_scene.find_children("*", "Bolt", true, false).size()
	var wall_bottom: float = _tile(Vector2(0, POCKET_WALL_BOTTOM_ROW)).y
	var ok: bool = fired > 0 and remaining == 0 and rat.health == rat_data.max_health and lowest_bolt < wall_bottom
	var evidence: String = "벽 너머 쥐에게 쏜 탄 %d개, 남은 탄 %d개, 탄이 내려간 가장 아래 y %.0f (벽 아랫면 %.0f), 쥐 체력 %.0f / %.0f" % [
		fired, remaining, lowest_bolt, wall_bottom, rat.health, rat_data.max_health]
	rat.queue_free()
	return _check("탄이 벽에 막힘", ok, evidence)


# --- 8. 투석병의 돌이 벽에 막힘 ---

func _stone_stops_at_wall() -> bool:
	_necromancer.global_position = _tile(POCKET_NECRO_TILE)
	var health_before: float = _necromancer.health
	var throw: ThrowBehavior = (load(GOBLIN_PATH) as MonsterData).behavior as ThrowBehavior
	var stone: Stone = throw.stone_scene.instantiate()
	var origin: Vector2 = _tile(POCKET_RAT_TILE)
	stone.direction = origin.direction_to(_necromancer.global_position)
	stone.speed = throw.stone_speed
	stone.damage = STONE_DAMAGE
	stone.max_distance = origin.distance_to(_necromancer.global_position) * 2.0
	stone.hostile_groups = [&"necromancer", &"undead"]
	current_scene.get_node("Actors").add_child(stone)
	stone.global_position = origin
	var highest_stone: float = INF
	for frame: int in BOLT_WATCH_FRAMES:
		await wait_frames(1)
		if not is_instance_valid(stone):
			break
		highest_stone = minf(highest_stone, stone.global_position.y)
	var wall_top: float = _tile(Vector2(0, POCKET_WALL_BOTTOM_ROW - 1.0)).y
	var ok: bool = not is_instance_valid(stone) and _necromancer.health == health_before and highest_stone > wall_top
	return _check("투석병의 돌이 벽에 막힘", ok, "막다른 굴에서 위 통로의 네크로맨서에게 던진 돌: 사라짐 %s, 올라간 가장 위 y %.0f (벽 윗면 %.0f), 네크로맨서 체력 %.0f → %.0f" % [
		not is_instance_valid(stone), highest_stone, wall_top, health_before, _necromancer.health])
