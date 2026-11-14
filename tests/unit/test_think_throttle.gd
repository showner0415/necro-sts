extends TestCase
## ThinkThrottle(먼 몬스터의 판단 줄이기) 단위 테스트.

const FAR: float = 640.0
const INTERVAL: int = 4


func test_near_or_busy_thinks_every_frame() -> void:
	for frame: int in 8:
		assert_true(ThinkThrottle.should_think(frame, 1, INTERVAL, FAR, FAR, false), "거리가 딱 경계면 가까운 것으로 본다")
		assert_true(ThinkThrottle.should_think(frame, 1, INTERVAL, 100.0, FAR, false), "가까우면 매 프레임")
		assert_true(ThinkThrottle.should_think(frame, 1, INTERVAL, 2000.0, FAR, true), "공격 중이면 멀어도 매 프레임")


func test_far_thinks_once_per_interval() -> void:
	var thought: int = 0
	for frame: int in INTERVAL * 5:
		if ThinkThrottle.should_think(frame, 2, INTERVAL, FAR + 1.0, FAR, false):
			thought += 1
	assert_eq(thought, 5, "먼 몸은 interval 프레임에 한 번")


func test_slots_spread_across_frames() -> void:
	var per_frame: Array[int] = [0, 0, 0, 0]
	for slot: int in 8:
		for frame: int in INTERVAL:
			if ThinkThrottle.should_think(frame, slot, INTERVAL, 2000.0, FAR, false):
				per_frame[frame] += 1
	assert_eq(per_frame, [2, 2, 2, 2] as Array[int], "몸 8마리가 프레임마다 2마리씩 나눠 판단한다")


func test_interval_one_or_less_always_thinks() -> void:
	assert_true(ThinkThrottle.should_think(3, 0, 1, 2000.0, FAR, false))
	assert_true(ThinkThrottle.should_think(3, 0, 0, 2000.0, FAR, false))
