extends TestCase
## Harvest(채집 한 번의 진행) 단위 테스트.

const DURATION: float = 1.5

var stack: ItemStack


func before_each() -> void:
	var bone: ItemData = ItemData.new()
	bone.id = &"test_bone"
	stack = ItemStack.of_item(bone, 2)


func test_finishes_after_duration() -> void:
	var harvest: Harvest = Harvest.new(stack, DURATION)
	assert_false(harvest.update(0.75))
	assert_almost_eq(harvest.get_progress(), 0.5, 0.0001, "0.75초면 절반")
	assert_false(harvest.update(0.7), "1.45초는 아직")
	assert_true(harvest.update(0.05), "1.5초가 되면 끝")
	assert_true(harvest.is_done())
	assert_false(harvest.is_active())
	assert_eq(harvest.get_progress(), 1.0)


func test_finishes_only_once() -> void:
	var harvest: Harvest = Harvest.new(stack, DURATION)
	assert_true(harvest.update(5.0))
	assert_false(harvest.update(1.0), "이미 끝났으면 다시 알리지 않는다")


func test_cancel_stops_progress() -> void:
	var harvest: Harvest = Harvest.new(stack, DURATION)
	harvest.update(1.0)
	harvest.cancel()
	assert_true(harvest.is_cancelled())
	assert_false(harvest.is_active())
	assert_false(harvest.update(5.0), "취소한 뒤에는 시간이 지나도 끝나지 않는다")
	assert_false(harvest.is_done())


func test_cancel_after_done_does_nothing() -> void:
	var harvest: Harvest = Harvest.new(stack, DURATION)
	harvest.update(DURATION)
	harvest.cancel()
	assert_true(harvest.is_done(), "끝난 채집은 취소되지 않는다")
	assert_false(harvest.is_cancelled())


func test_keeps_chosen_stack() -> void:
	var harvest: Harvest = Harvest.new(stack, DURATION)
	assert_eq(harvest.stack, stack, "시작할 때 고른 묶음을 끝까지 가진다")
