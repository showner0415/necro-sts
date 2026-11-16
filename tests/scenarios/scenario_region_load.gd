extends ScenarioTest
## 시나리오: 얕은 굴에 들어간 직후와 원점에서 먼 곳에서 소환한 직후 물리가 멈추지 않는다 (docs/plans/2026-11-16_region_load_plan.md).
## 몸을 (0,0)에 넣은 뒤 옮기면 2D 물리가 옮긴 만큼 넓힌 상자로 벽 모양과 쌍을 만들어 다음 물리 프레임이 멈췄다
## (무리 몬스터로 들어갈 때 약 10만 쌍·수십 초, 먼 곳에서 소환할 때 약 1만2천 쌍·1초).
## 1. 들어간 뒤 처음 CHECK_FRAMES 물리 프레임 동안 물리 충돌 쌍이 MAX_PAIRS를 넘지 않는다
## 2. 무리 몬스터가 모두 처음 자리 근처(무리 자리에서 spread_radius + 16px 안. 몇 프레임 걸었을 수 있어 몸 하나만큼 더 허용)에 있다
## 3. 원점에서 가장 먼 무리 자리로 네크로맨서를 옮기고(몬스터는 모두 치움) 쥐 언데드를 G로 소환하면,
##    소환 뒤 CHECK_FRAMES 물리 프레임 동안 충돌 쌍이 MAX_PAIRS를 넘지 않고, 언데드가 네크로맨서 곁(spawn_distance + 16px 안)에 있다
## 물리 프레임 사이의 실제 시간은 출력만 한다 (컴퓨터마다 달라서 판정하지 않는다)

const CAVE_SCENE: String = "res://regions/shallow_cave.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
## 쌍 수를 지켜보는 물리 프레임
const CHECK_FRAMES: int = 6
## 들어간 직후·소환 직후 물리 충돌 쌍의 한계. 고친 뒤 실제는 수십 개였다
const MAX_PAIRS: int = 2000
## 네크로맨서를 옮긴 뒤 소환하기 전에 기다리는 물리 프레임 (네크로맨서를 옮겨서 생긴 쌍이 사라지게)
const SETTLE_FRAMES: int = 20
## 몸 하나만큼의 여유 (픽셀)
const SLACK: float = 16.0

enum Step { ENTER, SETTLE, SUMMON, AFTER_SUMMON }

var _step: Step = Step.ENTER
var _necromancer: Necromancer
var _max_pairs: int = 0
var _last_usec: int = 0
var _gaps: Array[String] = []


func get_start_scene() -> String:
	return CAVE_SCENE


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	_last_usec = Time.get_ticks_usec()
	restart_step_timer()


func _tick() -> void:
	match _step:
		Step.ENTER:
			_watch_pairs()
			if step_frames < CHECK_FRAMES:
				return
			if not _check_pairs("들어간 직후 물리 충돌 쌍"):
				return
			if not _check_pack_members():
				return
			_move_far()
		Step.SETTLE:
			if step_frames < SETTLE_FRAMES:
				return
			press_key(KEY_1, true)
			_go(Step.SUMMON)
		Step.SUMMON:
			press_key(KEY_1, false)
			press_key(KEY_G, true)
			_max_pairs = 0
			_gaps.clear()
			_last_usec = Time.get_ticks_usec()
			_go(Step.AFTER_SUMMON)
		Step.AFTER_SUMMON:
			press_key(KEY_G, false)
			_watch_pairs()
			if step_frames < CHECK_FRAMES:
				return
			if _check_pairs("먼 곳에서 소환한 직후 물리 충돌 쌍"):
				_check_undead_near()


func _go(step: Step) -> void:
	_step = step
	restart_step_timer()


func _watch_pairs() -> void:
	var now: int = Time.get_ticks_usec()
	_gaps.append("%.1f" % ((now - _last_usec) / 1000.0))
	_last_usec = now
	_max_pairs = maxi(_max_pairs, int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)))


func _check_pairs(step_name: String) -> bool:
	print("        물리 프레임 사이 실제 시간 (ms): %s" % ", ".join(_gaps))
	var evidence: String = "처음 %d 물리 프레임의 가장 많은 충돌 쌍 %d개 (한계 %d)" % [CHECK_FRAMES, _max_pairs, MAX_PAIRS]
	if _max_pairs > MAX_PAIRS:
		fail_step(step_name, evidence)
		return false
	pass_step(step_name, evidence)
	return true


func _check_pack_members() -> bool:
	var count: int = 0
	var worst: float = 0.0
	var worst_name: String = ""
	for spawn: Node in current_scene.find_children("*", "PackSpawn", true, false):
		var pack_spawn: PackSpawn = spawn as PackSpawn
		for member: Monster in pack_spawn.get_members():
			count += 1
			var distance: float = member.global_position.distance_to(pack_spawn.global_position)
			if distance - pack_spawn.spread_radius > worst:
				worst = distance - pack_spawn.spread_radius
				worst_name = member.name
	var evidence: String = "무리 몬스터 %d마리, 흩어 놓기 범위를 가장 많이 넘은 것 %.1fpx%s" % [count, worst, " (%s)" % worst_name if worst > 0.0 else ""]
	if count > 0 and worst <= SLACK:
		pass_step("무리 몬스터가 제자리", evidence)
		return true
	fail_step("무리 몬스터가 제자리", evidence)
	return false


## 원점에서 가장 먼 무리 자리(바닥)로 네크로맨서를 옮기고, 쥐 머리뼈와 뼈를 주고 핫바 1번에 둔다. 몬스터는 모두 치운다.
func _move_far() -> void:
	var far: Vector2 = _necromancer.global_position
	for spawn: Node in current_scene.find_children("*", "PackSpawn", true, false):
		var at: Vector2 = (spawn as Node2D).global_position
		if at.length() > far.length():
			far = at
	for monster: Node in current_scene.get_tree().get_nodes_in_group(&"monsters"):
		monster.queue_free()
	_necromancer.global_position = far
	var rat: MonsterData = load(RAT_PATH)
	_necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), rat.summon_bone_cost))
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	_necromancer.inventory.try_add(ItemStack.of_skull(skull))
	root.get_node("GameState").hotbar.assign(0, skull)
	print("        네크로맨서를 %s(원점에서 %.0fpx)로 옮김" % [far, far.length()])
	_go(Step.SETTLE)


func _check_undead_near() -> void:
	var roster: UndeadRoster = _necromancer.summoner.roster
	var undead: Array[Node] = current_scene.get_tree().get_nodes_in_group(&"undead")
	var limit: float = _necromancer.summoner.spawn_distance + SLACK
	var distance: float = (undead[0] as Node2D).global_position.distance_to(_necromancer.global_position) if undead.size() == 1 else -1.0
	var evidence: String = "언데드 %d마리 (명단 %d), 네크로맨서와 거리 %.1f (한계 %.1f)" % [undead.size(), roster.get_count(), distance, limit]
	if undead.size() == 1 and roster.get_count() == 1 and distance <= limit:
		pass_step("소환한 언데드가 네크로맨서 곁", evidence)
		finish(true)
	else:
		fail_step("소환한 언데드가 네크로맨서 곁", evidence)
