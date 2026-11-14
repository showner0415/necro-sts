extends ScenarioTest
## 시나리오: 대장의 네임드 머리뼈 (계획 6b). 시험 던전 B(tests/dungeon_test_b.tscn)의 쥐 패거리 자리(RatGang)를 대장 확정으로 만들고 본다.
## 1. 네임드 확률을 1로 두고 대장을 잡으면, 시체에 "쥐 그레카의 머리뼈" 하나가 들고 일반 머리뼈는 없다
## 2. 대장이 아닌 무리원을 잡으면 시체에 네임드 머리뼈가 없다
## 3. 네임드 머리뼈를 채집해 핫바에 놓고 G로 소환하면, 머리뼈 체력이 쥐 체력 × 네임드 배율(1.2)이고 언데드 공격력도 쥐 공격력 × 1.2다.
##    핫바 칸에 네임드 표시가 있다
## 확률은 data/packs/leader_settings.tres(임시값)를 불러온 리소스에서 메모리로만 바꾸고 되돌린다 (파일은 바꾸지 않는다). 70% 자체는 단위 테스트가 본다.

const SCENE_A: String = "res://tests/dungeon_test_a.tscn"
const DATA_B: String = "res://data/regions/test_dungeon_b.tres"
const SETTINGS: String = "res://data/packs/leader_settings.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const PACK_ID: StringName = &"rat_gang"
const NAMED_TITLE: String = "쥐 그레카의 머리뼈"
const START_BONES: int = 10
const WAIT_FRAMES: int = 3
const TOLERANCE: float = 0.001
## 네크로맨서를 무리에서 떨어뜨려 둔다 (쥐 감지 범위 밖)
const SAFE_OFFSET: Vector2 = Vector2(0, 400)


func get_start_scene() -> String:
	return SCENE_A


func _on_scene_ready() -> void:
	var dungeon: DungeonRun = root.get_node("GameState").get(&"dungeon")
	var settings: PackLeaderSettings = load(SETTINGS)
	var chance: float = settings.named_skull_chance
	await wait_frames(WAIT_FRAMES)
	dungeon.forced_leader_packs.append(PACK_ID)
	await _travel(DATA_B)
	var spawn: PackSpawn = current_scene.get_node("RatGang") as PackSpawn
	var necromancer: Necromancer = find_necromancer()
	necromancer.global_position = spawn.global_position + SAFE_OFFSET
	var members: Array[Monster] = spawn.get_members()
	var leader: Monster = null
	var follower: Monster = null
	for member: Monster in members:
		if member.is_leader:
			leader = member
		elif follower == null:
			follower = member
	if leader == null or follower == null:
		fail_step("대장과 무리원 찾기", "무리원 %d마리, 대장 %s" % [members.size(), leader != null])
		finish(false)
		return
	var rat: MonsterData = leader.data

	# 1. 대장을 잡으면 네임드 머리뼈
	settings.named_skull_chance = 1.0
	var leader_corpse: Corpse = await _kill(leader, necromancer)
	settings.named_skull_chance = chance
	var leader_skulls: Array[Skull] = _skulls(leader_corpse)
	var named_ok: bool = leader_skulls.size() == 1 and leader_skulls[0].is_named() and leader_skulls[0].get_display_name() == NAMED_TITLE
	if not _check("대장을 잡으면 네임드 머리뼈", named_ok, "시체 %s, 머리뼈 %s" % [leader_corpse != null, leader_skulls.map(func(s: Skull) -> String: return s.get_display_name())]):
		finish(false)
		return

	# 2. 무리원은 네임드를 주지 않는다
	settings.named_skull_chance = 1.0
	var follower_corpse: Corpse = await _kill(follower, necromancer)
	settings.named_skull_chance = chance
	var follower_skulls: Array[Skull] = _skulls(follower_corpse)
	var plain_ok: bool = follower_corpse != null and follower_skulls.all(func(s: Skull) -> bool: return not s.is_named())
	if not _check("무리원은 네임드 없음", plain_ok, "시체 %s, 머리뼈 %s" % [follower_corpse != null, follower_skulls.map(func(s: Skull) -> String: return s.get_display_name())]):
		finish(false)
		return

	# 3. 채집해서 소환하면 네임드 배율
	var named: Skull = leader_skulls[0]
	var stack: ItemStack = leader_corpse.loot.get_stacks().filter(func(s: ItemStack) -> bool: return s.skull == named)[0]
	var taken: bool = leader_corpse.take(stack, necromancer.inventory)
	necromancer.inventory.try_add(ItemStack.of_item(load(BONE_PATH), START_BONES))
	var hotbar: Hotbar = root.get_node("GameState").get(&"hotbar")
	hotbar.assign(0, named)
	hotbar.select(0)
	await wait_frames(WAIT_FRAMES)
	press_key(KEY_G, true)
	await wait_frames(1)
	press_key(KEY_G, false)
	await wait_frames(WAIT_FRAMES)
	var undead: Node = get_first_node_in_group(&"undead")
	var rules: UndeadStatRules = MonsterData.get_undead_rules()
	var damage: float = (undead.call(&"_stats") as CombatStats).contact_damage if undead != null else -1.0
	var mark: bool = find_hud().hotbar_view.get_slot_control(0).get_skull() == named and named.is_named()
	var summon_ok: bool = taken and undead != null and absf(named.health - rat.max_health * rules.named_health_ratio) < TOLERANCE \
			and absf(damage - rat.contact_damage * rules.named_damage_ratio) < TOLERANCE and mark
	_check("네임드 소환은 체력·공격력 1.2배", summon_ok, "채집 %s, 언데드 %s, 머리뼈 체력 %.2f (쥐 %.1f × %.1f, 일반이면 %.2f), 공격력 %.2f (쥐 %.2f × %.1f), 핫바 칸 네임드 %s" % [
			taken, undead != null, named.health, rat.max_health, rules.named_health_ratio, rat.undead_max_health,
			damage, rat.contact_damage, rules.named_damage_ratio, mark])
	finish(summon_ok)


## monster를 잡고 그 자리에 남은 시체를 돌려준다 (없으면 null).
func _kill(monster: Monster, source: Node2D) -> Corpse:
	var at: Vector2 = monster.global_position
	monster.take_damage(monster.health + 1.0, source)
	await wait_frames(WAIT_FRAMES)
	for node: Node in current_scene.get_node("Actors").get_children():
		var corpse: Corpse = node as Corpse
		if corpse != null and corpse.global_position.is_equal_approx(at):
			return corpse
	return null


func _skulls(corpse: Corpse) -> Array[Skull]:
	var skulls: Array[Skull] = []
	if corpse == null:
		return skulls
	for stack: ItemStack in corpse.loot.get_stacks():
		if stack.is_skull():
			skulls.append(stack.skull)
	return skulls


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
