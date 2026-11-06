extends ScenarioTest
## 뛰기·구르기·스태미나 흐름 (거점에서 시작, 몬스터 없음):
## 가득 차면 도넛 숨김 → Shift+이동으로 뛰기(빠르고, 스태미나가 줄기만 함, 도넛 보임) → 멈추면 회복 → 가득 차면 숨김
## → Space로 구르기(이동 방향, 거리, 비용, 앞부분 무적) → 0까지 뛰면 걷는 속도로 돌아가고 구르기 불가
## → 언데드는 멀리 떨어지면 뛰는 속도로 따라옴

const WAIT_FRAMES: int = 3
const PHYSICS_FPS: float = 60.0
const RUN_FRAMES: int = 60
const REST_FRAMES: int = 30
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
## 구르는 방향 (이동 방향)
const ROLL_DIRECTION: Vector2 = Vector2.DOWN

var _necromancer: Necromancer
var _ring: StaminaRing


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	_ring = _necromancer.get_node("StaminaRing")
	_run()


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
	return ok


func _describe() -> String:
	var stamina: Stamina = _necromancer.stamina
	return "스태미나 %.1f / %.1f, 도넛 보임 %s (비율 %.2f)" % [stamina.current, stamina.maximum, _ring.visible, _ring.get_shown_ratio()]


