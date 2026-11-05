extends ScenarioTest
## 시나리오: 마나 자연 회복과 기본 공격의 마나 비용.
## 1. 처음에는 마나가 가득 차 있고 HUD 마나 바도 같다
## 2. 기본 공격(데이터상 비용 0)은 쏴도 마나가 줄지 않는다
## 3. 비용이 있는 공격(업그레이드된 공격을 흉내 냄)은 한 발마다 비용만큼 줄어든다
## 4. 마나가 비용보다 적으면 쏘지 않는다
## 5. 자연 회복으로 1초에 초당 회복량만큼 차고, HUD 마나 바도 따라간다

## 3~4단계에서 공격 데이터 복사본에 넣을 비용 (실제 데이터 파일은 바꾸지 않는다)
const TEST_MANA_COST: float = 3.0
## 4단계에서 남겨 둘 마나 (TEST_MANA_COST보다 작아야 한다)
const LOW_MANA: float = 1.0
const FIRE_FRAMES: int = 30
const SHOT_TIMEOUT_FRAMES: int = 60
const REGEN_FRAMES: int = 60
const PHYSICS_FPS: float = 60.0
## 남쪽으로 떨어뜨려 몬스터가 쫓아오지 않게 한다
const SAFE_POSITION: Vector2 = Vector2(0, 600)
const AIM_OFFSET: Vector2 = Vector2(100, 0)
const WAIT_FRAMES: int = 3
## 쥐 언데드 2마리를 띄우고 마나가 줄어드는지 지켜보는 시간 (3초)
const UPKEEP_FRAMES: int = 180
const RAT_PATH: String = "res://data/monsters/rat.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"

enum Step { FREE_ATTACK, PAID_ATTACK, NOT_ENOUGH, REGEN, UPKEEP }

var _step: Step = Step.FREE_ATTACK
var _necromancer: Necromancer
var _mana_bar: ProgressBar
var _hud: Hud
var _shots: int = 0
var _shots_before: int = 0
var _mana_before: float = 0.0
var _regen: float = 0.0


func get_start_scene() -> String:
	return TEST_REGION_SCENE


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	_hud = find_hud()
	_mana_bar = _hud.get_node("%ManaBar")
	_necromancer.position = SAFE_POSITION
	# 탄이 생길 때마다 센다.
	_necromancer.get_parent().child_entered_tree.connect(_on_actor_added)
	_regen = _necromancer.mana.regen_per_second

	var mana: ManaPool = _necromancer.mana
	var expected_text: String = "%d / %d" % [mana.maximum, mana.maximum]
	var evidence: String = "마나 %.1f / %.1f, HUD 바 %.1f / %.1f, 바 글씨 '%s', 초당 회복 %.1f" % [mana.current, mana.maximum, _mana_bar.value, _mana_bar.max_value, _bar_text(), _regen]
	if mana.current == mana.maximum and _mana_bar.value == mana.current and _mana_bar.max_value == mana.maximum and _bar_text() == expected_text:
		pass_step("처음 마나", evidence)
	else:
		fail_step("처음 마나", evidence)
		return

	print("        기본 공격 데이터: %s, 피해 %.1f, 마나 비용 %.1f" % [_necromancer.attack.id, _necromancer.attack.damage, _necromancer.attack.mana_cost])
	_shots_before = _shots
	_mana_before = mana.current
	_aim()
	press_mouse(true)


func _tick() -> void:
	_aim()
	match _step:
		Step.FREE_ATTACK:
			_free_attack()
		Step.PAID_ATTACK:
			_paid_attack()
		Step.NOT_ENOUGH:
			_not_enough()
		Step.REGEN:
			_regenerate()


func _go(step: Step) -> void:
	_step = step
	restart_step_timer()


func _on_actor_added(node: Node) -> void:
	if node is Bolt:
		_shots += 1


func _bar_text() -> String:
	return (_mana_bar.get_node("%ValueLabel") as Label).text


func _aim() -> void:
	aim_mouse_at(_necromancer.global_position + AIM_OFFSET)


