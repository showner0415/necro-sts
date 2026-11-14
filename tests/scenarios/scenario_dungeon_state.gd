extends ScenarioTest
## 시나리오: 던전 상태 (계획 5a·5b). 시험 던전(tests/dungeon_test_a.tscn ↔ tests/dungeon_test_b.tscn, 개발용 출구로 이어짐)에서 지역을 오간다.
## 쥐 무리는 무리 자리(PackSpawn "RatGang", 쥐 패거리 3~4)가 던전 시드로 만든다.
## 1. 던전 A에서 쥐 무리를 맞혀 쫓게 하고, 혼자 있는 쥐와 무리원 하나를 잡아 시체를 남기고, 바닥에 뼈를 떨어뜨린 뒤 B로 가면 A의 상태가 남는다
## 2. A로 돌아오면 무리 쥐의 위치·체력이 떠날 때 그대로이고, 잡은 쥐와 잡은 무리원은 다시 생기지 않으며, 시체(같은 루팅 상태)·바닥 물건·상자(같은 내용물)가 남는다
## 3. 떠날 때 쫓던 무리는 대상을 놓친 것으로 돌아와 경보 없이 그 자리에서 배회한다
## 4. 거점에 다녀오면 던전 상태가 비고, A에 다시 들어가면 몬스터(무리 3~4마리)·상자가 새로 생기고 시체·바닥 물건이 없다

const SCENE_A: String = "res://tests/dungeon_test_a.tscn"
const DATA_A: String = "res://data/regions/test_dungeon_a.tres"
const DATA_B: String = "res://data/regions/test_dungeon_b.tres"
const DATA_BASE: String = "res://data/regions/base.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const BONES: int = 3
## 무리 자리(PackSpawn "RatGang", 쥐 패거리 3~4)가 만든 무리원과 무리 노드
const GANG_RAT: String = "Actors/RatGang_0"
const GANG_VICTIM: String = "Actors/RatGang_1"
const GANG_PACK: String = "RatGangPack"
const LONE_RAT: String = "Actors/LoneRat"
## 무리를 맞힌 뒤 쫓게 두는 프레임, 돌아온 뒤 무리가 묶이고 판단할 때까지 기다리는 프레임
const CHASE_FRAMES: int = 30
const SETTLE_FRAMES: int = 10
const POSITION_TOLERANCE: float = 0.5


func get_start_scene() -> String:
	return SCENE_A


