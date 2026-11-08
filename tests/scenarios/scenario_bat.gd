extends ScenarioTest
## 시나리오: 박쥐(행동 조각 "치고 빠지기").
## 시험 지역 서쪽에 3마리 무리 → 날아다니는 충돌층(벽만 부딪힘) → 탄에 맞음 → 예고 → 돌진해 한 번 물기(몸을 지나 문다)
## → 물러나 돌기: 네크로맨서와 언데드 모두와 거리 유지 → 언데드 박쥐는 몬스터를 문다.
##
## 박쥐 한 마리와 쥐 한 마리만 남기고 다른 몬스터는 치운다. 쥐는 언데드 박쥐 단계에서 쓴다.
## 쥐는 데이터를 복사해 움직이지 않고 피해를 주지 않게 바꾼다 (실제 데이터 파일은 바꾸지 않는다).

const WAIT_FRAMES: int = 3
const TIMEOUT_FRAMES: int = 600
const PACK_SIZE: int = 3
## 서쪽 구역: x가 이보다 작다
const WEST_LIMIT: float = -250.0
## 박쥐에게서 이만큼 떨어져 선다 (감지 범위 110 안)
const NECROMANCER_OFFSET: Vector2 = Vector2(100, 0)
## 쥐 언데드를 네크로맨서 옆에 둔다 (도는 길 가까이)
const UNDEAD_OFFSET: Vector2 = Vector2(0, 30)
## 도는 동안 거리 판정 허용 오차 (픽셀)
const KEEP_TOLERANCE: float = 6.0
const PARKED_POSITION: Vector2 = Vector2(-420, 420)
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BAT_SKULL_PATH: String = "res://data/skulls/bat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 30
const UNDEAD_STAGE: Vector2 = Vector2(0, 300)
const RAT_OFFSET: Vector2 = Vector2(60, 0)

var _necromancer: Necromancer
var _bat: Monster
var _rat: Monster
var _dive: DiveBehavior


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


func _state_name() -> String:
	return DiveBehavior.State.keys()[_dive.get_state()]


func _wait_state(state: DiveBehavior.State) -> int:
	for frame: int in TIMEOUT_FRAMES:
		if _dive.get_state() == state:
			return frame
		await wait_frames(1)
	return -1


func _run() -> void:
	_necromancer = find_necromancer()
	var bats: Array[Monster] = []
	for node: Node in get_nodes_in_group(&"monsters"):
		var monster: Monster = node as Monster
		if monster.data.id == &"bat":
			bats.append(monster)
	var west: bool = bats.all(func(bat: Monster) -> bool: return bat.global_position.x < WEST_LIMIT)
	if not _check("서쪽에 박쥐 무리", bats.size() == PACK_SIZE and west,
			"박쥐 %d마리 (기대 %d), 모두 x < %.0f %s" % [bats.size(), PACK_SIZE, WEST_LIMIT, west]):
		return
	_bat = bats[0]
	_rat = current_scene.get_node("Actors/Rat1")
	for node: Node in get_nodes_in_group(&"monsters"):
		if node != _bat and node != _rat:
			node.queue_free()
	var harmless_rat: MonsterData = _rat.data.duplicate()
	harmless_rat.contact_damage = 0.0
	harmless_rat.move_speed = 0.0
	harmless_rat.wander_speed = 0.0
	_rat.data = harmless_rat
	_rat.global_position = PARKED_POSITION
	_dive = _bat.get_behavior() as DiveBehavior
	if not _check("날아다니는 충돌층", _dive != null and _bat.collision_layer == _bat.flying_layer and _bat.collision_mask == _bat.flying_mask,
			"행동 조각 %s, 충돌층 %d (flying %d), 부딪히는 대상 %d (벽 %d)" % [_dive, _bat.collision_layer, _bat.flying_layer, _bat.collision_mask, _bat.flying_mask]):
		return

	if not await _shot_hits():
		return
	if not await _bite():
		return
	if not await _orbit_keeps_distance():
		return
	await _undead_bat()


func _shot_hits() -> bool:
	_necromancer.global_position = _bat.global_position + NECROMANCER_OFFSET
	var health_before: float = _bat.health
	for i: int in WAIT_FRAMES:
		aim_mouse_at(_bat.global_position + PlaceholderBody.center(_bat.data))
		await wait_frames(1)
	press_mouse(true)
	await wait_frames(1)
	press_mouse(false)
	var frames: int = 0
	while _bat.health == health_before and frames < 60:
		await wait_frames(1)
		frames += 1
	return _check("탄이 날아다니는 박쥐를 맞힘", _bat.health < health_before,
			"%d프레임 만에 체력 %.0f → %.0f" % [frames, health_before, _bat.health])


func _bite() -> bool:
	if await _wait_state(DiveBehavior.State.WINDUP) < 0:
		fail_step("예고", "예고가 시작되지 않음 (상태 %s)" % _state_name())
		return false
	if not _check("예고: 멈춤", _bat.velocity == Vector2.ZERO and _dive.is_telegraphing(), "속도 %s, 예고 중 %s" % [_bat.velocity, _dive.is_telegraphing()]):
		return false
	var health_before: float = _necromancer.health
	await _wait_state(DiveBehavior.State.DIVE)
	var direction: Vector2 = _dive.get_attack_direction()
	var to_necromancer: Vector2 = _bat.global_position.direction_to(_necromancer.global_position)
	await _wait_state(DiveBehavior.State.RETREAT)
	var bitten: float = health_before - _necromancer.health
	return _check("돌진해 한 번 물기", is_equal_approx(bitten, _bat.data.contact_damage) and direction.dot(to_necromancer) > 0.99,
			"돌진 방향 %s (네크로맨서 쪽 %s), 피해 %.1f (기대 %.1f, 몸을 지나 물 거리 %.0f 안까지 들어옴)" % [
				direction, to_necromancer, bitten, _bat.data.contact_damage, _dive.bite_range])


