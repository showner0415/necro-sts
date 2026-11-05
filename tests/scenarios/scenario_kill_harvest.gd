extends ScenarioTest
## 시나리오: 쥐 처치 → 시체가 남음(바닥에 바로 떨어지지 않음) → 시체 안내 → 더 가까운 바닥 물건이 E 대상
## → 움직이면 채집 취소 → 피해를 받으면 채집 취소 → E 채집(게이지, 시간) → 한 종류 → 다시 E → 나머지 한 종류
## → 빈 시체(안내 없음, E 대상 아님) → 뼈 개수·머리뼈 개별 저장·HUD.
## 채집할 종류는 무작위라 순서는 매번 같지 않을 수 있다(시드가 고정이라 같은 코드면 같다). 두 번에 두 종류를 다 얻는지 본다.
##
## 확률 고정: 대상 쥐의 데이터를 복사해 모든 드랍 확률을 FORCED_DROP_CHANCE로 바꾼다
## (실제 데이터 파일은 바꾸지 않는다). 그래서 머리뼈가 매번 나온다.
## 다른 몬스터는 처음에 치운다. 다가와서 때리면 채집이 피해로 취소되어 결과가 흔들린다.

const FORCED_DROP_CHANCE: float = 1.0
const KILL_TIMEOUT_FRAMES: int = 600
const MOVE_TIMEOUT_FRAMES: int = 300
const WAIT_FRAMES: int = 3
## 시체 옆 이 거리 안까지 걸어간다
const ARRIVE_DISTANCE: float = 2.0
## 시체에서 이만큼 옆에 선다. 발밑에 놓은 바닥 물건이 시체보다 가깝게 하려고.
const STAND_OFFSET: Vector2 = Vector2(6, 0)
## 사거리의 이 비율보다 멀면 조준하면서 다가간다
const APPROACH_RATIO: float = 0.8
## 채집을 취소해 볼 때 기다리는 프레임 (게이지가 조금 찬 뒤)
const PARTIAL_FRAMES: int = 10
## 채집 시간 판정의 허용 오차 (프레임)
const DURATION_TOLERANCE_FRAMES: int = 3
const PICKUP_KEY_TEXT: String = "[E]"
const BONE_PATH: String = "res://data/items/bone.tres"

var _necromancer: Necromancer
var _inventory: Inventory
var _hud: Hud
var _target: Monster
var _corpse: Corpse


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


func _run() -> void:
	_necromancer = find_necromancer()
	_hud = find_hud()
	if _necromancer == null or _hud == null:
		fail_step("준비", "네크로맨서 %s, HUD %s" % [_necromancer, _hud])
		return
	_inventory = _necromancer.inventory
	_target = _nearest_monster()
	if _target == null:
		fail_step("준비", "씬에 몬스터가 없습니다")
		return
	for node: Node in get_nodes_in_group(&"monsters"):
		if node != _target:
			node.queue_free()
	_target.data = _with_forced_chance(_target.data)
	print("[준비] 대상 %s (%s, 체력 %.0f), 드랍 확률을 %.1f로 고정, 다른 몬스터는 치움" % [
		_target.name, _target.data.id, _target.health, FORCED_DROP_CHANCE])

	if not await _kill():
		return
	if not await _check_corpse():
		return
	if not await _walk_to(_corpse.global_position + STAND_OFFSET, "시체 옆"):
		return
	if not _check_corpse_prompt():
		return
	if not await _nearer_pickup_first():
		return
	if not await _move_cancels():
		return
	if not await _damage_cancels():
		return
	var bones_before: int = _inventory.get_count(&"bone")
	var first: ItemStack = await _harvest_once("채집 1")
	if first == null:
		return
	var second: ItemStack = await _harvest_once("채집 2")
	if second == null:
		return
	if not await _check_empty_corpse():
		return
	var harvested: Array[ItemStack] = [first, second]
	_check_totals(bones_before, harvested)


func _nearest_monster() -> Monster:
	var nearest: Monster = null
	var nearest_distance: float = INF
	for node: Node in get_nodes_in_group(&"monsters"):
		var monster: Monster = node as Monster
		var distance: float = monster.global_position.distance_to(_necromancer.global_position)
		if distance < nearest_distance:
			nearest = monster
			nearest_distance = distance
	return nearest


func _with_forced_chance(data: MonsterData) -> MonsterData:
	var copy: MonsterData = data.duplicate()
	var drops: Array[DropEntry] = []
	for entry: DropEntry in data.drops:
		var entry_copy: DropEntry = entry.duplicate()
		entry_copy.chance = FORCED_DROP_CHANCE
		drops.append(entry_copy)
	copy.drops = drops
	return copy


