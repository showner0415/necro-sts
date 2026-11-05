extends TestCase
## UndeadRoster(소환 규칙) 단위 테스트. 몬스터 데이터는 실제 .tres 대신 여기서 만든다.

const MAX_HEALTH: float = 4.0
const BONE_COST: int = 4
const SUMMON_MANA: float = 3.0
const DEATH_LOSS: float = 3.0
const HIT_LOSS: float = 1.0
const UPKEEP: float = 0.5
const MAX_MANA: float = 10.0
const MAX_DURABILITY: float = 10.0

var inventory: Inventory
var hotbar: Hotbar
var mana: ManaPool
var roster: UndeadRoster
var bone: ItemData
var monster: MonsterData
var skull_data: SkullData
var events: Array[String] = []


func before_each() -> void:
	inventory = Inventory.new(10)
	hotbar = Hotbar.new(2, inventory)
	mana = ManaPool.new(MAX_MANA, 0.0)
	bone = ItemData.new()
	bone.id = &"test_bone"
	monster = MonsterData.new()
	monster.id = &"test_rat"
	monster.summon_bone_cost = BONE_COST
	monster.summon_mana_cost = SUMMON_MANA
	monster.undead_death_durability_loss = DEATH_LOSS
	monster.undead_max_health = MAX_HEALTH
	skull_data = SkullData.new()
	skull_data.id = &"test_rat_skull"
	skull_data.source_monster_id = monster.id
	skull_data.max_durability = MAX_DURABILITY
	roster = UndeadRoster.new(inventory, hotbar, mana, bone.id, _find_monster, HIT_LOSS, UPKEEP)
	roster.summoned.connect(func(s: Skull) -> void: events.append("소환 %d" % hotbar.find_slot(s)))
	roster.unsummoned.connect(func(_s: Skull, died: bool) -> void: events.append("죽음" if died else "해제"))


## 시그널에 연결한 람다가 이 테스트(self)를 붙잡고 있어서, 끊지 않으면 서로를 놓지 못해 새어 나간다.
func after_each() -> void:
	for signal_name: StringName in [&"summoned", &"unsummoned"]:
		for connection: Dictionary in roster.get_signal_connection_list(signal_name):
			roster.disconnect(signal_name, connection.callable)


func _find_monster(id: StringName) -> MonsterData:
	return monster if id == monster.id else null


func _add_bones(count: int) -> void:
	inventory.try_add(ItemStack.of_item(bone, count))


## 머리뼈를 인벤토리에 넣고 핫바 칸에 놓는다.
func _add_skull(hotbar_index: int) -> Skull:
	var skull: Skull = Skull.create(skull_data)
	inventory.try_add(ItemStack.of_skull(skull))
	hotbar.assign(hotbar_index, skull)
	return skull


func _drop_slot_of(skull: Skull) -> void:
	for i: int in inventory.get_slot_count():
		var stack: ItemStack = inventory.get_slot(i)
		if stack != null and stack.skull == skull:
			inventory.remove_slot(i)
			return


# --- 처음 소환 ---

func test_first_summon_uses_bones_and_mana_and_fills_health() -> void:
	_add_bones(6)
	var skull: Skull = _add_skull(0)
	assert_eq(roster.summon(skull), UndeadRoster.Result.OK)
	assert_true(roster.is_summoned(skull))
	assert_eq(inventory.get_count(bone.id), 6 - BONE_COST, "처음 소환 비용만큼 뼈를 쓴다")
	assert_eq(mana.current, MAX_MANA - SUMMON_MANA, "소환 마나를 쓴다")
	assert_true(skull.awakened)
	assert_eq(skull.health, MAX_HEALTH, "체력이 가득 찬다")


func test_first_summon_without_enough_bones_fails() -> void:
	_add_bones(BONE_COST - 1)
	var skull: Skull = _add_skull(0)
	assert_eq(roster.summon(skull), UndeadRoster.Result.NOT_ENOUGH_BONES)
	assert_false(roster.is_summoned(skull))
	assert_eq(inventory.get_count(bone.id), BONE_COST - 1, "뼈는 쓰지 않는다")
	assert_eq(mana.current, MAX_MANA, "마나도 쓰지 않는다")


