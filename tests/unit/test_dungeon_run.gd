extends TestCase
## DungeonRun(던전 상태: 지역마다 스냅샷, 시드 난수) 단위 테스트.

var run: DungeonRun


func before_each() -> void:
	run = DungeonRun.new()


func test_starts_inactive_and_saves_per_region() -> void:
	assert_false(run.is_active(), "처음에는 던전에 있지 않다")
	run.start(7)
	assert_true(run.is_active())
	run.save(&"a", {"dead": ["Rat1"]})
	assert_true(run.has_snapshot(&"a"))
	assert_false(run.has_snapshot(&"b"), "다른 지역은 없다")
	assert_eq(run.get_snapshot(&"a")["dead"], ["Rat1"], "저장한 그대로 꺼낸다")
	assert_eq(run.get_snapshot(&"b"), {}, "없으면 빈 사전")


func test_clear_drops_everything() -> void:
	run.start(7)
	run.save(&"a", {"dead": ["Rat1"]})
	run.clear()
	assert_false(run.is_active(), "거점에 들어가면 던전 밖이다")
	assert_false(run.has_snapshot(&"a"), "잡은 무리 기록도 사라진다 (다음 입장 때 새로 생긴다)")


func test_start_again_forgets_old_snapshots_and_seeds_rng() -> void:
	run.start(7)
	run.save(&"a", {})
	var first: int = run.rng.randi()
	run.start(7)
	assert_false(run.has_snapshot(&"a"), "새로 들어가면 지난 기록이 없다")
	assert_eq(run.rng.randi(), first, "같은 시드면 같은 난수")
