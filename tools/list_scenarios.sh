#!/usr/bin/env bash
# 시나리오 테스트(tests/scenarios/scenario_*.gd)마다 무엇을 확인하는지 보여 준다 (Godot 없이 돈다).
# 설명은 각 파일 맨 위의 ## 주석이다. 이 주석이 시나리오 목록이므로, 시나리오를 바꾸면 주석도 고친다.
#   인자 없음: 파일마다 이름과 주석 첫 줄
#   인자 있음: 이름에 그 글자가 든 파일의 주석 전체 (여러 개를 줄 수 있다)
# 사용 예: bash tools/list_scenarios.sh
#          bash tools/list_scenarios.sh chest ui_click

cd "$(dirname "$0")/.." || exit 1

# 주석이 이 줄 수 안에서 시작해야 맨 위 주석으로 본다 (tests/check_rules.sh와 같다)
HEADER_START_LINES=5

files=()
for file in tests/scenarios/scenario_*.gd; do
	[ -f "$file" ] || continue
	if [ $# -eq 0 ]; then
		files+=("$file")
		continue
	fi
	name="${file##*/}"
	for part in "$@"; do
		if [[ "$name" == *"$part"* ]]; then
			files+=("$file")
			break
		fi
	done
done

if [ ${#files[@]} -eq 0 ]; then
	echo "맞는 시나리오가 없습니다: $*"
	exit 1
fi

full=1
[ $# -eq 0 ] && full=0

# 맨 위 ## 주석: 처음 나온 ## 줄부터 ##가 아닌 줄이 나오기 전까지.
# full이 1이면 주석 전체를, 0이면 내용이 있는 첫 줄만 이름 옆에 보여 준다. 주석이 없으면 그렇다고 알린다.
awk -v full="$full" -v head="$HEADER_START_LINES" '
	function finish_file() {
		if (name == "") return
		if (!shown) print name ": (설명 주석 없음)"
		else if (full == 1) print ""
	}
	FNR == 1 {
		finish_file()
		name = FILENAME
		sub(/^.*\//, "", name)
		found = 0
		shown = 0
		ended = 0
	}
	ended { next }
	/^##/ && (found || FNR <= head) {
		text = $0
		sub(/\r$/, "", text)
		sub(/^##[ \t]?/, "", text)
		found = 1
		if (full == 1) {
			if (!shown) print "== " name
			shown = 1
			print (text == "" ? "" : "  " text)
		} else if (text != "") {
			print name ": " text
			shown = 1
			ended = 1
		}
		next
	}
	found || FNR > head { ended = 1 }
	END { finish_file() }
' "${files[@]}"
