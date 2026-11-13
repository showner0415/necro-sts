extends TestCase
## 인벤토리 우클릭 메뉴 항목(ItemAction) 단위 테스트.
## 아이템별 항목은 실제 .tres를, 실행은 여기서 만든 인벤토리·핫바·소환 목록으로 확인한다.

const BONE_PATH: String = "res://data/items/bone.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const MAX_HEALTH: float = 4.0
const BONE_COST: int = 4

var inventory: Inventory
var hotbar: Hotbar
var mana: ManaPool
var roster: UndeadRoster
var monster: MonsterData
var bone: ItemData
var skull_data: SkullData
## 바닥에 놓인 물건 (drop_to_ground로 받은 것)
var dropped: Array[ItemStack] = []


func before_each() -> void:
	inventory = Inventory.new(10)
	hotbar = Hotbar.new(2, inventory)
	mana = ManaPool.new(10.0, 0.0)
	bone = load(BONE_PATH)
	skull_data = load(RAT_SKULL_PATH)
	monster = MonsterData.new()
	monster.id = skull_data.source_monster_id
	monster.summon_bone_cost = BONE_COST
	monster.summon_mana_cost = 1.0
	# 언데드 체력은 몬스터 체력 × 배율이므로, 배율 1로 두고 몬스터 체력을 정한다.
	monster.max_health = MAX_HEALTH
	monster.undead_health_ratio_override = 1.0
	monster.undead_death_durability_loss = 3.0
	roster = UndeadRoster.new(inventory, hotbar, mana, bone.id, _find_monster, 1.0)


func _find_monster(id: StringName) -> MonsterData:
	return monster if id == monster.id else null


func _on_dropped(stack: ItemStack) -> void:
	dropped.append(stack)


## 그 칸을 대상으로 하는 실행 환경
func _context(slot_index: int) -> ItemActionContext:
	var context: ItemActionContext = ItemActionContext.new()
	context.inventory = inventory
	context.hotbar = hotbar
	context.roster = roster
	context.slot_index = slot_index
	context.drop_to_ground = _on_dropped
	return context


func _action(item: ItemData, id: StringName) -> ItemAction:
	for action: ItemAction in item.actions:
		if action.id == id:
			return action
	return null


func _ids(item: ItemData) -> Array[StringName]:
	var ids: Array[StringName] = []
	for action: ItemAction in item.actions:
		ids.append(action.id)
	return ids


