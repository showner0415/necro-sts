extends ScenarioTest
## 시나리오: 몬스터 처치 → 드랍(뼈 + 머리뼈) → 흩뜨림 → 줍기 안내 → 하나씩 줍기 → 인벤토리·HUD.
## 가장 가까운 몬스터를 마우스로 조준해 쏘고(멀면 다가가고), 떨어진 물건마다 걸어가서
## 그 물건 위에 이름과 키 안내가 뜨는지 본 뒤 줍기 키를 누른다.
##
## 확률 고정: 대상 몬스터의 데이터를 복사해 모든 드랍 확률을 FORCED_DROP_CHANCE로 바꾼다
## (실제 데이터 파일은 바꾸지 않는다). 그래서 머리뼈가 매번 나온다.

const FORCED_DROP_CHANCE: float = 1.0
const KILL_TIMEOUT_FRAMES: int = 600
const MOVE_TIMEOUT_FRAMES: int = 300
const WAIT_FRAMES: int = 3
## 이 거리 안까지 걸어가서 줍는다. 흩뜨린 다른 물건보다 확실히 가까워야 한다.
const ARRIVE_DISTANCE: float = 2.0
## 흩뜨린 물건끼리 최소한 이만큼은 떨어져 있어야 한다
const MIN_SCATTER_GAP: float = 4.0
## 사거리의 이 비율보다 멀면 조준하면서 다가간다
const APPROACH_RATIO: float = 0.8
const PICKUP_KEY_TEXT: String = "[E]"

enum Step { KILL, WAIT_DROP, MOVE, PROMPT, PICKUP }

var _step: Step = Step.KILL
var _necromancer: Necromancer
var _target: Monster
var _last_target_position: Vector2
var _scatter_radius: float
## 떨어질 것으로 기대하는 더미들: [아이템 id, 개수, 머리뼈인지]
var _expected_drops: Array = []
## 아직 줍지 않은 더미들
var _remaining: Array[Pickup] = []
var _current: Pickup
var _current_name: String
var _bones_before: int
var _skulls_before: int


func get_start_scene() -> String:
	return TEST_REGION_SCENE


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	if _necromancer == null:
		fail_step("준비", "necromancer 그룹의 노드가 없습니다")
		return
	var nearest_distance: float = INF
	for node: Node in current_scene.find_children("*", "CharacterBody2D", true, false):
		var monster: Monster = node as Monster
		if monster == null:
			continue
		var distance: float = monster.global_position.distance_to(_necromancer.global_position)
		if distance < nearest_distance:
			_target = monster
			nearest_distance = distance
	if _target == null:
		fail_step("준비", "씬에 몬스터가 없습니다")
		return

	_target.data = _with_forced_chance(_target.data)
	# 대상은 죽으면 사라지므로 드랍을 찾을 반지름을 미리 읽어 둔다.
	_scatter_radius = _target.drop_scatter_radius
	for entry: DropEntry in _target.data.drops:
		if entry.item is SkullData:
			for i: int in entry.count:
				_expected_drops.append([entry.item.id, 1, true])
		else:
			_expected_drops.append([entry.item.id, entry.count, false])
	_bones_before = _necromancer.inventory.get_count(&"bone")
	_skulls_before = _necromancer.inventory.get_skulls().size()
	print("[준비] 대상 %s (%s, 체력 %.0f, 거리 %.0f), 드랍 확률을 %.1f로 고정, 기대 더미 %s" % [
		_target.name, _target.data.id, _target.health, nearest_distance, FORCED_DROP_CHANCE, _expected_drops])
	press_mouse(true)


func _with_forced_chance(data: MonsterData) -> MonsterData:
	var copy: MonsterData = data.duplicate()
	var drops: Array[DropEntry] = []
	for entry: DropEntry in data.drops:
		var entry_copy: DropEntry = entry.duplicate()
		entry_copy.chance = FORCED_DROP_CHANCE
		drops.append(entry_copy)
	copy.drops = drops
	return copy


func _tick() -> void:
	match _step:
		Step.KILL:
			_kill()
		Step.WAIT_DROP:
			_wait_drop()
		Step.MOVE:
			_move()
		Step.PROMPT:
			_check_prompt()
		Step.PICKUP:
			_check_pickup()


func _go(step: Step) -> void:
	_step = step
	restart_step_timer()


