extends TestCase
## MonsterBehavior의 공격권 기다리기(must_wait_for_token, wait_around) 단위 테스트.
## 쥐(다가가기)·멧돼지(돌진)·투석병(던지기)이 같이 쓴다. 공격권은 request_attack이 있는 가짜 몸으로 흉내 낸다.
## 벽에 막히는 경우는 can_move를 바꾼 조각으로 흉내 낸다 (단위 테스트는 물리 프레임 없이 돈다).

const SPEED: float = 40.0
const ATTACK_RANGE: float = 16.0
const WAIT_DISTANCE: float = 96.0


## 공격권을 묻는 횟수를 세고, allowed대로 답하는 가짜 몸
class FakeBody:
	extends CharacterBody2D
	var allowed: bool = false
	var asked: int = 0

	func request_attack(_target: Node2D) -> bool:
		asked += 1
		return allowed


## 위쪽(-y)으로만 갈 수 있는 조각 (나머지는 벽에 막혔다고 본다)
class WalledBehavior:
	extends MonsterBehavior

	func can_move(_body: CharacterBody2D, direction: Vector2, _probe: float) -> bool:
		return direction.normalized().y < -0.9


var body: FakeBody
var target: Node2D
var stats: CombatStats
var behavior: MonsterBehavior


func before_each() -> void:
	body = FakeBody.new()
	target = Node2D.new()
	stats = CombatStats.create(SPEED, ATTACK_RANGE, 2.0, 1.0)
	stats.wait_distance = WAIT_DISTANCE
	behavior = MonsterBehavior.new()


func after_each() -> void:
	if is_instance_valid(body):
		body.free()
	target.free()


func test_ask_distance_is_ring_or_engage_range() -> void:
	assert_eq(behavior.get_token_ask_distance(stats), WAIT_DISTANCE + behavior.wait_band * 2.0, "공격 반경이 짧으면 맴도는 거리 + 띠 × 2")
	var charge: ChargeBehavior = ChargeBehavior.new()
	charge.charge_range = 140.0
	assert_eq(charge.get_token_ask_distance(stats), 140.0, "돌진 거리가 더 길면 돌진 거리 (예고 전에 꼭 묻게)")


func test_far_target_is_not_asked() -> void:
	target.position = Vector2(behavior.get_token_ask_distance(stats) + 1.0, 0)
	assert_false(behavior.must_wait_for_token(body, stats, target), "묻는 거리 밖이면 기다리지 않는다")
	assert_eq(body.asked, 0, "묻지도 않는다 (다가오는 시간이 시간 제한에 들지 않게)")


func test_inside_ask_distance_waits_only_without_token() -> void:
	target.position = Vector2(WAIT_DISTANCE, 0)
	assert_true(behavior.must_wait_for_token(body, stats, target), "공격권이 없으면 기다린다")
	body.allowed = true
	assert_false(behavior.must_wait_for_token(body, stats, target), "공격권이 있으면 공격한다")
	assert_eq(body.asked, 2)


func test_body_without_tokens_never_waits() -> void:
	var plain: CharacterBody2D = CharacterBody2D.new()
	target.position = Vector2(WAIT_DISTANCE, 0)
	assert_false(behavior.must_wait_for_token(plain, stats, target), "공격권이 없는 쓰는 쪽(언데드 등)은 기다리지 않는다")
	plain.free()


func test_wait_around_far_approaches_at_move_speed() -> void:
	target.position = Vector2(WAIT_DISTANCE + behavior.wait_band + 4.0, 0)
	behavior.wait_around(body, stats, target)
	assert_eq(body.velocity, Vector2(SPEED, 0), "띠보다 멀면 대상 쪽으로 이동 속도만큼")


func test_wait_around_near_backs_off() -> void:
	target.position = Vector2(WAIT_DISTANCE - behavior.wait_band - 4.0, 0)
	behavior.wait_around(body, stats, target)
	assert_eq(body.velocity, Vector2(-behavior.wait_back_off_speed, 0), "띠보다 가까우면 대상 반대쪽으로 물러난다")


func test_wait_around_in_band_circles() -> void:
	target.position = Vector2(WAIT_DISTANCE, 0)
	behavior.wait_around(body, stats, target)
	assert_almost_eq(body.velocity.length(), behavior.wait_circle_speed, 0.001, "띠 안이면 맴도는 속도로")
	assert_almost_eq(body.velocity.dot(Vector2.RIGHT), 0.0, 0.001, "대상과 직각으로 (옆으로 돈다)")


func test_wait_around_turns_back_when_blocked() -> void:
	var walled: WalledBehavior = WalledBehavior.new()
	target.position = Vector2(-WAIT_DISTANCE, 0)
	# 대상은 왼쪽에 있고 처음 도는 쪽은 아래(+y). 위쪽 말고는 모두 막혔다.
	walled.wait_around(body, stats, target)
	assert_eq(body.velocity, Vector2.ZERO, "도는 쪽이 막히면 이번 프레임은 멈춘다")
	walled.wait_around(body, stats, target)
	assert_almost_eq(body.velocity.y, -walled.wait_circle_speed, 0.001, "다음 프레임부터 반대쪽(위)으로 돈다")
