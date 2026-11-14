extends ScenarioTest
## 시나리오: 무리 시야 공유. 시험 통로(regions/test_corridor.tscn)에서 쥐 2마리 무리를 코드로 만든다 (움직이지 않게 데이터 복사로 속도 0).
## 1. 벽 뒤 막다른 굴의 쥐가 맞으면 신호 뒤 경보, 두 마리 모두 네크로맨서를 노림
## 2. 한 마리(위 통로의 쥐)만 네크로맨서를 보는 동안에는 못 본 시간 한계(5초)가 지나도 포기하지 않음 (벽 뒤의 쥐도 계속 노림)
## 3. 네크로맨서가 두 마리 모두에게서 숨으면(추격 포기 거리 350 안) 못 본 시간 한계가 지난 뒤 함께 포기
## 씬에 놓인 몬스터는 처음에 모두 없앤다. 실제 .tres는 바꾸지 않는다.

const CORRIDOR_SCENE: String = "res://regions/test_corridor.tscn"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
## 통로 칸 좌표 → 월드 좌표: 벽(Walls)의 왼쪽 위 + 칸 좌표 × 32 (scenario_pathfinding.gd와 같다)
const TILE: float = 32.0
## 위 통로의 쥐, 그 아래 벽 뒤 막다른 굴의 쥐
const SEEING_RAT_TILE: Vector2 = Vector2(12.5, 3.0)
const HIDDEN_RAT_TILE: Vector2 = Vector2(14.5, 6.0)
## 네크로맨서: 위 통로의 쥐에게만 보이는 자리, 두 마리 모두에게서 숨는 자리 (오른쪽 세로 통로)
const SEEN_NECRO_TILE: Vector2 = Vector2(18.5, 3.0)
const HIDDEN_NECRO_TILE: Vector2 = Vector2(20.0, 7.5)
const TOUGH_HEALTH: float = 1000.0
const TIMEOUT_FRAMES: int = 120
## 2. 못 본 시간 한계보다 이만큼 더 지켜본다 (초)
const WATCH_EXTRA: float = 1.0
## 3. 포기 시각이 못 본 시간 한계에서 벗어나도 되는 시간 (초). 무리원마다 엇갈려 보므로 몇 프레임 늦을 수 있다
const GIVE_UP_TOLERANCE: float = 0.2

var _necromancer: Necromancer
var _walls: Node2D
var _pack: MonsterPack
var _seeing: Monster
var _hidden: Monster


func get_start_scene() -> String:
	return CORRIDOR_SCENE


func _on_scene_ready() -> void:
	_run()


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
	return ok


func _tile(tile: Vector2) -> Vector2:
	return _walls.global_position + tile * TILE


func _spawn(data: MonsterData, tile: Vector2) -> Monster:
	var monster: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	monster.data = data
	monster.position = _tile(tile)
	current_scene.get_node("Actors").add_child(monster)
	return monster


func _target_name(monster: Monster) -> String:
	return "네크로맨서" if monster.get_target() == _necromancer else ("없음" if monster.get_target() == null else str(monster.get_target()))


func _sees(monster: Monster) -> bool:
	return monster.can_see_point(_necromancer.global_position)


func _run() -> void:
	_necromancer = find_necromancer()
	_walls = current_scene.get_node("Walls")
	_necromancer.max_health = 100000.0
	_necromancer.health = _necromancer.max_health
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	var still: MonsterData = (load(RAT_PATH) as MonsterData).duplicate()
	still.move_speed = 0.0
	still.wander_speed = 0.0
	still.max_health = TOUGH_HEALTH
	_seeing = _spawn(still, SEEING_RAT_TILE)
	_hidden = _spawn(still, HIDDEN_RAT_TILE)
	_pack = MonsterPack.new()
	var members: Array[Monster] = [_seeing, _hidden]
	_pack.set_members(members)
	current_scene.add_child(_pack)
	_necromancer.global_position = _tile(SEEN_NECRO_TILE)
	await wait_frames(3)
	if not await _alert_from_hidden_rat():
		return
	if not await _one_seeing_keeps_chase():
		return
	await _both_lose_then_give_up()


