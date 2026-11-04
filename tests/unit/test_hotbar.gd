extends TestCase
## Hotbar(머리뼈 바로가기) 단위 테스트.

const INVENTORY_SLOTS: int = 5
const HOTBAR_SLOTS: int = 2
const INVENTORY_DATA_PATH: String = "res://data/inventory/necromancer_inventory.tres"
const DESIGN_HOTBAR_SLOTS: int = 2

var inventory: Inventory
var hotbar: Hotbar
var rat_skull: SkullData


func before_each() -> void:
	inventory = Inventory.new(INVENTORY_SLOTS)
	hotbar = Hotbar.new(HOTBAR_SLOTS, inventory)
	rat_skull = SkullData.new()
	rat_skull.id = &"test_rat_skull"
	rat_skull.max_durability = 10.0


## 인벤토리에 머리뼈 하나를 넣고 그 머리뼈를 돌려준다.
func _add_skull() -> Skull:
	var skull: Skull = Skull.create(rat_skull)
	inventory.try_add(ItemStack.of_skull(skull))
	return skull


func test_data_slot_count_matches_design() -> void:
	var data: InventoryData = load(INVENTORY_DATA_PATH)
	assert_eq(data.hotbar_slot_count, DESIGN_HOTBAR_SLOTS, "설계: 핫바는 2칸")


func test_starts_empty() -> void:
	assert_eq(hotbar.get_slot_count(), HOTBAR_SLOTS)
	assert_eq(hotbar.get_skull(0), null)
	assert_eq(hotbar.get_skull(1), null)


func test_assign_is_a_shortcut() -> void:
	var skull: Skull = _add_skull()
	assert_true(hotbar.assign(0, skull))
	assert_true(hotbar.get_skull(0) == skull, "핫바가 그 머리뼈를 가리킨다")
	assert_true(inventory.get_slot(0).skull == skull, "머리뼈는 인벤토리 원래 칸에 그대로 있다")
	assert_eq(inventory.get_skulls().size(), 1, "인벤토리에서 사라지지 않는다")


func test_cannot_assign_skull_not_in_inventory() -> void:
	assert_false(hotbar.assign(0, Skull.create(rat_skull)), "인벤토리에 없는 머리뼈는 놓을 수 없다")
	assert_false(hotbar.assign(0, null))
	assert_false(hotbar.assign(HOTBAR_SLOTS, _add_skull()), "범위 밖 칸")
	assert_eq(hotbar.get_skull(0), null)


func test_keeps_same_skull_after_inventory_move() -> void:
	var first: Skull = _add_skull()
	var second: Skull = _add_skull()
	hotbar.assign(0, first)
	inventory.move_slot(0, 4)
	inventory.move_slot(1, 0)
	assert_true(hotbar.get_skull(0) == first, "칸을 옮겨도 같은 머리뼈를 가리킨다")
	assert_true(inventory.get_slot(0).skull == second, "0번 칸에는 이제 다른 머리뼈가 있다")


func test_cleared_when_skull_dropped() -> void:
	var skull: Skull = _add_skull()
	hotbar.assign(1, skull)
	inventory.remove_slot(0)
	assert_eq(hotbar.get_skull(1), null, "버리면 그 핫바 칸은 빈다")


func test_cleared_when_inventory_cleared() -> void:
	hotbar.assign(0, _add_skull())
	inventory.clear()
	assert_eq(hotbar.get_skull(0), null)


func test_other_slot_kept_when_one_skull_dropped() -> void:
	var first: Skull = _add_skull()
	var second: Skull = _add_skull()
	hotbar.assign(0, first)
	hotbar.assign(1, second)
	inventory.remove_slot(0)
	assert_eq(hotbar.get_skull(0), null)
	assert_true(hotbar.get_skull(1) == second, "버리지 않은 머리뼈는 그대로")


func test_clear_slot_only_removes_shortcut() -> void:
	var skull: Skull = _add_skull()
	hotbar.assign(0, skull)
	assert_true(hotbar.clear_slot(0))
	assert_eq(hotbar.get_skull(0), null, "핫바에서 빠진다")
	assert_true(inventory.get_slot(0).skull == skull, "머리뼈는 버려지지 않는다")
	assert_false(hotbar.clear_slot(0), "빈 칸은 뺄 것이 없다")


func test_assign_to_filled_slot_replaces() -> void:
	var first: Skull = _add_skull()
	var second: Skull = _add_skull()
	hotbar.assign(0, first)
	hotbar.assign(0, second)
	assert_true(hotbar.get_skull(0) == second, "새 머리뼈로 바뀐다")
	assert_eq(inventory.get_skulls().size(), 2, "바뀐 머리뼈도 인벤토리에 그대로")


func test_same_kind_can_be_in_both_slots() -> void:
	var first: Skull = _add_skull()
	var second: Skull = _add_skull()
	hotbar.assign(0, first)
	hotbar.assign(1, second)
	assert_true(hotbar.get_skull(0) == first)
	assert_true(hotbar.get_skull(1) == second, "같은 종류라도 다른 머리뼈면 두 칸에 각각")


func test_same_skull_is_not_duplicated_but_moved() -> void:
	var skull: Skull = _add_skull()
	hotbar.assign(0, skull)
	assert_true(hotbar.assign(1, skull))
	assert_eq(hotbar.get_skull(0), null, "원래 칸은 빈다")
	assert_true(hotbar.get_skull(1) == skull, "새 칸으로 옮겨진다")


func test_swap_slots() -> void:
	var first: Skull = _add_skull()
	var second: Skull = _add_skull()
	hotbar.assign(0, first)
	hotbar.assign(1, second)
	assert_true(hotbar.swap(0, 1))
	assert_true(hotbar.get_skull(0) == second)
	assert_true(hotbar.get_skull(1) == first)


func test_swap_with_empty_slot_moves() -> void:
	var skull: Skull = _add_skull()
	hotbar.assign(0, skull)
	hotbar.swap(0, 1)
	assert_eq(hotbar.get_skull(0), null)
	assert_true(hotbar.get_skull(1) == skull)


func test_changed_signal() -> void:
	var events: Array[int] = [0]
	hotbar.changed.connect(func() -> void: events[0] += 1)
	var skull: Skull = _add_skull()
	hotbar.assign(0, skull)
	hotbar.swap(0, 1)
	hotbar.clear_slot(1)
	hotbar.assign(0, skull)
	inventory.move_slot(0, 3)
	inventory.remove_slot(3)
	assert_eq(events[0], 5, "놓기·바꾸기·빼기·놓기·버려서 비움 (인벤토리 칸 옮기기는 핫바를 바꾸지 않는다)")