## 그 칸의 메뉴에 실제로 보이는 항목 id (is_visible_in으로 거른 것).
func _visible_ids(slot_index: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	for action: ItemAction in inventory.get_slot(slot_index).item.actions:
		if action.is_visible_in(_context(slot_index)):
			ids.append(action.id)
	return ids


## 머리뼈를 넣고 칸 번호를 돌려준다.
func _add_skull() -> int:
	inventory.try_add(ItemStack.of_skull(Skull.create(skull_data)))
	return inventory.get_skulls().size() - 1


func _skull_at(index: int) -> Skull:
	return inventory.get_slot(index).skull


# --- 아이템별 항목 ---

func test_skull_menu_items() -> void:
	assert_eq(_ids(skull_data), [&"heal_skull", &"remove_bones", &"assign_hotbar", &"unassign_hotbar", &"drop"] as Array[StringName], "머리뼈: 회복하기, 뼈 제거, 핫바에 등록(또는 핫바에서 빼기), 버리기")


func test_bone_menu_items() -> void:
	assert_eq(_ids(bone), [&"drop"] as Array[StringName], "뼈: 버리기")


func test_labels() -> void:
	assert_eq(_action(skull_data, &"heal_skull").label, "회복하기")
	assert_eq(_action(skull_data, &"remove_bones").label, "뼈 제거")
	assert_eq(_action(skull_data, &"assign_hotbar").label, "핫바에 등록")
	assert_eq(_action(skull_data, &"unassign_hotbar").label, "핫바에서 빼기")
	assert_eq(_action(bone, &"drop").label, "버리기")


# --- 회색 처리 ---

func test_heal_gray_when_full_or_never_summoned() -> void:
	var index: int = _add_skull()
	inventory.try_add(ItemStack.of_item(bone, BONE_COST))
	var state: ItemActionState = _action(skull_data, &"heal_skull").get_state(_context(index))
	assert_false(state.enabled, "처음 소환 전에는 체력이 가득")
	assert_eq(state.reason, "체력 가득")


func test_heal_gray_while_summoned() -> void:
	var index: int = _add_skull()
	inventory.try_add(ItemStack.of_item(bone, BONE_COST))
	hotbar.assign(0, _skull_at(index))
	roster.summon(_skull_at(index))
	roster.damage(_skull_at(index), 1.0)
	var state: ItemActionState = _action(skull_data, &"heal_skull").get_state(_context(index))
	assert_false(state.enabled)
	assert_eq(state.reason, "소환 중")


func test_heal_gray_without_bones() -> void:
	var index: int = _add_skull()
	inventory.try_add(ItemStack.of_item(bone, BONE_COST))
	hotbar.assign(0, _skull_at(index))
	roster.summon(_skull_at(index))
	roster.damage(_skull_at(index), 1.0)
	roster.unsummon(_skull_at(index))
	var state: ItemActionState = _action(skull_data, &"heal_skull").get_state(_context(index))
	assert_false(state.enabled, "처음 소환에 뼈를 다 써서 없음")
	assert_eq(state.reason, "뼈 부족")


func test_hotbar_item_switches_to_unassign_when_in_hotbar() -> void:
	var index: int = _add_skull()
	assert_eq(_visible_ids(index), [&"heal_skull", &"remove_bones", &"assign_hotbar", &"drop"] as Array[StringName], "핫바에 없으면 '핫바에 등록'")
	hotbar.assign(1, _skull_at(index))
	assert_eq(_visible_ids(index), [&"heal_skull", &"remove_bones", &"unassign_hotbar", &"drop"] as Array[StringName], "핫바에 있으면 같은 자리에 '핫바에서 빼기'")


func test_unassign_removes_from_hotbar_only() -> void:
	var index: int = _add_skull()
	var skull: Skull = _skull_at(index)
	hotbar.assign(1, skull)
	var action: ItemAction = _action(skull_data, &"unassign_hotbar")
	assert_eq(action.get_state(_context(index)).warning, "", "소환 중이 아니면 경고 없음")
	assert_true(action.execute(_context(index)))
	assert_eq(hotbar.get_skull(1), null, "핫바 칸이 빈다")
	assert_true(_skull_at(index) == skull, "머리뼈는 인벤토리에 그대로")
	assert_false(action.execute(_context(index)), "핫바에 없으면 실행 안 됨")


func test_unassign_summoned_warns_and_unsummons() -> void:
	var index: int = _add_skull()
	inventory.try_add(ItemStack.of_item(bone, BONE_COST))
	var skull: Skull = _skull_at(index)
	hotbar.assign(0, skull)
	roster.summon(skull)
	var action: ItemAction = _action(skull_data, &"unassign_hotbar")
	var state: ItemActionState = action.get_state(_context(index))
	assert_true(state.enabled)
	assert_eq(state.warning, "소환이 해제됩니다")
	assert_eq(state.warning_kind, ItemActionState.WarningKind.CAUTION, "되돌릴 수 있으니 노란 경고")
	var durability: float = skull.durability
	assert_true(action.execute(_context(index)))
	assert_false(roster.is_summoned(skull), "핫바에서 빠지면 일반 해제")
	assert_eq(skull.durability, durability, "죽은 판정이 아니라 내구도 그대로")


func test_drop_warns_only_when_summoned() -> void:
	var index: int = _add_skull()
	inventory.try_add(ItemStack.of_item(bone, BONE_COST))
	var action: ItemAction = _action(skull_data, &"drop")
	assert_eq(action.get_state(_context(index)).warning, "", "소환 중이 아니면 경고 없음")
	hotbar.assign(0, _skull_at(index))
	roster.summon(_skull_at(index))
	var state: ItemActionState = action.get_state(_context(index))
	assert_true(state.enabled, "소환 중이어도 버릴 수는 있다")
	assert_eq(state.warning, "죽은 판정이 됩니다")
	assert_eq(state.warning_kind, ItemActionState.WarningKind.LOSS, "되돌릴 수 없는 손해라 빨간 경고")


# --- 실행 ---

func test_drop_via_menu() -> void:
	inventory.try_add(ItemStack.of_item(bone, 7))
	assert_true(_action(bone, &"drop").execute(_context(0)))
	assert_eq(inventory.get_slot(0), null, "칸이 빈다")
	assert_eq(dropped.size(), 1, "바닥에 놓인다")
	assert_eq(dropped[0].count, 7, "통째로")


func test_drop_summoned_skull_via_menu_is_death() -> void:
	var index: int = _add_skull()
	inventory.try_add(ItemStack.of_item(bone, BONE_COST))
	var skull: Skull = _skull_at(index)
	hotbar.assign(0, skull)
	roster.summon(skull)
	_action(skull_data, &"drop").execute(_context(index))
	assert_false(roster.is_summoned(skull))
	assert_eq(skull.durability, skull_data.max_durability - monster.undead_death_durability_loss, "죽은 판정으로 내구도가 준다")
	assert_true(dropped[0].skull == skull)


func test_heal_via_menu_uses_same_rule() -> void:
	var index: int = _add_skull()
	inventory.try_add(ItemStack.of_item(bone, BONE_COST + 5))
	var skull: Skull = _skull_at(index)
	hotbar.assign(0, skull)
	roster.summon(skull)
	roster.damage(skull, 2.0)
	roster.unsummon(skull)
	var context: ItemActionContext = _context(index)
	assert_true(_action(skull_data, &"heal_skull").get_state(context).enabled)
	assert_true(_action(skull_data, &"heal_skull").execute(context))
	assert_eq(skull.health, MAX_HEALTH)
	assert_eq(inventory.get_count(bone.id), 5 - 2, "4 × (2/4) = 2개")


func test_assign_via_menu_uses_empty_slot_then_selected() -> void:
	var first: int = _add_skull()
	var second: int = _add_skull()
	var third: int = _add_skull()
	var action: ItemAction = _action(skull_data, &"assign_hotbar")
	action.execute(_context(first))
	action.execute(_context(second))
	assert_true(hotbar.get_skull(0) == _skull_at(first), "가장 앞의 빈 칸")
	assert_true(hotbar.get_skull(1) == _skull_at(second))
	hotbar.select(1)
	assert_true(action.execute(_context(third)))
	assert_true(hotbar.get_skull(1) == _skull_at(third), "빈 칸이 없으면 선택된 칸을 바꾼다")
	assert_true(hotbar.get_skull(0) == _skull_at(first))


func test_unavailable_action_does_nothing() -> void:
	var index: int = _add_skull()
	assert_false(_action(skull_data, &"heal_skull").execute(_context(index)), "체력 가득이면 실행 안 됨")
	hotbar.assign(0, _skull_at(index))
	assert_false(_action(skull_data, &"assign_hotbar").execute(_context(index)))


# --- 뼈 제거 ---

## 소환했다가 damage만큼 다친 뒤 해제한 머리뼈의 칸 번호. 처음 소환 뼈는 테스트 안에서 주고, 남은 뼈는 extra_bones개.
func _add_used_skull(damage: float, extra_bones: int) -> int:
	var index: int = _add_skull()
	inventory.try_add(ItemStack.of_item(bone, BONE_COST + extra_bones))
	var skull: Skull = _skull_at(index)
	hotbar.assign(0, skull)
	roster.summon(skull)
	if damage > 0.0:
		roster.damage(skull, damage)
	roster.unsummon(skull)
	return index


func test_remove_bones_returns_bones_for_current_health() -> void:
	var index: int = _add_used_skull(0.0, 0)
	var skull: Skull = _skull_at(index)
	var durability: float = skull.durability
	var action: ItemAction = _action(skull_data, &"remove_bones")
	var state: ItemActionState = action.get_state(_context(index))
	assert_true(state.enabled, "체력 가득인 해제된 머리뼈")
	assert_eq(state.label, "뼈 제거 (4개)", "돌려받을 개수를 이름에 붙임")
	assert_true(action.execute(_context(index)))
	assert_eq(inventory.get_count(bone.id), BONE_COST, "처음 소환에 쓴 뼈가 그대로 돌아옴")
	assert_false(skull.awakened, "처음 소환 전 상태")
	assert_eq(skull.health, 0.0)
	assert_eq(skull.durability, durability, "내구도는 그대로")
	assert_true(inventory.get_skulls().has(skull), "머리뼈는 인벤토리에 남음")


func test_remove_bones_rounds_down_damaged_health() -> void:
	# 체력 4, 뼈 4개 → 뼈 하나당 체력 1. 1.5 다치면 2.5 → 2개.
	var index: int = _add_used_skull(1.5, 0)
	assert_eq(roster.get_stored_bones(_skull_at(index)), 2, "다친 만큼은 돌아오지 않고, 소수는 버림")
	_action(skull_data, &"remove_bones").execute(_context(index))
	assert_eq(inventory.get_count(bone.id), 2)


func test_remove_bones_after_heal_does_not_create_bones() -> void:
	var index: int = _add_used_skull(2.0, 2)
	var skull: Skull = _skull_at(index)
	_action(skull_data, &"heal_skull").execute(_context(index))
	assert_eq(inventory.get_count(bone.id), 0, "회복에 2개 씀")
	_action(skull_data, &"remove_bones").execute(_context(index))
	assert_eq(inventory.get_count(bone.id), BONE_COST, "회복해도 최대 체력만큼(처음 소환 비용)만 돌아옴")
	assert_false(skull.awakened)


func test_remove_bones_merges_into_bone_slot() -> void:
	var index: int = _add_used_skull(0.0, 3)
	var before_slots: int = 0
	for i: int in inventory.get_slot_count():
		if inventory.get_slot(i) != null:
			before_slots += 1
	_action(skull_data, &"remove_bones").execute(_context(index))
	var after_slots: int = 0
	for i: int in inventory.get_slot_count():
		if inventory.get_slot(i) != null:
			after_slots += 1
	assert_eq(inventory.get_count(bone.id), 3 + BONE_COST, "있던 뼈 칸에 합쳐짐")
	assert_eq(after_slots, before_slots, "새 칸을 쓰지 않음")


func test_remove_bones_gray_states() -> void:
	var action: ItemAction = _action(skull_data, &"remove_bones")
	var fresh: int = _add_skull()
	var state: ItemActionState = action.get_state(_context(fresh))
	assert_false(state.enabled, "처음 소환 전에는 뺄 뼈가 없음")
	assert_eq(state.reason, "뼈 없음")
	assert_false(action.execute(_context(fresh)))

	var summoned: int = _add_used_skull(0.0, 0)
	inventory.try_add(ItemStack.of_item(bone, 1))
	roster.summon(_skull_at(summoned))
	state = action.get_state(_context(summoned))
	assert_false(state.enabled)
	assert_eq(state.reason, "소환 중")
	roster.unsummon(_skull_at(summoned))

	# 죽은 판정으로 체력 0
	hotbar.assign(0, _skull_at(summoned))
	roster.summon(_skull_at(summoned))
	roster.damage(_skull_at(summoned), MAX_HEALTH)
	state = action.get_state(_context(summoned))
	assert_false(state.enabled, "체력 0이면 뺄 뼈가 없음")
	assert_eq(state.reason, "뼈 없음")


func test_remove_bones_gray_when_inventory_full() -> void:
	var index: int = _add_used_skull(0.0, 0)
	# 처음 소환에 뼈를 다 써서 뼈 칸이 없다. 나머지 칸을 머리뼈로 채운다.
	while inventory.can_add(ItemStack.of_skull(Skull.create(skull_data))):
		inventory.try_add(ItemStack.of_skull(Skull.create(skull_data)))
	var skull: Skull = _skull_at(index)
	var state: ItemActionState = _action(skull_data, &"remove_bones").get_state(_context(index))
	assert_false(state.enabled)
	assert_eq(state.reason, "인벤토리 가득 참")
	assert_false(_action(skull_data, &"remove_bones").execute(_context(index)))
	assert_true(skull.awakened, "그대로")

