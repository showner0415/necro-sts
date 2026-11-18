extends TestCase
## ChaseFan(쫓는 몬스터들의 다가갈 자리를 부채꼴로 나누는 규칙) 단위 테스트.

const STEP: float = PI / 4.5
const MAX_HALF: float = PI / 2.0
const RADIUS: float = 64.0
const MIN_AXIS: float = 16.0
const TARGET: Vector2 = Vector2(100, 50)


func test_single_chaser_keeps_its_own_side() -> void:
	var fan: ChaseFan = ChaseFan.create(TARGET, [7] as Array[int], [TARGET + Vector2(-200, 0)] as Array[Vector2], MIN_AXIS)
	assert_true(fan.valid, "쫓는 몸이 대상에서 떨어져 있으면 자리를 나눈다")
	var slot: Vector2 = fan.slot_for(7, TARGET, STEP, MAX_HALF, RADIUS)
	assert_almost_eq(slot.x, TARGET.x - RADIUS, 0.01, "한 마리면 자기 쪽에서 곧장 다가간다 (x)")
	assert_almost_eq(slot.y, TARGET.y, 0.01, "한 마리면 자기 쪽에서 곧장 다가간다 (y)")


func test_line_of_chasers_gets_different_slots() -> void:
	# 대상 서쪽에 한 줄로 선 세 마리 (완전히 같은 방향)
	var ids: Array[int] = [3, 1, 2]
	var positions: Array[Vector2] = [TARGET + Vector2(-100, 0), TARGET + Vector2(-130, 0), TARGET + Vector2(-160, 0)]
	var fan: ChaseFan = ChaseFan.create(TARGET, ids, positions, MIN_AXIS)
	var slots: Array[Vector2] = []
	for id: int in ids:
		slots.append(fan.slot_for(id, TARGET, STEP, MAX_HALF, RADIUS))
	assert_true(slots[0].distance_to(slots[1]) > 20.0 and slots[1].distance_to(slots[2]) > 20.0 and slots[0].distance_to(slots[2]) > 20.0, "한 줄로 서 있어도 자리는 서로 다르다")
	for slot: Vector2 in slots:
		assert_almost_eq(slot.distance_to(TARGET), RADIUS, 0.01, "자리는 대상에서 반지름만큼 떨어져 있다")
	# 방향이 같으면 번호 순서로 가른다: 1, 2, 3
	assert_eq(fan.rank_of(1), 0, "방향이 같으면 번호가 작은 몸이 먼저")
	assert_eq(fan.rank_of(2), 1)
	assert_eq(fan.rank_of(3), 2)


func test_chasers_keep_their_side_order() -> void:
	# 서쪽에서 오는 무리: 위쪽(y가 작은) 몸과 아래쪽 몸
	var ids: Array[int] = [10, 20]
	var positions: Array[Vector2] = [TARGET + Vector2(-150, -30), TARGET + Vector2(-150, 30)]
	var fan: ChaseFan = ChaseFan.create(TARGET, ids, positions, MIN_AXIS)
	var upper: Vector2 = fan.slot_for(10, TARGET, STEP, MAX_HALF, RADIUS)
	var lower: Vector2 = fan.slot_for(20, TARGET, STEP, MAX_HALF, RADIUS)
	assert_true(upper.y < TARGET.y, "위쪽에 있던 몸은 위쪽 자리를 받는다")
	assert_true(lower.y > TARGET.y, "아래쪽에 있던 몸은 아래쪽 자리를 받는다")
	assert_almost_eq(upper.y - TARGET.y, -(lower.y - TARGET.y), 0.01, "두 자리는 기준 방향의 양쪽에 대칭이다")


