extends ScenarioTest
## 시나리오: 언데드의 대상 고르기 (UndeadTargeting).
## 가까이 몬스터가 있어도 먼저 공격하지 않음 → 네크로맨서가 쥐 A를 쏘면 언데드가 A로 감 → A가 언데드 공격 반경에 들어오면 고정 →
## 네크로맨서가 쥐 B를 맞혀도 A 그대로 → A가 죽으면 최근에 맞은 B로 바로 감 → B도 죽고 나서,
## 네크로맨서를 노리며 다가오는 쥐 C에게는 네크로맨서의 공격 반경(160) 안에 들어와야 감 →
## 언데드를 노리는 쥐 D에게는 언데드의 공격 반경 안에 들어와야 반격함.
## 쥐는 데이터 복사로 배회 0·감지 0·피해 0·체력 크게 고정한다 (C, D는 따로 다가오게 한다). 다른 몬스터는 치운다.

const TIMEOUT_FRAMES: int = 240
const IDLE_FRAMES: int = 60
const HOLD_FRAMES: int = 30
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 30
## 네크로맨서에서 쥐들의 자리
const A_OFFSET: Vector2 = Vector2(60, 0)
const B_OFFSET: Vector2 = Vector2(-70, 0)
const C_OFFSET: Vector2 = Vector2(0, 240)
## D는 언데드에서 이만큼 떨어진 자리에서 언데드에게 다가온다
const D_OFFSET: Vector2 = Vector2(0, -90)
const TOUGH_HEALTH: float = 100000.0
## C가 네크로맨서를 노리게 하는 감지 범위 (C_OFFSET보다 크게)
const C_DETECT: float = 300.0

var _necromancer: Necromancer
var _undead: Undead
var _rats: Array[Monster] = []


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


func _name(monster: Monster) -> String:
	return "없음" if monster == null else str(monster.name)


## 움직이지 않고, 스스로 아무도 노리지 않고, 피해를 주지 않고, 잘 죽지 않는 쥐
func _make_still(rat: Monster, detect: float = 0.0, speed: float = 0.0) -> void:
	var still: MonsterData = rat.data.duplicate()
	still.wander_speed = 0.0
	still.detect_range = detect
	still.contact_damage = 0.0
	still.max_health = TOUGH_HEALTH
	still.move_speed = speed
	rat.data = still
	rat.health = TOUGH_HEALTH


## 언데드의 대상이 target이 될 때까지 기다린다. 걸린 프레임, 못 하면 -1.
func _wait_target(target: Monster) -> int:
	for frame: int in TIMEOUT_FRAMES:
		if _undead.get_target() == target:
			return frame
		await wait_frames(1)
	return -1


func _kill(rat: Monster) -> void:
	rat.take_damage(TOUGH_HEALTH * 2.0, _necromancer)
	await wait_frames(2)


