extends TestCase
## 창고와 인벤토리 ↔ 창고 옮기기(ItemTransfer, TransferItemAction) 단위 테스트.

const STORAGE_DATA_PATH: String = "res://data/inventory/storage.tres"
const DESIGN_STORAGE_SLOTS: int = 100
const TO_STORAGE_PATH: String = "res://data/item_actions/send_to_storage.tres"
const TO_INVENTORY_PATH: String = "res://data/item_actions/send_to_inventory.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const INVENTORY_SLOTS: int = 4
const STORAGE_SLOTS: int = 6

var inventory: Inventory
var storage: Inventory
var hotbar: Hotbar
var mana: ManaPool
var roster: UndeadRoster
var transfer: ItemTransfer
var bone: ItemData
var other_item: ItemData
var monster: MonsterData
var skull_data: SkullData


func before_each() -> void:
	inventory = Inventory.new(INVENTORY_SLOTS)
	inventory.display_name = "인벤토리"
	storage = Inventory.new(STORAGE_SLOTS)
	storage.display_name = "창고"
	hotbar = Hotbar.new(2, inventory)
	mana = ManaPool.new(10.0, 0.0)
	bone = ItemData.new()
	bone.id = &"test_bone"
	other_item = ItemData.new()
	other_item.id = &"test_other"
	skull_data = load(RAT_SKULL_PATH)
	monster = MonsterData.new()
	monster.id = skull_data.source_monster_id
	monster.summon_bone_cost = 0
	monster.summon_mana_cost = 0.0
	# 언데드 체력은 몬스터 체력 × 배율이므로, 배율 1로 두고 몬스터 체력을 정한다.
	monster.max_health = 4.0
	monster.undead_health_ratio_override = 1.0
	roster = UndeadRoster.new(inventory, hotbar, mana, bone.id, _find_monster, 1.0)
	transfer = ItemTransfer.new(inventory, roster)


func _find_monster(id: StringName) -> MonsterData:
	return monster if id == monster.id else null


func _skull_stack() -> ItemStack:
	return ItemStack.of_skull(Skull.create(skull_data))


func _fill(target: Inventory) -> void:
	while target.can_add(ItemStack.of_skull(Skull.create(skull_data))):
		target.try_add(_skull_stack())


func _context(container: Inventory, index: int, storage_open: bool = true) -> ItemActionContext:
	var context: ItemActionContext = ItemActionContext.new()
	context.inventory = inventory
	context.container = container
	context.storage = storage if storage_open else null
	context.hotbar = hotbar
	context.roster = roster
	context.transfer = transfer
	context.slot_index = index
	return context


# --- 창고 칸 수 ---

func test_storage_has_100_slots() -> void:
	var data: InventoryData = load(STORAGE_DATA_PATH)
	assert_eq(data.slot_count, DESIGN_STORAGE_SLOTS, "설계: 창고 100칸")
	var game_state: PackedScene = load("res://core/game_state.tscn")
	var node: Node = game_state.instantiate()
	assert_true(node.get("storage_data") == data, "GameState가 창고 데이터를 쓴다")
	node.free()


# --- 끌어 놓기 ---

func test_move_to_empty_storage_slot() -> void:
	inventory.try_add(ItemStack.of_item(bone, 3))
	assert_eq(transfer.move(inventory, 0, storage, 5), ItemTransfer.Result.OK)
	assert_eq(inventory.get_slot(0), null, "인벤토리 칸이 빈다")
	assert_eq(storage.get_slot(5).count, 3, "창고 5번 칸으로")


func test_move_onto_filled_slot_swaps() -> void:
	var skull: ItemStack = _skull_stack()
	inventory.try_add(skull)
	storage.try_add(ItemStack.of_item(other_item, 2))
	transfer.move(inventory, 0, storage, 0)
	assert_true(storage.get_slot(0) == skull, "머리뼈는 창고로")
	assert_eq(inventory.get_slot(0).item.id, other_item.id, "창고에 있던 물건은 인벤토리로")


