class_name TestCase
extends RefCounted
## 규칙 단위 테스트의 기반 클래스. tests/unit/test_*.gd가 이 클래스를 상속한다.
##
## 작성 규칙 (GUT와 같게 맞춰 두었다):
## - 파일 이름은 test_<대상>.gd, 테스트 함수 이름은 test_<확인할 내용>()
## - 함수마다 새 인스턴스에서 before_each() → test_*() → after_each() 순서로 실행된다
## - assert 함수 이름과 인자 순서는 GUT(GutTest)와 같다: assert_eq(실제, 기대, 설명)
## 나중에 GUT로 옮길 때는 extends TestCase를 extends GutTest로 바꾸면 된다.

## 이번 테스트 함수에서 실패한 assert의 설명
var failures: PackedStringArray = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_eq(got: Variant, expected: Variant, text: String = "") -> void:
	if got != expected:
		_fail("기대 %s, 실제 %s" % [expected, got], text)


func assert_ne(got: Variant, not_expected: Variant, text: String = "") -> void:
	if got == not_expected:
		_fail("%s가 아니어야 하는데 같음" % [not_expected], text)


func assert_true(got: bool, text: String = "") -> void:
	if not got:
		_fail("true여야 하는데 false", text)


func assert_false(got: bool, text: String = "") -> void:
	if got:
		_fail("false여야 하는데 true", text)


func assert_almost_eq(got: float, expected: float, error_interval: float, text: String = "") -> void:
	if absf(got - expected) > error_interval:
		_fail("기대 %s ± %s, 실제 %s" % [expected, error_interval, got], text)


func _fail(reason: String, text: String) -> void:
	failures.append(reason if text.is_empty() else "%s (%s)" % [text, reason])
