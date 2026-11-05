extends ScenarioTest
## 시나리오: 멧돼지(행동 조각 "돌진하기").
## 다가가기(돌진 거리 밖) → 예고(멈춤, 깜빡임, 방향이 대상을 따라 돌다 고정) → 돌진에 맞음(피해 한 번, 밀려남, 몸을 지나감)
## → 멈칫 → 구르기 무적 중에 맞으면 피해 없이 밀려나기만 → 언데드 멧돼지: 아군 색 방향 선, 돌진은 몬스터만 친다.
##
## 멧돼지 한 마리와 쥐 한 마리만 남기고 다른 몬스터는 치운다. 쥐는 언데드 단계에서 쓰려고 멀리 둔다.
## 쥐는 데이터를 복사해 움직이지 않고 피해를 주지 않게 바꾼다 (실제 데이터 파일은 바꾸지 않는다).
## 그래야 언데드 단계에서 네크로맨서 체력이 줄면 언데드 돌진 탓인지 알 수 있다.

const WAIT_FRAMES: int = 3
const TIMEOUT_FRAMES: int = 600
## 멧돼지에게서 이만큼 떨어져 선다: 감지 거리(100) 안, 돌진 거리(90) 밖
const APPROACH_OFFSET: Vector2 = Vector2(-95, 0)
## 예고 중 고정 전에 대상을 따라 도는지 보려고 옆으로 걷는 프레임
const SIDESTEP_FRAMES: int = 8
## 구르기 무적 확인: 돌진하는 멧돼지가 이 거리 안에 오면 멧돼지 쪽으로 구른다
const ROLL_TRIGGER_DISTANCE: float = 40.0
## 멈칫 시간 판정의 허용 오차 (프레임)
const RECOVER_TOLERANCE_FRAMES: int = 3
const PARKED_POSITION: Vector2 = Vector2(-420, 420)
const BOAR_SKULL_PATH: String = "res://data/skulls/boar_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 20
## 언데드 단계: 네크로맨서를 가운데 두고 왼쪽에 언데드 멧돼지, 오른쪽에 쥐 (돌진 길 위에 네크로맨서가 있다)
const UNDEAD_STAGE: Vector2 = Vector2(0, 300)
const UNDEAD_OFFSET: Vector2 = Vector2(-40, 0)
const RAT_OFFSET: Vector2 = Vector2(45, 0)

var _necromancer: Necromancer
var _boar: Monster
var _rat: Monster
var _charge: ChargeBehavior


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


func _state_name(state: ChargeBehavior.State) -> String:
	return ChargeBehavior.State.keys()[state]


## cond가 참이 될 때까지 기다린다. 걸린 프레임 수, 시간이 넘으면 -1.
## GDScript 람다는 바깥 지역 변수를 값으로 복사하므로, cond 안에서 기록할 것은 Dictionary(참조)에 넣는다.
func _wait_until(cond: Callable, max_frames: int = TIMEOUT_FRAMES) -> int:
	for frame: int in max_frames:
		if cond.call():
			return frame
		await wait_frames(1)
	return -1


func _run() -> void:
	_necromancer = find_necromancer()
	_boar = current_scene.get_node_or_null("Actors/Boar1")
	_rat = current_scene.get_node_or_null("Actors/Rat1")
	if _necromancer == null or _boar == null or _rat == null:
		fail_step("준비", "네크로맨서 %s, Boar1 %s, Rat1 %s" % [_necromancer, _boar, _rat])
		return
	for node: Node in get_nodes_in_group(&"monsters"):
		if node != _boar and node != _rat:
			node.queue_free()
	var harmless_rat: MonsterData = _rat.data.duplicate()
	harmless_rat.contact_damage = 0.0
	harmless_rat.move_speed = 0.0
	harmless_rat.wander_speed = 0.0
	_rat.data = harmless_rat
	_rat.position = PARKED_POSITION
	_charge = _boar.get_behavior() as ChargeBehavior
	if not _check("준비", _charge != null, "멧돼지 행동 조각 %s, 체력 %.0f, 다른 몬스터는 치우고 쥐는 %s에 둠" % [_boar.get_behavior(), _boar.health, PARKED_POSITION]):
		return

	if not await _approach():
		return
	if not await _windup():
		return
	if not await _charge_hits():
		return
	if not await _recover():
		return
	if not await _roll_through():
		return
	await _undead_boar()


