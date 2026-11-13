#!/usr/bin/env bash
# 세션 시작 점검. Claude Code의 SessionStart hook이다 (.claude/settings.json).
# 세션을 새로 열 때, 이어서 열 때(resume, fork), /clear 할 때 돈다. 대화를 압축(compact)한 뒤에는 돌지 않는다.
# 작업 도중에 pull할지 다시 묻지 않게 하려는 것이다. 압축 뒤에도 돌리려면 settings.json의 matcher에 compact를 넣는다.
# 두 컴퓨터에서 작업하므로, 시작할 때마다 원격을 받아 와서(fetch) git 상태와 GODOT_PATH를 알려 준다.
# pull은 하지 않는다. 원격이 앞서 있으면 Claude가 pull할지 사용자에게 묻는다 (CLAUDE.md).
#
# 보는 것
#   1. 원격: git fetch --prune origin. FETCH_TIMEOUT_SECONDS 안에 안 끝나거나 실패하면 "원격 확인 실패"라고 적고,
#      마지막으로 받아 둔 정보로 계속한다. 로그인 창이나 비밀번호 질문은 띄우지 않는다 (필요하면 실패로 친다).
#   2. 지금 브랜치와 upstream(원격 브랜치)보다 앞·뒤인 커밋 수. upstream이 없으면 "원격 브랜치 없음"이라고 적고,
#      같은 이름의 원격 브랜치가 있으면 그것과 비교한다. 분리된 HEAD와 끝나지 않은 병합·리베이스도 알린다.
#   3. 커밋하지 않은 변경 수 (수정, 새 파일, 충돌. 새 폴더는 하나로 센다). 처음 MAX_LISTED_FILES개는 이름도 보여 준다.
#   4. 다른 로컬 브랜치 중 upstream보다 앞서거나 뒤처진 것, 원격에 없는 커밋이 있는 것.
#   5. 이번 fetch로 바뀐 원격 브랜치 (다른 컴퓨터에서 push한 것)와, 최근에 커밋된 원격 브랜치 몇 개.
#   6. GODOT_PATH: 없음 / 파일 없음 / 정상. 파일이 있으면 "--version"으로 버전을 읽어 GODOT_VERSION_REQUIRED와 비교한다.
#      클라우드 세션(CLAUDE_CODE_REMOTE=true)에서 GODOT_PATH가 없으면 건너뛴다 (Godot가 없는 곳이다).
#
# 출력: stdout에는 JSON 한 줄만 낸다. 다른 글이 섞이면 Claude Code가 JSON을 읽지 못하므로, 명령 출력은 모두 변수나 파일로 받는다.
#   systemMessage: 사용자에게 보이는 요약. 손볼 것만 한 줄씩 적고, 모두 괜찮으면 "이상 없음" 한 줄.
#   hookSpecificOutput.additionalContext: Claude가 읽는 전체 상태와 할 일 (원격이 앞서 있으면 pull할지 묻기, GODOT_PATH 고치는 법 안내 등).
# 언제나 종료 코드 0으로 끝난다. 예상하지 못한 오류로 결과를 못 만들면 점검이 실패했다는 짧은 JSON을 낸다.
# fetch 오류와 Godot 버전 출력은 <git 폴더>/claude-hooks/에 파일로 받는다 (.git 안이라 저장소에 올라가지 않는다).
# 직접 실행해서 출력을 볼 수 있다: bash tools/hooks/session_start.sh (저장소 폴더에서)

# 이 프로젝트의 Godot 버전. CLAUDE.md "기술 환경"의 "4.7.2 stable"과 같아야 한다. Godot를 올리면 둘을 같이 고친다.
# "$GODOT_PATH" --version 출력(예: 4.7.2.stable.official.abc123)이 이 값이거나 "이 값."으로 시작하면 맞는 버전이다.
GODOT_VERSION_REQUIRED="4.7.2.stable"
# 받아 올 원격 이름
REMOTE_NAME="origin"
# 시간 제한 (초). 넘으면 그 단계를 실패로 치고 넘어간다. Godot 버전 확인은 fetch와 함께 돈다.
# 다 합쳐도 .claude/settings.json의 SessionStart timeout(30초)보다 짧아야 한다 (각각 끝내는 데 2초가 더 걸릴 수 있다).
FETCH_TIMEOUT_SECONDS=10
GODOT_TIMEOUT_SECONDS=5
STATUS_TIMEOUT_SECONDS=5
# 목록에 보여 줄 최대 개수
MAX_LISTED_FILES=5
MAX_LISTED_BRANCHES=8
MAX_RECENT_REMOTE_BRANCHES=3
# 출력 글자 수 한도. Claude Code는 글마다 10,000자에서 자르므로 그보다 훨씬 작게 둔다.
MAX_MESSAGE_CHARS=1500
MAX_CONTEXT_CHARS=6000

# 결과를 못 만들었을 때 내는 JSON
FALLBACK_JSON='{"systemMessage":"세션 시작 점검이 실패했습니다. 저장소 폴더에서 bash tools/hooks/session_start.sh를 실행해 원인을 보세요.","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"세션 시작 점검(tools/hooks/session_start.sh)이 실패해서 git 상태와 GODOT_PATH를 모른다. 작업을 시작하기 전에 git status로 상태를 보고, 원격이 앞서 있는지 확인하지 못했다는 것을 사용자에게 말한다."}}'