func _orbit_keeps_distance() -> bool:
	# 쥐 언데드를 네크로맨서 옆에 둔다. 도는 동안 둘 다와 거리를 지켜야 한다.
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	_summon(skull, 0)
	var undead: Undead = get_first_node_in_group(&"undead") as Undead
	if undead == null:
		fail_step("언데드 소환", "언데드가 없음")
		return false
	# 붙잡아 둔 언데드가 박쥐를 물면 무리가 그 언데드를 노려 도는 중심이 바뀐다. 거리 유지만 보려고 공격하지 못하게 한다
	# (공격 거리 0인 데이터 복사본). 박쥐가 방금 네크로맨서를 물어 곁에 있으므로, 한 프레임도 지나기 전에 바꾼다.
	var passive: MonsterData = undead.data.duplicate()
	passive.undead_attack_range_override = 0.0
	undead.data = passive
	await wait_frames(1)
	var frames: int = await _wait_state(DiveBehavior.State.ORBIT)
	if frames < 0:
		fail_step("물러나 돌기", "돌기 시작하지 않음 (상태 %s)" % _state_name())
		return false
	var orbit_frames: int = 0
	var bat_health: float = _bat.health
	var min_necromancer: float = INF
	var min_undead: float = INF
	while _dive.get_state() == DiveBehavior.State.ORBIT and orbit_frames < TIMEOUT_FRAMES:
		# 언데드가 박쥐를 쫓아 움직이지 않게 네크로맨서 옆에 붙잡아 둔다.
		if is_instance_valid(undead):
			undead.global_position = _necromancer.global_position + UNDEAD_OFFSET
			min_undead = minf(min_undead, _bat.global_position.distance_to(undead.global_position))
		min_necromancer = minf(min_necromancer, _bat.global_position.distance_to(_necromancer.global_position))
		await wait_frames(1)
		orbit_frames += 1
	var expected: int = roundi(_dive.orbit_time * Engine.physics_ticks_per_second)
	var limit: float = _dive.keep_distance - KEEP_TOLERANCE
	return _check("돌며 모두와 거리 유지", min_necromancer >= limit and min_undead >= limit and absi(orbit_frames - expected) <= 3 and _dive.get_state() == DiveBehavior.State.WINDUP,
			"%d프레임 돎 (기대 %d), 가장 가까웠던 거리: 네크로맨서 %.0f, 언데드 %.0f (유지 거리 %.0f, 허용 %.0f), 다음 상태 %s, 도는 동안 박쥐 체력 %.1f → %.1f" % [
				orbit_frames, expected, min_necromancer, min_undead, _dive.keep_distance, limit, _state_name(), bat_health, _bat.health])


func _undead_bat() -> void:
	_bat.queue_free()
	# 쥐 언데드는 핫바 0번을 골라 G(소환 해제)로 내린다.
	_hotbar().select(0)
	_necromancer.summoner.toggle_selected()
	_necromancer.global_position = UNDEAD_STAGE
	var skull: Skull = Skull.create(load(BAT_SKULL_PATH))
	_summon(skull, 1)
	await wait_frames(WAIT_FRAMES)
	var undead: Undead = null
	for node: Node in get_nodes_in_group(&"undead"):
		if (node as Undead).data.id == &"bat":
			undead = node as Undead
	if not _check("언데드 박쥐 소환", undead != null and undead.collision_layer == undead.flying_layer and undead.get_behavior() is DiveBehavior,
			"언데드 %s, 충돌층 %d" % [undead, undead.collision_layer if undead else -1]):
		return
	_rat.global_position = UNDEAD_STAGE + RAT_OFFSET
	var rat_health: float = _rat.health
	var necro_health: float = _necromancer.health
	var frames: int = 0
	while is_instance_valid(_rat) and _rat.health == rat_health and frames < TIMEOUT_FRAMES:
		await wait_frames(1)
		frames += 1
	var rat_after: float = _rat.health if is_instance_valid(_rat) else 0.0
	var ok: bool = is_equal_approx(rat_health - rat_after, undead.data.undead_contact_damage) and _necromancer.health == necro_health
	_check("언데드 박쥐는 몬스터를 묾", ok, "%d프레임 만에 쥐 체력 %.1f → %.1f (언데드 물기 %.1f), 네크로맨서 체력 %.0f → %.0f" % [
		frames, rat_health, rat_after, undead.data.undead_contact_damage, necro_health, _necromancer.health])
	finish(ok)


func _hotbar() -> Hotbar:
	return root.get_node("GameState").hotbar


## 머리뼈를 인벤토리와 핫바 slot 칸에 넣고 그 칸을 골라 소환한다.
func _summon(skull: Skull, slot: int) -> void:
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var hotbar: Hotbar = _hotbar()
	hotbar.assign(slot, skull)
	hotbar.select(slot)
	_necromancer.summoner.toggle_selected()
