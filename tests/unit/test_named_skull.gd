extends TestCase
## 네임드 머리뼈 (계획 6b) 단위 테스트: Skull의 네임드 이름, CorpseLoot의 일반 머리뼈 대신 넣기, MonsterData의 네임드 언데드 능력치와 드랍 머리뼈.

const RAT_PATH: String = "res://data/monsters/rat.tres"
const TOLERANCE: float = 0.001

var bone: ItemData
var skull_data: SkullData


func before_each() -> void:
	bone = ItemData.new()
	bone.id = &"test_bone"
	skull_data = SkullData.new()
	skull_data.id = &"test_skull"
	skull_data.display_name = "쥐의 머리뼈"
	skull_data.max_durability = 10.0


func _entry(item: ItemData, count: int) -> DropEntry:
	var entry: DropEntry = DropEntry.new()
	entry.item = item
	entry.count = count
	return entry


func test_named_display_name() -> void:
	var named: Skull = Skull.create_named(skull_data, "쥐", "그레카")
	assert_true(named.is_named())
	assert_eq(named.get_display_name(), "쥐 그레카의 머리뼈")
	assert_eq(named.durability, skull_data.max_durability, "내구도는 일반 머리뼈와 같이 가득")
	var plain: Skull = Skull.create(skull_data)
	assert_false(plain.is_named())
	assert_eq(plain.get_display_name(), "쥐의 머리뼈", "일반 머리뼈 이름은 그대로")


func test_named_replaces_normal_skull_keeps_bones() -> void:
	var named: Skull = Skull.create_named(skull_data, "쥐", "그레카")
	var loot: CorpseLoot = CorpseLoot.from_drops([_entry(bone, 2), _entry(skull_data, 1)], 1.0, named)
	var stacks: Array[ItemStack] = loot.get_stacks()
	var skulls: Array[ItemStack] = stacks.filter(func(s: ItemStack) -> bool: return s.is_skull())
	assert_eq(skulls.size(), 1, "머리뼈는 네임드 하나뿐")
	assert_eq(skulls[0].skull, named)
	assert_eq(stacks.filter(func(s: ItemStack) -> bool: return not s.is_skull() and s.count == 2).size(), 1, "뼈 2개는 그대로")


func test_named_appears_even_without_normal_skull_roll() -> void:
	var named: Skull = Skull.create_named(skull_data, "쥐", "그레카")
	var loot: CorpseLoot = CorpseLoot.from_drops([_entry(bone, 1)], 1.0, named)
	assert_eq(loot.get_stacks().filter(func(s: ItemStack) -> bool: return s.is_skull()).size(), 1, "일반 머리뼈가 안 나왔어도 네임드는 나온다")


func test_without_named_loot_is_unchanged() -> void:
	var loot: CorpseLoot = CorpseLoot.from_drops([_entry(bone, 1), _entry(skull_data, 1)], 1.0)
	var skulls: Array[ItemStack] = loot.get_stacks().filter(func(s: ItemStack) -> bool: return s.is_skull())
	assert_eq(skulls.size(), 1)
	assert_false(skulls[0].skull.is_named(), "네임드가 없으면 일반 머리뼈")


func test_named_undead_stats_use_named_ratio_on_original() -> void:
	var rat: MonsterData = load(RAT_PATH)
	var rules: UndeadStatRules = MonsterData.get_undead_rules()
	assert_almost_eq(rat.get_undead_max_health(true), rat.max_health * rules.named_health_ratio, TOLERANCE, "네임드 체력 = 원래 체력 × 네임드 배율")
	assert_almost_eq(rat.get_undead_max_health(false), rat.undead_max_health, TOLERANCE, "일반은 그대로")
	assert_almost_eq(rat.get_undead_stats(true).contact_damage, rat.contact_damage * rules.named_damage_ratio, TOLERANCE, "네임드 공격력 = 원래 공격력 × 네임드 배율")
	assert_almost_eq(rat.get_undead_stats(false).contact_damage, rat.undead_contact_damage, TOLERANCE, "일반은 그대로")
	assert_eq(rat.get_undead_stats(true).move_speed, rat.get_undead_stats(false).move_speed, "속도는 그대로")


func test_drop_skull_is_first_skull_in_drops() -> void:
	var monster: MonsterData = MonsterData.new()
	monster.drops = [_entry(bone, 1), _entry(skull_data, 1)]
	assert_eq(monster.get_drop_skull(), skull_data)
	monster.drops = [_entry(bone, 1)]
	assert_eq(monster.get_drop_skull(), null, "머리뼈가 없는 몬스터는 null")
