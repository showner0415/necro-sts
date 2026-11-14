extends ScenarioTest
## 시나리오: 무리 함께 배회와 디버그 표시. 무리 시험 지역(regions/test_pack.tscn)의 무리를 실제 데이터 그대로 쓴다.
## 1. 평소: 쥐 패거리 4마리가 배회 기준점에서 반지름(64) 안에 머물고, 기준점이 움직이며, 무리마다 기준점이 따로 있음
## 2. 경보 뒤 포기하면 기준점을 그 자리(무리 가운데)에 다시 두고, 흩어졌던 무리원이 다시 모여 함께 배회
## 3. 박쥐 무리(대상 하나를 함께 노리는 무리)는 함께 배회하지 않음
## 4. F3을 누르면 무리 디버그 표시가 켜지고, 다시 누르면 꺼짐 (무리가 여럿이어도 한 번 누름에 한 번만 바뀜)

const PACK_SCENE: String = "res://regions/test_pack.tscn"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const BAT_PATH: String = "res://data/monsters/bat.tres"
const GANG_NAMES: Array[String] = ["GangRat1", "GangRat2", "GangRat3", "GangRat4"]
## 네크로맨서를 무리들에게서 멀리 둔다 (어느 무리의 감지 범위에도 들지 않게)
const FAR_SPOT: Vector2 = Vector2(0, 700)
## 1. 지켜보는 시간 (프레임), 반지름 밖으로 나가도 되는 여유 (픽셀), 기준점이 적어도 움직여야 하는 길이 (픽셀)
const WANDER_FRAMES: int = 600
const RADIUS_SLACK: float = 6.0
const MIN_ANCHOR_PATH: float = 10.0
## 2. 경보를 내려고 네크로맨서를 무리 가운데에서 이만큼 둔다 (쥐 감지 80 밖), 쫓아오게 두는 시간 (프레임)
const ALERT_OFFSET: Vector2 = Vector2(0, 200)
const CHASE_FRAMES: int = 90
const TIMEOUT_FRAMES: int = 120
## 2. 포기한 뒤 다시 모이기까지 기다리는 시간과, 그 뒤 지켜보는 시간 (프레임)
const REGROUP_FRAMES: int = 180
const WATCH_FRAMES: int = 180
## 3. 박쥐 무리를 놓을 곳
const BAT_SPOT: Vector2 = Vector2(-300, 420)
const BAT_OFFSETS: Array[Vector2] = [Vector2(-14, 0), Vector2(14, 0), Vector2(0, 14)]

var _necromancer: Necromancer
var _gang: Array[Monster] = []
var _gang_pack: MonsterPack
var _east_pack: MonsterPack


func get_start_scene() -> String:
	return PACK_SCENE


func _on_scene_ready() -> void:
	_run()


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
	return ok


func _center(monsters: Array[Monster]) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for monster: Monster in monsters:
		sum += monster.global_position
	return sum / monsters.size()


## 무리원 중 기준점에서 가장 먼 거리
func _farthest(monsters: Array[Monster], anchor: Vector2) -> float:
	var far: float = 0.0
	for monster: Monster in monsters:
		far = maxf(far, monster.global_position.distance_to(anchor))
	return far


func _run() -> void:
	_necromancer = find_necromancer()
	_necromancer.max_health = 100000.0
	_necromancer.health = _necromancer.max_health
	_necromancer.global_position = FAR_SPOT
	for name: String in GANG_NAMES:
		_gang.append(current_scene.get_node("Actors/" + name) as Monster)
	_gang_pack = current_scene.get_node("RatGang") as MonsterPack
	_east_pack = current_scene.get_node("EastGang") as MonsterPack
	MonsterPack.set_debug_visible(false)
	await wait_frames(3)
	if not await _wander_together():
		return
	if not await _regroup_after_give_up():
		return
	if not await _bats_do_not_wander_together():
		return
	await _debug_toggle()


## 1. 평소에 기준점 둘레 안에서 함께 배회한다
func _wander_together() -> bool:
	var wander: PackWander = _gang_pack.get_wander()
	if wander == null:
		return _check("쥐 패거리가 함께 배회하는 무리", false, "기준점이 없음")
	var start: Vector2 = wander.anchor
	var path: float = 0.0
	var last: Vector2 = wander.anchor
	var farthest: float = 0.0
	var all_have: bool = _gang.all(func(rat: Monster) -> bool: return rat.has_pack_wander())
	for frame: int in WANDER_FRAMES:
		await wait_frames(1)
		path += wander.anchor.distance_to(last)
		last = wander.anchor
		farthest = maxf(farthest, _farthest(_gang, wander.anchor))
	var east: PackWander = _east_pack.get_wander()
	var separate: bool = east != null and east != wander and east.anchor.distance_to(wander.anchor) > wander.radius * 2.0
	var ok: bool = all_have and farthest <= wander.radius + RADIUS_SLACK and path >= MIN_ANCHOR_PATH and separate \
			and _gang_pack.get_alarm_state() == PackAlarm.State.CALM
	return _check("평소에 기준점 둘레 안에서 함께 배회", ok,
			"%.0f초 동안 기준점에서 가장 먼 쥐 %.1f (반지름 %.0f + 여유 %.0f), 기준점이 움직인 길이 %.0f (처음 자리에서 %.0f), 다른 무리의 기준점은 따로 %s (%.0f 떨어짐), 경보 %s" % [
				WANDER_FRAMES / float(Engine.physics_ticks_per_second), farthest, wander.radius, RADIUS_SLACK, path, wander.anchor.distance_to(start),
				separate, east.anchor.distance_to(wander.anchor) if east != null else -1.0, PackAlarm.State.keys()[_gang_pack.get_alarm_state()]])


