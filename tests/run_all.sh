#!/usr/bin/env bash
# tests/ 안의 모든 테스트를 한 번에 돌린다.
#   1. 임포트 (새 스크립트·클래스 반영, 스크립트 오류 확인)
#   2. 단위 테스트: tests/unit/test_*.gd 전부 (한 번의 실행). 코드·씬·데이터의 색이 팔레트 안인지도 여기서 본다 (test_palette_colors.gd)
#   3. 에셋 팔레트 검사: assets/의 PNG가 팔레트 밖의 색을 쓰는지 (tools/check_palette.gd)
#   4. 시나리오 테스트: tests/scenarios/scenario_*.gd 하나씩 (각각 따로 실행)
# 종료 코드가 0이 아니거나, 출력에 SCRIPT ERROR·ERROR: 줄이 있으면(누수 경고 포함) 실패로 센다.
# 하나라도 실패하면 종료 코드 1로 끝난다.
# 사용 예: bash tests/run_all.sh

cd "$(dirname "$0")/.." || exit 1

# 테스트 하나가 멈춰도 전체가 끝나도록 실행마다 시간 제한을 둔다 (초).
TIMEOUT_SECONDS=600
ERROR_PATTERN="SCRIPT ERROR|ERROR:"
failed=()

# 인자로 받은 Godot 명령을 실행해 출력을 보여 주고, 실패하면 이름($1)을 failed에 넣는다.
run_check() {
	local name="$1"
	shift
	local output
	output=$(timeout "$TIMEOUT_SECONDS" bash tools/godot.sh "$@" 2>&1)
	local code=$?
	echo "$output"
	if [ $code -ne 0 ]; then
		echo "--> 종료 코드 $code"
		failed+=("$name")
	elif echo "$output" | grep -qE "$ERROR_PATTERN"; then
		echo "--> 출력에 오류 줄이 있음"
		failed+=("$name")
	fi
}

echo "=== 임포트"
import_errors=$(timeout "$TIMEOUT_SECONDS" bash tools/godot.sh --headless --path . --import 2>&1 | grep -E "$ERROR_PATTERN")
if [ -n "$import_errors" ]; then
	echo "$import_errors"
	failed+=("임포트")
fi

echo "=== 단위 테스트"
run_check "단위 테스트" --headless --path . -s tests/run_unit_tests.gd

echo "=== 에셋 팔레트 검사"
run_check "에셋 팔레트 검사" --headless --path . -s tools/check_palette.gd

for scenario in tests/scenarios/scenario_*.gd; do
	echo "=== 시나리오: $scenario"
	run_check "$scenario" --headless --fixed-fps 60 --path . -s "$scenario"
done

echo "==="
if [ ${#failed[@]} -eq 0 ]; then
	echo "전체 결과: 통과"
	exit 0
fi
echo "전체 결과: 실패 (${failed[*]})"
exit 1
