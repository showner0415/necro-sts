extends TestCase
## PackLeader(무리 대장 고르기)와 DungeonRun의 대장 확정 목록 단위 테스트.


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_chance_zero_never_and_one_always() -> void:
	for seed_value: int in 20:
		assert_eq(PackLeader.pick(4, 0.0, false, _rng(seed_value)), -1, "확률 0이면 대장이 없다")
		var index: int = PackLeader.pick(4, 1.0, false, _rng(seed_value))
		assert_true(index >= 0 and index < 4, "확률 1이면 무리원 중 하나 (%d)" % index)


func test_forced_ignores_chance() -> void:
	assert_true(PackLeader.pick(3, 0.0, true, _rng(1)) >= 0, "확정이면 확률과 상관없이 생긴다")


func test_any_member_can_be_leader() -> void:
	var seen: Dictionary = {}
	for seed_value: int in 80:
		seen[PackLeader.pick(4, 1.0, false, _rng(seed_value))] = true
	assert_eq(seen.size(), 4, "무리원 넷이 모두 대장이 될 수 있다 (%s)" % [seen.keys()])


func test_chance_is_roughly_kept() -> void:
	var rng: RandomNumberGenerator = _rng(7)
	var leaders: int = 0
	for i: int in 2000:
		if PackLeader.pick(3, 0.15, false, rng) >= 0:
			leaders += 1
	assert_almost_eq(leaders / 2000.0, 0.15, 0.03, "15%쯤")


func test_empty_pack_has_no_leader() -> void:
	assert_eq(PackLeader.pick(0, 1.0, true, _rng(1)), -1)


func test_dungeon_run_forced_list() -> void:
	var run: DungeonRun = DungeonRun.new()
	assert_false(run.forces_leader(&"rat_gang"))
	run.forced_leader_packs.append(&"rat_gang")
	assert_true(run.forces_leader(&"rat_gang"), "목록에 있으면 확정")
	assert_false(run.forces_leader(&"boar_pack"))