case ${BASH_SOURCE[0]} in
	*/*) SCRIPT_DIR=${BASH_SOURCE[0]%/*} ;;
	*) SCRIPT_DIR=. ;;
esac
# shellcheck source=common.sh
if ! source "$SCRIPT_DIR/common.sh" 2> /dev/null; then
	printf '%s\n' "$FALLBACK_JSON"
	exit 0
fi

# ---- 모으는 결과 ----
NOTES=()          # 사용자에게 보일 줄 (손볼 것만)
STATUS=()         # Claude에게 줄 상태 줄
TODOS=()          # Claude가 할 일
UNPUSHED=()       # push하지 않은 커밋이 있는 브랜치 ("main 1개")
SUMMARY_BRANCH="" # 이상 없을 때 한 줄 요약에 쓰는 조각
SUMMARY_SYNC=""
SUMMARY_GODOT=""
RESULT_JSON=""

GIT_DIR_ABS="" # 저장소의 git 폴더 (절대 경로). git 저장소가 아니면 빈 문자열
WORK_DIR=""    # 임시 파일을 두는 곳 (<git 폴더>/claude-hooks)

FETCH_STATE="" # ok, failed, no_remote, no_timeout
FETCH_REASON=""
declare -A REMOTE_BEFORE=() # fetch 전 원격 브랜치 → 커밋
REMOTE_BEFORE_LIST=()

CURRENT_BRANCH=""
BRANCH_NAMES=()
declare -A BRANCH_OID=() BRANCH_UPSTREAM=() BRANCH_TRACK=()
REMOTE_REFS=()
declare -A REMOTE_OID=() REMOTE_DATE=()

CURRENT_AHEAD=0        # 지금 브랜치가 비교한 원격 브랜치보다 앞선 커밋 수
CURRENT_BEHIND=0       # 뒤처진 커밋 수 (pull로 받을 것)
CURRENT_REMOTE_LABEL="" # 비교한 원격 브랜치 (origin/main)
DIRTY_COUNT=0

GODOT_STATE="" # unset, skipped_remote, missing, no_timeout, running → ok, mismatch, timeout, run_failed, no_version
GODOT_PID=""
GODOT_OUT_FILE=""
GODOT_VERSION=""
GODOT_EXIT_CODE=0

# 원격과 비교한 글. 인자: 원격 브랜치(origin/main), 앞선 수, 뒤처진 수. 결과: AB_TEXT
ahead_behind_text() {
	local label=$1 ahead=$2 behind=$3
	if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
		AB_TEXT="원격($label)과 같음"
	elif [ "$behind" -eq 0 ]; then
		AB_TEXT="원격($label)보다 ${ahead}개 앞"
	elif [ "$ahead" -eq 0 ]; then
		AB_TEXT="원격($label)보다 ${behind}개 뒤"
	else
		AB_TEXT="원격($label)보다 ${ahead}개 앞, ${behind}개 뒤"
	fi
}

find_git_dir() {
	local out code
	out=$(git rev-parse --absolute-git-dir 2>&1)
	code=$?
	if [ $code -eq 0 ] && [ -n "$out" ] && [ -d "$out" ]; then
		GIT_DIR_ABS=$out
		WORK_DIR="$GIT_DIR_ABS/claude-hooks"
		[ -d "$WORK_DIR" ] || mkdir -p "$WORK_DIR" 2> /dev/null || WORK_DIR=""
		return 0
	fi
	SUMMARY_BRANCH="git 저장소 아님"
	if [ -e .git ]; then
		clip_text "${out%%$'\n'*}" 200
		STATUS+=("- git: 이 폴더를 git이 읽지 못했다 ($CLIPPED_TEXT)")
		NOTES+=("git이 이 폴더를 읽지 못했습니다: $CLIPPED_TEXT")
	else
		STATUS+=("- git: 이 폴더($PWD)는 git 저장소가 아니다")
		NOTES+=("이 폴더는 git 저장소가 아닙니다: $PWD")
	fi
}

# Godot 버전 확인을 뒤에서 시작한다 (fetch와 함께 돌려 기다리는 시간을 줄인다). 결과는 godot_finish가 본다.
godot_start() {
	if [ -z "${GODOT_PATH:-}" ]; then
		if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
			GODOT_STATE=skipped_remote
		else
			GODOT_STATE=unset
		fi
		return 0
	fi
	if [ ! -f "$GODOT_PATH" ]; then
		GODOT_STATE=missing
		return 0
	fi
	if [ -z "$TIMEOUT_BIN" ]; then
		GODOT_STATE=no_timeout
		return 0
	fi
	if [ -n "$WORK_DIR" ]; then
		GODOT_OUT_FILE="$WORK_DIR/godot_version.txt"
	else
		GODOT_OUT_FILE="${TMPDIR:-/tmp}/necro-sts-godot-version-$$.txt"
	fi
	# 출력은 파일로 받는다. 파이프로 받으면, 시간 초과로 끝낸 뒤에도 Godot가 띄운 하위 프로세스가 파이프를 잡고 있어 멈출 수 있다.
	"$TIMEOUT_BIN" -k 2 "$GODOT_TIMEOUT_SECONDS" "$GODOT_PATH" --version < /dev/null > "$GODOT_OUT_FILE" 2> /dev/null &
	GODOT_PID=$!
	GODOT_STATE=running
}

godot_finish() {
	local line count=0 version_re='^[[:space:]]*([0-9]+[.][0-9]+[^[:space:]]*)' first_output=""
	if [ "$GODOT_STATE" = running ]; then
		{ wait "$GODOT_PID"; } 2> /dev/null
		GODOT_EXIT_CODE=$?
		if [ -f "$GODOT_OUT_FILE" ]; then
			while IFS= read -r line || [ -n "$line" ]; do
				line=${line%$'\r'}
				[ -z "$first_output" ] && [ -n "$line" ] && first_output=$line
				if [[ $line =~ $version_re ]]; then
					GODOT_VERSION=${BASH_REMATCH[1]}
					break
				fi
				count=$((count + 1))
				[ $count -ge 50 ] && break
			done < "$GODOT_OUT_FILE"
			[ -n "$WORK_DIR" ] || rm -f "$GODOT_OUT_FILE" 2> /dev/null
		fi
		if [ -n "$GODOT_VERSION" ]; then
			if [[ $GODOT_VERSION == "$GODOT_VERSION_REQUIRED" || $GODOT_VERSION == "$GODOT_VERSION_REQUIRED".* ]]; then
				GODOT_STATE=ok
			else
				GODOT_STATE=mismatch
			fi
		elif [ "$GODOT_EXIT_CODE" -eq 124 ] || [ "$GODOT_EXIT_CODE" -eq 137 ]; then
			GODOT_STATE=timeout
		elif [ "$GODOT_EXIT_CODE" -ne 0 ]; then
			GODOT_STATE=run_failed
		else
			GODOT_STATE=no_version
		fi
	fi

	local required_short=${GODOT_VERSION_REQUIRED%.stable}
	local fix_todo="GODOT_PATH 문제를 사용자에게 알리고 고치는 법을 안내한다. 이 컴퓨터의 Godot ${required_short} console 실행 파일(예: Godot_v${required_short}-stable_win64_console.exe)의 전체 경로를 사용자 환경 변수 GODOT_PATH에 넣는다 (시작 메뉴의 \"계정의 환경 변수 편집\", 또는 명령 프롬프트에서 setx GODOT_PATH \"<경로>\"). 그다음 Claude Code를 완전히 닫고 다시 시작해야 반영된다. 고치기 전에는 tools/godot.sh를 쓰는 검증(tests/run_all.sh 등)이 실패한다."
	clip_text "$first_output" 120
	local shown_output=$CLIPPED_TEXT
	case $GODOT_STATE in
		ok)
			STATUS+=("- GODOT_PATH: 정상. 버전 $GODOT_VERSION (필요: $GODOT_VERSION_REQUIRED)")
			SUMMARY_GODOT="Godot $GODOT_VERSION"
			;;
		skipped_remote)
			STATUS+=("- GODOT_PATH: 클라우드 세션(CLAUDE_CODE_REMOTE)이고 GODOT_PATH가 없어 검사하지 않았다. 이 세션에서는 Godot 명령(tools/godot.sh)을 실행할 수 없을 것이다")
			SUMMARY_GODOT="Godot 검사 건너뜀(클라우드)"
			;;
		no_timeout)
			STATUS+=("- GODOT_PATH: 파일은 있다 ($GODOT_PATH). timeout 명령이 없어 버전 확인은 건너뛰었다")
			SUMMARY_GODOT="Godot 버전 확인 건너뜀"
			;;
		unset)
			STATUS+=("- GODOT_PATH: 없음 (환경 변수가 설정되지 않았다)")
			NOTES+=("GODOT_PATH 환경 변수가 없습니다. 이 컴퓨터의 Godot ${required_short} console 실행 파일 경로로 설정한 뒤 Claude Code를 다시 시작하세요.")
			TODOS+=("$fix_todo")
			;;
		missing)
			STATUS+=("- GODOT_PATH: 파일 없음 ($GODOT_PATH)")
			NOTES+=("GODOT_PATH가 가리키는 파일이 없습니다: $GODOT_PATH. 경로를 고친 뒤 Claude Code를 다시 시작하세요.")
			TODOS+=("$fix_todo")
			;;
		mismatch)
			STATUS+=("- GODOT_PATH: 버전이 다르다. $GODOT_VERSION (필요: $GODOT_VERSION_REQUIRED, 파일: $GODOT_PATH)")
			NOTES+=("Godot 버전이 다릅니다: $GODOT_VERSION (필요: $GODOT_VERSION_REQUIRED). GODOT_PATH를 ${required_short} 실행 파일로 바꾼 뒤 Claude Code를 다시 시작하세요.")
			TODOS+=("Godot 버전이 CLAUDE.md(${required_short} stable)와 다르다. 다른 버전으로 검증하면 결과를 믿을 수 없다. $fix_todo")
			;;
		timeout)
			STATUS+=("- GODOT_PATH: 파일은 있지만 \"--version\"이 ${GODOT_TIMEOUT_SECONDS}초 안에 끝나지 않았다 ($GODOT_PATH)")
			NOTES+=("Godot 버전을 확인하지 못했습니다 (${GODOT_TIMEOUT_SECONDS}초 안에 응답 없음): $GODOT_PATH")
			TODOS+=("GODOT_PATH의 Godot가 --version에 응답하지 않았다. 사용자에게 알리고, Godot console 실행 파일을 가리키는지 확인해 달라고 한다. $fix_todo")
			;;
		run_failed)
			STATUS+=("- GODOT_PATH: 실행 실패 (종료 코드 $GODOT_EXIT_CODE, 파일: $GODOT_PATH)")
			NOTES+=("Godot를 실행하지 못했습니다 (종료 코드 $GODOT_EXIT_CODE): $GODOT_PATH")
			TODOS+=("$fix_todo")
			;;
		no_version)
			STATUS+=("- GODOT_PATH: 실행은 됐지만 버전을 읽지 못했다 (출력: ${shown_output:-없음}, 파일: $GODOT_PATH)")
			NOTES+=("Godot 버전을 읽지 못했습니다: $GODOT_PATH. console 실행 파일(_console.exe)을 가리키는지 확인하세요.")
			TODOS+=("$fix_todo")
			;;
	esac
}

snapshot_remote_refs() {
	local out ref oid symref rest
	out=$(git for-each-ref --format='%(refname)%1f%(objectname)%1f%(symref)%1f' "refs/remotes/$REMOTE_NAME" 2> /dev/null)
	while IFS=$'\x1f' read -r ref oid symref rest; do
		[ -n "$ref" ] && [ -z "$symref" ] || continue
		REMOTE_BEFORE["$ref"]=$oid
		REMOTE_BEFORE_LIST+=("$ref")
	done <<< "$out"
}

fetch_remote() {
	if ! git config --get "remote.$REMOTE_NAME.url" > /dev/null 2>&1; then
		FETCH_STATE=no_remote
		STATUS+=("- 원격 확인: 건너뜀. $REMOTE_NAME 원격이 없다")
		NOTES+=("$REMOTE_NAME 원격이 없어 원격과 비교하지 못했습니다.")
		return 0
	fi
	if [ -z "$TIMEOUT_BIN" ]; then
		FETCH_STATE=no_timeout
		STATUS+=("- 원격 확인: 건너뜀. timeout 명령이 없어 fetch가 멈출 수 있다. 아래 원격 정보는 마지막으로 받아 온 때 기준이다")
		NOTES+=("timeout 명령을 찾지 못해 원격 확인을 건너뛰었습니다.")
		return 0
	fi
	snapshot_remote_refs
	local err_file=/dev/null
	[ -n "$WORK_DIR" ] && err_file="$WORK_DIR/fetch_error.txt"
	# 묻는 창을 막는다: 터미널 질문(GIT_TERMINAL_PROMPT), Git Credential Manager 창(GCM_INTERACTIVE), askpass 프로그램.
	# fetch 뒤 자동 정리(gc, maintenance)는 시간 제한에 걸려 중간에 끊기지 않게 끈다.
	# 바깥 { } 2> /dev/null은 timeout이 강제로 끝냈을 때 bash가 찍는 "Killed" 알림을 버린다.
	{
		GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never GIT_ASKPASS= SSH_ASKPASS= \
			"$TIMEOUT_BIN" -k 2 "$FETCH_TIMEOUT_SECONDS" \
			git -c gc.auto=0 -c maintenance.auto=false fetch --quiet --prune --no-recurse-submodules "$REMOTE_NAME" \
			< /dev/null > /dev/null 2> "$err_file"
	} 2> /dev/null
	local code=$?
	case $code in
		0)
			FETCH_STATE=ok
			STATUS+=("- 원격 확인: 성공 (git fetch --prune $REMOTE_NAME)")
			return 0
			;;
		124 | 137)
			FETCH_REASON="${FETCH_TIMEOUT_SECONDS}초 안에 끝나지 않음"
			;;
		*)
			read_first_line "$err_file"
			clip_text "$FIRST_LINE" 200
			FETCH_REASON="git fetch 실패${CLIPPED_TEXT:+: $CLIPPED_TEXT}"
			;;
	esac
	FETCH_STATE=failed
	STATUS+=("- 원격 확인: 실패 ($FETCH_REASON). 아래 원격 정보는 마지막으로 받아 온 때 기준이라 오래됐을 수 있다")
	NOTES+=("원격을 확인하지 못했습니다 ($FETCH_REASON). 원격과 비교한 정보는 마지막으로 받아 온 때 기준입니다.")
	TODOS+=("원격 확인에 실패해서 원격이 앞서 있는지 모른다. pull, push, 브랜치 고르기처럼 원격이 걸린 일을 하기 전에 이 점을 사용자에게 말한다.")
}

read_refs() {
	local out head ref oid symref upstream track cdate rest name
	# 앞·뒤 글(ahead 1, behind 2, gone)은 for-each-ref가 번역하지 않지만, 혹시 몰라 LC_ALL=C로 영어로 받는다.
	out=$(LC_ALL=C git for-each-ref --format='%(HEAD)%1f%(refname)%1f%(objectname)%1f%(symref)%1f%(upstream)%1f%(upstream:track,nobracket)%1f%(committerdate:unix)%1f' refs/heads "refs/remotes/$REMOTE_NAME" 2> /dev/null)
	while IFS=$'\x1f' read -r head ref oid symref upstream track cdate rest; do
		case $ref in
			refs/heads/*)
				name=${ref#refs/heads/}
				BRANCH_NAMES+=("$name")
				BRANCH_OID["$name"]=$oid
				BRANCH_UPSTREAM["$name"]=$upstream
				BRANCH_TRACK["$name"]=$track
				[ "$head" = "*" ] && CURRENT_BRANCH=$name
				;;
			refs/remotes/*)
				[ -z "$symref" ] || continue
				REMOTE_REFS+=("$ref")
				REMOTE_OID["$ref"]=$oid
				REMOTE_DATE["$ref"]=$cdate
				;;
		esac
	done <<< "$out"
}

check_operation() {
	local ops=()
	[ -f "$GIT_DIR_ABS/MERGE_HEAD" ] && ops+=("병합(merge)")
	if [ -d "$GIT_DIR_ABS/rebase-merge" ] || [ -d "$GIT_DIR_ABS/rebase-apply" ]; then
		ops+=("리베이스(rebase)")
	fi
	[ -f "$GIT_DIR_ABS/CHERRY_PICK_HEAD" ] && ops+=("cherry-pick")
	[ -f "$GIT_DIR_ABS/REVERT_HEAD" ] && ops+=("revert")
	[ -f "$GIT_DIR_ABS/BISECT_LOG" ] && ops+=("bisect")
	[ ${#ops[@]} -gt 0 ] || return 0
	join_by ", " "${ops[@]}"
	STATUS+=("- 끝나지 않은 git 작업: $JOINED_TEXT")
	NOTES+=("끝나지 않은 git 작업이 있습니다: $JOINED_TEXT.")
	TODOS+=("끝나지 않은 git 작업($JOINED_TEXT)이 있다. 다른 작업을 하기 전에 사용자에게 알리고, 끝낼지 되돌릴지 묻는다.")
}

check_current_branch() {
	if [ -z "$CURRENT_BRANCH" ]; then
		local unborn short
		unborn=$(git symbolic-ref -q --short HEAD 2> /dev/null)
		if [ -n "$unborn" ]; then
			STATUS+=("- 지금 브랜치: $unborn (아직 커밋이 없다)")
			SUMMARY_BRANCH="$unborn 브랜치"
			SUMMARY_SYNC="커밋 없음"
			return 0
		fi
		short=$(git rev-parse -q --verify --short HEAD 2> /dev/null)
		SUMMARY_BRANCH="분리된 HEAD"
		# 리베이스 중에는 HEAD가 원래 분리된다. 그때는 check_operation이 리베이스를 알리므로 따로 경고하지 않는다.
		if [ -d "$GIT_DIR_ABS/rebase-merge" ] || [ -d "$GIT_DIR_ABS/rebase-apply" ]; then
			STATUS+=("- 지금 브랜치: 없음. 리베이스 중이라 분리된 HEAD ($short)")
			SUMMARY_BRANCH="리베이스 중"
			return 0
		fi
		COUNT=$(git rev-list --count HEAD --not --branches --remotes 2> /dev/null)
		[[ $COUNT =~ ^[0-9]+$ ]] || COUNT=0
		STATUS+=("- 지금 브랜치: 없음. 분리된 HEAD ($short). 어느 브랜치·원격 브랜치에도 없는 커밋 ${COUNT}개")
		NOTES+=("브랜치가 아닌 커밋(분리된 HEAD, $short)에 있습니다. 여기서 만든 커밋은 브랜치에 남지 않습니다.")
		TODOS+=("브랜치에 있지 않다 (분리된 HEAD). 커밋하기 전에 사용자에게 알리고 어느 브랜치에서 작업할지 묻는다.")
		[ "$COUNT" -gt 0 ] && UNPUSHED+=("분리된 HEAD ${COUNT}개(브랜치에 없음)")
		return 0
	fi

	local name=$CURRENT_BRANCH
	local upstream=${BRANCH_UPSTREAM[$name]} oid=${BRANCH_OID[$name]}
	SUMMARY_BRANCH="$name 브랜치"
	case $upstream in
		refs/remotes/*)
			local label=${upstream#refs/remotes/}
			CURRENT_REMOTE_LABEL=$label
			parse_track "${BRANCH_TRACK[$name]}"
			if [ "$TRACK_GONE" -eq 1 ]; then
				count_not_on_remotes "$oid"
				STATUS+=("- 지금 브랜치: $name (원격 브랜치($label)가 원격에서 지워졌다. 어느 원격 브랜치에도 없는 커밋 ${COUNT}개)")
				NOTES+=("지금 브랜치의 원격 브랜치($label)가 원격에서 지워졌습니다.")
				[ "$COUNT" -gt 0 ] && UNPUSHED+=("$name ${COUNT}개(원격 브랜치가 지워짐)")
				SUMMARY_SYNC="원격 브랜치 지워짐"
				return 0
			fi
			CURRENT_AHEAD=$TRACK_AHEAD
			CURRENT_BEHIND=$TRACK_BEHIND
			ahead_behind_text "$label" "$CURRENT_AHEAD" "$CURRENT_BEHIND"
			STATUS+=("- 지금 브랜치: $name ($AB_TEXT)")
			SUMMARY_SYNC=$AB_TEXT
			add_pull_note
			[ "$CURRENT_AHEAD" -gt 0 ] && UNPUSHED+=("$name ${CURRENT_AHEAD}개")
			;;
		*)
			local same="refs/remotes/$REMOTE_NAME/$name"
			if [ -n "${REMOTE_OID[$same]+set}" ]; then
				local counts ahead behind
				counts=$(git rev-list --left-right --count "$oid...${REMOTE_OID[$same]}" 2> /dev/null)
				read -r ahead behind <<< "$counts"
				[[ $ahead =~ ^[0-9]+$ ]] || ahead=0
				[[ $behind =~ ^[0-9]+$ ]] || behind=0
				CURRENT_AHEAD=$ahead
				CURRENT_BEHIND=$behind
				CURRENT_REMOTE_LABEL="$REMOTE_NAME/$name"
				ahead_behind_text "$CURRENT_REMOTE_LABEL" "$ahead" "$behind"
				STATUS+=("- 지금 브랜치: $name (upstream이 설정되지 않았다. 같은 이름의 $AB_TEXT)")
				SUMMARY_SYNC=$AB_TEXT
				add_pull_note
				[ "$ahead" -gt 0 ] && UNPUSHED+=("$name ${ahead}개")
			else
				count_not_on_remotes "$oid"
				local why="원격 브랜치 없음"
				[ -n "$upstream" ] && why="upstream이 로컬 브랜치(${upstream#refs/heads/})"
				STATUS+=("- 지금 브랜치: $name ($why. 어느 원격 브랜치에도 없는 커밋 ${COUNT}개)")
				SUMMARY_SYNC="원격 브랜치 없음"
				[ "$COUNT" -gt 0 ] && UNPUSHED+=("$name ${COUNT}개(원격 브랜치 없음)")
			fi
			;;
	esac
}

check_worktree() {
	local out code
	if [ -n "$TIMEOUT_BIN" ]; then
		out=$({ "$TIMEOUT_BIN" -k 2 "$STATUS_TIMEOUT_SECONDS" git -c core.quotePath=false --no-optional-locks status --porcelain; } 2> /dev/null)
	else
		out=$(git -c core.quotePath=false --no-optional-locks status --porcelain 2> /dev/null)
	fi
	code=$?
	if [ $code -ne 0 ]; then
		STATUS+=("- 커밋하지 않은 변경: 확인 실패 (git status가 실패했거나 ${STATUS_TIMEOUT_SECONDS}초 안에 끝나지 않았다)")
		return 0
	fi
	local line xy path modified=0 untracked=0 conflicted=0 listed=() names=()
	while IFS= read -r line; do
		line=${line%$'\r'}
		[ -n "$line" ] || continue
		DIRTY_COUNT=$((DIRTY_COUNT + 1))
		xy=${line:0:2}
		path=${line:3}
		case $xy in
			'??') untracked=$((untracked + 1)) ;;
			DD | AU | UD | UA | DU | AA | UU) conflicted=$((conflicted + 1)) ;;
			*) modified=$((modified + 1)) ;;
		esac
		[ ${#listed[@]} -lt "$MAX_LISTED_FILES" ] && listed+=("    $xy $path")
		[ ${#names[@]} -lt 3 ] && names+=("$path")
	done <<< "$out"
	if [ "$DIRTY_COUNT" -eq 0 ]; then
		STATUS+=("- 커밋하지 않은 변경: 없음")
		return 0
	fi
	STATUS+=("- 커밋하지 않은 변경: ${DIRTY_COUNT}개 (수정 $modified, 새 파일 $untracked, 충돌 $conflicted)")
	STATUS+=("${listed[@]}")
	[ "$DIRTY_COUNT" -gt "$MAX_LISTED_FILES" ] && STATUS+=("    … 외 $((DIRTY_COUNT - MAX_LISTED_FILES))개")
	join_by ", " "${names[@]}"
	local note="커밋하지 않은 변경 ${DIRTY_COUNT}개: $JOINED_TEXT"
	[ "$DIRTY_COUNT" -gt ${#names[@]} ] && note+=" 외 $((DIRTY_COUNT - ${#names[@]}))개"
	[ "$conflicted" -gt 0 ] && note+=" (충돌 ${conflicted}개)"
	NOTES+=("$note")
}

check_other_branches() {
	local name upstream same why parts=() counted=0 others=0 need_list=0
	for name in "${BRANCH_NAMES[@]}"; do
		[ "$name" = "$CURRENT_BRANCH" ] && continue
		if [[ ${BRANCH_UPSTREAM[$name]} != refs/remotes/* ]] || [ "${BRANCH_TRACK[$name]}" = gone ]; then
			need_list=1
			break
		fi
	done
	[ $need_list -eq 1 ] && list_commits_not_on_remotes
	for name in "${BRANCH_NAMES[@]}"; do
		[ "$name" = "$CURRENT_BRANCH" ] && continue
		others=$((others + 1))
		upstream=${BRANCH_UPSTREAM[$name]}
		if [[ $upstream == refs/remotes/* ]]; then
			parse_track "${BRANCH_TRACK[$name]}"
			if [ "$TRACK_GONE" -eq 0 ]; then
				if [ "$TRACK_AHEAD" -gt 0 ] || [ "$TRACK_BEHIND" -gt 0 ]; then
					ahead_behind_text "${upstream#refs/remotes/}" "$TRACK_AHEAD" "$TRACK_BEHIND"
					parts+=("$name ($AB_TEXT)")
					[ "$TRACK_AHEAD" -gt 0 ] && UNPUSHED+=("$name ${TRACK_AHEAD}개")
				fi
				continue
			fi
		fi
		# upstream이 없거나 원격에서 지워진 브랜치: 끝 커밋이 원격에 없는 커밋 목록에 있으면 push하지 않은 커밋이 있다.
		# 수는 브랜치마다 git을 한 번 더 불러야 해서, 목록에 보여 줄 만큼(MAX_LISTED_BRANCHES)만 센다.
		is_not_on_remotes "${BRANCH_OID[$name]}" || continue
		same="refs/remotes/$REMOTE_NAME/$name"
		if [[ $upstream == refs/remotes/* ]]; then
			why="원격 브랜치가 지워짐"
		elif [ -n "${REMOTE_OID[$same]+set}" ]; then
			why="upstream 설정 안 됨"
		else
			why="원격 브랜치 없음"
		fi
		if [ $counted -lt "$MAX_LISTED_BRANCHES" ]; then
			counted=$((counted + 1))
			count_not_on_remotes "${BRANCH_OID[$name]}"
			parts+=("$name ($why, 원격에 없는 커밋 ${COUNT}개)")
			UNPUSHED+=("$name ${COUNT}개($why)")
		else
			# 목록의 "외 N개"에 들어가므로 수는 세지 않는다
			parts+=("$name ($why)")
			UNPUSHED+=("$name($why)")
		fi
	done
	if [ $others -eq 0 ]; then
		STATUS+=("- 다른 로컬 브랜치: 없음")
		return 0
	fi
	local line
	if [ ${#parts[@]} -eq 0 ]; then
		line="- 다른 로컬 브랜치 ${others}개: 원격과 다른 것 없음"
	else
		join_by ", " "${parts[@]:0:MAX_LISTED_BRANCHES}"
		line="- 다른 로컬 브랜치 ${others}개 중 원격과 다른 것: $JOINED_TEXT"
		[ ${#parts[@]} -gt "$MAX_LISTED_BRANCHES" ] && line+=" 외 $((${#parts[@]} - MAX_LISTED_BRANCHES))개"
	fi
	STATUS+=("$line")
}

check_remote_changes() {
	[ "$FETCH_STATE" = ok ] || return 0
	local ref label short old new kind parts=() user_parts=() checked=0
	for ref in "${REMOTE_REFS[@]}"; do
		label=${ref#refs/remotes/}
		short=${ref#refs/remotes/"$REMOTE_NAME"/}
		new=${REMOTE_OID[$ref]}
		if [ -z "${REMOTE_BEFORE[$ref]+set}" ]; then
			kind="새 브랜치"
		else
			old=${REMOTE_BEFORE[$ref]}
			[ "$old" = "$new" ] && continue
			kind="새 커밋"
			if [ $checked -lt "$MAX_LISTED_BRANCHES" ]; then
				checked=$((checked + 1))
				git merge-base --is-ancestor "$old" "$new" 2> /dev/null || kind="강제로 바뀜(force push)"
			fi
		fi
		parts+=("$label ($kind)")
		[ "$label" = "$CURRENT_REMOTE_LABEL" ] || user_parts+=("$short($kind)")
	done
	for ref in "${REMOTE_BEFORE_LIST[@]}"; do
		[ -n "${REMOTE_OID[$ref]+set}" ] && continue
		label=${ref#refs/remotes/}
		parts+=("$label (원격에서 지워짐)")
		# 지금 브랜치의 원격 브랜치가 지워진 것은 check_current_branch가 따로 알린다
		[ "$label" = "$CURRENT_REMOTE_LABEL" ] || user_parts+=("${ref#refs/remotes/"$REMOTE_NAME"/}(지워짐)")
	done
	if [ ${#parts[@]} -eq 0 ]; then
		STATUS+=("- 이번 fetch로 바뀐 원격 브랜치: 없음")
		return 0
	fi
	join_by ", " "${parts[@]:0:MAX_LISTED_BRANCHES}"
	local line="- 이번 fetch로 바뀐 원격 브랜치: $JOINED_TEXT"
	[ ${#parts[@]} -gt "$MAX_LISTED_BRANCHES" ] && line+=" 외 $((${#parts[@]} - MAX_LISTED_BRANCHES))개"
	STATUS+=("$line")
	[ ${#user_parts[@]} -gt 0 ] || return 0
	join_by ", " "${user_parts[@]:0:MAX_LISTED_BRANCHES}"
	local note="원격에서 새로 받은 변경: $JOINED_TEXT"
	[ ${#user_parts[@]} -gt "$MAX_LISTED_BRANCHES" ] && note+=" 외 $((${#user_parts[@]} - MAX_LISTED_BRANCHES))개"
	NOTES+=("$note")
	TODOS+=("이번 fetch로 지금 브랜치가 아닌 원격 브랜치가 바뀌었다 ($JOINED_TEXT). 다른 컴퓨터에서 그 브랜치로 작업했을 수 있다. 어느 브랜치에서 작업할지 분명하지 않으면 작업 전에 묻는다.")
}

list_recent_remote_branches() {
	[ ${#REMOTE_REFS[@]} -gt 0 ] || return 0
	# 커밋 날짜가 늦은 것부터 몇 개. 목록이 작으므로 그냥 여러 번 훑는다. 브랜치 이름에는 공백이 없다.
	local picked=" " ref best best_date date shown i parts=()
	for ((i = 0; i < MAX_RECENT_REMOTE_BRANCHES; i++)); do
		best=""
		best_date=-1
		for ref in "${REMOTE_REFS[@]}"; do
			[[ $picked == *" $ref "* ]] && continue
			date=${REMOTE_DATE[$ref]}
			[[ $date =~ ^[0-9]+$ ]] || date=0
			if [ "$date" -gt "$best_date" ]; then
				best=$ref
				best_date=$date
			fi
		done
		[ -n "$best" ] || break
		picked+="$best "
		printf -v shown '%(%m-%d %H:%M)T' "$best_date"
		parts+=("${best#refs/remotes/} ($shown)")
	done
	join_by ", " "${parts[@]}"
	STATUS+=("- 최근에 커밋된 원격 브랜치: $JOINED_TEXT")
}

# 원격이 앞서 있다는 알림. 가장 중요한 알림이라 지금 브랜치를 볼 때 바로 넣는다 (원격 확인 결과 다음 줄에 온다).
add_pull_note() {
	[ "$CURRENT_BEHIND" -gt 0 ] || return 0
	NOTES+=("원격($CURRENT_REMOTE_LABEL)에 받지 않은 커밋 ${CURRENT_BEHIND}개가 있습니다. 작업 전에 pull할지 정하세요.")
}

# pull할지 묻는 할 일. 커밋하지 않은 변경 수를 본 뒤에 만들고, 할 일 맨 앞에 둔다.
add_pull_todo() {
	[ "$CURRENT_BEHIND" -gt 0 ] || return 0
	local extra=""
	[ "$CURRENT_AHEAD" -gt 0 ] && extra+=" 로컬에도 push하지 않은 커밋이 ${CURRENT_AHEAD}개 있어 pull하면 둘을 합쳐야 한다(병합이나 rebase)는 것도 말한다."
	[ "$DIRTY_COUNT" -gt 0 ] && extra+=" 커밋하지 않은 변경이 ${DIRTY_COUNT}개 있어 pull이 멈추거나 충돌할 수 있다는 것도 말한다."
	TODOS=("지금 브랜치가 원격($CURRENT_REMOTE_LABEL)보다 ${CURRENT_BEHIND}개 뒤다. 사용자의 요청을 시작하기 전에 pull할지 선택 UI로 묻는다.$extra 사용자가 정하기 전에는 pull하지 않는다." "${TODOS[@]}")
}

add_unpushed_note() {
	[ ${#UNPUSHED[@]} -gt 0 ] || return 0
	join_by ", " "${UNPUSHED[@]:0:MAX_LISTED_BRANCHES}"
	local text=$JOINED_TEXT
	[ ${#UNPUSHED[@]} -gt "$MAX_LISTED_BRANCHES" ] && text+=" 외 $((${#UNPUSHED[@]} - MAX_LISTED_BRANCHES))개 브랜치"
	STATUS+=("- push하지 않은 커밋: $text")
	NOTES+=("push하지 않은 커밋: $text")
}

# 결과를 JSON 한 줄로 만들어 RESULT_JSON에 넣는다. 인자: 사용자에게 보일 글, Claude에게 줄 글
make_json() {
	local message context
	clip_text "$1" "$MAX_MESSAGE_CHARS"
	json_escape "$CLIPPED_TEXT"
	message=$JSON_TEXT
	clip_text "$2" "$MAX_CONTEXT_CHARS"
	json_escape "$CLIPPED_TEXT"
	context=$JSON_TEXT
	printf -v RESULT_JSON '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' "$message" "$context"
}

make_result() {
	local message context line pieces=()
	if [ ${#NOTES[@]} -eq 0 ]; then
		for line in "$SUMMARY_BRANCH" "$SUMMARY_SYNC" "$SUMMARY_GODOT"; do
			[ -n "$line" ] && pieces+=("$line")
		done
		join_by ", " "${pieces[@]}"
		message="세션 시작 점검: 이상 없음${JOINED_TEXT:+ ($JOINED_TEXT)}"
	else
		message="세션 시작 점검${SUMMARY_BRANCH:+ ($SUMMARY_BRANCH)}:"
		for line in "${NOTES[@]}"; do
			message+=$'\n'"- $line"
		done
	fi
	context="세션 시작 점검 결과 (tools/hooks/session_start.sh가 세션을 시작할 때 본 상태다. 그 뒤에 바뀐 것은 git 명령으로 다시 본다)"
	for line in "${STATUS[@]}"; do
		context+=$'\n'"$line"
	done
	if [ ${#TODOS[@]} -gt 0 ]; then
		context+=$'\n\n'"할 일:"
		for line in "${TODOS[@]}"; do
			context+=$'\n'"- $line"
		done
	fi
	context+=$'\n\n'"사용자는 이 결과의 요약을 이미 봤다. 할 일이 없으면 이 결과를 따로 말하지 않는다."
	make_json "$message" "$context"
}

main() {
	if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
		make_json "세션 시작 점검을 하지 못했습니다: bash 4 이상이 필요합니다 (지금 ${BASH_VERSION})." "세션 시작 점검(tools/hooks/session_start.sh)을 하지 못했다: bash가 너무 오래됐다 (${BASH_VERSION}). git 상태와 GODOT_PATH를 모른다."
		return 0
	fi
	find_timeout
	find_git_dir
	godot_start
	if [ -n "$GIT_DIR_ABS" ]; then
		fetch_remote
		read_refs
		check_current_branch
		check_operation
		check_worktree
		check_other_branches
		check_remote_changes
		list_recent_remote_branches
		add_pull_todo
		add_unpushed_note
	fi
	godot_finish
	make_result
}

# main의 stdout은 버린다. 결과는 RESULT_JSON으로만 받아서, 어떤 명령이 실수로 무엇을 찍어도 JSON이 깨지지 않게 한다.
main > /dev/null
if [ -n "$RESULT_JSON" ]; then
	printf '%s\n' "$RESULT_JSON"
else
	printf '%s\n' "$FALLBACK_JSON"
fi
exit 0
