extends TestCase
## RegionSnapshot(던전 지역 상태 담기·되살리기) 단위 테스트. 지역 대신 작은 노드 트리(지역 → Actors → 몬스터·시체·바닥 물건, 상자)로 본다.

const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const CORPSE_SCENE: String = "res://monsters/corpse.tscn"
const PICKUP_SCENE: String = "res://items/pickup.tscn"
const CHEST_SCENE: String = "res://regions/loot_chest.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const CHEST_DATA: String = "res://data/chests/test_chest.tres"
const BONE_PATH: String = "res://data/items/bone.tres"

var _regions: Array[Node2D] = []


func after_each() -> void:
	for region: Node2D in _regions:
		region.free()
	_regions.clear()


## 씬에 놓인 것처럼(owner가 지역) 쥐 둘(RatA, RatB)과 상자 하나를 둔 지역
func _region() -> Node2D:
	var region: Node2D = Node2D.new()
	var actors: Node2D = Node2D.new()
	actors.name = "Actors"
	region.add_child(actors)
	actors.owner = region
	for rat_name: String in ["RatA", "RatB"]:
		var rat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		rat.name = rat_name
		rat.data = load(RAT_PATH)
		# 단위 테스트 실행기는 _ready를 부르기 전에 돈다. 살아 있는 몸으로 보이게 체력을 직접 넣는다.
		rat.health = rat.data.max_health
		actors.add_child(rat)
		rat.owner = region
	var chest: LootChest = (load(CHEST_SCENE) as PackedScene).instantiate()
	chest.name = "Chest"
	chest.data = load(CHEST_DATA)
	region.add_child(chest)
	chest.owner = region
	(Engine.get_main_loop() as SceneTree).root.add_child(region)
	_regions.append(region)
	return region


func test_capture_then_restore_into_fresh_region() -> void:
	var left: Node2D = _region()
	var rat_a: Monster = left.get_node("Actors/RatA")
	rat_a.global_position = Vector2(30, 40)
	rat_a.health = 2.0
	# RatB는 죽었다.
	left.get_node("Actors/RatB").free()
	var corpse: Corpse = (load(CORPSE_SCENE) as PackedScene).instantiate()
	var loot: CorpseLoot = CorpseLoot.new([] as Array[ItemStack], 1.0)
	corpse.setup(load(RAT_PATH), loot)
	left.get_node("Actors").add_child(corpse)
	corpse.global_position = Vector2(5, 6)
	var pickup: Pickup = (load(PICKUP_SCENE) as PackedScene).instantiate()
	pickup.stack = ItemStack.of_item(load(BONE_PATH), 3)
	left.get_node("Actors").add_child(pickup)
	pickup.global_position = Vector2(7, 8)
	var contents: ChestContents = (left.get_node("Chest") as LootChest).contents
	var snapshot: Dictionary = RegionSnapshot.capture(left)

	var back: Node2D = _region()
	RegionSnapshot.restore(back, back.get_node("Actors"), snapshot)
	var restored: Monster = back.get_node_or_null("Actors/RatA")
	assert_true(restored != null, "살아 있던 쥐는 있다")
	assert_eq(restored.global_position, Vector2(30, 40), "위치")
	assert_eq(restored.health, 2.0, "체력")
	assert_true(back.get_node_or_null("Actors/RatB") == null, "죽은 쥐는 다시 생기지 않는다")
	var corpses: Array[Node] = back.get_node("Actors").get_children().filter(func(n: Node) -> bool: return n is Corpse)
	assert_eq(corpses.size(), 1, "시체 하나")
	assert_true((corpses[0] as Corpse).loot == loot, "같은 루팅 상태")
	assert_eq((corpses[0] as Corpse).global_position, Vector2(5, 6))
	var pickups: Array[Node] = back.get_node("Actors").get_children().filter(func(n: Node) -> bool: return n is Pickup)
	assert_eq(pickups.size(), 1, "바닥 물건 하나")
	assert_eq((pickups[0] as Pickup).stack.count, 3)
	assert_true((back.get_node("Chest") as LootChest).contents == contents, "상자는 담은 내용물로 바뀐다")


func test_runtime_monsters_are_not_captured() -> void:
	var region: Node2D = _region()
	var extra: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	extra.data = load(RAT_PATH)
	region.get_node("Actors").add_child(extra)
	var snapshot: Dictionary = RegionSnapshot.capture(region)
	assert_eq((snapshot["monsters"] as Dictionary).size(), 2, "씬에 놓인 쥐 둘만 (실행 중에 만든 몸은 경로로 되살릴 수 없다)")


func test_pack_spawn_members_are_captured_alive_only() -> void:
	var region: Node2D = _region()
	var spawn: PackSpawn = PackSpawn.new()
	spawn.name = "Gang"
	spawn.pack = load("res://data/packs/rat_gang.tres")
	region.add_child(spawn)
	spawn.owner = region
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4
	spawn.spawn(region.get_node("Actors"), rng, func(_point: Vector2) -> bool: return true)
	var members: Array[Monster] = spawn.get_members()
	assert_true(members.size() >= 3 and members.size() <= 4, "쥐 패거리 3~4 (%d)" % members.size())
	for monster: Monster in members:
		# 단위 테스트 실행기는 _ready 전에 돈다. 살아 있는 몸으로 보이게 체력을 넣는다.
		monster.health = 4.0
	members[0].is_leader = true
	var killed_name: String = members[1].name
	members[1].free()
	var packs: Dictionary = RegionSnapshot.capture(region)["packs"]
	assert_true(packs.has("Gang"), "자리 경로로 담는다")
	var entries: Array = packs["Gang"]
	assert_eq(entries.size(), members.size() - 1, "죽은 무리원은 담지 않는다")
	for entry: Dictionary in entries:
		assert_ne(entry["index"], 1, "죽은 번호(%s)는 없다" % killed_name)
		assert_eq(entry["health"], 4.0, "체력")
		assert_eq(entry["data"], load("res://data/monsters/rat.tres"), "몬스터 데이터")
		assert_eq(entry["leader"], entry["index"] == 0, "대장 여부 (0번이 대장)")
