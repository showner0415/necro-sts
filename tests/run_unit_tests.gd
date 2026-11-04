extends SceneTree
## tests/unit/test_*.gd를 모두 찾아, 그 안의 test_*() 함수를 하나씩 실행한다.
## 함수마다 [통과]/[실패]를 출력하고, 하나라도 실패하면 종료 코드 1로 끝난다.
##
## 보통은 tests/run_all.sh로 실행한다. 단위 테스트만 돌리려면:
##   bash tools/godot.sh --headless --path . -s tests/run_unit_tests.gd

const UNIT_DIR: String = "res://tests/unit"
const FILE_PREFIX: String = "test_"
const METHOD_PREFIX: String = "test_"


func _initialize() -> void:
	var passed: int = 0
	var failed: int = 0
	for file_name: String in DirAccess.get_files_at(UNIT_DIR):
		if not (file_name.begins_with(FILE_PREFIX) and file_name.get_extension() == "gd"):
			continue
		var script: GDScript = load(UNIT_DIR.path_join(file_name))
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method.name
			if not method_name.begins_with(METHOD_PREFIX):
				continue
			var test: TestCase = script.new()
			test.before_each()
			test.call(method_name)
			test.after_each()
			if test.failures.is_empty():
				print("[통과] %s::%s" % [file_name, method_name])
				passed += 1
			else:
				for failure: String in test.failures:
					print("[실패] %s::%s: %s" % [file_name, method_name, failure])
				failed += 1

	print("단위 테스트: 통과 %d, 실패 %d" % [passed, failed])
	if passed + failed == 0:
		print("(실행한 단위 테스트가 없습니다: %s/%s*.gd)" % [UNIT_DIR, FILE_PREFIX])
	quit(1 if failed > 0 else 0)
