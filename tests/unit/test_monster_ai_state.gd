extends TestCase
## MonsterAiState(평소 → 발견 → 싸움 → 찾기) 단위 테스트.

var ai: MonsterAiState


func before_each() -> void:
	ai = MonsterAiState.new()


func test_starts_idle() -> void:
	assert_eq(ai.update(false, false, false), MonsterAiState.State.IDLE, "대상이 없으면 평소")
	assert_false(ai.is_fighting(), "평소에는 행동 조각을 쓰지 않는다")


func test_new_target_is_alert_for_one_frame_then_combat() -> void:
	ai.update(false, false, false)
	assert_eq(ai.update(true, false, true), MonsterAiState.State.ALERT, "대상이 생긴 프레임은 발견")
	assert_true(ai.is_fighting(), "발견은 지연 없이 싸움처럼 움직인다")
	assert_eq(ai.update(true, false, true), MonsterAiState.State.COMBAT, "다음 프레임은 싸움")


func test_hidden_target_is_search_and_visible_again_is_combat() -> void:
	ai.update(true, false, true)
	ai.update(true, false, true)
	assert_eq(ai.update(true, false, false), MonsterAiState.State.SEARCH, "대상이 벽 뒤로 사라지면 찾기")
	assert_true(ai.is_fighting(), "찾기는 지금은 길을 따라 쫓는다")
	assert_eq(ai.update(true, false, true), MonsterAiState.State.COMBAT, "다시 보이면 싸움")


func test_busy_without_target_stays_in_combat() -> void:
	ai.update(true, false, true)
	ai.update(true, false, true)
	assert_eq(ai.update(false, true, false), MonsterAiState.State.COMBAT, "대상이 사라져도 하던 돌진은 이어 간다")


func test_giving_up_goes_straight_to_idle() -> void:
	ai.update(true, false, true)
	assert_eq(ai.update(false, false, false), MonsterAiState.State.IDLE, "포기하면 그 자리에서 평소 (돌아가기 상태는 없다)")
	assert_false(ai.is_fighting(), "평소에는 행동 조각을 쓰지 않는다")


func test_target_after_giving_up_is_alert() -> void:
	ai.update(true, false, true)
	ai.update(false, false, false)
	assert_eq(ai.update(true, false, true), MonsterAiState.State.ALERT, "포기한 뒤 다시 대상이 생기면 발견")
