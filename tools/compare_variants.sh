#!/usr/bin/env bash
# 화면 비교판 도구. 한 주제의 여러 안을 같은 장면에서 같은 인자로 하나씩 찍고, 번호를 붙인 비교판 한 장과 범례로 붙인다.
# compare-variants 에이전트(.claude/agents/compare-variants.md)가 쓴다. 고른 뒤의 diff·clean은 메인 대화가 쓴다.
#
# 비교 하나 = compare/<날짜>_<주제>/ 폴더 하나. .gitignore에 있고, Godot 에디터·임포트는 compare/.gdignore 때문에, 팔레트 검사는 경로로 이 폴더를 넘어간다.
#   setups/<번호>.gd  안마다 찍기 직전에 부르는 setup (static func run(scene: Node) -> void). 에이전트가 쓴다. 번호는 1부터 빈틈없이.
#                     찍을 때 --setup=res://compare/<이름>/setups/<번호>.gd 로 넘긴다. 이 폴더의 다른 파일(공통 코드, 그림)도 써도 된다
#   labels.txt        안마다 한 줄 "<안 이름> — <무엇을 바꿨는지>" (번호 순서, UTF-8). 에이전트가 쓴다
#   worktree-<번호>/  이 번호의 안을 찍을 git worktree. HEAD에서 브랜치 compare/<이름>/<번호>로 만든다. 코드 안은 꼭 쓴다.
#                     코드 안이 있고 본 checkout에 커밋하지 않은 변경이 있으면 값 안도 써서, 모든 안이 같은 HEAD에서 찍히게 한다.
#                     CLAUDE.md와 .claude/는 빼 둔다 (Claude Code가 사본을 또 읽지 않게. git에는 바뀐 것으로 안 나온다)
#   shots/<번호>.png  찍은 그림. logs/에 Godot 출력, shot_commands.txt에 찍은 명령
#   sheet.png, sheet_legend.txt  비교판과 범례
#
# 사용법 (저장소 폴더에서):
#   bash tools/compare_variants.sh new <주제>                    비교 폴더를 만든다. 주제는 영문 소문자·숫자·하이픈 (예: pitch, wall-height)
#   bash tools/compare_variants.sh worktree <이름> <번호>        그 안의 worktree를 만든다. .worktreeinclude의 파일(구운 지형)을 복사하고 임포트한다 (1분쯤)
#   bash tools/compare_variants.sh shoot <이름> [인자...]        모든 안을 같은 인자로 찍는다. 인자는 tools/screenshot.gd의 것 (예: --scene=res://regions/shallow_cave.tscn --seconds=2)
#   bash tools/compare_variants.sh sheet <이름> [--columns=<수>]  찍은 그림과 labels.txt로 비교판과 범례를 만든다 (tools/contact_sheet.gd)
#   bash tools/compare_variants.sh diff <이름> <번호> [--stat]    코드 안이 HEAD와 다른 곳을 패치로 낸다 (새 파일 포함). 고른 안을 본 checkout에 옮길 때 쓴다
#   bash tools/compare_variants.sh list                          남아 있는 비교 폴더, worktree, compare/ 브랜치
#   bash tools/compare_variants.sh clean <이름>                  그 비교의 worktree, 브랜치, 폴더를 지운다. 사용자가 고르고 옮긴 뒤에 메인 대화가 돌린다
# <이름>은 new가 알려 준 <날짜>_<주제>다. 실패하면 종료 코드 1, 잘못 부르면 2.
# shoot: --out과 --setup은 안마다 이 도구가 붙인다. --fixed-fps 60으로 찍어 몇 프레임 뒤에 찍는지도 안마다 같다. worktree는 찍기 전에 다시 임포트한다.
# Godot에는 절대 경로를 넘긴다. Git Bash에서는 cygpath -m으로 드라이브 글자로 시작하는 Windows 꼴(슬래시)로 바꾼다 (경로에 공백이 있어도 된다).

cd "$(dirname "$0")/.." || exit 1

