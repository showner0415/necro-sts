extends ScenarioTest
## 시나리오: 박쥐 무리의 공동 어그로.
## 감지 범위 밖에서 한 마리만 쏴도 세 마리 모두 네크로맨서를 노림 → 언데드가 한 마리를 치면 모두 언데드로 바뀜
## (가까이 다른 대상이 있어도 가장 최근 어그로를 따름) → 네크로맨서가 다시 치면 모두 네크로맨서 →
## 모두가 쫓기 한계를 넘으면 무리가 함께 포기하고 각자 무리 싸움을 시작한 자리로 돌아감.
## 박쥐 말고 다른 몬스터는 치운다. 네크로맨서는 체력을 크게 해서 죽지 않게 한다.

const TIMEOUT_FRAMES: int = 120
const RETURN_TIMEOUT_FRAMES: int = 900
## 박쥐 무리 가운데에서 이만큼 떨어져 선다 (감지 범위 110 밖, 사거리 160 안)
const STAND_OFFSET: Vector2 = Vector2(150, 0)
## 무리가 포기하도록 네크로맨서를 옮기는 거리 (쫓기 한계 250 밖)
const FAR_OFFSET: Vector2 = Vector2(700, 0)
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 30
## 다 돌아왔다고 보는 거리 (Monster.return_arrive_distance보다 조금 넉넉하게)
const HOME_TOLERANCE: float = 8.0

var _necromancer: Necromancer
var _bats: Array[Monster] = []


func get_start_scene() -> String:
	return TEST_REGION_SCENE


func _on_scene_ready() -> void:
	_run()


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
	return ok


func _target_name(bat: Monster) -> String:
	var target: Node2D = bat.get_target()
	if target == null:
		return "없음"
	if target == _necromancer:
		return "네크로맨서"
	return "언데드" if target.is_in_group(&"undead") else str(target)


func _describe() -> String:
	return ", ".join(_bats.map(func(bat: Monster) -> String:
		return "%s: 대상 %s, 상태 %s" % [bat.name, _target_name(bat), Aggro.State.keys()[bat.get_aggro().state]]))


## 모든 박쥐가 target을 노릴 때까지 기다린다. 걸린 프레임 수, 못 하면 -1.
func _wait_all_target(target: Node2D) -> int:
	for frame: int in TIMEOUT_FRAMES:
		if _bats.all(func(bat: Monster) -> bool: return bat.get_target() == target):
			return frame
		await wait_frames(1)
	return -1


