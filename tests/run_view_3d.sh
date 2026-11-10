#!/usr/bin/env bash
# 창을 띄우는 3D 화면 검사를 한 번에 돌린다 (tests/view_3d/). 약 3분 걸리고 창이 번갈아 뜬다.
# 판정이 있는 검사는 종료 코드가 0이 아니거나 출력에 SCRIPT ERROR·ERROR: 줄이 있으면 실패로 센다.
# 판정 없이 값만 재는 것(벽 가림, 벽 픽셀 흔들림)도 [측정]을 그대로 보여 준다.
# 하나라도 실패하면 종료 코드 1로 끝난다. 마지막 줄은 "화면 검사 결과: 통과" 또는 "화면 검사 결과: 실패 (<실패한 것>)".
# 사용 예: bash tests/run_view_3d.sh

cd "$(dirname "$0")/.." || exit 1

TIMEOUT_SECONDS=300
ERROR_PATTERN="SCRIPT ERROR|ERROR:"
failed=()

# 인자: 이름, 검사 파일과 사용자 인자
check() {
	local name="$1"
	shift
	echo "=== $name"
	local output
	output=$(timeout "$TIMEOUT_SECONDS" bash tools/godot.sh --fixed-fps 60 --path . -s "tests/view_3d/$@" 2>&1)
	local code=$?
	echo "$output" | grep -E "^\[|^결과|지형:|^  둘레|$ERROR_PATTERN"
	if [ $code -ne 0 ]; then
		echo "--> 종료 코드 $code"
		failed+=("$name")
	elif echo "$output" | grep -qE "$ERROR_PATTERN"; then
		echo "--> 출력에 오류 줄이 있음"
		failed+=("$name")
	fi
}

check "지형: 얕은 굴" check_terrain_3d.gd -- --scene=res://regions/shallow_cave.tscn
check "지형: 거점" check_terrain_3d.gd -- --scene=res://regions/base.tscn
check "지형: 시험 통로" check_terrain_3d.gd -- --scene=res://regions/test_corridor.tscn
check "몸과 앞벽" check_bodies_3d.gd
check "표시: 시험 지역" check_marks_3d.gd -- --scene=res://regions/test_region.tscn
check "표시: 거점" check_marks_3d.gd -- --scene=res://regions/base.tscn
check "시야" check_vision_3d.gd
check "앞벽 뒤 예고" check_vision_3d.gd -- --marks
check "걷는 동안 화면" check_camera_motion.gd
check "벽 가림" check_wall_occlusion.gd
check "벽 픽셀 흔들림" check_wall_flicker.gd -- --target=layer --mode=poses

echo "==="
if [ ${#failed[@]} -eq 0 ]; then
	echo "화면 검사 결과: 통과"
	exit 0
fi
echo "화면 검사 결과: 실패 (${failed[*]})"
exit 1
