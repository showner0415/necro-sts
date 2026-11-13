extends ShallowCaveUndeadScenario
## 시나리오: 얕은 굴에서 언데드가 따라오기 (앞). 뒤는 scenario_shallow_cave_undead_2.gd, 공용 부분은 tests/shallow_cave_undead_scenario.gd.
## 구조는 scenario_shallow_cave.gd, 걷기는 scenario_shallow_cave_walk.gd.
## 9. 몬스터를 없애고 동굴 입구에서 쥐 언데드 2마리를 소환한다. 이어진 두 굴 사이를 모두 한 번씩 오가는 순서(PNG의 굴 연결에서 만든다)의 앞 절반을 걷는다.
##    굴에 닿을 때마다 2마리 모두 따라와 곁에 모인다 (휘어진 통로에서 걸리지 않음)
## 10. 모든 바위가 윤곽에서도 남는다. 바위를 굴 순서로 가까운 것부터 돌며(_rock_order) 앞 ROCKS_IN_FIRST_PART개 바위마다,
##     네크로맨서가 바위 한쪽에서 반대쪽으로 가면 언데드 2마리가 바위를 돌아 따라와 곁에 모인다
## 단계마다 걸린 실제 시간·게임 시간을 [시간] 줄로 출력한다 (판정 없음)


func _run_steps() -> void:
	_phase_begin()
	if not _find_roles():
		return
	var route: Array[int] = _full_route()
	var split: int = _split_index(route)
	var started: bool = await _start_at(_roles.cave_mouth)
	_phase_end("준비 (씬 준비 → 소환)")
	if not started:
		return
	_phase_begin()
	var followed: bool = await _undead_follow(route, 0, split, "앞 절반")
	_phase_end("통로")
	if not followed:
		return
	_phase_begin()
	var rounded: bool = await _around_rocks(_rock_order(route[split - 1]), 0, ROCKS_IN_FIRST_PART, "앞")
	_phase_end("바위")
	if not rounded:
		return
	print("[시간] 엔진 시작부터 끝까지: 실제 %.1f초" % (Time.get_ticks_msec() / 1000.0))
	finish(true)
