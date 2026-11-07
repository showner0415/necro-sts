extends TestCase
## 언데드가 싸울 몬스터를 정하는 규칙 (UndeadTargeting). 몬스터 대신 RefCounted 객체를 쓴다.

var _rule: UndeadTargeting
var _a: RefCounted
var _b: RefCounted


func before_each() -> void:
	_rule = UndeadTargeting.new()
	_a = RefCounted.new()
	_b = RefCounted.new()


func _candidate(monster: Object, distance: float, qualified: bool = false, hit: bool = false, engage: bool = false, leash: bool = true) -> UndeadTargeting.Candidate:
	var c: UndeadTargeting.Candidate = UndeadTargeting.Candidate.new()
	c.monster = monster
	c.distance = distance
	c.qualified = qualified
	c.hit_by_necromancer = hit
	c.in_engage_range = engage
	c.within_leash = leash
	return c


func _update(candidates: Array) -> Object:
	var typed: Array[UndeadTargeting.Candidate] = []
	typed.assign(candidates)
	return _rule.update(typed)


func test_no_reason_no_target() -> void:
	assert_eq(_update([_candidate(_a, 20.0), _candidate(_b, 30.0)]), null, "계기가 없으면 아무도 노리지 않음 (가까워도)")


func test_hit_by_necromancer_becomes_target() -> void:
	assert_eq(_update([_candidate(_a, 20.0), _candidate(_b, 90.0, true, true)]), _b, "맞힌 몬스터를 노림 (더 가까운 a는 무시)")


func test_newly_qualified_is_trigger_and_latest_wins_before_lock() -> void:
	assert_eq(_update([_candidate(_a, 80.0, true)]), _a, "a가 조건에 새로 맞음")
	assert_eq(_update([_candidate(_a, 70.0, true), _candidate(_b, 100.0, true)]), _b, "고정 전에는 가장 최근 계기(b)로 바꿈 (a가 더 가까워도)")
	assert_eq(_update([_candidate(_a, 60.0, true), _candidate(_b, 90.0, true)]), _b, "계기가 없는 프레임에는 그대로")


func test_locks_in_engage_range_and_ignores_new_triggers() -> void:
	_update([_candidate(_a, 80.0, true, true)])
	assert_eq(_update([_candidate(_a, 10.0, true, false, true)]), _a, "공격 반경에 들어옴")
	assert_true(_rule.locked, "고정됨")
	assert_eq(_update([_candidate(_a, 10.0, true, false, true), _candidate(_b, 5.0, true, true, true)]), _a, "고정 뒤에는 맞힌 b가 더 가까워도 a 그대로")


func test_release_when_target_dies_then_picks_nearest_qualified() -> void:
	_update([_candidate(_a, 10.0, true, true, true)])
	assert_true(_rule.locked)
	# b는 이미 조건에 맞던 몬스터 (새 계기는 아님)
	_update([_candidate(_a, 10.0, true, false, true), _candidate(_b, 50.0, true)])
	assert_eq(_update([_candidate(_b, 50.0, true)]), _b, "a가 죽으면(후보에서 빠짐) 조건에 맞는 b를 바로 노림")
	assert_false(_rule.locked, "b는 아직 공격 반경 밖이라 고정 전")


func test_release_when_target_leaves_leash() -> void:
	_update([_candidate(_a, 10.0, true, true, true)])
	assert_eq(_update([_candidate(_a, 10.0, true, false, true, false)]), null, "leash 밖이면 풀리고 돌아옴")
	assert_false(_rule.locked)


func test_triggers_outside_leash_are_ignored() -> void:
	assert_eq(_update([_candidate(_a, 30.0, true, true, false, false)]), null, "leash 밖에서 맞힌 몬스터는 쫓지 않음")


func test_same_frame_triggers_pick_nearest() -> void:
	assert_eq(_update([_candidate(_a, 90.0, true, true), _candidate(_b, 40.0, true, true)]), _b, "같은 프레임 계기 여럿이면 가장 가까운 것")


func test_qualification_lost_keeps_target_until_released() -> void:
	_update([_candidate(_a, 80.0, true, true)])
	assert_eq(_update([_candidate(_a, 80.0)]), _a, "조건이 없어져도(네크로맨서를 안 노리게 됨) 대상은 유지")


func test_freed_target_is_dropped() -> void:
	var node: Node = Node.new()
	_update([_candidate(node, 80.0, true, true)])
	node.free()
	assert_eq(_update([_candidate(_b, 50.0, true, true)]), _b, "대상이 노드째 지워지면 죽은 것과 같이 보고 새 계기(b)를 고름")
	assert_false(_rule.locked, "고정도 풀림")