func _approach() -> bool:
	_necromancer.global_position = _boar.global_position + APPROACH_OFFSET
	await wait_frames(WAIT_FRAMES)
	var to_necromancer: Vector2 = _boar.global_position.direction_to(_necromancer.global_position)
	var velocity: Vector2 = _boar.velocity
	return _check("돌진 거리 밖이면 다가가기만", _charge.get_state() == ChargeBehavior.State.APPROACH and velocity.normalized().dot(to_necromancer) > 0.99 and absf(velocity.length() - _boar.data.move_speed) < 0.01,
			"상태 %s, 속도 %s (크기 %.1f, 기대 %.1f, 네크로맨서 쪽), 거리 %.0f (돌진 거리 %.0f)" % [
				_state_name(_charge.get_state()), velocity.round(), velocity.length(), _boar.data.move_speed,
				_boar.global_position.distance_to(_necromancer.global_position), _charge.charge_range])


func _windup() -> bool:
	var frames: int = await _wait_until(func() -> bool: return _charge.get_state() == ChargeBehavior.State.WINDUP)
	if not _check("돌진 거리 안이면 예고 시작", frames >= 0 and _boar.velocity == Vector2.ZERO,
			"%d프레임 만에 예고, 멧돼지 속도 %s, 거리 %.0f" % [frames, _boar.velocity, _boar.global_position.distance_to(_necromancer.global_position)]):
		return false

	# 고정 전: 네크로맨서가 아래로 걸으면 방향이 따라 돈다. 그동안 깜빡이는지도 본다.
	var colors: Dictionary[Color, bool] = {}
	var before: Vector2 = _charge.get_direction()
	press_moves(Vector2.DOWN)
	for i: int in SIDESTEP_FRAMES:
		colors[_charge.get_body_color(_boar.data.placeholder_color)] = true
		await wait_frames(1)
	press_moves(Vector2.ZERO)
	var after: Vector2 = _charge.get_direction()
	var turned: float = rad_to_deg(absf(before.angle_to(after)))
	if not _check("고정 전에는 방향이 대상을 따라 돎", not _charge.is_direction_locked() and turned > 1.0,
			"방향 %s → %s (%.1f도 돎), 고정됨 %s" % [before, after, turned, _charge.is_direction_locked()]):
		return false

	await _wait_until(func() -> bool:
		colors[_charge.get_body_color(_boar.data.placeholder_color)] = true
		return _charge.is_direction_locked())
	var locked: Vector2 = _charge.get_direction()
	# 고정 뒤에는 조금 움직여도 방향이 그대로다 (돌진 길에서 벗어나지 않을 만큼만 움직인다).
	press_moves(Vector2.UP)
	await wait_frames(2)
	press_moves(Vector2.ZERO)
	var still_locked: bool = _charge.get_direction() == locked
	if not _check("고정 뒤에는 방향 그대로", _charge.get_state() == ChargeBehavior.State.WINDUP and still_locked,
			"고정된 방향 %s, 움직인 뒤 %s, 상태 %s" % [locked, _charge.get_direction(), _state_name(_charge.get_state())]):
		return false
	return _check("예고 중 깜빡임", colors.has(_charge.blink_color) and colors.has(_boar.data.placeholder_color),
			"보인 몸 색 %s (원래 %s, 깜빡임 %s)" % [colors.keys().map(func(c: Color) -> String: return c.to_html(false)), _boar.data.placeholder_color.to_html(false), _charge.blink_color.to_html(false)])


func _charge_hits() -> bool:
	var health_before: float = _necromancer.health
	if await _wait_until(func() -> bool: return _charge.get_state() == ChargeBehavior.State.CHARGE) < 0:
		fail_step("돌진 시작", "돌진이 시작되지 않음")
		return false
	var start: Vector2 = _boar.global_position
	var mask_during: int = _boar.collision_mask
	var seen: Dictionary[StringName, bool] = {&"knocked": false}
	await _wait_until(func() -> bool:
		if _necromancer.is_knocked_back():
			seen[&"knocked"] = true
		return _charge.get_state() != ChargeBehavior.State.CHARGE)
	var knocked: bool = seen[&"knocked"]
	var travelled: float = _boar.global_position.distance_to(start)
	var damage: float = health_before - _necromancer.health
	return _check("돌진에 맞음", is_equal_approx(damage, _boar.data.contact_damage) and knocked and travelled >= _charge.charge_distance - 1.0,
			"체력 %.0f → %.0f (피해 %.0f, 기대 한 번 %.0f), 밀려남 %s, 멧돼지가 달린 거리 %.0f (기대 %.0f, 몸을 지나감), 돌진 중 충돌층 %d" % [
				health_before, _necromancer.health, damage, _boar.data.contact_damage, knocked, travelled, _charge.charge_distance, mask_during])


