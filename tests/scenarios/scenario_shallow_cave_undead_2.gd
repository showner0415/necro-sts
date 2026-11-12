extends ShallowCaveUndeadScenario
## 시나리오: 얕은 굴에서 언데드가 따라오기 (뒤). 앞은 scenario_shallow_cave_undead.gd, 공용 부분은 tests/shallow_cave_undead_scenario.gd.
## 9. 굴 사이를 오가는 순서의 뒤 절반: 앞 절반이 끝난 굴에서 쥐 언데드 2마리를 새로 소환해 나머지 구간을 걷는다. 굴에 닿을 때마다 2마리 모두 따라와 곁에 모인다
## 10. 앞 파일이 보지 않은 나머지 바위마다, 네크로맨서가 바위 한쪽에서 반대쪽으로 가면 언데드 2마리가 바위를 돌아 따라와 곁에 모인다


func _run_steps() -> void:
	if not _find_roles():
		return
	var route: Array[int] = _full_route()
	var split: int = _split_index(route)
	var start: int = route[split - 1] if split > 0 else _roles.cave_mouth
	if not await _start_at(start):
		return
	if not await _undead_follow(route, split, route.size(), "뒤 절반"):
		return
	if not await _around_rocks(ROCKS_IN_FIRST_PART, _layout.rocks.size(), "뒤"):
		return
	finish(true)
