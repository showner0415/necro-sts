#!/usr/bin/env bash
# tools/hooks/의 hook 스크립트(session_start.sh, stop_check.sh)가 같이 쓰는 함수. source로 불러오고, 혼자 실행하지 않는다.
# 함수는 결과를 전역 변수에 넣는다. $(...)로 받으면 subshell이 하나 더 생기는데, Windows(Git Bash)에서는 이것도 느리다.
# git·timeout 말고는 bash 기본 기능만 쓴다 (jq, python, sed, awk 없이 돈다).

# 비교판 도구(tools/compare_variants.sh)가 worktree마다 HEAD에서 만드는 브랜치 이름의 앞부분. 그 도구의 BRANCH_PREFIX와 같아야 한다.
# 원격에 올리지 않는 임시 브랜치라 push 알림에서 뺀다.
COMPARE_BRANCH_PREFIX="compare/"

# JSON 제어 문자 표. \b \t \n \f \r 말고 나머지 제어 문자(0x01~0x1f)는 \u00XX로 쓴다. bash 문자열에는 0x00이 들어가지 않는다.
JSON_CONTROL_CHARS=()
JSON_CONTROL_CODES=()
for _json_code in 1 2 3 4 5 6 7 11 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31; do
	printf -v _json_hex '%02x' "$_json_code"
	printf -v _json_char "\\x$_json_hex"
	JSON_CONTROL_CHARS+=("$_json_char")
	JSON_CONTROL_CODES+=("\\u00$_json_hex")
done
unset _json_code _json_hex _json_char

# 글을 JSON 문자열 안에 넣을 수 있게 바꾼다 (앞뒤 따옴표는 붙이지 않는다). 결과: JSON_TEXT
# \ 와 " 와 제어 문자(줄바꿈, 탭 등)를 바꾼다. 한글처럼 ASCII가 아닌 글자는 그대로 둔다 (JSON은 UTF-8 글자를 그대로 받는다).
# 바꿀 글자와 바꿀 내용은 따옴표로 감싼 변수로 쓴다. 그래야 bash 버전(5.2의 patsub_replacement 등)과 관계없이 글자 그대로 바뀐다.
json_escape() {
	local text=$1 i
	local backslash='\' quote='"'
	text=${text//"$backslash"/"$backslash$backslash"}
	text=${text//"$quote"/"$backslash$quote"}
	text=${text//$'\n'/"${backslash}n"}
	text=${text//$'\r'/"${backslash}r"}
	text=${text//$'\t'/"${backslash}t"}
	text=${text//$'\b'/"${backslash}b"}
	text=${text//$'\f'/"${backslash}f"}
	for i in "${!JSON_CONTROL_CHARS[@]}"; do
		if [[ $text == *"${JSON_CONTROL_CHARS[i]}"* ]]; then
			text=${text//"${JSON_CONTROL_CHARS[i]}"/"${JSON_CONTROL_CODES[i]}"}
		fi
	done
	JSON_TEXT=$text
}

# 글자 수가 max보다 많으면 잘라서 끝에 표시를 붙인다. 결과: CLIPPED_TEXT
# 인자: 글, 최대 글자 수
clip_text() {
	local text=$1 max=$2
	if [ "${#text}" -gt "$max" ]; then
		text="${text:0:max} …(생략)"
	fi
	CLIPPED_TEXT=$text
}

# 파일에서 내용이 있는 첫 줄. 줄 끝의 \r(Windows 출력)은 뗀다. 파일이 없거나 비었으면 빈 문자열. 결과: FIRST_LINE
read_first_line() {
	FIRST_LINE=""
	local line
	[ -r "$1" ] || return 0
	while IFS= read -r line || [ -n "$line" ]; do
		line=${line%$'\r'}
		if [ -n "${line//[[:space:]]/}" ]; then
			FIRST_LINE=$line
			return 0
		fi
	done < "$1"
	return 0
}

# 항목들을 구분자로 잇는다. 인자: 구분자, 항목들. 결과: JOINED_TEXT
join_by() {
	local separator=$1 first=1 item
	shift
	JOINED_TEXT=""
	for item in "$@"; do
		if [ $first -eq 1 ]; then
			JOINED_TEXT=$item
			first=0
		else
			JOINED_TEXT+="$separator$item"
		fi
	done
}

# git for-each-ref의 %(upstream:track,nobracket) 글을 읽는다: "ahead 1, behind 2", "gone", 빈 글(같음).
# 결과: TRACK_AHEAD, TRACK_BEHIND (수), TRACK_GONE (upstream이 원격에서 지워졌으면 1)
parse_track() {
	local track=$1 re_ahead='ahead ([0-9]+)' re_behind='behind ([0-9]+)'
	TRACK_AHEAD=0
	TRACK_BEHIND=0
	TRACK_GONE=0
	if [ "$track" = "gone" ]; then
		TRACK_GONE=1
		return 0
	fi
	[[ $track =~ $re_ahead ]] && TRACK_AHEAD=${BASH_REMATCH[1]}
	[[ $track =~ $re_behind ]] && TRACK_BEHIND=${BASH_REMATCH[1]}
	return 0
}

# 커밋에서 닿는 커밋 중 어느 원격 브랜치(refs/remotes/)에도 없는 것의 수. 인자: 커밋 해시. 결과: COUNT (실패하면 0)
# 브랜치 이름 대신 해시를 넘긴다. 한글 브랜치 이름을 Windows 프로그램 인자로 넘기다 깨질 일이 없다.
count_not_on_remotes() {
	COUNT=$(git rev-list --count "$1" --not --remotes 2> /dev/null)
	[[ $COUNT =~ ^[0-9]+$ ]] || COUNT=0
	return 0
}

# 로컬 브랜치의 커밋 중 어느 원격 브랜치에도 없는 커밋의 해시 목록을 한 번에 받는다. 결과: COMMITS_NOT_ON_REMOTES
# 브랜치가 많아도 git을 한 번만 부르려는 것이다 (Windows에서는 git 한 번이 수십 ms 걸린다).
list_commits_not_on_remotes() {
	COMMITS_NOT_ON_REMOTES=$'\n'"$(git rev-list --branches --not --remotes 2> /dev/null)"$'\n'
}

# 커밋이 위 목록에 있는지. 브랜치의 끝 커밋이 있으면 그 브랜치에 원격에 없는 커밋이 있다
# (끝 커밋이 어느 원격 브랜치에서 닿으면 그 앞의 커밋도 모두 닿는다). 인자: 커밋 해시
is_not_on_remotes() {
	[[ $COMMITS_NOT_ON_REMOTES == *$'\n'"$1"$'\n'* ]]
}

# GNU timeout 명령을 찾는다. 못 찾으면 빈 문자열. 결과: TIMEOUT_BIN
# Git Bash와 Linux에는 /usr/bin/timeout이 있다. Windows의 System32\timeout.exe는 이름만 같고 기다리기만 하는 다른 명령이라 쓰지 않는다.
find_timeout() {
	TIMEOUT_BIN=""
	local candidate
	for candidate in /usr/bin/timeout /bin/timeout; do
		if [ -x "$candidate" ]; then
			TIMEOUT_BIN=$candidate
			return 0
		fi
	done
	candidate=$(type -P timeout 2> /dev/null)
	case $candidate in
		"" | *[Ss][Yy][Ss][Tt][Ee][Mm]32* | *[Ss][Yy][Ss][Ww][Oo][Ww]64*) ;;
		*) TIMEOUT_BIN=$candidate ;;
	esac
	return 0
}