COMPARE_DIR="compare"
# worktree 브랜치 이름의 앞부분. tools/hooks/common.sh의 COMPARE_BRANCH_PREFIX와 같아야 한다 (push 알림에서 뺀다)
BRANCH_PREFIX="compare/"
FIXED_FPS=60
# 시간 제한 (초). 에이전트의 Bash 도구는 명령 하나를 10분까지 기다리므로, worktree(임포트 두 번까지)와 shoot이 그 안에 끝나게 둔다
SHOT_TIMEOUT_SECONDS=120
IMPORT_TIMEOUT_SECONDS=240
SHEET_TIMEOUT_SECONDS=120
# 시간 제한에 걸린 뒤에도 Godot가 안 끝나면 이만큼 더 기다렸다가 강제로 끝낸다 (초)
KILL_AFTER_SECONDS=10
ERROR_PATTERN="SCRIPT ERROR|ERROR:"
NOTE_PATTERN="SCRIPT ERROR|ERROR:|WARNING:"
# 안마다 보여 줄 오류·경고 줄 수 (나머지는 로그 파일에)
MAX_NOTE_LINES=8
TOPIC_PATTERN='^[a-z0-9][a-z0-9-]{0,39}$'
NAME_PATTERN='^[0-9]{4}-[0-9]{2}-[0-9]{2}_[a-z0-9][a-z0-9-]*$'
NUMBER_PATTERN='^[1-9][0-9]*$'
# compare/.gdignore가 없을 때 쓰는 내용 (저장소의 것과 같은 뜻. 커밋하기 전의 HEAD로 만든 worktree에는 이 파일이 없다)
GDIGNORE_TEXT="# Godot가 이 폴더를 읽지 않게 한다. 비교판 작업 폴더 (tools/compare_variants.sh)"

CYGPATH=$(type -P cygpath 2> /dev/null)

usage() {
	awk '/^# 사용법/ { on = 1; next } on && /^#/ { sub(/^# ?/, ""); print; next } on { exit }' "$0" >&2
}

fail() {
	echo "실패: $*" >&2
	exit 1
}

bad_usage() {
	echo "잘못 불렀다: $*" >&2
	usage
	exit 2
}

