extends ShallowCaveUndeadScenario
## 시나리오: 얕은 굴에서 언데드가 따라오기 (뒤). 앞은 scenario_shallow_cave_undead.gd, 공용 부분은 tests/shallow_cave_undead_scenario.gd.
## 9. 굴 사이를 오가는 순서의 뒤 절반: 앞 절반이 끝난 굴에서 쥐 언데드 2마리를 새로 소환해 나머지 구간을 걷는다. 굴에 닿을 때마다 2마리 모두 따라와 곁에 모인다
## 10. 앞 파일과 같은 바위 순서(_rock_order)에서 앞 파일이 보지 않은 나머지 바위마다, 네크로맨서가 바위 한쪽에서 반대쪽으로 가면 언데드 2마리가 바위를 돌아 따라와 곁에 모인다
## 11. 지금 굴에서 굴 연결로 가장 먼 굴까지 멈추지 않고 한 번에 걸으면 언데드 2마리가 따라와 곁에 모인다
## 단계마다 걸린 실제 시간·게임 시간을 [시간] 줄로 출력한다 (판정 없음)


func _run_steps() -> void:
	_phase_begin()
	if not _find_roles():
		return
	var route: Array[int] = _full_route()
	var split: int = _split_index(route)
	var started: bool = await _start_at(route[split - 1])
	_phase_end("준비 (씬 준비 → 소환)")
	if not started:
		return
	_phase_begin()
	var followed: bool = await _undead_follow(route, split, route.size(), "뒤 절반")
	_phase_end("통로")
	if not followed:
		return
	if ROCKS_IN_FIRST_PART < _layout.rocks.size():
		_phase_begin()
		var rounded: bool = await _around_rocks(_rock_order(route[split - 1]), ROCKS_IN_FIRST_PART, _layout.rocks.size(), "뒤")
		_phase_end("바위")
		if not rounded:
			return
	_phase_begin()
	var long_followed: bool = await _long_follow()
	_phase_end("먼 거리")
	if not long_followed:
		return
	print("[시간] 엔진 시작부터 끝까지: 실제 %.1f초" % (Time.get_ticks_msec() / 1000.0))
	finish(true)
