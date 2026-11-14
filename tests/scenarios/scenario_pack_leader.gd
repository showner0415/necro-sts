extends ScenarioTest
## 시나리오: 무리 대장 (계획 6a). 시험 던전(tests/dungeon_test_a.tscn ↔ b.tscn)의 쥐 패거리 자리(RatGang, rat_gang)로 본다.
## 1. 대장 확률을 0으로 두고 B에 처음 들어가면 대장이 없고 무리원 공격력도 그대로다
## 2. 대장 확률을 1로 두고(던전을 새로 시작해 B를 새로 만듦) 들어가면 무리원 중 하나만 대장이다
## 3. 확률을 원래대로 두고 던전 상태의 대장 확정 목록에 쥐 패거리를 넣고 B에 처음 들어가면, 무리원 중 하나만 대장이고, 대장 체력은 최대의 1.5배, 무리원 모두의 공격력이 1.2배다
## 4. A에 갔다 B로 돌아와도 같은 무리원이 대장이고 체력·강화가 그대로다
## 5. 대장을 잡으면 남은 무리원의 공격력이 바로 원래대로 돌아온다
## 6. 다시 A에 갔다 오면 죽은 대장은 다시 생기지 않고 강화도 없다
## 확률은 data/packs/leader_settings.tres(임시값)를 불러온 리소스에서 메모리로만 바꾸고 되돌린다 (파일은 바꾸지 않는다). 15% 자체는 단위 테스트(test_pack_leader.gd)가 본다.

const SCENE_A: String = "res://tests/dungeon_test_a.tscn"
const DATA_A: String = "res://data/regions/test_dungeon_a.tres"
const DATA_B: String = "res://data/regions/test_dungeon_b.tres"
const SETTINGS: String = "res://data/packs/leader_settings.tres"
const PACK_ID: StringName = &"rat_gang"
const TOLERANCE: float = 0.001


func get_start_scene() -> String:
	return SCENE_A