func _kill() -> void:
	if not is_instance_valid(_target):
		press_mouse(false)
		press_moves(Vector2.ZERO)
		pass_step("처치", "%d프레임 만에 대상이 사라짐, 네크로맨서 체력 %.0f" % [step_frames, _necromancer.health])
		_go(Step.WAIT_DROP)
		return
	if step_frames > KILL_TIMEOUT_FRAMES:
		fail_step("처치", "%d프레임 안에 잡지 못함, 대상 체력 %.0f" % [KILL_TIMEOUT_FRAMES, _target.health])
		return
	_last_target_position = _target.global_position
	var aim: Vector2 = _target.global_position + Vector2(0, -_target.data.placeholder_radius)
	aim_mouse_at(aim)
	var to_target: Vector2 = _target.global_position - _necromancer.global_position
	if to_target.length() > _necromancer.attack.projectile_range * APPROACH_RATIO:
		press_moves(to_target.normalized())
	else:
		press_moves(Vector2.ZERO)


func _wait_drop() -> void:
	# 드랍은 call_deferred로 추가되므로 몇 프레임 뒤에 찾는다.
	if step_frames < WAIT_FRAMES:
		return
	var search_radius: float = _scatter_radius + 1.0
	for node: Node in current_scene.find_children("*", "Area2D", true, false):
		var pickup: Pickup = node as Pickup
		if pickup != null and pickup.global_position.distance_to(_last_target_position) <= search_radius:
			_remaining.append(pickup)

	# 드랍 내용
	var found: Array = []
	for pickup: Pickup in _remaining:
		found.append([pickup.stack.item.id, pickup.stack.count, pickup.stack.is_skull()])
	var sorted_found: Array = found.duplicate()
	sorted_found.sort()
	var sorted_expected: Array = _expected_drops.duplicate()
	sorted_expected.sort()
	if sorted_found != sorted_expected:
		fail_step("드랍", "처치 위치 근처 더미 %s (기대 %s)" % [found, _expected_drops])
		return
	for pickup: Pickup in _remaining:
		if pickup.stack.is_skull() and pickup.stack.skull.durability != pickup.stack.skull.data.max_durability:
			fail_step("드랍", "새 머리뼈 내구도 %.1f (기대 %.1f)" % [pickup.stack.skull.durability, pickup.stack.skull.data.max_durability])
			return
	pass_step("드랍", "처치 위치 근처 더미 %s, 머리뼈는 최대 내구도" % [found])

	# 흩뜨림
	var min_gap: float = INF
	var positions: Array[Vector2] = []
	for pickup: Pickup in _remaining:
		positions.append(pickup.global_position.round())
		for other: Pickup in _remaining:
			if other != pickup:
				min_gap = minf(min_gap, pickup.global_position.distance_to(other.global_position))
	var scatter_evidence: String = "위치 %s, 가장 가까운 두 더미 사이 %.1f (최소 %.1f)" % [positions, min_gap, MIN_SCATTER_GAP]
	if _remaining.size() < 2 or min_gap >= MIN_SCATTER_GAP:
		pass_step("흩뜨림", scatter_evidence)
	else:
		fail_step("흩뜨림", scatter_evidence)
		return

	# 멀리 있을 때는 안내가 없어야 한다
	for pickup: Pickup in _remaining:
		if pickup.is_prompt_visible():
			fail_step("멀면 안내 없음", "%s 위에 안내가 떠 있음 (거리 %.0f)" % [pickup.get_display_name(), pickup.global_position.distance_to(_necromancer.global_position)])
			return
	pass_step("멀면 안내 없음", "거리 %.0f (줍기 범위 %.0f)에서 모든 더미 안내 꺼짐" % [_last_target_position.distance_to(_necromancer.global_position), _necromancer.pickup_range])
	_next_pickup()


func _next_pickup() -> void:
	if _remaining.is_empty():
		_check_totals()
		return
	_current = _remaining.pop_front()
	_go(Step.MOVE)


func _move() -> void:
	var to_pickup: Vector2 = _current.global_position - _necromancer.global_position
	if to_pickup.length() <= ARRIVE_DISTANCE:
		press_moves(Vector2.ZERO)
		pass_step("이동", "%s 옆 도착 (%d프레임, 거리 %.1f)" % [_current.get_display_name(), step_frames, to_pickup.length()])
		_go(Step.PROMPT)
		return
	if step_frames > MOVE_TIMEOUT_FRAMES:
		fail_step("이동", "%d프레임 안에 %s에 닿지 못함 (남은 거리 %.1f)" % [MOVE_TIMEOUT_FRAMES, _current.get_display_name(), to_pickup.length()])
		return
	# 가까워지면 천천히 다가가서 지나치지 않게 한다.
	press_moves(to_pickup.normalized() * minf(1.0, to_pickup.length() / ARRIVE_DISTANCE))