## 1. 벽 뒤의 쥐가 맞으면 신호 뒤 경보, 두 마리 모두 네크로맨서
func _alert_from_hidden_rat() -> bool:
	var to_seeing: float = _seeing.global_position.distance_to(_necromancer.global_position)
	var to_hidden: float = _hidden.global_position.distance_to(_necromancer.global_position)
	var ready: bool = _sees(_seeing) and not _sees(_hidden) and to_seeing > _seeing.data.detect_range and to_hidden > _hidden.data.detect_range \
			and maxf(to_seeing, to_hidden) < _seeing.data.chase_attacker_limit and _seeing.get_target() == null and _hidden.get_target() == null
	if not _check("자리", ready, "위 통로의 쥐: 네크로맨서를 봄 %s, 거리 %.0f / 벽 뒤의 쥐: 봄 %s, 거리 %.0f (감지 %.0f 밖, 추격 포기 %.0f 안이어야 함), 대상 %s / %s" % [
			_sees(_seeing), to_seeing, _sees(_hidden), to_hidden, _seeing.data.detect_range, _seeing.data.chase_attacker_limit, _target_name(_seeing), _target_name(_hidden)]):
		finish(false)
		return false
	_hidden.take_damage(0.1, _necromancer)
	var frames: int = -1
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		if _pack.get_alarm_state() == PackAlarm.State.ALERT and _seeing.get_target() == _necromancer and _hidden.get_target() == _necromancer:
			frames = frame + 1
			break
	if not _check("벽 뒤의 쥐가 맞아도 무리 전체가 경보", frames >= 0, "%d프레임 만에 경보 %s, 대상 %s / %s" % [
			frames, PackAlarm.State.keys()[_pack.get_alarm_state()], _target_name(_seeing), _target_name(_hidden)]):
		finish(false)
		return false
	return true


## 2. 한 마리만 보는 동안에는 못 본 시간 한계가 지나도 포기하지 않는다
func _one_seeing_keeps_chase() -> bool:
	var lost_time: float = _seeing.data.chase_lost_time
	var frames: int = roundi((lost_time + WATCH_EXTRA) * Engine.physics_ticks_per_second)
	var dropped: int = -1
	for frame: int in frames:
		await wait_frames(1)
		if _pack.get_alarm_state() != PackAlarm.State.ALERT or _hidden.get_target() != _necromancer:
			dropped = frame + 1
			break
	return _check("한 마리만 봐도 무리가 계속 쫓음", dropped < 0 and _sees(_seeing) and not _sees(_hidden),
			"%.1f초 동안 (못 본 시간 한계 %.1f초) 경보 %s, 벽 뒤의 쥐 대상 %s, 그만둔 프레임 %d, 위 통로의 쥐가 봄 %s, 벽 뒤의 쥐가 봄 %s" % [
				frames / float(Engine.physics_ticks_per_second), lost_time, PackAlarm.State.keys()[_pack.get_alarm_state()], _target_name(_hidden), dropped, _sees(_seeing), _sees(_hidden)])


## 3. 두 마리 모두에게서 숨으면 못 본 시간 한계가 지난 뒤 함께 포기
func _both_lose_then_give_up() -> void:
	_necromancer.global_position = _tile(HIDDEN_NECRO_TILE)
	await wait_frames(1)
	var to_seeing: float = _seeing.global_position.distance_to(_necromancer.global_position)
	var to_hidden: float = _hidden.global_position.distance_to(_necromancer.global_position)
	var hidden_from_both: bool = not _sees(_seeing) and not _sees(_hidden) and maxf(to_seeing, to_hidden) < _seeing.data.chase_attacker_limit
	var lost_time: float = _seeing.data.chase_lost_time
	var frames: int = roundi((lost_time + WATCH_EXTRA) * Engine.physics_ticks_per_second)
	var gave_up: float = -1.0
	for frame: int in frames:
		await wait_frames(1)
		if _pack.get_alarm_state() == PackAlarm.State.CALM:
			gave_up = (frame + 2) / float(Engine.physics_ticks_per_second)
			break
	await wait_frames(1)
	var ok: bool = hidden_from_both and gave_up > 0.0 and absf(gave_up - lost_time) <= GIVE_UP_TOLERANCE \
			and _seeing.get_target() == null and _hidden.get_target() == null
	_check("둘 다 못 보면 못 본 시간 한계 뒤 함께 포기", ok,
			"숨은 자리: 위 통로의 쥐가 봄 %s (거리 %.0f), 벽 뒤의 쥐가 봄 %s (거리 %.0f, 추격 포기 %.0f 안) → 숨은 뒤 %.2f초에 포기 (한계 %.1f초), 대상 %s / %s" % [
				_sees(_seeing), to_seeing, _sees(_hidden), to_hidden, _seeing.data.chase_attacker_limit, gave_up, lost_time, _target_name(_seeing), _target_name(_hidden)])
	finish(ok)