func _free_attack() -> void:
	if step_frames < FIRE_FRAMES:
		return
	press_mouse(false)
	var fired: int = _shots - _shots_before
	var evidence: String = "%d프레임 동안 %d발, 마나 %.1f → %.1f" % [FIRE_FRAMES, fired, _mana_before, _necromancer.mana.current]
	if _necromancer.attack.mana_cost != 0.0:
		fail_step("기본 공격 비용 0", "데이터의 마나 비용이 %.1f임" % _necromancer.attack.mana_cost)
	elif fired > 0 and _necromancer.mana.current == _mana_before:
		pass_step("기본 공격 비용 0", evidence)
	else:
		fail_step("기본 공격 비용 0", evidence)
		return
	# 비용 확인 중에는 회복이 섞이지 않게 잠시 끈다.
	_necromancer.mana.regen_per_second = 0.0
	_necromancer.attack = _necromancer.attack.duplicate()
	_necromancer.attack.mana_cost = TEST_MANA_COST
	_shots_before = _shots
	_mana_before = _necromancer.mana.current
	press_mouse(true)
	_go(Step.PAID_ATTACK)


func _paid_attack() -> void:
	var fired: int = _shots - _shots_before
	if fired == 0:
		if step_frames > SHOT_TIMEOUT_FRAMES:
			fail_step("공격 비용", "%d프레임 안에 한 발도 나가지 않음" % SHOT_TIMEOUT_FRAMES)
		return
	press_mouse(false)
	var spent: float = _mana_before - _necromancer.mana.current
	var evidence: String = "비용 %.1f인 공격 %d발, 마나 %.1f → %.1f (줄어든 양 %.1f)" % [TEST_MANA_COST, fired, _mana_before, _necromancer.mana.current, spent]
	if is_equal_approx(spent, TEST_MANA_COST * fired):
		pass_step("공격 비용", evidence)
	else:
		fail_step("공격 비용", evidence)
		return
	_necromancer.mana.try_spend(_necromancer.mana.current - LOW_MANA)
	_shots_before = _shots
	_mana_before = _necromancer.mana.current
	press_mouse(true)
	_go(Step.NOT_ENOUGH)


func _not_enough() -> void:
	if step_frames < FIRE_FRAMES:
		return
	press_mouse(false)
	var fired: int = _shots - _shots_before
	var evidence: String = "마나 %.1f에서 비용 %.1f인 공격을 %d프레임 누름: %d발, 마나 %.1f → %.1f" % [_mana_before, TEST_MANA_COST, FIRE_FRAMES, fired, _mana_before, _necromancer.mana.current]
	if fired == 0 and _necromancer.mana.current == _mana_before:
		pass_step("마나 부족", evidence)
	else:
		fail_step("마나 부족", evidence)
		return
	_necromancer.mana.regen_per_second = _regen
	_mana_before = _necromancer.mana.current
	_go(Step.REGEN)


func _regenerate() -> void:
	if step_frames < REGEN_FRAMES:
		return
	var mana: ManaPool = _necromancer.mana
	var expected: float = minf(_mana_before + _regen * REGEN_FRAMES / PHYSICS_FPS, mana.maximum)
	# 실제 값이 아니라 기대값으로 글씨를 정해야, 표시 계산이 틀려도 잡아낸다.
	var expected_text: String = "%d / %d" % [roundi(expected), roundi(mana.maximum)]
	var expected_change: String = "+%.1f" % _regen
	var evidence: String = "%d프레임(1초) 뒤 마나 %.2f → %.2f (기대 %.2f), HUD 바 %.2f, 바 글씨 '%s', 초당 변화량 '%s' (기대 '%s')" % [
		REGEN_FRAMES, _mana_before, mana.current, expected, _mana_bar.value, _bar_text(), _hud.get_mana_change_text(), expected_change]
	# 프레임 한 번만큼의 회복량은 오차로 허용한다.
	if absf(mana.current - expected) <= _regen / PHYSICS_FPS + 0.0001 and is_equal_approx(_mana_bar.value, mana.current) and _bar_text() == expected_text \
			and _hud.get_mana_change_text() == expected_change:
		pass_step("자연 회복과 + 표시", evidence)
		_go(Step.UPKEEP)
		_check_upkeep()
	else:
		fail_step("자연 회복과 + 표시", evidence)