func test_bones_merge_across_containers() -> void:
	inventory.try_add(ItemStack.of_item(bone, 3))
	storage.try_add(ItemStack.of_item(bone, 5))
	transfer.move(inventory, 0, storage, 0)
	assert_eq(storage.get_slot(0).count, 8, "뼈 칸에 놓으면 합쳐진다")
	assert_eq(inventory.get_slot(0), null)


func test_bones_merge_inside_inventory() -> void:
	inventory.try_add(ItemStack.of_item(bone, 3))
	storage.try_add(ItemStack.of_item(bone, 4))
	transfer.move(storage, 0, inventory, 2)
	assert_eq(inventory.get_slot(2).count, 4, "빈 칸에 놓으면 뼈 칸이 하나 더 생긴다")
	inventory.move_slot(2, 0)
	assert_eq(inventory.get_slot(0).count, 7, "인벤토리 안에서도 뼈 칸끼리 합쳐진다")
	assert_eq(inventory.get_slot(2), null)


func test_unlimited_bones_in_one_storage_slot() -> void:
	storage.try_add(ItemStack.of_item(bone, 9999))
	storage.try_add(ItemStack.of_item(bone, 1))
	assert_eq(storage.get_slot(0).count, 10000)
	assert_eq(storage.get_slot(1), null)


# --- 가득 찼을 때 ---

func test_send_to_full_storage_fails() -> void:
	_fill(storage)
	inventory.try_add(_skull_stack())
	assert_eq(transfer.send(inventory, 0, storage), ItemTransfer.Result.FULL)
	assert_true(inventory.get_slot(0) != null, "인벤토리에 그대로")


func test_send_bones_to_full_storage_with_bone_slot_merges() -> void:
	storage.try_add(ItemStack.of_item(bone, 1))
	_fill(storage)
	inventory.try_add(ItemStack.of_item(bone, 4))
	assert_eq(transfer.send(inventory, 0, storage), ItemTransfer.Result.OK, "뼈 칸이 있으면 가득 차도 합쳐진다")
	assert_eq(storage.get_slot(0).count, 5)


func test_drag_swap_works_even_when_full() -> void:
	_fill(storage)
	_fill(inventory)
	var from_inventory: ItemStack = inventory.get_slot(1)
	var from_storage: ItemStack = storage.get_slot(3)
	assert_eq(transfer.move(inventory, 1, storage, 3), ItemTransfer.Result.OK)
	assert_true(storage.get_slot(3) == from_inventory)
	assert_true(inventory.get_slot(1) == from_storage, "가득 차 있어도 자리 바꾸기는 된다")


func test_send_to_storage_action_gray_when_full() -> void:
	_fill(storage)
	inventory.try_add(_skull_stack())
	var action: ItemAction = load(TO_STORAGE_PATH)
	var state: ItemActionState = action.get_state(_context(inventory, 0))
	assert_false(state.enabled)
	assert_eq(state.reason, "창고 가득 참")


func test_send_to_inventory_action_gray_when_full() -> void:
	_fill(inventory)
	storage.try_add(_skull_stack())
	var state: ItemActionState = (load(TO_INVENTORY_PATH) as ItemAction).get_state(_context(storage, 0))
	assert_false(state.enabled)
	assert_eq(state.reason, "인벤토리 가득 참")


# --- 핫바 연동 ---

func test_skull_moved_to_storage_clears_hotbar() -> void:
	var stack: ItemStack = _skull_stack()
	inventory.try_add(stack)
	hotbar.assign(1, stack.skull)
	transfer.move(inventory, 0, storage, 0)
	assert_eq(hotbar.get_skull(1), null, "창고로 옮기면 핫바 칸이 빈다")
	transfer.move(storage, 0, inventory, 0)
	assert_eq(hotbar.get_skull(1), null, "다시 꺼내도 저절로 돌아오지 않는다")


func test_skull_sent_to_storage_by_menu_clears_hotbar() -> void:
	var stack: ItemStack = _skull_stack()
	inventory.try_add(stack)
	hotbar.assign(0, stack.skull)
	assert_true((load(TO_STORAGE_PATH) as ItemAction).execute(_context(inventory, 0)))
	assert_eq(hotbar.get_skull(0), null)
	assert_true(storage.get_slot(0) == stack)


# --- 소환 중인 머리뼈 ---