func _recover() -> bool:
	var frames: int = 0
	var still: bool = true
	while _charge.get_state() == ChargeBehavior.State.RECOVER and frames < TIMEOUT_FRAMES:
		still = still and _boar.velocity == Vector2.ZERO
		await wait_frames(1)
		frames += 1
	var expected: int = roundi(_charge.recover_time * Engine.physics_ticks_per_second)
	return _check("돌진 뒤 멈칫", still and absi(frames - expected) <= RECOVER_TOLERANCE_FRAMES,
			"%d프레임 멈춤 (기대 %d = %.1f초), 그동안 속도 0 %s, 원래 충돌층 %d로 돌아옴" % [frames, expected, _charge.recover_time, still, _boar.collision_mask])


## 돌진이 가까이 오면 멧돼지 쪽으로 구른다. 구르기 앞부분 무적이라 피해는 없고 밀려나기만 한다.
func _roll_through() -> bool:
	var health_before: float = _necromancer.health
	if await _wait_until(func() -> bool: return _charge.get_state() == ChargeBehavior.State.CHARGE) < 0:
		fail_step("구르기 무적", "다음 돌진이 시작되지 않음")
		return false
	var seen: Dictionary[StringName, bool] = {&"rolled": false, &"knocked": false, &"invincible": false}
	await _wait_until(func() -> bool:
		if not seen[&"rolled"] and _boar.global_position.distance_to(_necromancer.global_position) < ROLL_TRIGGER_DISTANCE:
			press_moves(_necromancer.global_position.direction_to(_boar.global_position))
			press_key(KEY_SPACE, true)
			press_key(KEY_SPACE, false)
			seen[&"rolled"] = true
		if _necromancer.is_knocked_back() and not seen[&"knocked"]:
			seen[&"knocked"] = true
			seen[&"invincible"] = _necromancer.is_invincible()
		return _charge.get_state() != ChargeBehavior.State.CHARGE)
	press_moves(Vector2.ZERO)
	var rolled: bool = seen[&"rolled"]
	var knocked: bool = seen[&"knocked"]
	var invincible_when_hit: bool = seen[&"invincible"]
	return _check("구르기 무적 중에는 밀려나기만", rolled and knocked and invincible_when_hit and _necromancer.health == health_before,
			"구름 %s, 밀려남 %s (그때 무적 %s), 체력 %.0f → %.0f" % [rolled, knocked, invincible_when_hit, health_before, _necromancer.health])


func _undead_boar() -> void:
	var enemy_color: Color = _boar.indicator_color
	_boar.queue_free()
	_necromancer.global_position = UNDEAD_STAGE
	var skull: Skull = Skull.create(load(BOAR_SKULL_PATH))
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	hotbar.assign(0, skull)
	hotbar.select(0)
	_necromancer.summoner.toggle_selected()
	await wait_frames(WAIT_FRAMES)
	var undead: Undead = get_first_node_in_group(&"undead") as Undead
	if not _check("언데드 멧돼지 소환", undead != null and undead.get_behavior() is ChargeBehavior,
			"언데드 %s, 행동 조각 %s" % [undead, undead.get_behavior() if undead else null]):
		return
	if not _check("아군 방향 선 색은 적과 다름", undead.indicator_color != enemy_color,
			"언데드 %s, 적 %s" % [undead.indicator_color.to_html(false), enemy_color.to_html(false)]):
		return

	# 언데드 → 네크로맨서 → 쥐 순서로 한 줄에 세운다. 돌진 길 위에 네크로맨서가 있다.
	undead.global_position = UNDEAD_STAGE + UNDEAD_OFFSET
	_rat.global_position = UNDEAD_STAGE + RAT_OFFSET
	var undead_charge: ChargeBehavior = undead.get_behavior() as ChargeBehavior
	var health_before: float = _necromancer.health
	var rat_health_before: float = _rat.health
	var seen: Dictionary[StringName, bool] = {&"windup": false, &"knocked": false}
	var frames: int = await _wait_until(func() -> bool:
		seen[&"windup"] = seen[&"windup"] or undead_charge.get_state() == ChargeBehavior.State.WINDUP
		seen[&"knocked"] = seen[&"knocked"] or _necromancer.is_knocked_back()
		return not is_instance_valid(_rat) or _rat.health < rat_health_before)
	var saw_windup: bool = seen[&"windup"]
	var knocked: bool = seen[&"knocked"]
	var rat_health_after: float = _rat.health if is_instance_valid(_rat) else 0.0
	var ok: bool = frames >= 0 and saw_windup and _necromancer.health == health_before and not knocked
	_check("언데드 돌진은 몬스터만 침", ok,
			"%d프레임 만에 쥐가 돌진에 맞음 (체력 %.0f → %.0f), 예고 봄 %s, 길 위의 네크로맨서 체력 %.0f → %.0f, 밀려남 %s" % [
				frames, rat_health_before, rat_health_after, saw_windup, health_before, _necromancer.health, knocked])
	finish(ok)
