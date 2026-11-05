extends TestCase
## CorpseLoot(시체에 남은 아이템과 채집 규칙) 단위 테스트.

const SEED: int = 1234
const BASE_TIME: float = 2.0
const BONE_MULTIPLIER: float = 0.8
const SKULL_MULTIPLIER: float = 1.5
const BONE_COUNT: int = 2
## 무작위 선택을 이만큼 굴려서 두 종류가 다 나오는지 본다
const PICKS: int = 200

var bone: ItemData
var skull_data: SkullData
var rng: RandomNumberGenerator


func before_each() -> void:
	bone = ItemData.new()
	bone.id = &"test_bone"
	bone.harvest_time_multiplier = BONE_MULTIPLIER
	skull_data = SkullData.new()
	skull_data.id = &"test_skull"
	skull_data.max_durability = 10.0
	skull_data.harvest_time_multiplier = SKULL_MULTIPLIER
	rng = RandomNumberGenerator.new()
	rng.seed = SEED


func _entry(item: ItemData, count: int) -> DropEntry:
	var entry: DropEntry = DropEntry.new()
	entry.item = item
	entry.count = count
	return entry


## 뼈 BONE_COUNT개 + 머리뼈 하나가 든 시체
func _bone_and_skull_loot() -> CorpseLoot:
	var entries: Array[DropEntry] = [_entry(bone, BONE_COUNT), _entry(skull_data, 1)]
	return CorpseLoot.from_drops(entries, BASE_TIME)


func test_from_drops_makes_one_stack_per_kind_and_each_skull_separately() -> void:
	var entries: Array[DropEntry] = [_entry(bone, 3), _entry(skull_data, 2)]
	var stacks: Array[ItemStack] = CorpseLoot.from_drops(entries, BASE_TIME).get_stacks()
	assert_eq(stacks.size(), 3, "뼈 한 묶음 + 머리뼈 두 개")
	assert_eq(stacks[0].count, 3, "뼈는 개수째 한 묶음")
	assert_true(stacks[1].is_skull() and stacks[2].is_skull())
	assert_ne(stacks[1].skull, stacks[2].skull, "머리뼈는 하나하나 따로")
	assert_eq(stacks[1].skull.durability, skull_data.max_durability, "새 머리뼈는 최대 내구도")


func test_harvest_time_is_base_times_multiplier() -> void:
	var loot: CorpseLoot = _bone_and_skull_loot()
	var stacks: Array[ItemStack] = loot.get_stacks()
	assert_almost_eq(loot.get_harvest_time(stacks[0]), BASE_TIME * BONE_MULTIPLIER, 0.0001, "뼈")
	assert_almost_eq(loot.get_harvest_time(stacks[1]), BASE_TIME * SKULL_MULTIPLIER, 0.0001, "머리뼈")


func test_take_gives_one_kind_at_a_time() -> void:
	var loot: CorpseLoot = _bone_and_skull_loot()
	var inventory: Inventory = Inventory.new(10)
	var first: ItemStack = loot.pick_harvestable(inventory, rng)
	assert_true(loot.take(first, inventory))
	assert_eq(loot.get_stacks().size(), 1, "한 번에 한 종류만 빠진다")
	assert_false(loot.is_empty())
	var second: ItemStack = loot.pick_harvestable(inventory, rng)
	assert_ne(second, first)
	assert_true(loot.take(second, inventory))
	assert_true(loot.is_empty(), "두 번 채집하면 빈다")
	assert_eq(inventory.get_count(bone.id), BONE_COUNT, "뼈는 개수째 들어왔다")
	assert_eq(inventory.get_skulls().size(), 1, "머리뼈 하나가 들어왔다")


func test_pick_is_random_among_remaining() -> void:
	var loot: CorpseLoot = _bone_and_skull_loot()
	var inventory: Inventory = Inventory.new(10)
	var seen: Dictionary[StringName, int] = {}
	for i: int in PICKS:
		var stack: ItemStack = loot.pick_harvestable(inventory, rng)
		seen[stack.item.id] = seen.get(stack.item.id, 0) + 1
	assert_eq(seen.size(), 2, "두 종류가 다 골린다: %s" % seen)


func test_full_inventory_only_picks_what_fits() -> void:
	var loot: CorpseLoot = _bone_and_skull_loot()
	# 칸 하나에 뼈가 있으면, 가득 차 있어도 뼈는 합쳐지지만 머리뼈는 들어갈 자리가 없다.
	var inventory: Inventory = Inventory.new(1)
	inventory.try_add(ItemStack.of_item(bone, 1))
	for i: int in PICKS:
		var stack: ItemStack = loot.pick_harvestable(inventory, rng)
		if stack.is_skull():
			assert_true(false, "%d번째에 넣을 자리가 없는 머리뼈를 골랐다" % i)
			return
	assert_true(loot.can_harvest(inventory))


func test_nothing_fits_returns_null_and_keeps_all() -> void:
	var loot: CorpseLoot = _bone_and_skull_loot()
	var other: ItemData = ItemData.new()
	other.id = &"other"
	var inventory: Inventory = Inventory.new(1)
	inventory.try_add(ItemStack.of_item(other, 1))
	assert_eq(loot.pick_harvestable(inventory, rng), null, "넣을 수 있는 것이 없으면 고르지 않는다")
	assert_false(loot.can_harvest(inventory))
	assert_eq(loot.get_stacks().size(), 2, "시체에 그대로 남는다")


func test_take_without_room_leaves_it_in_corpse() -> void:
	var loot: CorpseLoot = _bone_and_skull_loot()
	var skull_stack: ItemStack = loot.get_stacks()[1]
	var inventory: Inventory = Inventory.new(1)
	inventory.try_add(ItemStack.of_item(bone, 1))
	assert_false(loot.take(skull_stack, inventory), "자리가 없으면 꺼내지 못한다")
	assert_true(loot.get_stacks().has(skull_stack), "머리뼈는 시체에 남는다")
	assert_eq(inventory.get_skulls().size(), 0)