func _on_scene_ready() -> void:
	var dungeon: DungeonRun = root.get_node("GameState").get(&"dungeon")
	var settings: PackLeaderSettings = load(SETTINGS)
	await wait_frames(3)
	var chance: float = settings.chance
	# 1. 확률 0이면 대장 없음
	settings.chance = 0.0
	await _travel(DATA_B)
	var none: Array[Monster] = _members()
	var none_ok: bool = not none.is_empty() and none.all(func(m: Monster) -> bool: return not m.is_leader and m.damage_ratio == 1.0)
	if not _check("확률 0이면 대장 없음", none_ok, "무리원 %d마리, 대장 %d마리, 공격력 배율 %s" % [
			none.size(), none.filter(func(m: Monster) -> bool: return m.is_leader).size(), none.map(func(m: Monster) -> float: return m.damage_ratio)]):
		settings.chance = chance
		finish(false)
		return
	# 2. 확률 1이면 반드시 대장. 던전을 새로 시작해 B의 저장 상태를 비운다
	await _travel(DATA_A)
	settings.chance = 1.0
	dungeon.start(dungeon.rng.seed)
	await _travel(DATA_B)
	var sure: Array[Monster] = _members()
	var sure_leaders: int = sure.filter(func(m: Monster) -> bool: return m.is_leader).size()
	settings.chance = chance
	if not _check("확률 1이면 대장 하나", sure_leaders == 1, "무리원 %d마리 중 대장 %d마리" % [sure.size(), sure_leaders]):
		finish(false)
		return
	# 3. 확률은 원래대로, 확정 목록이면 반드시 대장
	await _travel(DATA_A)
	dungeon.start(dungeon.rng.seed)
	dungeon.forced_leader_packs.append(PACK_ID)
	await _travel(DATA_B)
	var members: Array[Monster] = _members()
	var leaders: Array[Monster] = members.filter(func(m: Monster) -> bool: return m.is_leader)
	var leader: Monster = leaders[0] if leaders.size() == 1 else null
	var all_boosted: bool = members.all(func(m: Monster) -> bool: return absf(m.damage_ratio - settings.member_damage_ratio) < TOLERANCE)
	var base_damage: float = members[0].data.contact_damage
	var dealt: float = (members[0].call(&"_combat_stats") as CombatStats).contact_damage
	var born_ok: bool = leader != null and absf(leader.health - leader.data.max_health * settings.leader_health_ratio) < TOLERANCE and all_boosted \
			and absf(dealt - base_damage * settings.member_damage_ratio) < TOLERANCE
	if not _check("대장 생김", born_ok, "무리원 %d마리 중 대장 %d마리, 대장 체력 %.1f (최대 %.1f × %.1f), 무리원 공격력 배율 모두 %.1f %s, 싸울 때 피해 %.2f (데이터 %.2f)" % [
			members.size(), leaders.size(), leader.health if leader != null else -1.0, members[0].data.max_health, settings.leader_health_ratio,
			settings.member_damage_ratio, all_boosted, dealt, base_damage]):
		finish(false)
		return
	var leader_name: StringName = leader.name
	var leader_health: float = leader.health
	# 4. 오가도 유지
	await _travel(DATA_A)
	await _travel(DATA_B)
	var back: Monster = current_scene.get_node_or_null("Actors/%s" % leader_name)
	members = _members()
	var kept: bool = back != null and back.is_leader and absf(back.health - leader_health) < TOLERANCE \
			and members.filter(func(m: Monster) -> bool: return m.is_leader).size() == 1 \
			and members.all(func(m: Monster) -> bool: return absf(m.damage_ratio - settings.member_damage_ratio) < TOLERANCE)
	if not _check("오가도 대장 유지", kept, "돌아온 %s: 대장 %s, 체력 %.1f (떠날 때 %.1f), 무리원 강화 유지" % [
			leader_name, back.is_leader if back != null else false, back.health if back != null else -1.0, leader_health]):
		finish(false)
		return
	# 5. 대장을 잡으면 강화가 풀린다
	back.take_damage(back.health + 1.0, find_necromancer())
	await wait_frames(2)
	var rest: Array[Monster] = _members()
	var released: bool = not rest.is_empty() and rest.all(func(m: Monster) -> bool: return m.damage_ratio == 1.0 and not m.is_leader)
	if not _check("대장을 잡으면 강화 풀림", released, "남은 무리원 %d마리의 공격력 배율 %s" % [rest.size(), rest.map(func(m: Monster) -> float: return m.damage_ratio)]):
		finish(false)
		return
	# 6. 다시 오가도 죽은 대장은 없다
	await _travel(DATA_A)
	await _travel(DATA_B)
	var after: Array[Monster] = _members()
	var gone: bool = current_scene.get_node_or_null("Actors/%s" % leader_name) == null and after.size() == rest.size() \
			and after.all(func(m: Monster) -> bool: return m.damage_ratio == 1.0 and not m.is_leader)
	_check("죽은 대장은 돌아오지 않음", gone, "돌아온 무리원 %d마리 (잡기 전 남은 %d), 대장 없음 %s" % [after.size(), rest.size(), after.all(func(m: Monster) -> bool: return not m.is_leader)])
	finish(gone)


func _members() -> Array[Monster]:
	var spawn: PackSpawn = current_scene.get_node("RatGang") as PackSpawn
	return spawn.get_members().filter(func(m: Monster) -> bool: return not m.is_queued_for_deletion())


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
	return ok


## 지금 지역에서 destination(RegionData 경로)으로 가고 새 씬이 준비될 때까지 기다린다.
func _travel(destination: String) -> void:
	var old_scene: Node = current_scene
	current_scene.call(&"travel_to", load(destination))
	while current_scene == old_scene or current_scene == null or not current_scene.is_node_ready():
		await physics_frame
	await wait_frames(2)