func test_second_summon_does_not_use_bones() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	roster.unsummon(skull)
	assert_eq(roster.summon(skull), UndeadRoster.Result.OK, "뼈가 없어도 다시 소환된다")
	assert_eq(mana.current, MAX_MANA - SUMMON_MANA * 2, "마나는 소환마다 쓴다")


func test_not_enough_mana_fails() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	mana.try_spend(MAX_MANA - SUMMON_MANA + 1.0)
	assert_eq(roster.summon(skull), UndeadRoster.Result.NOT_ENOUGH_MANA)
	assert_eq(inventory.get_count(bone.id), BONE_COST, "뼈를 쓰지 않는다")
	assert_false(skull.awakened)


func test_skull_must_be_in_hotbar() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	hotbar.clear_slot(0)
	assert_eq(roster.summon(skull), UndeadRoster.Result.NO_SKULL)


func test_toggle() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	roster.toggle(skull)
	assert_true(roster.is_summoned(skull), "한 번 누르면 소환")
	roster.toggle(skull)
	assert_false(roster.is_summoned(skull), "다시 누르면 해제")
	assert_eq(events, ["소환 0", "해제"] as Array[String])


# --- 여러 마리 ---

func test_multiple_summons_at_once() -> void:
	_add_bones(BONE_COST * 2)
	var first: Skull = _add_skull(0)
	var second: Skull = _add_skull(1)
	assert_eq(roster.summon(first), UndeadRoster.Result.OK)
	assert_eq(roster.summon(second), UndeadRoster.Result.OK)
	assert_eq(roster.get_count(), 2, "두 마리가 동시에 소환된다")
	assert_eq(roster.summon(first), UndeadRoster.Result.SUMMONED, "머리뼈 하나로는 한 마리")
	assert_eq(roster.get_count(), 2)


func test_upkeep_drains_per_undead() -> void:
	_add_bones(BONE_COST * 2)
	roster.summon(_add_skull(0))
	roster.summon(_add_skull(1))
	var before: float = mana.current
	roster.process(1.0)
	assert_almost_eq(mana.current, before - UPKEEP * 2, 0.0001, "두 마리면 초당 유지 마나 × 2")


# --- 체력 저장 ---

func test_health_is_stored_in_skull_after_unsummon() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	roster.damage(skull, 1.5)
	roster.unsummon(skull)
	assert_eq(skull.health, MAX_HEALTH - 1.5, "해제해도 체력이 머리뼈에 남는다")
	roster.summon(skull)
	assert_eq(skull.health, MAX_HEALTH - 1.5, "다시 소환해도 다친 체력 그대로")


func test_health_does_not_regenerate_over_time() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	roster.damage(skull, 1.0)
	roster.unsummon(skull)
	roster.process(10.0)
	assert_eq(skull.health, MAX_HEALTH - 1.0, "저절로 차지 않는다")


func test_cannot_summon_with_zero_health() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	roster.damage(skull, MAX_HEALTH)
	assert_eq(roster.summon(skull), UndeadRoster.Result.NO_HEALTH)


# --- 내구도 ---

func test_each_hit_reduces_durability_by_one() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	roster.damage(skull, 0.5)
	assert_eq(skull.durability, MAX_DURABILITY - HIT_LOSS)
	roster.damage(skull, 0.5)
	assert_eq(skull.durability, MAX_DURABILITY - HIT_LOSS * 2, "피해량과 상관없이 한 번에 1")


func test_death_reduces_durability_by_monster_value_only() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	roster.damage(skull, MAX_HEALTH)
	assert_false(roster.is_summoned(skull), "죽으면 사라진다")
	assert_eq(skull.health, 0.0)
	assert_eq(skull.durability, MAX_DURABILITY - DEATH_LOSS, "죽는 일격은 1을 따로 깎지 않고 3만")
	assert_eq(events.back(), "죽음")


func test_broken_skull_cannot_summon() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	skull.durability = 0.0
	assert_eq(roster.summon(skull), UndeadRoster.Result.BROKEN)
	assert_eq(inventory.get_skulls().size(), 1, "파괴되지 않는다")