# Godot(Windows에서는 Windows 프로그램)에 넘길 절대 경로. Git Bash면 cygpath -m으로 Windows 꼴로 바꾼다. 인자: 경로(저장소 기준이나 절대). 결과: NATIVE_PATH
native_path() {
	local path=$1
	[[ $path == /* ]] || path="$PWD/$path"
	path=${path%/.}
	if [ -n "$CYGPATH" ]; then
		NATIVE_PATH=$("$CYGPATH" -m "$path")
	else
		NATIVE_PATH=$path
	fi
}

# 명령을 다시 붙여 넣을 수 있는 한 줄로 만든다. 공백·따옴표 등이 든 인자는 작은따옴표로 감싼다. 결과: QUOTED
quote_command() {
	local arg sq="'" esc="'\\''"
	QUOTED=""
	for arg in "$@"; do
		if [[ $arg =~ [^A-Za-z0-9_./:=,+@%-] ]]; then
			arg="'${arg//"$sq"/"$esc"}'"
		fi
		QUOTED+="${QUOTED:+ }$arg"
	done
}

# 여러 줄 글을 들여 써서 낸다. 인자: 글
print_indented() {
	local line
	while IFS= read -r line; do
		[ -n "$line" ] && echo "    ${line%$'\r'}"
	done <<< "$1"
}

# PNG의 가로×세로 (IHDR). 못 읽으면 빈 문자열. 결과: PNG_SIZE
png_size() {
	PNG_SIZE=""
	local bytes
	bytes=$(od -An -tu1 -j16 -N8 -- "$1" 2> /dev/null) || return 0
	local b=()
	read -r -a b <<< "$bytes"
	[ ${#b[@]} -eq 8 ] || return 0
	PNG_SIZE="$(((b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]))×$(((b[4] << 24) | (b[5] << 16) | (b[6] << 8) | b[7]))"
}

require_godot() {
	if [ -z "${GODOT_PATH:-}" ] || [ ! -f "$GODOT_PATH" ]; then
		fail "GODOT_PATH가 없거나 그 파일이 없다 (${GODOT_PATH:-없음}). CLAUDE.md \"검증\"대로 사용자에게 그 컴퓨터의 GODOT_PATH를 고치고 Claude Code를 다시 시작해 달라고 한다"
	fi
}

# 비교 이름을 확인하고 RUN_NAME, RUN_DIR을 정한다. 인자: 이름
require_run() {
	[ -n "${1:-}" ] || bad_usage "비교 이름이 없다 (new가 알려 준 <날짜>_<주제>)"
	[[ $1 =~ $NAME_PATTERN ]] || bad_usage "비교 이름이 <날짜>_<주제> 꼴이 아니다: $1"
	RUN_NAME=$1
	RUN_DIR="$COMPARE_DIR/$1"
	[ -d "$RUN_DIR" ] || fail "비교 폴더가 없다: $RUN_DIR (남은 것: bash tools/compare_variants.sh list)"
}

# 안 번호를 setups/<번호>.gd에서 모은다. 1부터 빈틈없어야 하고, worktree-<번호>마다 setup이 있어야 한다. 결과: VARIANTS
read_variants() {
	VARIANTS=()
	local file number max=0
	local -A seen=()
	for file in "$RUN_DIR"/setups/*.gd; do
		[ -f "$file" ] || continue
		number=${file##*/}
		number=${number%.gd}
		[[ $number =~ $NUMBER_PATTERN ]] || continue
		seen[$number]=1
		[ "$number" -gt "$max" ] && max=$number
	done
	[ "$max" -gt 0 ] || fail "안이 없다. 안마다 $RUN_DIR/setups/<번호>.gd를 1부터 쓴다"
	local missing=()
	for ((number = 1; number <= max; number++)); do
		if [ -n "${seen[$number]:-}" ]; then
			VARIANTS+=("$number")
		else
			missing+=("$number")
		fi
	done
	[ ${#missing[@]} -eq 0 ] || fail "setup 번호에 빈틈이 있다: ${missing[*]}번이 없다 ($RUN_DIR/setups/<번호>.gd, 1부터 빈틈없이)"
	local dir
	for dir in "$RUN_DIR"/worktree-*/; do
		[ -d "$dir" ] || continue
		number=${dir%/}
		number=${number##*/worktree-}
		[ -n "${seen[$number]:-}" ] || fail "${dir%/}가 있는데 $RUN_DIR/setups/$number.gd가 없다. worktree에서 찍는 안도 setup을 하나씩 쓴다 (코드 안은 보통 공통 장면만 부른다)"
	done
}

# 본 checkout의 커밋하지 않은 변경 (compare/는 .gitignore에 있어 세지 않는다). 결과: DIRTY_COUNT, DIRTY_NAMES (앞 5개)
count_dirty() {
	DIRTY_COUNT=0
	DIRTY_NAMES=()
	local line
	while IFS= read -r line; do
		[ -n "$line" ] || continue
		DIRTY_COUNT=$((DIRTY_COUNT + 1))
		[ ${#DIRTY_NAMES[@]} -lt 5 ] && DIRTY_NAMES+=("${line:3}")
	done < <(git -c core.quotePath=false status --porcelain 2> /dev/null)
}

dirty_note() {
	count_dirty
	[ "$DIRTY_COUNT" -gt 0 ] || return 0
	local more=""
	[ "$DIRTY_COUNT" -gt ${#DIRTY_NAMES[@]} ] && more=" 외 $((DIRTY_COUNT - ${#DIRTY_NAMES[@]}))개"
	echo "알림: 본 checkout에 커밋하지 않은 변경 ${DIRTY_COUNT}개 (${DIRTY_NAMES[*]}$more). $1"
}

# <프로젝트>/compare/.gdignore가 없으면 만든다. 인자: 프로젝트 폴더
ensure_gdignore() {
	local dir="$1/$COMPARE_DIR"
	mkdir -p "$dir" || return 1
	[ -f "$dir/.gdignore" ] || printf '%s\n' "$GDIGNORE_TEXT" > "$dir/.gdignore"
}

# .worktreeinclude(.gitignore 문법)에 맞고 .gitignore에도 있는 파일을 본 checkout에서 worktree로 복사한다.
# Claude Code가 worktree를 만들 때와 같은 규칙이다. 인자: worktree 폴더. 결과: COPIED (복사한 경로들)
copy_includes() {
	local wt=$1 file
	COPIED=()
	[ -f .worktreeinclude ] || return 0
	local candidates=() ignored=()
	mapfile -t candidates < <(git -c core.quotePath=false ls-files --others --ignored --exclude-from=.worktreeinclude 2> /dev/null)
	[ ${#candidates[@]} -gt 0 ] || return 0
	mapfile -t ignored < <(printf '%s\n' "${candidates[@]}" | git -c core.quotePath=false check-ignore --stdin 2> /dev/null)
	for file in "${ignored[@]}"; do
		file=${file%$'\r'}
		[ -f "$file" ] || continue
		# 비교 폴더 안(다른 worktree의 사본)은 복사하지 않는다
		[[ $file == "$COMPARE_DIR"/* ]] && continue
		[[ $file == */* ]] && mkdir -p "$wt/${file%/*}"
		cp -p -- "$file" "$wt/$file" && COPIED+=("$file")
	done
}

# worktree에서 CLAUDE.md와 .claude/ 사본을 뺀다. 저장소 안의 하위 폴더라서, Claude Code가 그 안의 파일을 다루면
# 사본 CLAUDE.md와 스킬(compare/…:view-check 같은 이름)을 또 읽어 들이기 때문이다. 게임에는 쓰지 않는 파일이다.
# 그 worktree의 색인에만 skip-worktree로 표시하므로 git은 지운 것으로 보지 않는다 (status·diff에 안 나오고, 저장소 설정은 그대로).
# 인자: worktree 폴더. 결과: HIDDEN_COUNT (뺀 파일 수)
hide_claude_files() {
	local wt=$1 files=() file
	HIDDEN_COUNT=0
	mapfile -t files < <(git -C "$wt" -c core.quotePath=false ls-files -- ':(glob)**/CLAUDE.md' ':(glob)**/.claude/**')
	[ ${#files[@]} -gt 0 ] || return 0
	git -C "$wt" update-index --skip-worktree -- "${files[@]}" || return 1
	for file in "${files[@]}"; do
		rm -f -- "$wt/$file"
	done
	[ -d "$wt/.claude" ] && rm -r -- "$wt/.claude" < /dev/null
	HIDDEN_COUNT=${#files[@]}
}

# 프로젝트를 임포트한다. 오류 줄이 나오면 한 번 더 한다 (새 폴더의 첫 임포트는 클래스 목록이 없어 오류가 날 수 있다).
# 시간 제한에 걸리면 다시 하지 않는다. 인자: 프로젝트 폴더, 로그 파일. 결과: IMPORT_ERRORS (마지막 임포트의 오류 줄). 오류가 남으면 1을 돌려준다
import_project() {
	local project=$1 log=$2 try code
	native_path "$project"
	for try in 1 2; do
		timeout -k "$KILL_AFTER_SECONDS" "$IMPORT_TIMEOUT_SECONDS" bash tools/godot.sh --headless --path "$NATIVE_PATH" --import > "$log" 2>&1
		code=$?
		IMPORT_ERRORS=$(grep -E "$ERROR_PATTERN" "$log" | head -n "$MAX_NOTE_LINES")
		[ $code -eq 0 ] && [ -z "$IMPORT_ERRORS" ] && return 0
		if [ $code -eq 124 ] || [ $code -eq 137 ]; then
			IMPORT_ERRORS="${IMPORT_TIMEOUT_SECONDS}초 안에 끝나지 않았다"$'\n'"$IMPORT_ERRORS"
			return 1
		fi
		[ $code -eq 0 ] || IMPORT_ERRORS="종료 코드 $code"$'\n'"$IMPORT_ERRORS"
	done
	return 1
}

default_columns() {
	if [ "$1" -le 3 ]; then
		DEFAULT_COLUMNS=$1
	elif [ "$1" -eq 4 ]; then
		DEFAULT_COLUMNS=2
	else
		DEFAULT_COLUMNS=3
	fi
}

cmd_new() {
	[ $# -eq 1 ] || bad_usage "new <주제> 하나를 받는다"
	local topic=$1
	[[ $topic =~ $TOPIC_PATTERN ]] || bad_usage "주제는 영문 소문자·숫자·하이픈 40자까지다 (예: pitch, wall-height): $topic"
	ensure_gdignore . || fail "$COMPARE_DIR 폴더를 만들지 못했다"
	local today name suffix=1
	today=$(date +%F)
	name="${today}_$topic"
	while [ -e "$COMPARE_DIR/$name" ]; do
		suffix=$((suffix + 1))
		name="${today}_$topic-$suffix"
	done
	mkdir -p "$COMPARE_DIR/$name/setups" "$COMPARE_DIR/$name/shots" "$COMPARE_DIR/$name/logs" || fail "폴더를 만들지 못했다: $COMPARE_DIR/$name"
	native_path "$COMPARE_DIR/$name"
	echo "비교 이름: $name"
	echo "폴더: $NATIVE_PATH"
	echo "다음: 안마다 $COMPARE_DIR/$name/setups/<번호>.gd를 쓴다 (1부터). 코드 안은 bash tools/compare_variants.sh worktree $name <번호>"
	dirty_note "본 checkout에서 찍는 안에는 이 변경이 들어가고, worktree는 HEAD에서 만들어 들어가지 않는다. 코드 안이 있으면 값 안도 worktree로 만들어 같은 바탕에서 견준다"
}

cmd_worktree() {
	[ $# -eq 2 ] || bad_usage "worktree <이름> <번호>"
	require_run "$1"
	local number=$2
	[[ $number =~ $NUMBER_PATTERN ]] || bad_usage "번호는 1 이상의 정수다: $number"
	require_godot
	local wt="$RUN_DIR/worktree-$number" branch="$BRANCH_PREFIX$RUN_NAME/$number"
	[ ! -e "$wt" ] || fail "이미 있다: $wt"
	if git show-ref --verify --quiet "refs/heads/$branch"; then
		fail "브랜치가 이미 있다: $branch (지난 비교가 남았으면 사용자에게 묻고 clean으로 지운다)"
	fi
	mkdir -p "$RUN_DIR/logs"
	local log="$RUN_DIR/logs/worktree-$number.txt"
	if ! git worktree add -b "$branch" "$wt" HEAD > "$log" 2>&1; then
		print_indented "$(cat "$log")"
		fail "git worktree add가 실패했다"
	fi
	hide_claude_files "$wt" || fail "worktree에서 CLAUDE.md와 .claude/를 빼지 못했다 ($wt)"
	copy_includes "$wt"
	ensure_gdignore "$wt"
	native_path "$wt"
	echo "worktree: $NATIVE_PATH"
	echo "브랜치: $branch ($(git rev-parse --short HEAD)에서)"
	echo "뺀 파일: CLAUDE.md와 .claude/ ${HIDDEN_COUNT}개 (Claude Code가 사본을 또 읽지 않게. git은 바뀐 것으로 보지 않는다)"
	if [ ${#COPIED[@]} -gt 0 ]; then
		echo "복사 (.worktreeinclude): ${COPIED[*]}"
	else
		echo "복사 (.worktreeinclude): 없음. 본 checkout에 맞는 파일이 없다 (구운 지형이 없으면 얕은 굴이 칸 지형으로 보인다)"
	fi
	dirty_note "이 변경은 worktree에 없다"
	echo "임포트 중 (1분쯤)..."
	if ! import_project "$wt" "$RUN_DIR/logs/import-$number.txt"; then
		echo "임포트: 실패 (로그 $RUN_DIR/logs/import-$number.txt)"
		print_indented "$IMPORT_ERRORS"
		fail "worktree는 만들었지만 임포트가 실패했다 (위 줄과 로그를 본다. shoot은 찍기 전에 다시 임포트한다)"
	fi
	echo "임포트: 오류 없음"
	echo "다음: 이 worktree 안의 파일만 고친다. shoot이 찍기 전에 다시 임포트한다"
}

cmd_shoot() {
	[ $# -ge 1 ] || bad_usage "shoot <이름> [screenshot.gd 인자...]"
	require_run "$1"
	shift
	local arg
	for arg in "$@"; do
		case $arg in
			--out=* | --setup=*) bad_usage "$arg: --out과 --setup은 안마다 이 도구가 붙인다. 안마다 다른 것은 setups/<번호>.gd에 쓴다" ;;
			--headless) bad_usage "--headless로는 3D가 그려지지 않는다" ;;
		esac
	done
	read_variants
	require_godot
	mkdir -p "$RUN_DIR/shots" "$RUN_DIR/logs"
	rm -f "$RUN_DIR"/shots/*.png "$RUN_DIR/sheet.png" "$RUN_DIR/sheet_legend.txt"
	local commands_file="$RUN_DIR/shot_commands.txt"
	quote_command "$@"
	echo "# 모든 안에 같이 넘긴 인자: --fixed-fps $FIXED_FPS -s tools/screenshot.gd -- ${QUOTED:-(screenshot.gd 기본값)}" > "$commands_file"
	echo "같이 넘기는 인자: ${QUOTED:-(없음, screenshot.gd 기본값)} (--fixed-fps $FIXED_FPS)"
	local number wt project where setup out log code notes sum problems=() in_main=() in_worktree=()
	local -A sum_owner=()
	local same=() sizes=() first_size="" size_differs=0
	for number in "${VARIANTS[@]}"; do
		wt="$RUN_DIR/worktree-$number"
		project="."
		where="본 checkout"
		if [ ! -d "$wt" ]; then
			in_main+=("$number")
		else
			project=$wt
			where="worktree $wt"
			in_worktree+=("$number")
			# setup을 worktree의 같은 자리로 복사해서 res:// 경로를 같게 한다
			ensure_gdignore "$wt"
			mkdir -p "$wt/$RUN_DIR/setups"
			cp -R "$RUN_DIR/setups/." "$wt/$RUN_DIR/setups/" || fail "setup을 $wt로 복사하지 못했다"
			if ! import_project "$wt" "$RUN_DIR/logs/import-$number.txt"; then
				echo "[$number] 임포트 오류 (로그 $RUN_DIR/logs/import-$number.txt):"
				print_indented "$IMPORT_ERRORS"
				problems+=("${number}번 임포트")
			fi
		fi
		setup="res://$RUN_DIR/setups/$number.gd"
		out="$RUN_DIR/shots/$number.png"
		log="$RUN_DIR/logs/shot-$number.txt"
		native_path "$project"
		local project_native=$NATIVE_PATH
		native_path "$out"
		local out_native=$NATIVE_PATH
		local command=(bash tools/godot.sh --fixed-fps "$FIXED_FPS" --path "$project_native" -s tools/screenshot.gd -- "--out=$out_native" "--setup=$setup" "$@")
		quote_command "${command[@]}"
		echo "$number: $QUOTED" >> "$commands_file"
		timeout -k "$KILL_AFTER_SECONDS" "$SHOT_TIMEOUT_SECONDS" "${command[@]}" > "$log" 2>&1
		code=$?
		local code_text="종료 코드 $code"
		if [ $code -eq 124 ] || [ $code -eq 137 ]; then
			code_text+=", ${SHOT_TIMEOUT_SECONDS}초 안에 끝나지 않았다"
		fi
		notes=$(grep -E "$NOTE_PATTERN" "$log" | head -n "$MAX_NOTE_LINES")
		if [ ! -s "$out" ]; then
			echo "[$number] $where: 그림이 없다 ($code_text, 로그 $log)"
			print_indented "$notes"
			problems+=("${number}번 그림 없음")
			continue
		fi
		png_size "$out"
		echo "[$number] $where · setups/$number.gd → $out_native ($PNG_SIZE)"
		print_indented "$notes"
		if [ $code -ne 0 ]; then
			echo "    $code_text (로그 $log)"
			problems+=("${number}번 종료 코드 $code")
		elif grep -qE "$ERROR_PATTERN" "$log"; then
			problems+=("${number}번 오류 줄")
		fi
		sizes+=("${number}번 $PNG_SIZE")
		[ -n "$first_size" ] || first_size=$PNG_SIZE
		[ "$PNG_SIZE" = "$first_size" ] || size_differs=1
		sum=$(cksum < "$out")
		if [ -n "${sum_owner[$sum]:-}" ]; then
			same+=("${sum_owner[$sum]}번 = ${number}번")
		else
			sum_owner[$sum]=$number
		fi
	done
	if [ $size_differs -eq 1 ]; then
		echo "알림: 그림 크기가 다르다 (${sizes[*]}). 비교판은 칸을 가장 큰 크기로 잡고 작은 그림을 칸 위쪽 가운데에 둔다"
	fi
	if [ ${#same[@]} -gt 0 ]; then
		echo "알림: 바이트까지 같은 그림이 있다: ${same[*]}. 바꾼 것이 화면에 안 나왔을 수 있다. setup이나 worktree를 다시 본다"
	fi
	if [ ${#in_worktree[@]} -gt 0 ]; then
		if [ ${#in_main[@]} -gt 0 ]; then
			dirty_note "본 checkout에서 찍은 안(${in_main[*]}번)에는 들어가고 worktree에서 찍은 안(${in_worktree[*]}번)에는 없다. 같은 바탕에서 견주려면 본 checkout에서 찍은 안도 worktree로 만든다"
		else
			dirty_note "모든 안을 worktree(HEAD)에서 찍어서 이 변경은 어느 안에도 없다"
		fi
	fi
	echo "찍은 명령: $commands_file"
	if [ ${#problems[@]} -gt 0 ]; then
		echo "찍기 결과: 문제 있음 (${problems[*]})"
		exit 1
	fi
	echo "찍기 결과: ${#VARIANTS[@]}장. 하나씩 열어 의도한 차이가 보이는지 본다"
}

cmd_sheet() {
	[ $# -ge 1 ] || bad_usage "sheet <이름> [--columns=<수>]"
	require_run "$1"
	shift
	local columns="" arg
	for arg in "$@"; do
		case $arg in
			--columns=*)
				columns=${arg#--columns=}
				[[ $columns =~ $NUMBER_PATTERN ]] || bad_usage "열 수는 1 이상의 정수다: $columns"
				;;
			*) bad_usage "모르는 인자: $arg" ;;
		esac
	done
	read_variants
	require_godot
	local labels="$RUN_DIR/labels.txt"
	[ -f "$labels" ] || fail "$labels가 없다. 안마다 한 줄 \"<안 이름> — <무엇을 바꿨는지>\"를 번호 순서로 쓴다 (UTF-8)"
	local count
	count=$(grep -cvE '^[[:space:]]*(#|$)' "$labels")
	[ "$count" -eq ${#VARIANTS[@]} ] || fail "$labels의 줄 수($count)가 안 수(${#VARIANTS[@]})와 다르다 (빈 줄과 #로 시작하는 줄은 세지 않는다)"
	local shots=() missing=() number
	for number in "${VARIANTS[@]}"; do
		if [ -s "$RUN_DIR/shots/$number.png" ]; then
			native_path "$RUN_DIR/shots/$number.png"
			shots+=("$NATIVE_PATH")
		else
			missing+=("$number")
		fi
	done
	[ ${#missing[@]} -eq 0 ] || fail "그림이 없는 안: ${missing[*]}번. shoot을 먼저 돌린다"
	if [ -z "$columns" ]; then
		default_columns ${#VARIANTS[@]}
		columns=$DEFAULT_COLUMNS
	fi
	local sheet="$RUN_DIR/sheet.png" legend="$RUN_DIR/sheet_legend.txt" log="$RUN_DIR/logs/sheet.txt"
	rm -f "$sheet" "$legend"
	native_path "$sheet"
	local sheet_native=$NATIVE_PATH
	native_path "$labels"
	timeout -k "$KILL_AFTER_SECONDS" "$SHEET_TIMEOUT_SECONDS" bash tools/godot.sh --headless --path . -s tools/contact_sheet.gd -- "--out=$sheet_native" "--columns=$columns" "--labels=$NATIVE_PATH" "${shots[@]}" > "$log" 2>&1
	local code=$?
	if [ $code -ne 0 ] || [ ! -s "$sheet" ] || [ ! -f "$legend" ] || grep -qE "$ERROR_PATTERN" "$log"; then
		print_indented "$(grep -vE '^Godot Engine' "$log" | head -n "$MAX_NOTE_LINES")"
		fail "비교판을 만들지 못했다 (종료 코드 $code, 로그 $log)"
	fi
	png_size "$sheet"
	echo "비교판: $sheet_native ($PNG_SIZE, ${#VARIANTS[@]}장, ${columns}열)"
	native_path "$legend"
	echo "범례: $NATIVE_PATH"
	print_indented "$(cat "$legend")"
}

cmd_diff() {
	[ $# -ge 2 ] && [ $# -le 3 ] || bad_usage "diff <이름> <번호> [--stat]"
	require_run "$1"
	local number=$2 stat=0
	[[ $number =~ $NUMBER_PATTERN ]] || bad_usage "번호는 1 이상의 정수다: $number"
	if [ $# -eq 3 ]; then
		[ "$3" = "--stat" ] || bad_usage "모르는 인자: $3"
		stat=1
	fi
	local wt="$RUN_DIR/worktree-$number"
	[ -d "$wt" ] || fail "$wt가 없다. 코드 안이 아니다 (값 안이면 바꾼 것은 $RUN_DIR/setups/$number.gd에 있다)"
	# 새 파일도 패치에 들어가게 intent-to-add로 적어 둔다 (그 worktree의 색인만 바뀐다). 비교 폴더(setup 사본)는 뺀다
	git -C "$wt" add --intent-to-add --all -- . ":(exclude)$COMPARE_DIR" || fail "git add --intent-to-add가 실패했다 ($wt)"
	if [ $stat -eq 1 ]; then
		git -C "$wt" -c core.quotePath=false diff --stat HEAD -- . ":(exclude)$COMPARE_DIR"
	else
		git -C "$wt" diff --binary HEAD -- . ":(exclude)$COMPARE_DIR"
	fi
}

cmd_list() {
	[ $# -eq 0 ] || bad_usage "list는 인자를 받지 않는다"
	local dir name file line found=0 count shots wts
	echo "비교 폴더 ($COMPARE_DIR/):"
	for dir in "$COMPARE_DIR"/*/; do
		[ -d "$dir" ] || continue
		name=${dir%/}
		name=${name##*/}
		[[ $name =~ $NAME_PATTERN ]] || continue
		found=1
		count=0
		shots=0
		wts=0
		for file in "$dir"setups/*.gd; do
			file=${file##*/}
			[[ ${file%.gd} =~ $NUMBER_PATTERN ]] && count=$((count + 1))
		done
		for file in "$dir"shots/*.png; do
			[ -f "$file" ] && shots=$((shots + 1))
		done
		for file in "$dir"worktree-*/; do
			[ -d "$file" ] && wts=$((wts + 1))
		done
		line="  $name: 안 ${count}개, 그림 ${shots}장"
		[ $wts -gt 0 ] && line+=", worktree ${wts}개"
		[ -f "${dir}sheet.png" ] && line+=", 비교판 있음"
		echo "$line"
	done
	[ $found -eq 1 ] || echo "  없음"
	echo "브랜치 (${BRANCH_PREFIX}…):"
	local branches
	branches=$(git for-each-ref --format='%(refname:short)' "refs/heads/${BRANCH_PREFIX%/}")
	if [ -n "$branches" ]; then
		print_indented "$branches"
	else
		echo "    없음"
	fi
	echo "git에 남은 비교 worktree:"
	local listed
	listed=$(git worktree list --porcelain 2> /dev/null | awk -v dir="$COMPARE_DIR" '
		/^worktree / {
			path = substr($0, 10)
			if (path ~ ("/" dir "/[^/]+/worktree-[0-9]+$")) print path
		}')
	if [ -n "$listed" ]; then
		print_indented "$listed"
	else
		echo "    없음"
	fi
}

cmd_clean() {
	[ $# -eq 1 ] || bad_usage "clean <이름>"
	[[ $1 =~ $NAME_PATTERN ]] || bad_usage "비교 이름이 <날짜>_<주제> 꼴이 아니다: $1"
	local name=$1 dir="$COMPARE_DIR/$1" wt branch removed=() problems=()
	for wt in "$dir"/worktree-*/; do
		[ -d "$wt" ] || continue
		wt=${wt%/}
		if git worktree remove --force "$wt" > /dev/null 2>&1; then
			removed+=("worktree $wt")
		else
			problems+=("worktree $wt를 git으로 지우지 못했다 (Godot나 탐색기가 그 폴더를 쓰는지 본다)")
		fi
	done
	if [ -d "$dir" ]; then
		if rm -r -- "$dir" < /dev/null; then
			removed+=("폴더 $dir")
		else
			problems+=("폴더 $dir를 다 지우지 못했다")
		fi
	fi
	git worktree prune 2> /dev/null
	while IFS= read -r branch; do
		[ -n "$branch" ] || continue
		if git branch -D "$branch" > /dev/null 2>&1; then
			removed+=("브랜치 $branch")
		else
			problems+=("브랜치 $branch를 지우지 못했다")
		fi
	done < <(git for-each-ref --format='%(refname:short)' "refs/heads/$BRANCH_PREFIX$name")
	if [ ${#removed[@]} -eq 0 ] && [ ${#problems[@]} -eq 0 ]; then
		echo "지울 것이 없다: $name"
		return 0
	fi
	local item
	for item in "${removed[@]}"; do
		echo "지움: $item"
	done
	for item in "${problems[@]}"; do
		echo "문제: $item"
	done
	[ ${#problems[@]} -eq 0 ] || exit 1
}

[ $# -ge 1 ] || bad_usage "명령이 없다"
command_name=$1
shift
case $command_name in
	new) cmd_new "$@" ;;
	worktree) cmd_worktree "$@" ;;
	shoot) cmd_shoot "$@" ;;
	sheet) cmd_sheet "$@" ;;
	diff) cmd_diff "$@" ;;
	list) cmd_list "$@" ;;
	clean) cmd_clean "$@" ;;
	-h | --help | help)
		usage
		exit 0
		;;
	*) bad_usage "모르는 명령: $command_name" ;;
esac
