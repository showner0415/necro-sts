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