func test_durability_zero_while_summoned_unsummons() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	skull.durability = HIT_LOSS
	roster.damage(skull, 0.5)
	assert_false(roster.is_summoned(skull))
	assert_eq(events.back(), "해제", "죽은 판정이 아니라 일반 해제")
	assert_eq(skull.health, MAX_HEALTH - 0.5, "체력은 남는다")


# --- 버리기·핫바·마나 ---

func test_dropping_summoned_skull_is_death() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	_drop_slot_of(skull)
	assert_false(roster.is_summoned(skull))
	assert_eq(events.back(), "죽음", "버리면 죽은 판정")
	assert_eq(skull.durability, MAX_DURABILITY - DEATH_LOSS)


func test_removing_from_hotbar_is_normal_unsummon() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	hotbar.clear_slot(0)
	assert_false(roster.is_summoned(skull))
	assert_eq(events.back(), "해제")
	assert_eq(skull.durability, MAX_DURABILITY, "내구도는 그대로")


func test_moving_between_hotbar_slots_keeps_summon() -> void:
	_add_bones(BONE_COST)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	hotbar.swap(0, 1)
	inventory.move_slot(1, 5)
	assert_true(roster.is_summoned(skull), "핫바·인벤토리 안에서 옮기기만 하면 그대로")


func test_mana_zero_unsummons_all_normally() -> void:
	_add_bones(BONE_COST * 2)
	var first: Skull = _add_skull(0)
	var second: Skull = _add_skull(1)
	roster.summon(first)
	roster.summon(second)
	events.clear()
	roster.process(100.0)
	assert_eq(mana.current, 0.0)
	assert_eq(roster.get_count(), 0, "마나가 0이 되면 전부 해제")
	assert_eq(events, ["해제", "해제"] as Array[String], "일반 해제")
	assert_eq(first.durability, MAX_DURABILITY)
	assert_eq(first.health, MAX_HEALTH)


# --- 회복 ---

func test_heal_uses_bones_by_missing_ratio() -> void:
	_add_bones(BONE_COST + 10)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	roster.damage(skull, 1.0)
	roster.unsummon(skull)
	assert_eq(roster.get_heal_bone_cost(skull), 1, "4 × (1/4) = 1")
	assert_eq(roster.heal(skull), UndeadRoster.Result.OK)
	assert_eq(skull.health, MAX_HEALTH)
	assert_eq(inventory.get_count(bone.id), 10 - 1)


func test_heal_after_death_costs_first_cost() -> void:
	_add_bones(BONE_COST * 2)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	roster.damage(skull, MAX_HEALTH)
	assert_eq(roster.get_heal_bone_cost(skull), BONE_COST)
	roster.heal(skull)
	assert_eq(skull.health, MAX_HEALTH)
	assert_eq(inventory.get_count(bone.id), 0)


func test_heal_with_not_enough_bones_is_partial() -> void:
	_add_bones(BONE_COST + 2)
	var skull: Skull = _add_skull(0)
	roster.summon(skull)
	roster.damage(skull, MAX_HEALTH)
	assert_eq(roster.heal(skull), UndeadRoster.Result.OK)
	assert_almost_eq(skull.health, MAX_HEALTH / BONE_COST * 2, 0.0001, "뼈 2개만큼만 회복")
	assert_eq(inventory.get_count(bone.id), 0, "가진 뼈를 다 쓴다")
	assert_eq(roster.heal(skull), UndeadRoster.Result.NO_BONES, "뼈가 없으면 회복 안 됨")


func test_cannot_heal_while_summoned_or_full_or_unawakened() -> void:
	_add_bones(BONE_COST + 5)
	var skull: Skull = _add_skull(0)
	assert_eq(roster.heal(skull), UndeadRoster.Result.NOT_AWAKENED)
	roster.summon(skull)
	assert_eq(roster.get_heal_bone_cost(skull), 0)
	roster.damage(skull, 1.0)
	assert_eq(roster.heal(skull), UndeadRoster.Result.SUMMONED, "소환 중에는 회복 불가")
	roster.unsummon(skull)
	roster.heal(skull)
	assert_eq(roster.heal(skull), UndeadRoster.Result.FULL_HEALTH)
