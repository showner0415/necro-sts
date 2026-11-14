extends TestCase
## DropRoller(드랍 확률 규칙) 단위 테스트.

const SEED: int = 1234
const ROLLS: int = 2000
## 확률 0.5를 ROLLS번 굴렸을 때 허용하는 비율 오차
const RATIO_TOLERANCE: float = 0.05

var bone: ItemData


func before_each() -> void:
	bone = ItemData.new()
	bone.id = &"test_bone"


func _entry(item: ItemData, count: int, chance: float) -> DropEntry:
	var entry: DropEntry = DropEntry.new()
	entry.item = item
	entry.count = count
	entry.chance = chance
	return entry


func test_chance_one_always_drops() -> void:
	var entries: Array[DropEntry] = [_entry(bone, 2, 1.0)]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for i: int in ROLLS:
		if DropRoller.roll(entries, rng).size() != 1:
			assert_true(false, "%d번째에 확률 1인데 안 떨어짐" % i)
			return


func test_chance_zero_never_drops() -> void:
	var entries: Array[DropEntry] = [_entry(bone, 2, 0.0)]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for i: int in ROLLS:
		if not DropRoller.roll(entries, rng).is_empty():
			assert_true(false, "%d번째에 확률 0인데 떨어짐" % i)
			return


func test_half_chance_drops_about_half() -> void:
	var entries: Array[DropEntry] = [_entry(bone, 1, 0.5)]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var dropped: int = 0
	for i: int in ROLLS:
		dropped += DropRoller.roll(entries, rng).size()
	assert_almost_eq(float(dropped) / ROLLS, 0.5, RATIO_TOLERANCE, "%d번 중 %d번" % [ROLLS, dropped])


func test_same_seed_gives_same_result() -> void:
	var entries: Array[DropEntry] = [_entry(bone, 1, 0.5), _entry(bone, 1, 0.5), _entry(bone, 1, 0.5)]
	var first: Array[int] = []
	var second: Array[int] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for i: int in 50:
		first.append(DropRoller.roll(entries, rng).size())
	rng.seed = SEED
	for i: int in 50:
		second.append(DropRoller.roll(entries, rng).size())
	assert_eq(second, first, "시드가 같으면 결과도 같다")


func test_returns_entries_unchanged() -> void:
	var entry: DropEntry = _entry(bone, 3, 1.0)
	var result: Array[DropEntry] = DropRoller.roll([entry])
	assert_eq(result.size(), 1)
	assert_true(result[0] == entry, "같은 줄을 그대로 돌려준다")
	assert_eq(result[0].count, 3)


func test_skips_empty_entries() -> void:
	var entries: Array[DropEntry] = [_entry(null, 1, 1.0), _entry(bone, 0, 1.0), null]
	assert_eq(DropRoller.roll(entries).size(), 0, "아이템이 없거나 개수가 0인 줄은 건너뛴다")


func _expected_entry(item: ItemData, expected: float) -> DropEntry:
	var entry: DropEntry = _entry(item, 99, 1.0)
	entry.expected_count = expected
	return entry


func test_roll_count_whole_number_is_exact() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for i: int in 100:
		assert_eq(DropRoller.roll_count(3.0, rng), 3, "정수 기대값은 언제나 그 개수")
	assert_eq(DropRoller.roll_count(0.0, rng), 0, "0이면 0개")


func test_roll_count_fraction_gives_floor_or_one_more_with_mean() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var total: int = 0
	var seen: Dictionary = {}
	for i: int in ROLLS:
		var count: int = DropRoller.roll_count(2.4, rng)
		seen[count] = true
		total += count
	assert_eq(seen.keys().size(), 2, "2.4면 2개나 3개만 (%s)" % [seen.keys()])
	assert_true(seen.has(2) and seen.has(3), "2와 3이 모두 나온다")
	assert_almost_eq(float(total) / ROLLS, 2.4, RATIO_TOLERANCE, "평균은 기대값 근처")


func test_expected_entry_uses_rolled_count_without_changing_data() -> void:
	var entry: DropEntry = _expected_entry(bone, 1.0)
	var entries: Array[DropEntry] = [entry]
	var rolled: Array[DropEntry] = DropRoller.roll(entries)
	assert_eq(rolled.size(), 1)
	assert_eq(rolled[0].count, 1, "count(99) 대신 기대값 1")
	assert_ne(rolled[0], entry, "굴린 개수는 복사본에 넣는다")
	assert_eq(entry.count, 99, "데이터는 바뀌지 않는다")


func test_expected_entry_with_zero_result_is_dropped() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var entries: Array[DropEntry] = [_expected_entry(bone, 0.0001)]
	var empty: int = 0
	for i: int in 50:
		if DropRoller.roll(entries, rng).is_empty():
			empty += 1
	assert_true(empty > 40, "0개가 되면 그 줄은 빠진다 (%d/50)" % empty)
