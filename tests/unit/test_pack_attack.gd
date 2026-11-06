extends TestCase
## PackAttack(무리 동시 공격 시각 규칙) 단위 테스트: 간격마다 예고 시작, 멤버가 모자라면 안 함·시간 초기화,
## 멤버가 자기 공격 중이면 기다림, 방향 고정 시점, 예고 끝.

const INTERVAL: float = 6.0
const WINDUP: float = 0.8
const LOCK: float = 0.2
const MIN_MEMBERS: int = 2
const DT: float = 1.0 / 60.0

var pack: PackAttack


func before_each() -> void:
	pack = PackAttack.new(INTERVAL, WINDUP, LOCK, MIN_MEMBERS)


## seconds초 동안 프레임마다 update한다.
func _run(seconds: float, engaged: int, ready: bool = true) -> void:
	for i: int in roundi(seconds / DT):
		pack.update(DT, engaged, ready)


func test_starts_after_interval() -> void:
	_run(INTERVAL - 0.1, 3)
	assert_false(pack.is_winding_up(), "6초 전에는 시작하지 않는다")
	_run(0.2, 3)
	assert_true(pack.is_winding_up(), "6초가 지나면 동시 공격 예고")
	assert_eq(pack.get_round(), 1)


func test_two_members_are_enough() -> void:
	_run(INTERVAL + 0.1, 2)
	assert_true(pack.is_winding_up(), "2마리면 한다")


func test_one_member_never_starts() -> void:
	_run(INTERVAL * 3.0, 1)
	assert_false(pack.is_winding_up(), "1마리만 남으면 하지 않는다")
	assert_eq(pack.get_round(), 0)


func test_too_few_members_resets_timer() -> void:
	_run(INTERVAL - 1.0, 3)
	_run(0.1, 1)
	_run(INTERVAL - 1.0, 3)
	assert_false(pack.is_winding_up(), "싸우는 멤버가 모자랐던 순간 시간이 처음으로 돌아간다")
	_run(1.1, 3)
	assert_true(pack.is_winding_up())


func test_waits_until_members_are_ready() -> void:
	_run(INTERVAL + 1.0, 3, false)
	assert_false(pack.is_winding_up(), "누가 자기 공격 중이면 기다린다")
	_run(DT, 3, true)
	assert_true(pack.is_winding_up(), "모두 끝나면 바로 시작")


func test_direction_locks_before_end() -> void:
	_run(INTERVAL + 0.05, 3)
	assert_true(pack.is_winding_up())
	assert_false(pack.is_direction_locked(), "예고 앞부분은 방향이 정해지지 않는다")
	_run(WINDUP - LOCK, 3)
	assert_true(pack.is_direction_locked(), "끝나기 0.2초 전부터 방향 고정")
	assert_true(pack.is_winding_up(), "아직 예고 중")


func test_windup_ends_and_next_round_after_interval() -> void:
	_run(INTERVAL + 0.05, 3)
	_run(WINDUP + 0.05, 3)
	assert_false(pack.is_winding_up(), "0.8초 뒤 예고가 끝난다 (멤버는 이때 돌진)")
	assert_false(pack.is_direction_locked())
	_run(INTERVAL - 0.5, 3)
	assert_false(pack.is_winding_up(), "다음은 다시 6초 뒤")
	_run(0.6, 3)
	assert_true(pack.is_winding_up())
	assert_eq(pack.get_round(), 2)


func test_windup_continues_when_members_drop() -> void:
	_run(INTERVAL + 0.05, 3)
	_run(WINDUP * 0.5, 1)
	assert_true(pack.is_winding_up(), "예고 도중 멤버가 죽어도 예고는 이어진다")


# --- 자리 나누기 ---

func test_formation_angle_turns() -> void:
	var turning: PackAttack = PackAttack.new(INTERVAL, WINDUP, LOCK, MIN_MEMBERS, 12.0)
	turning.update(3.0, 0, true)
	assert_almost_eq(turning.get_formation_angle(), TAU / 4.0, 0.0001, "12초에 한 바퀴면 3초에 90도")


func test_slots_are_distinct_and_follow_positions() -> void:
	pack.set_formation_angle(0.0)
	# 자리 가운데는 0도, 120도, 240도. 박쥐들이 거의 그 근처에 있으면 가장 가까운 자리를 받는다.
	var angles: Array[float] = [deg_to_rad(250.0 - 360.0), deg_to_rad(10.0), deg_to_rad(110.0)]
	var slots: Array[int] = pack.assign_slots(angles)
	assert_eq(slots, [2, 0, 1] as Array[int], "각자 가까운 자리 (240도, 0도, 120도)")


func test_bunched_members_get_spread_slots() -> void:
	pack.set_formation_angle(0.0)
	var angles: Array[float] = [0.0, 0.05, 0.1]
	var slots: Array[int] = pack.assign_slots(angles)
	var sorted: Array[int] = slots.duplicate()
	sorted.sort()
	assert_eq(sorted, [0, 1, 2] as Array[int], "붙어 있어도 서로 다른 자리로 나뉜다")


func test_slots_redistribute_when_one_dies() -> void:
	pack.set_formation_angle(0.0)
	var slots: Array[int] = pack.assign_slots([deg_to_rad(5.0), deg_to_rad(170.0)] as Array[float])
	assert_eq(slots, [0, 1] as Array[int], "2마리면 0도·180도 두 자리로 다시 나눈다")


func test_assembling_until_ready_then_overdue() -> void:
	pack.assemble_timeout = 1.5
	_run(INTERVAL + 0.1, 3, false)
	assert_true(pack.is_assembling(), "때가 되었는데 아직 다 모이지 않음: 자리 잡는 중")
	assert_false(pack.is_assembly_overdue())
	_run(1.5, 3, false)
	assert_true(pack.is_assembly_overdue(), "1.5초 넘게 기다리면 자리와 상관없이 들어간다")
	_run(DT, 3, true)
	assert_true(pack.is_winding_up())
	assert_false(pack.is_assembling(), "예고가 시작되면 자리 잡기는 끝")
