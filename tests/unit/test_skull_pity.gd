extends TestCase
## SkullPity(머리뼈 보정) 단위 테스트.

const DEFAULT_PATH: String = "res://data/skull_pity.tres"

var bone: ItemData
var rat_skull: SkullData
var boar_skull: SkullData
var pity: SkullPity


func before_each() -> void:
	bone = ItemData.new()
	bone.id = &"bone"
	rat_skull = SkullData.new()
	rat_skull.id = &"rat_skull"
	boar_skull = SkullData.new()
	boar_skull.id = &"boar_skull"
	pity = SkullPity.new()
	pity.skull = rat_skull
	pity.boosted_chance = 0.8


func _entry(item: ItemData, chance: float) -> DropEntry:
	var entry: DropEntry = DropEntry.new()
	entry.item = item
	entry.chance = chance
	return entry


func test_no_skull_boosts_only_target_skull() -> void:
	var drops: Array[DropEntry] = [_entry(bone, 1.0), _entry(rat_skull, 0.5), _entry(boar_skull, 0.3)]
	var boosted: Array[DropEntry] = pity.apply(drops, true)
	assert_eq(boosted[0], drops[0], "뼈 줄은 그대로")
	assert_almost_eq(boosted[1].chance, 0.8, 0.0001, "쥐의 머리뼈만 0.8로")
	assert_eq(boosted[2], drops[2], "다른 종의 머리뼈는 그대로")
	assert_almost_eq(drops[1].chance, 0.5, 0.0001, "데이터는 바뀌지 않는다 (복사본)")


func test_with_skull_keeps_drops() -> void:
	var drops: Array[DropEntry] = [_entry(rat_skull, 0.5)]
	assert_eq(pity.apply(drops, false), drops, "머리뼈가 있으면 그대로")


func test_higher_chance_is_not_lowered() -> void:
	var drops: Array[DropEntry] = [_entry(rat_skull, 0.9)]
	assert_almost_eq(pity.apply(drops, true)[0].chance, 0.9, 0.0001, "원래 확률이 더 높으면 그대로")


func test_has_no_skull_counts_any_skull() -> void:
	assert_true(SkullPity.has_no_skull([]), "빈 인벤토리면 없음")
	var broken: Skull = Skull.create(rat_skull)
	broken.durability = 0.0
	assert_false(SkullPity.has_no_skull([broken]), "내구도 0도 있음으로 센다")
	assert_false(SkullPity.has_no_skull([Skull.create_named(rat_skull, "쥐", "그레카")]), "네임드도 있음으로 센다")


func test_default_is_rat_skull_temporary_value() -> void:
	var default_pity: SkullPity = load(DEFAULT_PATH)
	assert_eq(default_pity.skull.id, &"rat_skull")
	assert_almost_eq(default_pity.boosted_chance, 0.8, 0.0001)


func test_active_only_without_skull_and_before_any_corpse_skull() -> void:
	assert_true(SkullPity.is_active([], false), "머리뼈가 없고 시체에 나온 적이 없으면 켜진다")
	assert_false(SkullPity.is_active([], true), "시체에 한 번 나왔으면 인벤토리가 비어도 꺼진다")
	assert_false(SkullPity.is_active([Skull.create(rat_skull)], false), "인벤토리에 있으면 꺼진다")


func test_loot_has_skull_counts_any_skull() -> void:
	var bone_only: CorpseLoot = CorpseLoot.from_drops([_entry(bone, 1.0)], 1.0)
	assert_false(SkullPity.loot_has_skull(bone_only), "뼈만 든 시체")
	var boar: CorpseLoot = CorpseLoot.from_drops([_entry(boar_skull, 1.0)], 1.0)
	assert_true(SkullPity.loot_has_skull(boar), "다른 종의 머리뼈도 센다")
	var named: CorpseLoot = CorpseLoot.from_drops([_entry(bone, 1.0)], 1.0, Skull.create_named(rat_skull, "쥐", "그레카"))
	assert_true(SkullPity.loot_has_skull(named), "네임드 머리뼈도 센다")