## 언데드 유지비: 가득 차면 숫자 숨김 → 쥐 1마리(회복이 더 큼, +) → 2마리(유지비가 더 큼, 마나가 줄고 -)
func _check_upkeep() -> void:
	var mana: ManaPool = _necromancer.mana
	var rat: MonsterData = load(RAT_PATH)
	mana.regenerate(mana.maximum)  # 가득 채운다
	await wait_frames(WAIT_FRAMES)
	var evidence: String = "마나 %.1f / %.1f, 언데드 0마리, 표시 '%s'" % [mana.current, mana.maximum, _hud.get_mana_change_text()]
	if mana.current != mana.maximum or _hud.get_mana_change_text() != "":
		fail_step("가득 차고 언데드 없으면 숫자 숨김", evidence)
		return
	pass_step("가득 차고 언데드 없으면 숫자 숨김", evidence)

	var bone: ItemData = load(BONE_PATH)
	var skull_data: SkullData = load(RAT_SKULL_PATH)
	var game_state: Node = root.get_node("GameState")
	_necromancer.inventory.try_add(ItemStack.of_item(bone, rat.summon_bone_cost * 2))
	for i: int in 2:
		var skull: Skull = Skull.create(skull_data)
		_necromancer.inventory.try_add(ItemStack.of_skull(skull))
		game_state.hotbar.assign(i, skull)
	var roster: UndeadRoster = _necromancer.summoner.roster

	await _tap(KEY_1)
	await _tap(KEY_G)
	await wait_frames(WAIT_FRAMES)
	# 회복과 유지비가 딱 맞으면(계산값 0) 숫자를 숨긴다 (ManaPool.has_change).
	var one_change: float = _regen - rat.undead_upkeep_mana_per_second
	var one_expected: String = "" if is_zero_approx(one_change) else "%s%.1f" % ["+" if one_change > 0.0 else "-", absf(one_change)]
	evidence = "쥐 언데드 %d마리, 유지비 %.1f/초 (쥐 데이터 %.1f), 회복 %.1f/초, 표시 '%s' (기대 '%s')" % [
		roster.get_count(), roster.get_upkeep_per_second(), rat.undead_upkeep_mana_per_second, _regen, _hud.get_mana_change_text(), one_expected]
	if roster.get_count() != 1 or _hud.get_mana_change_text() != one_expected:
		fail_step("1마리", evidence)
		return
	pass_step("1마리", evidence)

	await _tap(KEY_2)
	await _tap(KEY_G)
	await wait_frames(WAIT_FRAMES)
	var before: float = mana.current
	var change: float = _regen - rat.undead_upkeep_mana_per_second * 2
	await wait_frames(UPKEEP_FRAMES)
	var expected_change: String = "-%.1f" % absf(change)
	var expected_mana: float = before + change * UPKEEP_FRAMES / PHYSICS_FPS
	evidence = "쥐 언데드 %d마리, 유지비 %.1f/초, %d프레임(%.0f초) 동안 마나 %.2f → %.2f (기대 %.2f), 표시 '%s' (기대 '%s')" % [
		roster.get_count(), roster.get_upkeep_per_second(), UPKEEP_FRAMES, UPKEEP_FRAMES / PHYSICS_FPS, before, mana.current, expected_mana, _hud.get_mana_change_text(), expected_change]
	if roster.get_count() == 2 and change < 0.0 and mana.current < before and absf(mana.current - expected_mana) < 0.05 and _hud.get_mana_change_text() == expected_change:
		pass_step("2마리면 마나가 줄고 - 표시", evidence)
		finish(true)
	else:
		fail_step("2마리면 마나가 줄고 - 표시", evidence)


func _tap(key: Key) -> void:
	press_key(key, true)
	await wait_frames(1)
	press_key(key, false)
	await wait_frames(1)