func _run() -> void:
	_necromancer = find_necromancer()
	for node: Node in get_nodes_in_group(&"monsters"):
		var monster: Monster = node as Monster
		if monster.data.id == &"bat":
			_bats.append(monster)
		else:
			monster.free()
	var pack_center: Vector2 = Vector2.ZERO
	for bat: Monster in _bats:
		pack_center += bat.global_position / _bats.size()
	_necromancer.global_position = pack_center + STAND_OFFSET
	_necromancer.max_health = 10000.0
	_necromancer.health = 10000.0
	await wait_frames(3)

	# 1. 처음: 아무도 노리지 않음 (모두 감지 범위 밖)
	if not _check("처음", _bats.size() == 3 and _bats.all(func(bat: Monster) -> bool: return bat.get_target() == null),
			"박쥐 %d마리, %s, 네크로맨서와 가장 가까운 박쥐 거리 %.0f (감지 %.0f)" % [_bats.size(), _describe(),
				_bats.map(func(bat: Monster) -> float: return bat.global_position.distance_to(_necromancer.global_position)).min(), _bats[0].data.detect_range]):
		finish(false)
		return

	# 2. 한 마리만 쏜다 → 세 마리 모두 네크로맨서
	var shot: Monster = _bats[0]
	for bat: Monster in _bats:
		if bat.global_position.distance_to(_necromancer.global_position) < shot.global_position.distance_to(_necromancer.global_position):
			shot = bat
	var health_before: float = shot.health
	aim_mouse_at(shot.global_position + Vector2(0, -4))
	press_mouse(true)
	await wait_frames(2)
	press_mouse(false)
	var hit_frames: int = -1
	for frame: int in TIMEOUT_FRAMES:
		if _bats.any(func(bat: Monster) -> bool: return bat.health < bat.data.max_health):
			hit_frames = frame
			break
		await wait_frames(1)
	var hit_count: int = _bats.filter(func(bat: Monster) -> bool: return bat.health < bat.data.max_health).size()
	var frames: int = await _wait_all_target(_necromancer)
	if not _check("한 마리만 맞아도 무리 전체", hit_frames >= 0 and hit_count == 1 and frames >= 0,
			"%d프레임 만에 맞음 (맞은 박쥐 %d마리, 겨눈 박쥐 체력 %.0f → %.0f), 그 뒤 %d프레임 만에 모두 네크로맨서: %s" % [hit_frames, hit_count, health_before, shot.health, frames, _describe()]):
		finish(false)
		return

	# 3. 언데드가 한 마리를 치면 모두 언데드 (네크로맨서가 바로 옆에 있어도 가장 최근 어그로)
	var undead: Node2D = await _summon_undead()
	if undead == null:
		fail_step("언데드 소환", "언데드가 나오지 않음")
		finish(false)
		return
	_bats[2].take_damage(0.1, undead)
	frames = await _wait_all_target(undead)
	if not _check("언데드가 치면 모두 언데드", frames >= 0,
			"%s가 언데드에게 맞음, %d프레임 만에: %s" % [_bats[2].name, frames, _describe()]):
		finish(false)
		return

	# 4. 네크로맨서가 다시 치면 모두 네크로맨서
	_bats[1].take_damage(0.1, _necromancer)
	frames = await _wait_all_target(_necromancer)
	if not _check("다시 치면 모두 네크로맨서", frames >= 0,
			"%s가 네크로맨서에게 맞음, %d프레임 만에: %s" % [_bats[1].name, frames, _describe()]):
		finish(false)
		return

	# 5. 언데드를 내리고 네크로맨서가 멀리 가면 무리가 함께 포기하고, 각자 시작한 자리로 돌아감
	_necromancer.summoner.toggle_selected()
	_necromancer.global_position += FAR_OFFSET
	var gave_up: int = -1
	for frame: int in TIMEOUT_FRAMES:
		if _bats.all(func(bat: Monster) -> bool: return bat.get_target() == null and bat.get_aggro().state == Aggro.State.RETURNING):
			gave_up = frame
			break
		await wait_frames(1)
	if not _check("함께 포기", gave_up >= 0, "네크로맨서를 %s만큼 옮기고 %d프레임 만에: %s" % [FAR_OFFSET, gave_up, _describe()]):
		finish(false)
		return
	var homes: Array[Vector2] = []
	for bat: Monster in _bats:
		homes.append(bat.get_aggro().origin)
	var back: int = -1
	for frame: int in RETURN_TIMEOUT_FRAMES:
		if _bats.all(func(bat: Monster) -> bool: return bat.get_aggro().state == Aggro.State.IDLE):
			back = frame
			break
		await wait_frames(1)
	var distances: Array = []
	for i: int in _bats.size():
		distances.append("%.1f" % _bats[i].global_position.distance_to(homes[i]))
	_check("각자 시작한 자리로 돌아감", back >= 0 and _bats.all(func(bat: Monster) -> bool: return bat.get_target() == null),
		"%d프레임 만에 모두 평소 상태, 돌아갈 자리까지 거리 %s (도착 기준 %.0f): %s" % [back, distances, HOME_TOLERANCE, _describe()])
	finish(back >= 0)


## 쥐 언데드를 소환해 돌려준다 (네크로맨서 옆에 나온다).
func _summon_undead() -> Node2D:
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	hotbar.assign(0, skull)
	hotbar.select(0)
	_necromancer.summoner.toggle_selected()
	await wait_frames(2)
	var undead: Array[Node] = get_nodes_in_group(&"undead")
	return undead[0] as Node2D if not undead.is_empty() else null
