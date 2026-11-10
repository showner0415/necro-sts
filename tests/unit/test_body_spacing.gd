extends TestCase
## BodySpacing(몸끼리 겹치지 않게 비켜 서기) 단위 테스트.

const LIMIT: float = 32.0


func test_no_push_when_far() -> void:
	assert_eq(BodySpacing.push(Vector2.ZERO, 1, [Vector2(LIMIT, 0)], [2], LIMIT), Vector2.ZERO, "간격 이상이면 비키지 않는다")


func test_pushes_away_from_close_body() -> void:
	var result: Vector2 = BodySpacing.push(Vector2.ZERO, 1, [Vector2(16, 0)], [2], LIMIT)
	assert_true(result.x < 0.0, "가까운 몸의 반대쪽으로")
	assert_almost_eq(result.length(), sqrt(0.5), 0.001, "세기는 남은 간격 비율의 제곱근")


func test_same_spot_pushes_opposite_ways() -> void:
	var first: Vector2 = BodySpacing.push(Vector2.ZERO, 2, [Vector2.ZERO], [1], LIMIT)
	var second: Vector2 = BodySpacing.push(Vector2.ZERO, 1, [Vector2.ZERO], [2], LIMIT)
	assert_eq(first, -second, "같은 자리면 번호에 따라 서로 반대쪽으로")
	assert_almost_eq(first.length(), 1.0, 0.001, "겹치면 가장 세게")


func test_push_length_is_limited() -> void:
	var result: Vector2 = BodySpacing.push(Vector2.ZERO, 3, [Vector2(1, 0), Vector2(1, 0.1)], [1, 2], LIMIT)
	assert_almost_eq(result.length(), 1.0, 0.001, "여러 몸이 밀어도 길이는 1을 넘지 않는다")