func _on_scene_ready() -> void:
	var dungeon: DungeonRun = root.get_node("GameState").get(&"dungeon")
	await wait_frames(3)
	# 1. A에서 상태를 만들고 B로 간다.
	var gang: Monster = current_scene.get_node(GANG_RAT)
	var necromancer: Necromancer = find_necromancer()
	gang.take_damage(1.0, necromancer)
	(current_scene.get_node(LONE_RAT) as Monster).take_damage(1000.0, necromancer)
	(current_scene.get_node(GANG_VICTIM) as Monster).take_damage(1000.0, necromancer)
	var gang_size: int = (current_scene.get_node("RatGang") as PackSpawn).get_members().size()
	necromancer.drop_to_ground(ItemStack.of_item(load(BONE_PATH), BONES))
	var chest_contents: ChestContents = (current_scene.get_node("Chest") as LootChest).contents
	await wait_frames(CHASE_FRAMES)
	var corpse: Corpse = _first(Corpse)
	# 씬이 바뀌면 노드가 사라지므로 비교할 값은 떠나기 전에 받아 둔다.
	var had_corpse: bool = corpse != null
	var corpse_loot: CorpseLoot = corpse.loot if had_corpse else null
	var chasing: bool = gang.get_target() != null
	var left_position: Vector2 = gang.global_position
	var left_health: float = gang.health
	await _travel(DATA_B)
	var saved: bool = dungeon.is_active() and dungeon.has_snapshot(&"test_dungeon_a")
	_check("떠나면 상태를 남김", saved and had_corpse and chasing, "B에 도착: 던전 진행 중 %s, A 상태 남김 %s, 떠날 때 시체 %s, 무리 쥐가 쫓는 중이었음 %s" % [dungeon.is_active(), saved, had_corpse, chasing])
	# 2·3. A로 돌아온다.
	await _travel(DATA_A)
	await wait_frames(SETTLE_FRAMES)
	gang = current_scene.get_node_or_null(GANG_RAT)
	var lone_gone: bool = current_scene.get_node_or_null(LONE_RAT) == null
	var victim_gone: bool = current_scene.get_node_or_null(GANG_VICTIM) == null
	var gang_back: int = (current_scene.get_node("RatGang") as PackSpawn).get_members().size()
	var corpse_back: Corpse = _first(Corpse)
	var pickup_back: Pickup = _first(Pickup)
	var chest_back: ChestContents = (current_scene.get_node("Chest") as LootChest).contents
	var same_spot: bool = gang != null and gang.global_position.distance_to(left_position) <= POSITION_TOLERANCE + gang.data.wander_speed * SETTLE_FRAMES / Engine.physics_ticks_per_second
	var same_health: bool = gang != null and gang.health == left_health
	var kept: bool = same_spot and same_health and lone_gone and victim_gone and gang_back == gang_size - 1 and corpse_back != null and corpse_back.loot == corpse_loot and pickup_back != null and pickup_back.stack.count == BONES and chest_back == chest_contents
	_check("돌아오면 그대로", kept, "무리 쥐 위치 %s → %s (배회 %d프레임 허용), 체력 %.1f → %.1f, 잡은 쥐 다시 안 생김 %s, 잡은 무리원 다시 안 생김 %s (무리 %d → %d), 시체 같은 루팅 %s, 바닥 뼈 %s, 상자 같은 내용물 %s" % [
			left_position.round(), gang.global_position.round() if gang != null else Vector2.ZERO, SETTLE_FRAMES, left_health, gang.health if gang != null else -1.0, lone_gone, victim_gone, gang_size, gang_back,
			corpse_back != null and corpse_back.loot == corpse_loot, pickup_back.stack.count if pickup_back != null else 0, chest_back == chest_contents])
	var calm: bool = true
	for node: Node in get_nodes_in_group(&"monsters"):
		if (node as Monster).get_target() != null:
			calm = false
	var pack: MonsterPack = current_scene.get_node(GANG_PACK)
	calm = calm and pack.get_alarm_state() == PackAlarm.State.CALM
	_check("떠나면 놓침", calm, "돌아온 뒤 대상이 있는 몬스터 없음 %s, 무리 경보 상태 %s (평소 %s)" % [calm, pack.get_alarm_state(), PackAlarm.State.CALM])
	# 4. 거점에 다녀와 A에 다시 들어간다.
	await _travel(DATA_BASE)
	var cleared: bool = not dungeon.is_active() and not dungeon.has_snapshot(&"test_dungeon_a")
	await _travel(DATA_A)
	await wait_frames(3)
	var fresh_gang: Monster = current_scene.get_node_or_null(GANG_RAT)
	var fresh_count: int = (current_scene.get_node("RatGang") as PackSpawn).get_members().size()
	var fresh: bool = cleared and fresh_count >= 3 and fresh_count <= 4 and current_scene.get_node_or_null(LONE_RAT) != null and fresh_gang != null and fresh_gang.health == fresh_gang.data.max_health \
			and _first(Corpse) == null and _first(Pickup) == null and (current_scene.get_node("Chest") as LootChest).contents != chest_contents
	_check("거점에 다녀오면 초기화", fresh, "거점에서 던전 상태 비움 %s, 다시 들어온 A: 무리 %d마리, 잡은 쥐 다시 생김 %s, 무리 쥐 체력 가득 %s, 시체 없음 %s, 바닥 물건 없음 %s, 상자 새로 %s" % [
			cleared, fresh_count, current_scene.get_node_or_null(LONE_RAT) != null, fresh_gang != null and fresh_gang.health == fresh_gang.data.max_health,
			_first(Corpse) == null, _first(Pickup) == null, (current_scene.get_node("Chest") as LootChest).contents != chest_contents])
	finish(fresh and calm and kept and saved)


func _check(step_name: String, ok: bool, evidence: String) -> void:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)


## 지금 지역에서 destination(RegionData 경로)으로 가고 새 씬이 준비될 때까지 기다린다.
func _travel(destination: String) -> void:
	var old_scene: Node = current_scene
	current_scene.call(&"travel_to", load(destination))
	while current_scene == old_scene or current_scene == null or not current_scene.is_node_ready():
		await physics_frame
	await wait_frames(2)


## 지금 씬에서 type(스크립트 클래스)인 첫 노드 (없으면 null). find_children의 type은 엔진 클래스만 가린다
func _first(type: Script) -> Node:
	var found: Array[Node] = current_scene.find_children("*", "", true, false)
	for node: Node in found:
		if is_instance_of(node, type) and not node.is_queued_for_deletion():
			return node
	return null
