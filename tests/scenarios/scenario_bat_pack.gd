extends ScenarioTest
## 시나리오: 박쥐 무리의 어그로 공유 (MonsterPack).
## 감지로 깨움: 한 마리만 감지 범위 안 → 무리 전체가 각자 가장 가까운 대상(네크로맨서 / 언데드)을 노림
## → 다 같이 멈춤: 무리 누구의 감지 범위에도 없으면 모두 노리지 않음
## → 피격으로 깨움: 감지 범위 밖에서 한 마리를 쏘면 무리 전체가 싸움을 시작.
##
## 다른 몬스터는 치운다. 박쥐는 데이터를 복사해 배회·이동·물기를 멈춘 것으로 같은 자리에 새로 만든다
## (위치가 바뀌면 감지 범위 판정이 흔들린다. 행동 조각은 준비될 때 만들어지므로 데이터만 바꿔서는 멈추지 않는다).
## 실제 데이터 파일은 바꾸지 않는다.

const WAIT_FRAMES: int = 5
## 감지 범위보다 이만큼 안쪽에 서서 한 마리만 감지하게 한다 (픽셀)
const DETECT_MARGIN: float = 5.0
## 언데드를 둘 자리: 무리 중 가장 서쪽 박쥐에게서 서쪽으로 (감지 범위 밖, 그 박쥐에게는 네크로맨서보다 가깝게)
const UNDEAD_OFFSET: Vector2 = Vector2(-120, 0)
## 감지 범위 밖, 사거리 안에서 쏜다 (픽셀)
const SHOOT_DISTANCE: float = 140.0
const FAR_AWAY: Vector2 = Vector2(400, 300)
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 10
const MONSTER_SCENE: String = "res://monsters/monster.tscn"

var _necromancer: Necromancer
var _pack: MonsterPack
var _bats: Array[Monster] = []
var _undead: Undead


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
	return "네크로맨서" if target == _necromancer else "언데드"


func _targets() -> Array:
	return _bats.map(func(bat: Monster) -> String: return "%s→%s" % [bat.name, _target_name(bat)])


func _run() -> void:
	_necromancer = find_necromancer()
	_pack = current_scene.get_node_or_null("Actors/BatPack") as MonsterPack
	if _pack == null:
		fail_step("준비", "Actors/BatPack(MonsterPack)이 없음")
		return
	var originals: Array[Monster] = _pack.get_members()
	for node: Node in get_nodes_in_group(&"monsters"):
		if not originals.has(node):
			node.queue_free()
	var still: MonsterData = originals[0].data.duplicate()
	still.wander_speed = 0.0
	still.move_speed = 0.0
	still.contact_damage = 0.0
	still.behavior = MonsterBehavior.new()
	for original: Monster in originals:
		var bat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		bat.data = still
		bat.name = original.name
		bat.position = original.position
		original.free()
		_pack.add_child(bat)
		_bats.append(bat)
	if not _check("무리", _bats.size() == 3, "BatPack 아래 박쥐 %d마리" % _bats.size()):
		return
	# 무리를 깨우지 않게 멀리 서서 언데드를 소환해 둔다.
	_necromancer.global_position = _pack.global_position + FAR_AWAY
	_summon_rat()
	await wait_frames(WAIT_FRAMES)
	if not _check("처음에는 아무도 노리지 않음", not _pack.is_engaged() and _bats.all(func(b: Monster) -> bool: return b.get_target() == null), "무리 싸움 중 %s, %s" % [_pack.is_engaged(), _targets()]):
		return

	if not await _wake_by_detection():
		return
	if not await _stop_together():
		return
	await _wake_by_hit()


func _summon_rat() -> void:
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), BONES))
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	hotbar.assign(0, skull)
	hotbar.select(0)
	_necromancer.summoner.toggle_selected()


