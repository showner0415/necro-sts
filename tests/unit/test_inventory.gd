extends TestCase
## Inventory(고정 칸 인벤토리) 단위 테스트.

const SLOT_COUNT: int = 4
const INVENTORY_DATA_PATH: String = "res://data/inventory/necromancer_inventory.tres"
const DESIGN_SLOT_COUNT: int = 10

var inventory: Inventory
var bone: ItemData
var rat_skull: SkullData


func before_each() -> void:
	inventory = Inventory.new(SLOT_COUNT)
	bone = ItemData.new()
	bone.id = &"test_bone"
	rat_skull = SkullData.new()
	rat_skull.id = &"test_rat_skull"
	rat_skull.max_durability = 10.0


func _skull() -> ItemStack:
	return ItemStack.of_skull(Skull.create(rat_skull))


func _fill_with_skulls() -> void:
	for i: int in SLOT_COUNT:
		inventory.try_add(_skull())


func test_data_slot_count_matches_design() -> void:
	var data: InventoryData = load(INVENTORY_DATA_PATH)
	assert_eq(data.slot_count, DESIGN_SLOT_COUNT, "설계: 지금은 10칸")


func test_starts_with_all_slots_empty() -> void:
	assert_eq(inventory.get_slot_count(), SLOT_COUNT)
	for i: int in SLOT_COUNT:
		assert_eq(inventory.get_slot(i), null, "%d번 칸은 비어 있다" % i)


func test_slot_count_limit() -> void:
	for i: int in SLOT_COUNT:
		assert_true(inventory.try_add(_skull()), "%d번째 머리뼈는 들어간다" % i)
	assert_false(inventory.try_add(_skull()), "칸 수보다 많이는 못 넣는다")
	assert_eq(inventory.get_skulls().size(), SLOT_COUNT)


func test_full_inventory_rejects_pickup_and_stays_same() -> void:
	_fill_with_skulls()
	var before: Array[ItemStack] = []
	for i: int in SLOT_COUNT:
		before.append(inventory.get_slot(i))
	var bones: ItemStack = ItemStack.of_item(bone, 2)
	assert_false(inventory.can_add(bones), "가득 차면 넣을 수 없다고 알려 준다")
	assert_false(inventory.try_add(bones), "가득 차면 줍기 실패")
	for i: int in SLOT_COUNT:
		assert_true(inventory.get_slot(i) == before[i], "%d번 칸은 그대로" % i)
	assert_eq(inventory.get_count(&"test_bone"), 0)


func test_bones_stack_in_one_slot_without_limit() -> void:
	inventory.try_add(ItemStack.of_item(bone, 2))
	inventory.try_add(ItemStack.of_item(bone, 3))
	inventory.try_add(ItemStack.of_item(bone, 100))
	assert_eq(inventory.get_slot(0).count, 105, "한 칸에 계속 쌓인다")
	assert_eq(inventory.get_slot(1), null, "다른 칸을 쓰지 않는다")


func test_bones_merge_even_when_full() -> void:
	inventory.try_add(ItemStack.of_item(bone, 2))
	for i: int in SLOT_COUNT - 1:
		inventory.try_add(_skull())
	var more_bones: ItemStack = ItemStack.of_item(bone, 3)
	assert_true(inventory.can_add(more_bones), "뼈 칸이 있으면 가득 차도 뼈는 넣을 수 있다")
	assert_true(inventory.try_add(more_bones))
	assert_eq(inventory.get_count(&"test_bone"), 5)
	assert_false(inventory.can_add(_skull()), "머리뼈는 여전히 못 넣는다")


func test_skulls_take_one_slot_each() -> void:
	inventory.try_add(_skull())
	inventory.try_add(_skull())
	assert_true(inventory.get_slot(0).is_skull())
	assert_true(inventory.get_slot(1).is_skull())
	assert_true(inventory.get_slot(0).skull != inventory.get_slot(1).skull, "서로 다른 머리뼈")


func test_drop_leaves_empty_slot() -> void:
	inventory.try_add(ItemStack.of_item(bone, 2))
	inventory.try_add(_skull())
	var dropped: ItemStack = inventory.remove_slot(0)
	assert_eq(dropped.count, 2, "칸의 물건을 통째로 돌려준다")
	assert_eq(inventory.get_slot(0), null, "버린 칸은 빈다")
	assert_eq(inventory.get_count(&"test_bone"), 0)
	assert_eq(inventory.remove_slot(0), null, "빈 칸을 버리면 아무것도 없다")