func _pickups() -> Array[Pickup]:
	var result: Array[Pickup] = []
	for node: Node in current_scene.find_children("*", "Area2D", true, false):
		if node is Pickup and not node.is_queued_for_deletion():
			result.append(node as Pickup)
	return result


func _kill() -> bool:
	press_mouse(true)
	var last_position: Vector2 = _target.global_position
	for frame: int in KILL_TIMEOUT_FRAMES:
		if not is_instance_valid(_target):
			press_mouse(false)
			press_moves(Vector2.ZERO)
			pass_step("처치", "%d프레임 만에 대상이 사라짐, 네크로맨서 체력 %.0f" % [frame, _necromancer.health])
			_target = null
			# 시체는 call_deferred로 추가되므로 몇 프레임 뒤에 찾는다.
			await wait_frames(WAIT_FRAMES)
			for node: Node in current_scene.find_children("*", "Area2D", true, false):
				var corpse: Corpse = node as Corpse
				if corpse != null and corpse.global_position.distance_to(last_position) < 1.0:
					_corpse = corpse
			return _check("시체가 남음", _corpse != null, "죽은 자리 %s의 시체 %s" % [last_position.round(), _corpse])
		last_position = _target.global_position
		aim_mouse_at(_target.global_position + Vector2(0, -_target.data.placeholder_radius))
		var to_target: Vector2 = _target.global_position - _necromancer.global_position
		var far: bool = to_target.length() > _necromancer.attack.projectile_range * APPROACH_RATIO
		press_moves(to_target.normalized() if far else Vector2.ZERO)
		await wait_frames(1)
	press_mouse(false)
	fail_step("처치", "%d프레임 안에 잡지 못함, 대상 체력 %.0f" % [KILL_TIMEOUT_FRAMES, _target.health])
	return false


func _describe_loot() -> Array:
	var result: Array = []
	for stack: ItemStack in _corpse.loot.get_stacks():
		result.append("%s×%d" % [stack.item.id, stack.count])
	return result


func _check_corpse() -> bool:
	var stacks: Array[ItemStack] = _corpse.loot.get_stacks()
	var has_bone: bool = stacks.any(func(stack: ItemStack) -> bool: return stack.item.id == &"bone" and stack.count == 2)
	var skull_stacks: Array[ItemStack] = stacks.filter(func(stack: ItemStack) -> bool: return stack.is_skull())
	var fresh_skull: bool = skull_stacks.size() == 1 and skull_stacks[0].skull.durability == skull_stacks[0].skull.data.max_durability
	if not _check("시체 내용", stacks.size() == 2 and has_bone and fresh_skull,
			"시체에 %s (기대: bone×2, 최대 내구도 rat_skull×1)" % [_describe_loot()]):
		return false
	if not _check("바닥에 바로 떨어지지 않음", _pickups().is_empty(), "바닥 더미 %d개 (기대 0)" % _pickups().size()):
		return false
	return _check("멀면 안내 없음", not _corpse.is_prompt_visible(),
			"거리 %.0f (줍기 범위 %.0f), 시체 안내 보임 %s" % [_corpse.global_position.distance_to(_necromancer.global_position), _necromancer.pickup_range, _corpse.is_prompt_visible()])


func _walk_to(point: Vector2, label: String) -> bool:
	for frame: int in MOVE_TIMEOUT_FRAMES:
		var to_point: Vector2 = point - _necromancer.global_position
		if to_point.length() <= ARRIVE_DISTANCE:
			press_moves(Vector2.ZERO)
			await wait_frames(WAIT_FRAMES)
			pass_step("이동", "%s 도착 (%d프레임, 남은 거리 %.1f)" % [label, frame, to_point.length()])
			return true
		# 가까워지면 천천히 다가가서 지나치지 않게 한다.
		press_moves(to_point.normalized() * minf(1.0, to_point.length() / ARRIVE_DISTANCE))
		await wait_frames(1)
	press_moves(Vector2.ZERO)
	fail_step("이동", "%d프레임 안에 %s에 닿지 못함" % [MOVE_TIMEOUT_FRAMES, label])
	return false