## 2. 포기하면 그 자리에서 다시 함께 배회한다
func _regroup_after_give_up() -> bool:
	var wander: PackWander = _gang_pack.get_wander()
	_necromancer.global_position = _center(_gang) + ALERT_OFFSET
	await wait_frames(1)
	_gang[0].take_damage(0.1, _necromancer)
	var alert: int = -1
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if _gang_pack.get_alarm_state() == PackAlarm.State.ALERT:
			alert = frame + 1
			break
	if alert < 0:
		return _check("경보", false, "%d프레임 안에 경보가 나지 않음" % TIMEOUT_FRAMES)
	await wait_frames(CHASE_FRAMES)
	_necromancer.global_position = FAR_SPOT + Vector2(0, 400)
	var gave_up: int = -1
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if _gang_pack.get_alarm_state() == PackAlarm.State.CALM:
			gave_up = frame + 1
			break
	if gave_up < 0:
		return _check("포기", false, "%d프레임 안에 포기하지 않음 (경보 %s)" % [TIMEOUT_FRAMES, PackAlarm.State.keys()[_gang_pack.get_alarm_state()]])
	var reset_gap: float = wander.anchor.distance_to(_center(_gang))
	var spread: float = _farthest(_gang, wander.anchor)
	await wait_frames(REGROUP_FRAMES)
	var farthest: float = 0.0
	var moved: float = 0.0
	var before: Array[Vector2] = []
	for rat: Monster in _gang:
		before.append(rat.global_position)
	for frame: int in WATCH_FRAMES:
		await wait_frames(1)
		farthest = maxf(farthest, _farthest(_gang, wander.anchor))
	for i: int in _gang.size():
		moved = maxf(moved, _gang[i].global_position.distance_to(before[i]))
	var ok: bool = reset_gap <= 2.0 and farthest <= wander.radius + RADIUS_SLACK and moved > 0.0 and _gang_pack.get_alarm_state() == PackAlarm.State.CALM
	return _check("포기한 뒤 그 자리에서 다시 함께 배회", ok,
			"%d프레임 만에 경보, %d프레임 쫓은 뒤 멀리 가자 %d프레임 만에 포기. 포기할 때 기준점과 무리 가운데 차이 %.1f, 기준점에서 가장 먼 쥐 %.0f → %d프레임 뒤부터 %d프레임 동안 가장 먼 쥐 %.1f (반지름 %.0f + 여유 %.0f), 가장 많이 움직인 쥐 %.0f" % [
				alert, CHASE_FRAMES, gave_up, reset_gap, spread, REGROUP_FRAMES, WATCH_FRAMES, farthest, wander.radius, RADIUS_SLACK, moved])


## 3. 박쥐 무리는 함께 배회하지 않는다
func _bats_do_not_wander_together() -> bool:
	var bats: Array[Monster] = []
	for offset: Vector2 in BAT_OFFSETS:
		var bat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		bat.data = load(BAT_PATH)
		bat.position = BAT_SPOT + offset
		_necromancer.get_parent().add_child(bat)
		bats.append(bat)
	var pack: MonsterPack = MonsterPack.new()
	pack.set_members(bats)
	current_scene.add_child(pack)
	await wait_frames(3)
	var ok: bool = not pack.uses_alarm() and pack.get_wander() == null and bats.all(func(bat: Monster) -> bool: return not bat.has_pack_wander())
	return _check("박쥐 무리는 함께 배회하지 않음", ok, "경보를 쓰는 무리 %s, 기준점 %s, 함께 배회하는 박쥐 %d마리" % [
		pack.uses_alarm(), pack.get_wander(), bats.filter(func(bat: Monster) -> bool: return bat.has_pack_wander()).size()])


## 4. F3으로 디버그 표시를 켜고 끈다
func _debug_toggle() -> void:
	var packs: int = current_scene.get_children().filter(func(node: Node) -> bool: return node is MonsterPack).size()
	var before: bool = MonsterPack.is_debug_visible()
	press_key(KEY_F3, true)
	await wait_frames(2)
	press_key(KEY_F3, false)
	await wait_frames(1)
	var after_on: bool = MonsterPack.is_debug_visible()
	press_key(KEY_F3, true)
	await wait_frames(2)
	press_key(KEY_F3, false)
	await wait_frames(1)
	var after_off: bool = MonsterPack.is_debug_visible()
	var ok: bool = not before and after_on and not after_off
	_check("F3으로 디버그 표시 켜고 끄기", ok, "무리 %d개, 처음 %s → F3 → %s → F3 → %s" % [packs, before, after_on, after_off])
	finish(ok)
