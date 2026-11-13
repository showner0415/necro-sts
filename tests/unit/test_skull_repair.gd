extends TestCase
## SkullRepair(수리 기계의 내구도 수리 규칙) 단위 테스트. 몬스터·머리뼈 데이터는 실제 .tres 대신 여기서 만든다.

const MAX_DURABILITY: float = 10.0
const PER_ITEM: float = 1.0

var inventory: Inventory
var hotbar: Hotbar
var mana: ManaPool
var roster: UndeadRoster
var repair: SkullRepair
var bone: ItemData
var monster: MonsterData
var skull_data: SkullData


func before_each() -> void:
	inventory = Inventory.new(10)
	hotbar = Hotbar.new(2, inventory)
	mana = ManaPool.new(10.0, 0.0)
	bone = ItemData.new()
	bone.id = &"test_bone"
	monster = MonsterData.new()
	monster.id = &"test_rat"
	monster.summon_bone_cost = 0
	monster.summon_mana_cost = 0.0
	monster.max_health = 4.0
	skull_data = SkullData.new()
	skull_data.id = &"test_rat_skull"
	skull_data.source_monster_id = monster.id
	skull_data.max_durability = MAX_DURABILITY
	roster = UndeadRoster.new(inventory, hotbar, mana, bone.id, _find_monster, 1.0)
	repair = SkullRepair.new(inventory, roster, bone.id, PER_ITEM)


func _find_monster(id: StringName) -> MonsterData:
	return monster if id == monster.id else null


## 내구도가 durability인 머리뼈를 인벤토리에 넣어 돌려준다.
func _add_skull(durability: float) -> Skull:
	var skull: Skull = Skull.create(skull_data)
	skull.durability = durability
	inventory.try_add(ItemStack.of_skull(skull))
	return skull


func _add_bones(count: int) -> void:
	inventory.try_add(ItemStack.of_item(bone, count))


func test_cost_is_missing_durability_per_item() -> void:
	assert_eq(SkullRepair.cost_for(7.0, 10.0, 1.0), 3, "3 모자라면 뼈 3개")
	assert_eq(SkullRepair.cost_for(0.0, 10.0, 1.0), 10, "0이면 뼈 10개")
	assert_eq(SkullRepair.cost_for(10.0, 10.0, 1.0), 0, "가득 차면 0개")


func test_cost_rounds_up() -> void:
	assert_eq(SkullRepair.cost_for(7.5, 10.0, 1.0), 3, "2.5 모자라면 올림해서 3개")
	assert_eq(SkullRepair.cost_for(7.0, 10.0, 2.0), 2, "개당 2씩이면 3 모자랄 때 2개")


func test_cost_ignores_float_error() -> void:
	# 0.1을 열 번 더하면 1.0보다 아주 조금 작아질 수 있다. 그래도 하나 더 들지 않는다.
	var durability: float = 0.0
	for i: int in 10:
		durability += 0.1
	assert_eq(SkullRepair.cost_for(9.0 + durability - 1.0, 10.0, 1.0), 1, "1 모자랄 때 소수 오차로 2개가 되지 않음")


func test_repair_fills_and_uses_bones() -> void:
	var skull: Skull = _add_skull(6.0)
	_add_bones(10)
	assert_eq(repair.repair(skull), SkullRepair.Result.OK, "수리됨")
	assert_almost_eq(skull.durability, MAX_DURABILITY, 0.001, "가득 참")
	assert_eq(inventory.get_count(bone.id), 6, "뼈 4개 씀")


func test_partial_repair_with_few_bones() -> void:
	var skull: Skull = _add_skull(2.0)
	_add_bones(3)
	assert_eq(repair.repair(skull), SkullRepair.Result.OK, "가진 만큼 수리됨")
	assert_almost_eq(skull.durability, 5.0, 0.001, "뼈 3개만큼 참")
	assert_eq(inventory.get_count(bone.id), 0, "뼈를 다 씀")


func test_does_not_exceed_max() -> void:
	var skull: Skull = _add_skull(9.5)
	_add_bones(5)
	repair.repair(skull)
	assert_almost_eq(skull.durability, MAX_DURABILITY, 0.001, "최대를 넘지 않음")
	assert_eq(inventory.get_count(bone.id), 4, "뼈 1개만 씀")


func test_broken_skull_can_be_repaired() -> void:
	var skull: Skull = _add_skull(0.0)
	_add_bones(1)
	assert_true(skull.is_broken(), "처음에는 소환할 수 없음")
	assert_eq(repair.repair(skull), SkullRepair.Result.OK, "내구도 0도 수리됨")
	assert_false(skull.is_broken(), "수리하면 다시 소환할 수 있음")


func test_full_skull_is_not_repaired() -> void:
	var skull: Skull = _add_skull(MAX_DURABILITY)
	_add_bones(5)
	assert_eq(repair.check(skull), SkullRepair.Result.FULL, "가득 참")
	assert_eq(repair.repair(skull), SkullRepair.Result.FULL, "수리하지 않음")
	assert_eq(inventory.get_count(bone.id), 5, "뼈를 쓰지 않음")


func test_no_bones() -> void:
	var skull: Skull = _add_skull(3.0)
	assert_eq(repair.check(skull), SkullRepair.Result.NO_COST_ITEM, "뼈 없음")
	assert_almost_eq(skull.durability, 3.0, 0.001, "그대로")


func test_summoned_skull_is_not_repaired() -> void:
	var skull: Skull = _add_skull(3.0)
	_add_bones(10)
	hotbar.assign(0, skull)
	assert_eq(roster.summon(skull), UndeadRoster.Result.OK, "소환됨 (비용 0으로 둠)")
	assert_eq(repair.repair(skull), SkullRepair.Result.SUMMONED, "소환 중이라 못 함")
	assert_almost_eq(skull.durability, 3.0, 0.001, "그대로")
	roster.unsummon(skull)
	assert_eq(repair.repair(skull), SkullRepair.Result.OK, "해제하면 수리됨")


func test_skull_outside_inventory_is_not_repaired() -> void:
	var skull: Skull = Skull.create(skull_data)
	skull.durability = 3.0
	_add_bones(10)
	assert_eq(repair.check(skull), SkullRepair.Result.NO_SKULL, "인벤토리에 없는 머리뼈(창고 등)는 못 함")
	assert_eq(repair.check(null), SkullRepair.Result.NO_SKULL, "머리뼈 없음")