func _check_corpse_prompt() -> bool:
	var prompt: Label = _corpse.get_node("%Prompt")
	var expected: String = "%s의 시체\n%s" % [_corpse.data.display_name, PICKUP_KEY_TEXT]
	var prompt_bottom: float = prompt.global_position.y + prompt.size.y
	var corpse_top: float = _corpse.global_position.y - _corpse.data.placeholder_radius * _corpse.flatten_ratio
	return _check("시체 안내", prompt.is_visible_in_tree() and prompt.text == expected and prompt_bottom <= corpse_top,
			"안내 보임 %s, 글자 '%s' (기대 '%s'), 안내 아래 끝 y %.0f (시체 위 끝 y %.0f), 내용은 안내에 없음" % [
				prompt.is_visible_in_tree(), prompt.text.replace("\n", " / "), expected.replace("\n", " / "), prompt_bottom, corpse_top])


func _press_e() -> void:
	press_key(KEY_E, true)
	press_key(KEY_E, false)
	await wait_frames(WAIT_FRAMES)


## 발밑에 바닥 물건을 놓으면 시체보다 가까우므로 E가 그것을 줍고, 채집은 시작되지 않는다.
func _nearer_pickup_first() -> bool:
	var pickup: Pickup = _necromancer.pickup_scene.instantiate()
	pickup.stack = ItemStack.of_item(load(BONE_PATH), 1)
	_necromancer.get_parent().add_child(pickup)
	pickup.global_position = _necromancer.global_position
	await wait_frames(WAIT_FRAMES)
	var evidence: String = "바닥 물건 거리 %.1f, 시체 거리 %.1f, 바닥 물건 안내 %s, 시체 안내 %s" % [
		pickup.global_position.distance_to(_necromancer.global_position), _corpse.global_position.distance_to(_necromancer.global_position),
		pickup.is_prompt_visible(), _corpse.is_prompt_visible()]
	if not _check("더 가까운 것에 안내", pickup.is_prompt_visible() and not _corpse.is_prompt_visible(), evidence):
		return false
	var bones_before: int = _inventory.get_count(&"bone")
	await _press_e()
	var picked: bool = not is_instance_valid(pickup) or pickup.is_queued_for_deletion()
	if not _check("E는 더 가까운 바닥 물건을 주움", picked and not _necromancer.is_harvesting() and _inventory.get_count(&"bone") == bones_before + 1,
			"주움 %s, 채집 시작 %s, 뼈 %d → %d" % [picked, _necromancer.is_harvesting(), bones_before, _inventory.get_count(&"bone")]):
		return false
	return _check("바닥 물건이 없어지면 다시 시체에 안내", _corpse.is_prompt_visible(), "시체 안내 보임 %s" % _corpse.is_prompt_visible())


func _move_cancels() -> bool:
	await _press_e()
	await wait_frames(PARTIAL_FRAMES)
	var started: bool = _necromancer.is_harvesting() and _hud.is_harvest_gauge_visible() and _hud.get_harvest_progress() > 0.0
	var progress: float = _hud.get_harvest_progress()
	press_moves(Vector2.RIGHT)
	await wait_frames(1)
	press_moves(Vector2.ZERO)
	await wait_frames(WAIT_FRAMES)
	var ok: bool = started and not _necromancer.is_harvesting() and not _hud.is_harvest_gauge_visible() and _corpse.loot.get_stacks().size() == 2
	if not _check("움직이면 채집 취소", ok, "채집 시작·게이지 %s (%.2f) → 한 프레임 이동 뒤 채집 중 %s, 게이지 보임 %s, 시체 %s" % [
			started, progress, _necromancer.is_harvesting(), _hud.is_harvest_gauge_visible(), _describe_loot()]):
		return false
	return await _walk_to(_corpse.global_position + STAND_OFFSET, "시체 옆으로 돌아옴")


func _damage_cancels() -> bool:
	await _press_e()
	await wait_frames(PARTIAL_FRAMES)
	var started: bool = _necromancer.is_harvesting()
	var health_before: float = _necromancer.health
	_necromancer.take_damage(1.0)
	await wait_frames(WAIT_FRAMES)
	return _check("피해를 받으면 채집 취소", started and not _necromancer.is_harvesting() and not _hud.is_harvest_gauge_visible() and _corpse.loot.get_stacks().size() == 2,
			"채집 시작 %s → 피해(체력 %.0f → %.0f) 뒤 채집 중 %s, 게이지 보임 %s, 시체 %s" % [
				started, health_before, _necromancer.health, _necromancer.is_harvesting(), _hud.is_harvest_gauge_visible(), _describe_loot()])