func _check_prompt() -> void:
	# 겹침 판정과 안내 갱신은 물리 프레임 뒤에 반영되므로 몇 프레임 기다린다.
	if step_frames < WAIT_FRAMES:
		return
	var prompt: Label = _current.get_node("%Prompt")
	var expected_text: String = "%s\n%s" % [_current.get_display_name(), PICKUP_KEY_TEXT]
	var others_shown: Array[String] = []
	for other: Pickup in _remaining:
		if other.is_prompt_visible():
			others_shown.append(other.get_display_name())
	var prompt_bottom: float = prompt.global_position.y + prompt.size.y
	var item_top: float = _current.global_position.y - _current.stack.item.placeholder_size.y
	var evidence: String = "안내 보임 %s, 글자 '%s' (기대 '%s'), 안내 아래 끝 y %.0f (물건 그림 위 끝 y %.0f), 다른 물건에 뜬 안내 %s" % [
		prompt.is_visible_in_tree(), prompt.text.replace("\n", " / "), expected_text.replace("\n", " / "),
		prompt_bottom, item_top, others_shown]
	# 안내의 아래 끝이 물건 그림의 위 끝보다 위에 있어야 "물건 위"이고 그림을 가리지 않는다.
	if prompt.is_visible_in_tree() and prompt.text == expected_text and prompt_bottom <= item_top and others_shown.is_empty():
		pass_step("줍기 안내", evidence)
	else:
		fail_step("줍기 안내", evidence)
		return
	# 주우면 더미 노드가 사라지므로 이름을 미리 적어 둔다.
	_current_name = _current.get_display_name()
	press_key(KEY_E, true)
	press_key(KEY_E, false)
	_go(Step.PICKUP)


func _check_pickup() -> void:
	if step_frames < WAIT_FRAMES:
		return
	var gone: bool = not is_instance_valid(_current) or _current.is_queued_for_deletion()
	if not gone:
		fail_step("줍기", "%s가 바닥에 그대로 있음" % _current_name)
		return
	pass_step("줍기", "%s 주움" % _current_name)
	_next_pickup()


func _check_totals() -> void:
	var inventory: Inventory = _necromancer.inventory
	var hud: Hud = find_hud()
	var expected_bones: int = _bones_before
	var expected_skulls: Dictionary[StringName, int] = {}
	for drop: Array in _expected_drops:
		if drop[2]:
			expected_skulls[drop[0]] = expected_skulls.get(drop[0], 0) + 1
		elif drop[0] == &"bone":
			expected_bones += drop[1]

	var bone_label: String = (hud.get_node("%BoneLabel") as Label).text
	var bone_evidence: String = "뼈 %d (기대 %d), HUD '%s'" % [inventory.get_count(&"bone"), expected_bones, bone_label]
	if inventory.get_count(&"bone") == expected_bones and bone_label.ends_with(" %d" % expected_bones):
		pass_step("뼈 개수", bone_evidence)
	else:
		fail_step("뼈 개수", bone_evidence)
		return

	var skulls: Array[Skull] = inventory.get_skulls()
	var new_skulls: Array[Skull] = skulls.slice(_skulls_before)
	var stored: Array = []
	for skull: Skull in new_skulls:
		stored.append("%s(내구도 %.0f/%.0f)" % [skull.data.id, skull.durability, skull.data.max_durability])
	var expected_lines: PackedStringArray = []
	for skull_data: SkullData in inventory.get_skull_counts():
		expected_lines.append("%s %d" % [skull_data.display_name, inventory.get_skull_counts()[skull_data]])
	var hud_lines: PackedStringArray = hud.get_skull_lines()
	var skull_evidence: String = "새로 저장된 머리뼈 %s (기대 종류별 %s), HUD %s" % [stored, expected_skulls, hud_lines]
	var stored_counts: Dictionary[StringName, int] = {}
	for skull: Skull in new_skulls:
		stored_counts[skull.data.id] = stored_counts.get(skull.data.id, 0) + 1
	if stored_counts == expected_skulls and hud_lines == expected_lines and not hud_lines.is_empty():
		pass_step("머리뼈 저장·HUD", skull_evidence)
		finish(true)
	else:
		fail_step("머리뼈 저장·HUD", skull_evidence)