func test_drop_makes_room_when_full() -> void:
	_fill_with_skulls()
	inventory.remove_slot(2)
	assert_true(inventory.try_add(ItemStack.of_item(bone, 1)), "버리고 나면 다시 넣을 수 있다")
	assert_false(inventory.get_slot(2).is_skull(), "빈 2번 칸에 들어간다")


func test_items_keep_their_slot() -> void:
	inventory.try_add(_skull())
	var second: ItemStack = _skull()
	inventory.try_add(second)
	inventory.try_add(_skull())
	inventory.remove_slot(0)
	assert_true(inventory.get_slot(1) == second, "앞 칸을 비워도 뒤 칸의 물건은 앞으로 당겨지지 않는다")
	inventory.try_add(ItemStack.of_item(bone, 1))
	assert_false(inventory.get_slot(0).is_skull(), "새 물건은 가장 앞의 빈 칸(0번)에 들어간다")
	assert_true(inventory.get_slot(1) == second, "1번 칸은 그대로")


func test_move_to_empty_slot() -> void:
	var skull: ItemStack = _skull()
	inventory.try_add(skull)
	assert_true(inventory.move_slot(0, 3))
	assert_eq(inventory.get_slot(0), null, "원래 칸은 빈다")
	assert_true(inventory.get_slot(3) == skull, "옮긴 칸에 있다")


func test_move_onto_filled_slot_swaps() -> void:
	var bones: ItemStack = ItemStack.of_item(bone, 2)
	var skull: ItemStack = _skull()
	inventory.try_add(bones)
	inventory.try_add(skull)
	assert_true(inventory.move_slot(0, 1))
	assert_true(inventory.get_slot(0) == skull, "두 칸의 자리가 바뀐다")
	assert_true(inventory.get_slot(1) == bones)


func test_move_does_nothing_for_empty_or_invalid_slot() -> void:
	inventory.try_add(_skull())
	var events: Array[int] = [0]
	inventory.changed.connect(func() -> void: events[0] += 1)
	assert_false(inventory.move_slot(2, 0), "빈 칸은 옮길 수 없다")
	assert_false(inventory.move_slot(0, SLOT_COUNT), "범위 밖으로는 옮길 수 없다")
	assert_false(inventory.move_slot(-1, 0))
	assert_true(inventory.move_slot(0, 0), "제자리에 놓으면 그대로")
	assert_true(inventory.get_slot(0).is_skull())
	assert_eq(events[0], 0, "바뀐 것이 없으면 알리지 않는다")


func test_each_skull_keeps_its_own_durability() -> void:
	var first: ItemStack = _skull()
	inventory.try_add(first)
	inventory.try_add(_skull())
	first.skull.durability = 3.0
	assert_eq(inventory.get_skulls()[0].durability, 3.0)
	assert_eq(inventory.get_skulls()[1].durability, 10.0, "다른 머리뼈의 내구도는 그대로")


func test_skull_counts_follow_slot_order() -> void:
	var wolf_skull: SkullData = SkullData.new()
	wolf_skull.id = &"test_wolf_skull"
	inventory.try_add(_skull())
	inventory.try_add(ItemStack.of_skull(Skull.create(wolf_skull)))
	inventory.try_add(_skull())
	inventory.move_slot(1, 0)
	var counts: Dictionary[SkullData, int] = inventory.get_skull_counts()
	assert_eq(counts.keys(), [wolf_skull, rat_skull], "칸 순서에서 처음 나온 종류 순서")
	assert_eq(counts[rat_skull], 2)


func test_clear_empties_all_slots() -> void:
	_fill_with_skulls()
	inventory.clear()
	for i: int in SLOT_COUNT:
		assert_eq(inventory.get_slot(i), null)


func test_changed_signal_on_each_change() -> void:
	var events: Array[int] = [0]
	inventory.changed.connect(func() -> void: events[0] += 1)
	inventory.try_add(_skull())
	inventory.try_add(ItemStack.of_item(bone, 1))
	inventory.try_add(ItemStack.of_item(bone, 1))
	inventory.move_slot(0, 1)
	inventory.remove_slot(0)
	assert_eq(events[0], 5, "넣기 3번, 옮기기 1번, 버리기 1번")


func test_remove_count_takes_bones_and_empties_used_slot() -> void:
	inventory.try_add(ItemStack.of_item(bone, 5))
	assert_eq(inventory.remove_count(bone.id, 3), 3)
	assert_eq(inventory.get_count(bone.id), 2)
	assert_eq(inventory.remove_count(bone.id, 10), 2, "있는 만큼만 꺼낸다")
	assert_eq(inventory.get_slot(0), null, "다 쓴 칸은 빈다")
	assert_eq(inventory.remove_count(bone.id, 1), 0)
