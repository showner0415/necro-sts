extends TestCase
## 지역 상자 단위 테스트: ChestContents(하나씩 드러나기, 희귀도별 시간, 닫았다 다시 열었을 때),
## 잠긴 칸과 가져가기(ItemTransfer), 인벤토리 가득, 상자 거리(LootChest), 메뉴 이름(TransferItemAction).

const BONE_PATH: String = "res://data/items/bone.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BOAR_SKULL_PATH: String = "res://data/skulls/boar_skull.tres"
const RARITY_DIR: String = "res://data/rarities/"
const EPS: float = 0.0001

var bone: ItemData
var rat_skull: SkullData
var inventory: Inventory
var transfer: ItemTransfer


func before_each() -> void:
	bone = load(BONE_PATH)
	rat_skull = load(RAT_SKULL_PATH)
	inventory = Inventory.new(3)
	inventory.display_name = "인벤토리"
	transfer = ItemTransfer.new(inventory, null)


func _rarity(id: String) -> RarityData:
	return load(RARITY_DIR + id + ".tres")


## 뼈 3개, 빈 칸, 쥐 머리뼈 순서의 상자 (드러나는 시간 1, 1, 2.5초)
func _make_chest() -> ChestContents:
	var stacks: Array[ItemStack] = [ItemStack.of_item(bone, 3), null, ItemStack.of_skull(Skull.create(rat_skull))]
	var times: Array[float] = [1.0, 1.0, 2.5]
	return ChestContents.new(stacks, times)


# --- 하나씩 드러나기 ---

func test_all_hidden_at_start() -> void:
	var chest: ChestContents = _make_chest()
	for i: int in 3:
		assert_false(chest.is_revealed(i), "처음에는 %d번 칸이 무엇인지 모른다" % i)
	assert_eq(chest.get_revealing_index(), 0, "앞 칸부터")
	assert_eq(chest.inventory.display_name, "상자")


func test_reveals_one_at_a_time_in_order() -> void:
	var chest: ChestContents = _make_chest()
	chest.advance(0.5)
	assert_false(chest.is_revealed(0), "1초 전에는 아직")
	assert_almost_eq(chest.get_reveal_progress(), 0.5, EPS, "진행 비율")
	chest.advance(0.5)
	assert_true(chest.is_revealed(0), "1초가 지나면 첫 칸이 드러난다")
	assert_false(chest.is_revealed(1), "다음 칸은 그때부터 다시 잰다")
	assert_eq(chest.get_revealing_index(), 1)
	chest.advance(1.0)
	assert_true(chest.is_revealed(1), "빈 칸도 시간이 지나야 빈 칸인 줄 안다")
	chest.advance(2.4)
	assert_false(chest.is_revealed(2))
	chest.advance(0.1)
	assert_true(chest.is_revealed(2))
	assert_true(chest.is_all_revealed())
	assert_eq(chest.get_revealing_index(), -1)


func test_large_step_reveals_several_with_carry_over() -> void:
	var chest: ChestContents = _make_chest()
	chest.advance(2.5)
	assert_true(chest.is_revealed(0) and chest.is_revealed(1), "한 번에 여러 칸이 지나가면 차례로 모두 드러난다")
	assert_almost_eq(chest.get_reveal_progress(), 0.5 / 2.5, EPS, "남은 시간은 다음 칸으로 넘어간다")


# --- 희귀도별 시간 ---

func test_rarity_reveal_times() -> void:
	assert_eq(_rarity("common").reveal_time, 1.0, "흔함")
	assert_eq(_rarity("uncommon").reveal_time, 2.5, "고급")
	assert_eq(_rarity("rare").reveal_time, 5.0, "희귀")
	assert_eq(_rarity("legendary").reveal_time, 7.5, "전설")


func test_roll_uses_item_rarity_and_empty_rarity() -> void:
	var data: ChestData = ChestData.new()
	data.slot_count = 4
	data.empty_rarity = _rarity("common")
	var entry: ChestLootEntry = ChestLootEntry.new()
	entry.item = load(BOAR_SKULL_PATH)
	data.entries = [entry]
	var chest: ChestContents = ChestContents.roll(data)
	assert_eq(chest.reveal_times, [5.0, 5.0, 5.0, 5.0] as Array[float], "멧돼지 머리뼈(희귀)는 5초")
	var empty: ChestLootEntry = ChestLootEntry.new()
	data.entries = [empty]
	chest = ChestContents.roll(data)
	assert_eq(chest.inventory.get_slot(0), null, "빈 칸 항목")
	assert_eq(chest.reveal_times[0], 1.0, "빈 칸은 상자 데이터의 빈 칸 희귀도(흔함) 시간")