## E를 눌러 채집이 끝날 때까지 기다리고, 시체에서 인벤토리로 옮겨 온 묶음을 돌려준다. 실패하면 null.
func _harvest_once(step_name: String) -> ItemStack:
	var stacks_before: Array[ItemStack] = _corpse.loot.get_stacks()
	await _press_e()
	if not _necromancer.is_harvesting():
		fail_step(step_name, "E를 눌러도 채집이 시작되지 않음, 시체 %s" % [_describe_loot()])
		return null
	# _press_e()가 기다린 프레임도 채집 시간에 들어간다.
	var frames: int = WAIT_FRAMES
	var max_progress: float = 0.0
	while _necromancer.is_harvesting() and frames < MOVE_TIMEOUT_FRAMES:
		max_progress = maxf(max_progress, _hud.get_harvest_progress())
		await wait_frames(1)
		frames += 1
	var stacks_after: Array[ItemStack] = _corpse.loot.get_stacks()
	var taken: Array[ItemStack] = stacks_before.filter(func(stack: ItemStack) -> bool: return not stacks_after.has(stack))
	if taken.size() != 1:
		fail_step(step_name, "시체에서 빠진 묶음 %d개 (기대 1), %d프레임" % [taken.size(), frames])
		return null
	var stack: ItemStack = taken[0]
	var expected_frames: int = roundi(_corpse.loot.get_harvest_time(stack) * Engine.physics_ticks_per_second)
	var in_inventory: bool = _inventory.get_skulls().has(stack.skull) if stack.is_skull() else _inventory.get_count(stack.item.id) > 0
	var ok: bool = in_inventory and absi(frames - expected_frames) <= DURATION_TOLERANCE_FRAMES and not _hud.is_harvest_gauge_visible() and max_progress > 0.5
	if not _check(step_name, ok, "%s×%d 얻음 (인벤토리에 있음 %s), %d프레임 걸림 (기대 %d = %.1f초 × 배율 %.1f), 게이지 최대 %.2f 뒤 숨김 %s, 시체에 남은 것 %s" % [
			stack.item.id, stack.count, in_inventory, frames, expected_frames, _corpse.loot.base_time, stack.item.harvest_time_multiplier,
			max_progress, not _hud.is_harvest_gauge_visible(), _describe_loot()]):
		return null
	return stack


func _check_empty_corpse() -> bool:
	var still_there: bool = is_instance_valid(_corpse) and not _corpse.is_queued_for_deletion()
	if not _check("빈 시체로 남음", still_there and _corpse.loot.is_empty() and not _corpse.is_available() and not _corpse.is_prompt_visible(),
			"시체 남음 %s, 비었음 %s, E 대상 %s, 안내 보임 %s (색은 empty_color로 바뀜)" % [
				still_there, _corpse.loot.is_empty(), _corpse.is_available(), _corpse.is_prompt_visible()]):
		return false
	await _press_e()
	return _check("빈 시체에 E는 아무것도 안 함", not _necromancer.is_harvesting(), "채집 중 %s" % _necromancer.is_harvesting())


func _check_totals(bones_before: int, harvested: Array[ItemStack]) -> void:
	var kinds: Array = harvested.map(func(stack: ItemStack) -> String: return String(stack.item.id))
	var bone_stacks: Array[ItemStack] = harvested.filter(func(stack: ItemStack) -> bool: return not stack.is_skull())
	var skull_stacks: Array[ItemStack] = harvested.filter(func(stack: ItemStack) -> bool: return stack.is_skull())
	if not _check("두 번에 두 종류", bone_stacks.size() == 1 and skull_stacks.size() == 1, "채집 순서 %s" % [kinds]):
		return
	var expected_bones: int = bones_before + bone_stacks[0].count
	var bone_label: String = (_hud.get_node("%BoneLabel") as Label).text
	if not _check("뼈 개수", _inventory.get_count(&"bone") == expected_bones and bone_label.ends_with(" %d" % expected_bones),
			"뼈 %d (기대 %d), HUD '%s'" % [_inventory.get_count(&"bone"), expected_bones, bone_label]):
		return
	var skull: Skull = skull_stacks[0].skull
	var hud_lines: PackedStringArray = _hud.get_skull_lines()
	var expected_line: String = "%s %d" % [skull.data.display_name, _inventory.get_skull_counts()[skull.data]]
	if _check("머리뼈 저장·HUD", _inventory.get_skulls().has(skull) and skull.durability == skull.data.max_durability and hud_lines.has(expected_line),
			"인벤토리에 %s(내구도 %.0f/%.0f), HUD %s (기대 줄 '%s')" % [skull.data.id, skull.durability, skull.data.max_durability, hud_lines, expected_line]):
		finish(true)
