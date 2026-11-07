extends TestCase
## RegionExit의 개발용 출구(debug_only) 규칙 단위 테스트.


func test_normal_exit_always_available() -> void:
	var exit: RegionExit = RegionExit.new()
	assert_true(exit.is_available(true), "디버그 실행")
	assert_true(exit.is_available(false), "릴리스 빌드")
	exit.free()


func test_debug_only_exit_only_in_debug_build() -> void:
	var exit: RegionExit = RegionExit.new()
	exit.debug_only = true
	assert_true(exit.is_available(true), "디버그 실행(에디터·테스트)에서는 있다")
	assert_false(exit.is_available(false), "릴리스 빌드에서는 없어진다")
	exit.free()