func _run() -> void:
	var stamina: Stamina = _necromancer.stamina
	await wait_frames(WAIT_FRAMES)
	if not _check("처음", stamina.is_full() and not _ring.visible, _describe()):
		return

	# 1. 뛰기
	var start: Vector2 = _necromancer.global_position
	press_key(KEY_SHIFT, true)
	press_moves(Vector2.RIGHT)
	await wait_frames(1)
	var previous: float = stamina.current
	var only_down: bool = true
	for i: int in RUN_FRAMES - 1:
		await wait_frames(1)
		if stamina.current > previous:
			only_down = false
		previous = stamina.current
	var moved: float = _necromancer.global_position.x - start.x
	var expected_move: float = _necromancer.run_speed * RUN_FRAMES / PHYSICS_FPS
	var expected_stamina: float = stamina.maximum - stamina.run_cost_per_second * RUN_FRAMES / PHYSICS_FPS
	var evidence: String = "%d프레임(1초) 뛰기: %.1fpx 이동 (뛰기 %.0f/초, 걷기 %.0f/초 → 기대 %.1f), 뛰는 중 %s, 줄기만 함 %s, %s (기대 %.1f)" % [
		RUN_FRAMES, moved, _necromancer.run_speed, _necromancer.move_speed, expected_move, _necromancer.is_running, only_down, _describe(), expected_stamina]
	if not _check("뛰기와 스태미나 감소", _necromancer.is_running and only_down and absf(moved - expected_move) < _necromancer.run_speed / PHYSICS_FPS * 2.0
			and absf(stamina.current - expected_stamina) < stamina.run_cost_per_second / PHYSICS_FPS * 2.0 and _ring.visible and is_equal_approx(_ring.get_shown_ratio(), stamina.get_ratio()), evidence):
		return

	# 2. 멈추면 회복
	press_moves(Vector2.ZERO)
	press_key(KEY_SHIFT, false)
	await wait_frames(1)
	var rest_start: float = stamina.current
	await wait_frames(REST_FRAMES)
	var expected_rest: float = minf(rest_start + stamina.regen_per_second * REST_FRAMES / PHYSICS_FPS, stamina.maximum)
	evidence = "멈추고 %d프레임: %.1f → %s (기대 %.1f)" % [REST_FRAMES, rest_start, _describe(), expected_rest]
	if not _check("멈추면 회복", stamina.current > rest_start and absf(stamina.current - expected_rest) < stamina.regen_per_second / PHYSICS_FPS * 2.0 and _ring.visible, evidence):
		return
	var full_frames: int = await _wait_until_full()
	if not _check("가득 차면 도넛 숨김", stamina.is_full() and not _ring.visible, "%d프레임 더 기다림, %s" % [full_frames, _describe()]):
		return

	# 3. 구르기 (이동 방향, 앞부분 무적)
	start = _necromancer.global_position
	var health_before: float = _necromancer.health
	press_moves(ROLL_DIRECTION)
	press_key(KEY_SPACE, true)
	await wait_frames(1)
	press_key(KEY_SPACE, false)
	var rolled: bool = _necromancer.is_rolling()
	var after_cost: float = stamina.current
	_necromancer.take_damage(1.0)
	var health_in_invincible: float = _necromancer.health
	press_moves(Vector2.ZERO)
	var roll_frames: int = 0
	var regen_during_roll: bool = false
	var invincible_frames: int = 0
	while _necromancer.is_rolling() and roll_frames < 120:
		if _necromancer.is_invincible():
			invincible_frames += 1
		await wait_frames(1)
		roll_frames += 1
		if stamina.current > after_cost:
			regen_during_roll = true
	var offset: Vector2 = _necromancer.global_position - start
	evidence = "구르기 시작 %s, %d프레임 동안 %s 방향으로 (%.1f, %.1f) 이동 (거리 설정 %.0f), 스태미나 %.1f → %.1f (비용 %.0f), 구르는 중 회복 %s, 무적 %d프레임 (설정 %.2f초), 무적 중 피해 → 체력 %.0f → %.0f" % [
		rolled, roll_frames, ROLL_DIRECTION, offset.x, offset.y, _necromancer.roll_distance, stamina.maximum, after_cost, stamina.roll_costs[0], regen_during_roll,
		invincible_frames, _necromancer.roll_invincible_duration, health_before, health_in_invincible]
	if not _check("구르기", rolled and absf(offset.y - _necromancer.roll_distance) < _necromancer.roll_distance * 0.1 and absf(offset.x) < 0.5
			and is_equal_approx(after_cost, stamina.maximum - stamina.roll_costs[0]) and not regen_during_roll and health_in_invincible == health_before and invincible_frames > 0, evidence):
		return
	_necromancer.take_damage(1.0)
	if not _check("구른 뒤에는 피해를 받음", _necromancer.health == health_before - 1.0, "구르기가 끝난 뒤 피해 1 → 체력 %.0f → %.0f" % [health_before, _necromancer.health]):
		return

	# 4. 0까지 뛰면 걷기로 돌아가고 구르기 불가
	await _wait_until_full()
	press_key(KEY_SHIFT, true)
	press_moves(Vector2.LEFT)
	var limit: int = ceili(stamina.maximum / stamina.run_cost_per_second * PHYSICS_FPS) + 30
	var frames: int = 0
	while stamina.current > 0.0 and frames < limit:
		await wait_frames(1)
		frames += 1
	await wait_frames(WAIT_FRAMES)
	var x_before: float = _necromancer.global_position.x
	await wait_frames(10)
	var walk_speed: float = (x_before - _necromancer.global_position.x) * PHYSICS_FPS / 10.0
	var roll_ok: bool = _necromancer.try_roll()
	evidence = "%d프레임 만에 0, Shift를 누른 채 이동 속도 %.0f/초 (걷기 %.0f), 뛰는 중 %s, 구르기 시도 %s, %s" % [
		frames, walk_speed, _necromancer.move_speed, _necromancer.is_running, roll_ok, _describe()]
	if not _check("스태미나가 없으면 뛰기·구르기 불가", not _necromancer.is_running and absf(walk_speed - _necromancer.move_speed) < 2.0 and not roll_ok and not stamina.can_roll(), evidence):
		return
	press_key(KEY_SHIFT, false)
	press_moves(Vector2.ZERO)

	# 5. 언데드가 뛰는 속도로 따라옴
	await _wait_until_full()
	await _undead_catch_up()


func _wait_until_full() -> int:
	var frames: int = 0
	while not _necromancer.stamina.is_full() and frames < 600:
		await wait_frames(1)
		frames += 1
	await wait_frames(1)
	return frames