func _run() -> void:
	_necromancer = find_necromancer()
	_necromancer.max_health = 10000.0
	_necromancer.health = 10000.0
	for node: Node in get_nodes_in_group(&"monsters"):
		var monster: Monster = node as Monster
		if monster.name in ["Rat1", "Rat2", "Rat3", "Rat4"]:
			_rats.append(monster)
		else:
			monster.free()
	var a: Monster = _rats[0]
	var b: Monster = _rats[1]
	var c: Monster = _rats[2]
	var d: Monster = _rats[3]
	for rat: Monster in _rats:
		_make_still(rat)
	var center: Vector2 = _necromancer.global_position
	a.global_position = center + A_OFFSET
	b.global_position = center + B_OFFSET
	# C, D는 나중에 쓴다. 그때까지 멀리 둔다.
	c.global_position = center + Vector2(2000, 0)
	d.global_position = center + Vector2(-2000, 0)
	_undead = await _summon_undead()
	if _undead == null:
		fail_step("언데드 소환", "언데드가 나오지 않음")
		finish(false)
		return
	var engage: float = _undead.get_behavior().get_engage_range(_undead.data.get_undead_stats())

	# 1. 먼저 공격하지 않음
	var start: Vector2 = _undead.global_position
	await wait_frames(IDLE_FRAMES)
	if not _check("이유 없이 먼저 공격하지 않음", _undead.get_target() == null and _undead.global_position.distance_to(a.global_position) > engage,
			"%d프레임 동안 대상 %s, 언데드와 A 거리 %.0f (언데드 공격 반경 %.0f), 처음 자리에서 %.0f 움직임" % [IDLE_FRAMES, _name(_undead.get_target()),
				_undead.global_position.distance_to(a.global_position), engage, _undead.global_position.distance_to(start)]):
		finish(false)
		return

	# 2. 네크로맨서가 A를 쏴서 맞히면 언데드가 A로 감
	var hit_frames: int = -1
	press_mouse(true)
	for frame: int in TIMEOUT_FRAMES:
		aim_mouse_at(a.global_position + PlaceholderBody.center(a.data))
		await wait_frames(1)
		if a.health < TOUGH_HEALTH:
			hit_frames = frame
			break
	press_mouse(false)
	var frames: int = await _wait_target(a)
	if not _check("네크로맨서가 맞힌 몬스터로 감", hit_frames >= 0 and frames >= 0,
			"%d프레임 만에 A가 맞음, 그 뒤 %d프레임 만에 언데드 대상 %s" % [hit_frames, frames, _name(_undead.get_target())]):
		finish(false)
		return

	# 3. A가 언데드 공격 반경에 들어오면 고정
	var lock_frames: int = -1
	for frame: int in TIMEOUT_FRAMES:
		if _undead.is_target_locked():
			lock_frames = frame
			break
		await wait_frames(1)
	if not _check("공격 반경에 들어오면 고정", lock_frames >= 0 and _undead.get_target() == a,
			"%d프레임 만에 고정, 언데드와 A 거리 %.0f (공격 반경 %.0f)" % [lock_frames, _undead.global_position.distance_to(a.global_position), engage]):
		finish(false)
		return

	# 4. 고정된 뒤에는 네크로맨서가 B를 맞혀도 A 그대로
	b.take_damage(1.0, _necromancer)
	var kept: bool = true
	for frame: int in HOLD_FRAMES:
		await wait_frames(1)
		kept = kept and _undead.get_target() == a
	if not _check("고정되면 다른 몬스터를 맞혀도 바꾸지 않음", kept,
			"B가 네크로맨서에게 맞은 뒤 %d프레임 동안 대상 %s" % [HOLD_FRAMES, _name(_undead.get_target())]):
		finish(false)
		return

	# 5. A가 죽으면 최근에 맞은 B로 바로 감
	await _kill(a)
	frames = await _wait_target(b)
	if not _check("대상이 죽으면 조건에 맞는 몬스터로", frames >= 0,
			"A가 죽은 뒤 %d프레임 만에 대상 %s (B는 %.1f초 전에 맞음)" % [frames, _name(_undead.get_target()), HOLD_FRAMES / 60.0]):
		finish(false)
		return

	# 6. B도 죽인 뒤, 네크로맨서를 노리며 다가오는 C에게는 공격 반경(160) 안에 들어와야 감
	await _kill(b)
	await _wait_target(null)
	_make_still(c, C_DETECT, _rat_speed())
	c.global_position = _necromancer.global_position + C_OFFSET
	var radius: float = _necromancer.attack.projectile_range
	var early: bool = false
	var picked_at: float = -1.0
	for frame: int in TIMEOUT_FRAMES * 4:
		await wait_frames(1)
		var distance: float = c.global_position.distance_to(_necromancer.global_position)
		if _undead.get_target() == c:
			picked_at = distance
			break
		early = early or (c.get_target() == _necromancer and distance > radius and _undead.get_target() != null)
	if not _check("네크로맨서를 노리는 몬스터는 공격 반경 안에 들어와야", picked_at > 0.0 and picked_at <= radius and not early and c.get_target() == _necromancer,
			"C가 네크로맨서를 노림 %s, 언데드가 C를 고른 거리 %.0f (네크로맨서 공격 반경 %.0f)" % [c.get_target() == _necromancer, picked_at, radius]):
		finish(false)
		return

	# 7. 언데드를 노리는 D에게는 언데드 공격 반경 안에 들어와야 반격
	await _kill(c)
	await _wait_target(null)
	_make_still(d, 0.0, _rat_speed())
	d.global_position = _undead.global_position + D_OFFSET
	var picked_d: float = -1.0
	for frame: int in TIMEOUT_FRAMES * 4:
		d.set_pack_target(_undead)
		await wait_frames(1)
		if _undead.get_target() == d:
			picked_d = _undead.global_position.distance_to(d.global_position)
			break
	var undead_engage: float = engage
	var ok: bool = _check("언데드를 노리는 몬스터에게는 언데드 공격 반경 안에서 반격", picked_d > 0.0 and picked_d <= undead_engage + 1.0,
			"D가 언데드를 노리고 다가옴, 언데드가 D를 고른 거리 %.1f (언데드 공격 반경 %.0f)" % [picked_d, undead_engage])
	finish(ok)


func _summon_undead() -> Undead:
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	hotbar.assign(0, skull)
	hotbar.select(0)
	_necromancer.summoner.toggle_selected()
	await wait_frames(2)
	var undead: Array[Node] = get_nodes_in_group(&"undead")
	return undead[0] as Undead if not undead.is_empty() else null


## 원래 쥐 데이터의 이동 속도 (복사본은 0으로 고정해 두므로)
func _rat_speed() -> float:
	return (load("res://data/monsters/rat.tres") as MonsterData).move_speed
