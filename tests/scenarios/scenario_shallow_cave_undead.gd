extends ShallowCaveUndeadScenario
## 시나리오: 얕은 굴에서 언데드가 따라오기 (앞). 뒤는 scenario_shallow_cave_undead_2.gd, 공용 부분은 tests/shallow_cave_undead_scenario.gd.
## 구조는 scenario_shallow_cave.gd, 걷기는 scenario_shallow_cave_walk.gd.
## 9. 몬스터를 없애고 동굴 입구에서 쥐 언데드 2마리를 소환한다. 이어진 두 굴 사이를 모두 한 번씩 오가는 순서(PNG의 굴 연결에서 만든다)의 앞 절반을 걷는다.
##    굴에 닿을 때마다 2마리 모두 따라와 곁에 모인다 (휘어진 통로에서 걸리지 않음)
## 10. 모든 바위가 윤곽에서도 남는다. 앞 ROCKS_IN_FIRST_PART개 바위마다, 네크로맨서가 바위 한쪽에서 반대쪽으로 가면 언데드 2마리가 바위를 돌아 따라와 곁에 모인다


func _run_steps() -> void:
	if not _find_roles():
		return
	var route: Array[int] = _full_route()
	if not await _start_at(_roles.cave_mouth):
		return
	if not await _undead_follow(route, 0, _split_index(route), "앞 절반"):
		return
	if not await _around_rocks(0, ROCKS_IN_FIRST_PART, "앞"):
		return
	finish(true)