func _undead_catch_up() -> void:
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), 10))
	root.get_node("GameState").hotbar.assign(0, skull)
	_necromancer.summoner.toggle_selected()
	await wait_frames(WAIT_FRAMES * 10)
	var undead: Undead = get_first_node_in_group(&"undead") as Undead
	if undead == null:
		fail_step("언데드 따라오기", "소환되지 않음")
		return
	# 가까이에서 따라갈 때는 언데드 자기 속도와 네크로맨서 걷는 속도 중 빠른 쪽이다.
	var walk_speed: float = maxf(undead.data.move_speed, _necromancer.move_speed)
	press_key(KEY_SHIFT, true)
	press_moves(Vector2.UP)
	var max_speed: float = 0.0
	for i: int in 60:
		await wait_frames(1)
		max_speed = maxf(max_speed, undead.velocity.length())
	press_key(KEY_SHIFT, false)
	press_moves(Vector2.ZERO)
	var evidence: String = "네크로맨서가 1초 뜀: 언데드 최고 속도 %.0f/초 (가까이 따라갈 때 속도 %.0f, 네크로맨서 뛰기 %.0f)" % [max_speed, walk_speed, _necromancer.run_speed]
	if not _check("언데드는 멀어지면 뛰는 속도로 따라옴", walk_speed < _necromancer.run_speed and is_equal_approx(max_speed, _necromancer.run_speed), evidence):
		return
	await wait_frames(60)
	evidence = "가까워진 뒤 언데드 속도 %.0f/초, 거리 %.0f" % [undead.velocity.length(), undead.global_position.distance_to(_necromancer.global_position)]
	if not _check("가까워지면 원래대로", undead.velocity.length() <= walk_speed + 0.01, evidence):
		return
	await _wait_until_full()
	await _space_with_menu_open(skull)


## 메뉴가 열린 채 Space: 구르기만 되고 메뉴는 그대로. 마우스로 쓰는 UI는 키보드 포커스를 받지 않아야 한다.
func _space_with_menu_open(skull: Skull) -> void:
	var screen: InventoryScreen = current_scene.get_node("InventoryScreen")
	screen.set_open(true)
	await wait_frames(WAIT_FRAMES)
	var slot_index: int = -1
	for i: int in _necromancer.inventory.get_slot_count():
		var slot: ItemStack = _necromancer.inventory.get_slot(i)
		if slot != null and slot.skull == skull:
			slot_index = i
	await click_ui(screen.get_slot_control(slot_index).get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	var menu: ItemMenu = screen.get_menu()
	var button: Button = menu.get_button(&"heal_skull")
	# 실제 마우스 클릭은 포커스를 줄 수 있으므로 직접 포커스를 달라고 해 본다 (FOCUS_NONE이면 받지 않는다).
	if button != null:
		button.grab_focus()
	# 메뉴 버튼은 메뉴를 열 때 만들어지므로, 연 뒤에 씬 전체를 확인한다.
	var focusable: Array[String] = []
	for node: Node in current_scene.find_children("*", "Control", true, false):
		if (node as Control).focus_mode != Control.FOCUS_NONE:
			focusable.append(str(current_scene.get_path_to(node)))
	var focus_owner: Control = root.gui_get_focus_owner()
	var inventory_before: String = _inventory_text()
	var stamina_before: float = _necromancer.stamina.current
	press_key(KEY_SPACE, true)
	await wait_frames(1)
	press_key(KEY_SPACE, false)
	var rolled: bool = _necromancer.is_rolling()
	await wait_frames(WAIT_FRAMES)
	var evidence: String = "포커스를 받을 수 있는 UI %s, 메뉴 열림 %s → %s, 포커스 %s, Space 뒤 구르기 %s (스태미나 %.0f → %.0f), 인벤토리 '%s' → '%s'" % [
		focusable, button != null, menu.is_open(), focus_owner, rolled, stamina_before, _necromancer.stamina.current, inventory_before, _inventory_text()]
	if not _check("메뉴가 열린 채 Space면 구르기만", focusable.is_empty() and button != null and focus_owner == null and rolled and menu.is_open()
			and screen.is_open() and _inventory_text() == inventory_before, evidence):
		return
	finish(true)


func _inventory_text() -> String:
	var parts: Array[String] = []
	for i: int in _necromancer.inventory.get_slot_count():
		var stack: ItemStack = _necromancer.inventory.get_slot(i)
		if stack != null:
			parts.append("%d:%s×%d" % [i, stack.item.id, stack.count])
	return ", ".join(parts)