func test_roll_bone_count_in_range() -> void:
	var data: ChestData = ChestData.new()
	data.slot_count = 20
	var entry: ChestLootEntry = ChestLootEntry.new()
	entry.item = bone
	entry.min_count = 2
	entry.max_count = 4
	data.entries = [entry]
	var chest: ChestContents = ChestContents.roll(data)
	for i: int in 20:
		var count: int = chest.inventory.get_slot(i).count
		assert_true(count >= 2 and count <= 4, "뼈 %d개가 2~4 안" % count)
		assert_eq(chest.reveal_times[i], 1.0, "뼈는 흔함")


# --- 닫았다 다시 열기 ---

func test_progress_pauses_and_revealed_stays() -> void:
	var chest: ChestContents = _make_chest()
	chest.advance(1.4)
	# 창을 닫은 동안에는 지역 씬이 advance를 부르지 않는다. 다시 열었을 때 그대로인지 본다.
	assert_true(chest.is_revealed(0), "드러난 칸은 그대로")
	assert_almost_eq(chest.get_reveal_progress(), 0.4, EPS, "진행 중이던 칸도 멈춘 자리 그대로")
	chest.advance(0.6)
	assert_true(chest.is_revealed(1), "다시 열면 이어서 진행")


# --- 가져가기 ---

func test_hidden_slot_cannot_be_taken_or_filled() -> void:
	var chest: ChestContents = _make_chest()
	assert_eq(transfer.move(chest.inventory, 0, inventory, 0), ItemTransfer.Result.LOCKED, "드러나기 전에는 꺼낼 수 없다")
	assert_eq(transfer.check_send(chest.inventory, 0, inventory), ItemTransfer.Result.LOCKED, "메뉴로 보내기도 안 된다")
	inventory.try_add(ItemStack.of_item(bone, 1))
	assert_eq(transfer.move(inventory, 0, chest.inventory, 1), ItemTransfer.Result.LOCKED, "드러나지 않은 칸에 넣을 수 없다")
	assert_eq(chest.inventory.get_slot(0).count, 3, "상자 그대로")


func test_take_revealed_by_drag_and_by_menu() -> void:
	var chest: ChestContents = _make_chest()
	chest.advance(4.5)
	assert_eq(transfer.move(chest.inventory, 0, inventory, 1), ItemTransfer.Result.OK, "드러난 칸은 끌어서 가져간다")
	assert_eq(inventory.get_slot(1).count, 3)
	assert_eq(chest.inventory.get_slot(0), null)
	assert_eq(transfer.send(chest.inventory, 2, inventory), ItemTransfer.Result.OK, "메뉴(인벤토리로 옮기기)로도 가져간다")
	assert_true(inventory.get_skulls().size() == 1)


func test_put_into_revealed_slot_only() -> void:
	var chest: ChestContents = _make_chest()
	chest.advance(2.0)
	inventory.try_add(ItemStack.of_item(bone, 2))
	assert_eq(transfer.send(inventory, 0, chest.inventory), ItemTransfer.Result.OK, "창고처럼 상자에 넣을 수도 있다")
	assert_eq(chest.inventory.get_slot(0).count, 5, "드러난 같은 종류 뼈 칸에 합친다")
	assert_true(chest.inventory.is_locked(2), "잠긴 칸은 건드리지 않는다")


func test_inventory_full() -> void:
	var chest: ChestContents = _make_chest()
	chest.advance(4.5)
	for i: int in 3:
		inventory.try_add(ItemStack.of_skull(Skull.create(rat_skull)))
	assert_eq(transfer.check_send(chest.inventory, 2, inventory), ItemTransfer.Result.FULL, "인벤토리 가득")
	var action: TransferItemAction = load("res://data/item_actions/send_to_inventory.tres")
	var context: ItemActionContext = ItemActionContext.new()
	context.inventory = inventory
	context.container = chest.inventory
	context.storage = chest.inventory
	context.transfer = transfer
	context.slot_index = 2
	var state: ItemActionState = action.get_state(context)
	assert_false(state.enabled)
	assert_eq(state.reason, "인벤토리 가득 참", "메뉴에 이유")
	assert_eq(state.label, "인벤토리로 옮기기")


func test_menu_label_uses_chest_name() -> void:
	var chest: ChestContents = _make_chest()
	inventory.try_add(ItemStack.of_item(bone, 1))
	var action: TransferItemAction = load("res://data/item_actions/send_to_storage.tres")
	var context: ItemActionContext = ItemActionContext.new()
	context.inventory = inventory
	context.container = inventory
	context.storage = chest.inventory
	context.transfer = transfer
	context.slot_index = 0
	assert_eq(action.get_state(context).label, "상자로 옮기기", "열린 것이 상자면 '상자로 옮기기'")


# --- 거리 ---

func test_open_range() -> void:
	var chest: LootChest = LootChest.new()
	chest.open_distance = 48.0
	chest.position = Vector2(100, 0)
	assert_true(chest.is_in_open_range(Vector2(100 + 48, 0)), "48 안이면 열려 있다")
	assert_false(chest.is_in_open_range(Vector2(100 + 49, 0)), "벗어나면 닫힌다")
	chest.free()
