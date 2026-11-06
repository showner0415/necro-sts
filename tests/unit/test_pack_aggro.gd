extends TestCase
## PackAggro(무리 공동 대상 규칙) 단위 테스트: 가장 최근 어그로가 무리 대상, 포기.

var pack: PackAggro
var necromancer: RefCounted
var undead: RefCounted


func before_each() -> void:
	pack = PackAggro.new()
	necromancer = RefCounted.new()
	undead = RefCounted.new()


func test_no_target_at_start() -> void:
	assert_false(pack.resolve(), "어그로가 없으면 바뀌지 않는다")
	assert_eq(pack.target, null)


func test_first_aggro_becomes_pack_target() -> void:
	pack.on_aggro(necromancer)
	assert_true(pack.resolve())
	assert_eq(pack.target, necromancer, "한 마리라도 어그로가 끌리면 무리 대상")


func test_latest_aggro_wins() -> void:
	pack.on_aggro(necromancer)
	pack.resolve()
	pack.on_aggro(undead)
	assert_true(pack.resolve())
	assert_eq(pack.target, undead, "다른 프레임: 가장 최근 어그로")
	pack.on_aggro(undead)
	pack.on_aggro(necromancer)
	pack.resolve()
	assert_eq(pack.target, necromancer, "같은 프레임: 마지막에 알린 것")


func test_target_stays_without_new_aggro() -> void:
	pack.on_aggro(necromancer)
	pack.resolve()
	assert_false(pack.resolve(), "새 어그로가 없으면 그대로")
	assert_eq(pack.target, necromancer)


func test_give_up_clears_target_and_pending() -> void:
	pack.on_aggro(necromancer)
	pack.resolve()
	pack.on_aggro(undead)
	pack.give_up()
	assert_eq(pack.target, null, "함께 포기")
	assert_false(pack.resolve(), "포기 전에 알린 어그로도 버린다")
	assert_eq(pack.target, null)