func test_summoned_skull_cannot_go_to_storage() -> void:
	var stack: ItemStack = _skull_stack()
	inventory.try_add(stack)
	hotbar.assign(0, stack.skull)
	roster.summon(stack.skull)
	assert_eq(transfer.move(inventory, 0, storage, 0), ItemTransfer.Result.SUMMONED, "끌어 놓기 막힘")
	assert_eq(transfer.send(inventory, 0, storage), ItemTransfer.Result.SUMMONED, "보내기 막힘")
	assert_true(inventory.get_slot(0) == stack, "인벤토리에 그대로")
	assert_true(roster.is_summoned(stack.skull), "소환도 그대로")
	var state: ItemActionState = (load(TO_STORAGE_PATH) as ItemAction).get_state(_context(inventory, 0))
	assert_false(state.enabled)
	assert_eq(state.reason, "소환 중")


func test_summoned_skull_cannot_be_swapped_out_to_storage() -> void:
	var stack: ItemStack = _skull_stack()
	inventory.try_add(stack)
	hotbar.assign(0, stack.skull)
	roster.summon(stack.skull)
	storage.try_add(ItemStack.of_item(other_item, 1))
	assert_eq(transfer.move(storage, 0, inventory, 0), ItemTransfer.Result.SUMMONED, "창고 물건을 소환 중인 머리뼈 칸에 놓아도 막힘")
	assert_true(inventory.get_slot(0) == stack)


# --- 메뉴 항목이 보이는 곳 ---

func test_menu_visibility() -> void:
	inventory.try_add(_skull_stack())
	storage.try_add(_skull_stack())
	var to_storage: ItemAction = load(TO_STORAGE_PATH)
	var to_inventory: ItemAction = load(TO_INVENTORY_PATH)
	var heal: ItemAction = skull_data.actions[0]
	assert_true(to_storage.is_visible_in(_context(inventory, 0)), "창고가 열려 있으면 인벤토리 칸에 '창고로 옮기기'")
	assert_false(to_storage.is_visible_in(_context(inventory, 0, false)), "창고가 닫혀 있으면 없음")
	assert_false(to_inventory.is_visible_in(_context(inventory, 0)))
	assert_true(to_inventory.is_visible_in(_context(storage, 0)), "창고 칸에 '인벤토리로 옮기기'")
	assert_false(to_storage.is_visible_in(_context(storage, 0)))
	assert_false(heal.is_visible_in(_context(storage, 0)), "창고 칸에는 아이템 메뉴(회복하기 등)가 없다")
	assert_true(heal.is_visible_in(_context(inventory, 0)))


func test_send_to_inventory_merges_bones() -> void:
	inventory.try_add(_skull_stack())
	inventory.try_add(ItemStack.of_item(bone, 2))
	storage.try_add(ItemStack.of_item(bone, 5))
	assert_true((load(TO_INVENTORY_PATH) as ItemAction).execute(_context(storage, 0)))
	assert_eq(inventory.get_slot(1).count, 7, "인벤토리의 뼈 칸에 합쳐진다")
	assert_eq(storage.get_slot(0), null)


# --- 빠른 옮기기 (Shift+좌클릭) ---

func test_quick_move_both_ways() -> void:
	var skull: ItemStack = _skull_stack()
	inventory.try_add(skull)
	assert_eq(transfer.quick_move(inventory, 0, storage), ItemTransfer.Result.OK, "인벤토리 → 열려 있는 창고")
	assert_true(storage.get_slot(0) == skull)
	assert_eq(inventory.get_slot(0), null)
	assert_eq(transfer.quick_move(storage, 0, storage), ItemTransfer.Result.OK, "창고 → 인벤토리")
	assert_true(inventory.get_slot(0) == skull)
	assert_eq(storage.get_slot(0), null)


func test_quick_move_goes_to_first_empty_slot() -> void:
	storage.try_add(ItemStack.of_item(other_item, 1))
	storage.try_add(ItemStack.of_item(other_item, 1))
	storage.remove_slot(0)
	inventory.try_add(_skull_stack())
	transfer.quick_move(inventory, 0, storage)
	assert_true(storage.get_slot(0) != null and storage.get_slot(0).is_skull(), "가장 앞의 빈 칸(0번)으로")


