extends TestCase
## ChokeIndex(구운 길목을 월드 좌표로 찾기)와 ChokeWaitSpots(대기 자리 나눠 주기) 단위 테스트.

const CELL: float = 32.0
const STEP: float = 8.0
const LIMIT: float = 1.5

var index: ChokeIndex


## 맵 칸 (5~6, 2~3)에 길목 하나. 입구는 왼쪽(4, 2.5)과 오른쪽(7, 2.5) 칸, 우회 비율은 ratio
func _choke(ratio: float) -> ChokeData:
	var choke: ChokeData = ChokeData.new()
	for cell: Vector2 in [Vector2(5, 2), Vector2(6, 2), Vector2(5, 3), Vector2(6, 3)]:
		choke.cells.append(cell)
	choke.entrances = PackedVector2Array([Vector2(4.5, 3.0) * CELL, Vector2(7.5, 3.0) * CELL])
	choke.wait_spots = [PackedVector2Array([Vector2(2.5, 2.0) * CELL, Vector2(2.5, 3.0) * CELL, Vector2(2.5, 4.0) * CELL]), PackedVector2Array([Vector2(9.5, 3.0) * CELL])]
	choke.detour_ratios = PackedFloat32Array([ratio])
	return choke


func before_each() -> void:
	index = ChokeIndex.new([_choke(1.2)] as Array[ChokeData], CELL, Vector2(40, 0), STEP)


func test_choke_at_uses_origin() -> void:
	assert_eq(index.choke_at(Vector2(40 + 5.5 * CELL, 2.5 * CELL)), 0, "길목 칸 안")
	assert_eq(index.choke_at(Vector2(5.5 * CELL, 2.5 * CELL)), -1, "origin만큼 옮긴 자리는 왼쪽 칸이라 길목 밖")


func test_first_choke_on_path_samples_between_points() -> void:
	var across: PackedVector2Array = PackedVector2Array([Vector2(40 + 1.0 * CELL, 3.0 * CELL), Vector2(40 + 10.0 * CELL, 3.0 * CELL)])
	assert_eq(index.first_choke_on_path(across), 0, "두 점 사이에서 길목을 지난다")
	assert_eq(index.first_choke_on_path(across, 0), -1, "그 길목을 건너뛰면 없다")
	var below: PackedVector2Array = PackedVector2Array([Vector2(40 + 1.0 * CELL, 6.0 * CELL), Vector2(40 + 10.0 * CELL, 6.0 * CELL)])
	assert_eq(index.first_choke_on_path(below), -1, "길목 아래로 지나면 없다")


func test_can_detour_by_ratio_and_sides() -> void:
	var left: Vector2 = Vector2(40 + 1.0 * CELL, 3.0 * CELL)
	var right: Vector2 = Vector2(40 + 12.0 * CELL, 3.0 * CELL)
	assert_true(index.can_detour(0, left, right, LIMIT), "우회 비율 1.2 ≤ 1.5")
	assert_false(index.can_detour(0, left, left, LIMIT), "같은 쪽이면 돌아갈 까닭이 없다")
	var far: ChokeIndex = ChokeIndex.new([_choke(2.0)] as Array[ChokeData], CELL, Vector2.ZERO, STEP)
	assert_false(far.can_detour(0, Vector2(32, 96), Vector2(400, 96), LIMIT), "우회 비율 2.0 > 1.5")
	var none: ChokeIndex = ChokeIndex.new([_choke(-1.0)] as Array[ChokeData], CELL, Vector2.ZERO, STEP)
	assert_false(none.can_detour(0, Vector2(32, 96), Vector2(400, 96), LIMIT), "돌아갈 길이 없으면(-1) 기다린다")


func test_wait_spots_are_shared_out_then_overflow() -> void:
	var spots: ChokeWaitSpots = ChokeWaitSpots.new()
	var list: PackedVector2Array = _choke(1.0).wait_spots[0]
	var members: Array[RefCounted] = []
	for i: int in 4:
		members.append(RefCounted.new())
	var near: Vector2 = Vector2(2.5, 3.0) * CELL
	var given: Dictionary = {}
	for i: int in 3:
		given[spots.claim(members[i], 0, 0, list, near)] = true
	assert_eq(given.size(), 3, "세 몸이 서로 다른 자리를 받는다")
	assert_eq(spots.claim(members[0], 0, 0, list, Vector2.ZERO), list[spots.spot_index(members[0])], "이미 받은 자리는 그대로")
	assert_eq(spots.claim(members[3], 0, 0, list, near), list[1], "자리가 다 차면 가장 가까운 자리를 함께 쓴다")
	spots.release(members[1])
	assert_eq(spots.spot_index(members[1]), -1, "반납하면 자리가 없다")


func test_empty_spots_give_inf() -> void:
	var spots: ChokeWaitSpots = ChokeWaitSpots.new()
	assert_eq(spots.claim(RefCounted.new(), 0, 1, PackedVector2Array(), Vector2.ZERO), Vector2.INF)