func test_slot_offset_spreads_by_step_and_is_capped() -> void:
	assert_almost_eq(ChaseFan.slot_offset(0, 1, STEP, MAX_HALF), 0.0, 0.0001, "한 마리는 벌리지 않는다")
	assert_almost_eq(ChaseFan.slot_offset(0, 3, STEP, MAX_HALF), -STEP, 0.0001, "세 마리: 왼쪽 끝은 -step")
	assert_almost_eq(ChaseFan.slot_offset(1, 3, STEP, MAX_HALF), 0.0, 0.0001, "세 마리: 가운데는 0")
	assert_almost_eq(ChaseFan.slot_offset(2, 3, STEP, MAX_HALF), STEP, 0.0001, "세 마리: 오른쪽 끝은 +step")
	# 여덟 마리면 step × 3.5가 최대 폭을 넘으므로 ±max_half 안에 고르게 나눈다
	assert_almost_eq(ChaseFan.slot_offset(0, 8, STEP, MAX_HALF), -MAX_HALF, 0.0001, "많으면 왼쪽 끝이 -max_half")
	assert_almost_eq(ChaseFan.slot_offset(7, 8, STEP, MAX_HALF), MAX_HALF, 0.0001, "많으면 오른쪽 끝이 +max_half")
	assert_almost_eq(ChaseFan.slot_offset(4, 8, STEP, MAX_HALF) - ChaseFan.slot_offset(3, 8, STEP, MAX_HALF), MAX_HALF * 2.0 / 7.0, 0.0001, "그 안에 고르게 나눈다")


func test_surrounding_chasers_do_not_fan() -> void:
	# 대상을 이미 둘러싸서 가운데가 대상과 겹친다
	var ids: Array[int] = [1, 2]
	var positions: Array[Vector2] = [TARGET + Vector2(-60, 0), TARGET + Vector2(60, 0)]
	var fan: ChaseFan = ChaseFan.create(TARGET, ids, positions, MIN_AXIS)
	assert_false(fan.valid, "쫓는 몸들의 가운데가 대상과 겹치면 자리를 나누지 않는다")
	assert_eq(fan.slot_for(1, TARGET, STEP, MAX_HALF, RADIUS), TARGET, "나누지 않으면 겨누는 점 그대로다")


func test_unknown_chaser_and_empty_fan() -> void:
	var fan: ChaseFan = ChaseFan.create(TARGET, [1] as Array[int], [TARGET + Vector2(0, 100)] as Array[Vector2], MIN_AXIS)
	assert_false(fan.has(99))
	assert_eq(fan.rank_of(99), -1, "없는 몸의 순서는 -1")
	assert_eq(fan.slot_for(99, TARGET, STEP, MAX_HALF, RADIUS), TARGET, "없는 몸은 겨누는 점 그대로다")
	var empty: ChaseFan = ChaseFan.create(TARGET, [] as Array[int], [] as Array[Vector2], MIN_AXIS)
	assert_false(empty.valid, "쫓는 몸이 없으면 나누지 않는다")
	assert_eq(empty.count, 0)


func test_predict_leads_moving_target() -> void:
	var chaser: Vector2 = TARGET + Vector2(-80, 0)
	# 대상이 아래로 초속 50, 쫓는 몸은 초속 40: 닿는 데 2초지만 최대 1초만 앞질러 보고 그 절반을 겨눈다
	var aim: Vector2 = ChaseFan.predict(TARGET, Vector2(0, 50), chaser, 40.0, 0.5, 1.0)
	assert_almost_eq(aim.x, TARGET.x, 0.01)
	assert_almost_eq(aim.y, TARGET.y + 25.0, 0.01, "속도 × 최대 시간 × 비율만큼 앞을 겨눈다")
	# 가까우면 닿는 시간만큼만: 20px ÷ 40 = 0.5초
	var near: Vector2 = ChaseFan.predict(TARGET, Vector2(0, 50), TARGET + Vector2(-20, 0), 40.0, 1.0, 1.0)
	assert_almost_eq(near.y, TARGET.y + 20.0, 0.01, "앞지르는 거리는 대상까지의 거리를 넘지 않는다")


func test_predict_off_or_standing_target() -> void:
	var chaser: Vector2 = TARGET + Vector2(-80, 0)
	assert_eq(ChaseFan.predict(TARGET, Vector2(0, 50), chaser, 40.0, 0.0, 1.0), TARGET, "비율 0이면 지금 자리")
	assert_eq(ChaseFan.predict(TARGET, Vector2.ZERO, chaser, 40.0, 0.5, 1.0), TARGET, "대상이 서 있으면 지금 자리")
	assert_eq(ChaseFan.predict(TARGET, Vector2(0, 50), chaser, 0.0, 0.5, 1.0), TARGET, "쫓는 몸의 속도가 0이면 지금 자리")