func test_quick_move_merges_bones() -> void:
	storage.try_add(_skull_stack())
	storage.try_add(ItemStack.of_item(bone, 5))
	inventory.try_add(ItemStack.of_item(bone, 3))
	assert_eq(transfer.quick_move(inventory, 0, storage), ItemTransfer.Result.OK)
	assert_eq(storage.get_slot(1).count, 8, "받는 쪽의 뼈 칸에 합쳐진다")
	assert_eq(storage.get_slot(2), null, "새 칸을 쓰지 않는다")
	inventory.try_add(_skull_stack())
	inventory.try_add(ItemStack.of_item(bone, 2))
	assert_eq(transfer.quick_move(storage, 1, storage), ItemTransfer.Result.OK)
	assert_eq(inventory.get_slot(1).count, 10, "창고 → 인벤토리도 뼈 칸에 합쳐진다 (2 + 8)")
	assert_eq(inventory.get_slot(2), null, "새 칸을 쓰지 않는다")


func test_quick_move_to_full_side_fails() -> void:
	_fill(storage)
	inventory.try_add(_skull_stack())
	assert_eq(transfer.quick_move(inventory, 0, storage), ItemTransfer.Result.FULL, "창고가 가득 차면 옮겨지지 않음")
	assert_true(inventory.get_slot(0) != null, "인벤토리에 그대로")
	storage.remove_slot(0)
	_fill(inventory)
	storage.try_add(_skull_stack())
	assert_eq(transfer.quick_move(storage, 0, storage), ItemTransfer.Result.FULL, "인벤토리가 가득 차면 옮겨지지 않음")
	assert_true(storage.get_slot(0) != null, "창고에 그대로")


func test_quick_move_hidden_chest_slot_fails() -> void:
	var chest: ChestContents = ChestContents.new([_skull_stack(), ItemStack.of_item(bone, 2)] as Array[ItemStack], [1.0, 1.0] as Array[float])
	assert_eq(transfer.quick_move(chest.inventory, 0, chest.inventory), ItemTransfer.Result.LOCKED, "확인되지 않은 칸은 꺼낼 수 없음")
	assert_eq(inventory.get_slot(0), null)
	chest.advance(1.0)
	assert_eq(transfer.quick_move(chest.inventory, 0, chest.inventory), ItemTransfer.Result.OK, "확인된 칸은 꺼낼 수 있음")
	assert_true(inventory.get_slot(0) != null and inventory.get_slot(0).is_skull())
	inventory.try_add(ItemStack.of_item(other_item, 1))
	assert_eq(transfer.quick_move(inventory, 1, chest.inventory), ItemTransfer.Result.OK, "상자로 넣을 때는 확인된 칸(0번)에 들어감")
	assert_true(chest.inventory.get_slot(0) != null and chest.inventory.get_slot(0).item.id == other_item.id)
	assert_true(chest.inventory.is_locked(1), "확인되지 않은 칸은 그대로 잠김")


func test_quick_move_summoned_skull_fails() -> void:
	var stack: ItemStack = _skull_stack()
	inventory.try_add(stack)
	hotbar.assign(0, stack.skull)
	roster.summon(stack.skull)
	assert_eq(transfer.quick_move(inventory, 0, storage), ItemTransfer.Result.SUMMONED, "소환 중인 머리뼈는 못 옮김")
	assert_true(inventory.get_slot(0) == stack)
	assert_true(roster.is_summoned(stack.skull))


func test_quick_move_hotbar_skull_clears_hotbar() -> void:
	var stack: ItemStack = _skull_stack()
	inventory.try_add(stack)
	hotbar.assign(1, stack.skull)
	transfer.quick_move(inventory, 0, storage)
	assert_eq(hotbar.get_skull(1), null, "핫바에 올린 머리뼈를 옮기면 핫바 칸이 빈다")


func test_quick_move_with_only_inventory_open_does_nothing() -> void:
	inventory.try_add(_skull_stack())
	assert_eq(transfer.quick_move(inventory, 0, null), ItemTransfer.Result.INVALID, "인벤토리만 열려 있으면 아무것도 안 함")
	assert_true(inventory.get_slot(0) != null)