## 가장 동쪽 박쥐 하나만 감지 범위 안에 들어오게 선다. 언데드는 가장 서쪽 박쥐 옆(감지 범위 밖)에 둔다.
func _wake_by_detection() -> bool:
	_undead = get_first_node_in_group(&"undead") as Undead
	var east: Monster = _bats[0]
	var west: Monster = _bats[0]
	for bat: Monster in _bats:
		if bat.global_position.x > east.global_position.x:
			east = bat
		if bat.global_position.x < west.global_position.x:
			west = bat
	var detect: float = east.data.detect_range
	_necromancer.global_position = east.global_position + Vector2(detect - DETECT_MARGIN, 0)
	var undead_position: Vector2 = west.global_position + UNDEAD_OFFSET
	var outside: Array = _bats.filter(func(b: Monster) -> bool: return b != east and b.global_position.distance_to(_necromancer.global_position) > detect)
	if not _check("한 마리만 감지 범위 안", outside.size() == _bats.size() - 1 and undead_position.distance_to(west.global_position) > detect,
			"%s만 %.0f 안, 나머지 거리 %s, 언데드는 %s에게서 %.0f" % [east.name, detect, _bats.map(func(b: Monster) -> int: return roundi(b.global_position.distance_to(_necromancer.global_position))), west.name, undead_position.distance_to(west.global_position)]):
		return false
	for i: int in WAIT_FRAMES:
		_undead.global_position = undead_position
		await wait_frames(1)
	var ok: bool = _pack.is_engaged()
	var details: Array[String] = []
	for bat: Monster in _bats:
		var to_necro: float = bat.global_position.distance_to(_necromancer.global_position)
		var to_undead: float = bat.global_position.distance_to(_undead.global_position)
		var nearest: Node2D = _necromancer if to_necro <= to_undead else _undead
		ok = ok and bat.get_target() == nearest
		details.append("%s→%s (네크로맨서 %.0f, 언데드 %.0f)" % [bat.name, _target_name(bat), to_necro, to_undead])
	return _check("감지로 깨우면 무리 전체가 각자 가장 가까운 대상", ok, "무리 싸움 중 %s, %s" % [_pack.is_engaged(), ", ".join(details)])


func _stop_together() -> bool:
	_necromancer.global_position = _pack.global_position + FAR_AWAY
	for i: int in WAIT_FRAMES:
		_undead.global_position = _necromancer.global_position
		await wait_frames(1)
	return _check("무리 누구의 감지에도 없으면 다 같이 멈춤", not _pack.is_engaged() and _bats.all(func(b: Monster) -> bool: return b.get_target() == null),
			"무리 싸움 중 %s, %s" % [_pack.is_engaged(), _targets()])


func _wake_by_hit() -> void:
	var east: Monster = _bats[0]
	for bat: Monster in _bats:
		if bat.global_position.x > east.global_position.x:
			east = bat
	_necromancer.global_position = east.global_position + Vector2(SHOOT_DISTANCE, 0)
	for i: int in WAIT_FRAMES:
		_undead.global_position = _necromancer.global_position + Vector2(0, 40)
		aim_mouse_at(east.global_position + PlaceholderBody.center(east.data))
		await wait_frames(1)
	var none_before: bool = not _pack.is_engaged()
	var health: float = east.health
	press_mouse(true)
	await wait_frames(1)
	press_mouse(false)
	var frames: int = 0
	while east.health == health and frames < 120:
		_undead.global_position = _necromancer.global_position + Vector2(0, 40)
		await wait_frames(1)
		frames += 1
	for i: int in WAIT_FRAMES:
		_undead.global_position = _necromancer.global_position + Vector2(0, 40)
		await wait_frames(1)
	var all_engaged: bool = _bats.all(func(b: Monster) -> bool: return b.get_target() != null)
	var ok: bool = none_before and east.health < health and east.get_aggro().state == Aggro.State.CHASING and _pack.is_engaged() and all_engaged
	_check("피격으로 깨우면 무리 전체가 싸움", ok, "쏘기 전 무리 싸움 중 %s, %d프레임 만에 %s 맞음 (체력 %.0f → %.0f, 상태 %s), 무리 싸움 중 %s, %s" % [
		not none_before, frames, east.name, health, east.health, Aggro.State.keys()[east.get_aggro().state], _pack.is_engaged(), _targets()])
	finish(ok)
