#!/usr/bin/env bash
# 응답 끝 점검. Claude Code의 Stop hook이다 (.claude/settings.json). Claude가 응답을 끝낼 때마다 돌므로 조용하고 빠르게 돈다.
# 원격을 받아 오지 않는다 (fetch 없음). 이 컴퓨터가 마지막으로 받아 온 원격 정보와 비교한다.
# 보통은 git을 두 번만 부른다. 브랜치가 많아도 늘지 않고, 알릴 때만 보여 줄 브랜치의 커밋 수를 센다.
#
# push하지 않은 커밋이 있으면 사용자에게 한 번 알린다. 다른 컴퓨터로 옮기기 전에 push를 잊지 않게 하려는 것이다.
#   알리는 브랜치
#     upstream(원격 브랜치)이 있으면: upstream보다 앞선 커밋이 있을 때
#     upstream이 없거나 원격에서 지워졌으면: 어느 원격 브랜치에도 없는 커밋이 있을 때
#     분리된 HEAD: 어느 브랜치·원격 브랜치에도 없는 커밋이 있을 때
#     비교판 도구가 만든 compare/… 브랜치는 원격에 올리지 않는 임시 브랜치라 알리지 않는다 (COMPARE_BRANCH_PREFIX)
#   같은 상태로는 한 번만 알린다. 알린 상태(브랜치마다 이름, 끝 커밋, 종류)를 <git 폴더>/claude-hooks/stop_unpushed.txt에 적어 두고,
#   그 내용이 바뀌었을 때만 다시 알린다 (새 커밋, 다른 브랜치의 커밋, 브랜치 하나만 push 등).
#   push해서 알릴 것이 없어지면 그 파일을 비우고 아무것도 내지 않는다.
#   원격이 하나도 없는 저장소와 git 저장소가 아닌 폴더에서는 아무것도 하지 않는다.
#
# 출력: 알릴 때만 stdout에 {"systemMessage": "..."} 한 줄. 사용자에게만 보이고 Claude는 계속 일하지 않는다.
#   decision, reason, additionalContext는 내지 않는다. Stop에서 이것들은 Claude가 멈추지 않고 계속 일하게 만든다.
# 언제나 종료 코드 0으로 끝난다 (Stop에서 종료 코드 2는 Claude를 계속 일하게 한다). 예상하지 못한 오류가 나면 아무것도 내지 않는다.
# 직접 실행해 볼 수 있다: bash tools/hooks/stop_check.sh (저장소 폴더에서). 알린 것으로 기록되므로 두 번째부터는 조용하다.
# 다시 알리게 하려면 .git/claude-hooks/stop_unpushed.txt를 지운다.

# 알림에 보여 줄 최대 브랜치 수
MAX_LISTED_BRANCHES=5
# 알림 글자 수 한도
MAX_MESSAGE_CHARS=1000
STATE_FILE_NAME="stop_unpushed.txt"

case ${BASH_SOURCE[0]} in
	*/*) SCRIPT_DIR=${BASH_SOURCE[0]%/*} ;;
	*) SCRIPT_DIR=. ;;
esac
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh" 2> /dev/null || exit 0

RESULT_JSON=""

# 알린 상태를 지운다 (파일을 비운다). 비어 있으면 손대지 않는다.
clear_state() {
	[ -s "$1" ] && : > "$1" 2> /dev/null
	return 0
}

main() {
	local git_dir
	git_dir=$(git rev-parse --absolute-git-dir 2> /dev/null) || return 0
	[ -n "$git_dir" ] && [ -d "$git_dir" ] || return 0
	local state_dir="$git_dir/claude-hooks"
	local state_file="$state_dir/$STATE_FILE_NAME"

	local out
	out=$(LC_ALL=C git for-each-ref --format='%(HEAD)%1f%(refname)%1f%(objectname)%1f%(upstream)%1f%(upstream:track,nobracket)%1f' refs/heads refs/remotes 2> /dev/null) || return 0

	local head ref oid upstream track rest on_branch=0 has_remote_refs=0 need_list=0
	local names=() oids=() upstreams=() tracks=()
	# 원격 브랜치 이름 모음 (원격 이름은 뗀다). 브랜치 이름에는 공백이 없으므로 " 이름 "으로 찾는다.
	local remote_names=" "
	while IFS=$'\x1f' read -r head ref oid upstream track rest; do
		case $ref in
			refs/heads/*)
				names+=("${ref#refs/heads/}")
				oids+=("$oid")
				upstreams+=("$upstream")
				tracks+=("$track")
				[ "$head" = "*" ] && on_branch=1
				[[ $ref == "refs/heads/$COMPARE_BRANCH_PREFIX"* ]] && continue
				[[ $upstream == refs/remotes/* ]] && [ "$track" != gone ] || need_list=1
				;;
			refs/remotes/*)
				has_remote_refs=1
				remote_names+="${ref#refs/remotes/*/} "
				;;
		esac
	done <<< "$out"

	if [ $has_remote_refs -eq 0 ] && [ -z "$(git remote 2> /dev/null)" ]; then
		clear_state "$state_file"
		return 0
	fi
	# upstream이 없거나 지워진 브랜치가 있을 때만, 원격에 없는 커밋 목록을 한 번에 받는다
	[ $need_list -eq 1 ] && list_commits_not_on_remotes

	# 알릴 것: 브랜치마다 이름, 끝 커밋, 종류, 수(upstream보다 앞선 것만 바로 안다. 나머지는 알릴 때 센다), 붙일 말
	local item_names=() item_oids=() item_kinds=() item_counts=() item_suffixes=() i
	for i in "${!names[@]}"; do
		[[ ${names[i]} == "$COMPARE_BRANCH_PREFIX"* ]] && continue
		if [[ ${upstreams[i]} == refs/remotes/* ]] && [ "${tracks[i]}" != gone ]; then
			parse_track "${tracks[i]}"
			if [ "$TRACK_AHEAD" -gt 0 ]; then
				item_names+=("${names[i]}")
				item_oids+=("${oids[i]}")
				item_kinds+=(ahead)
				item_counts+=("$TRACK_AHEAD")
				item_suffixes+=("")
			fi
			continue
		fi
		is_not_on_remotes "${oids[i]}" || continue
		item_names+=("${names[i]}")
		item_oids+=("${oids[i]}")
		item_counts+=("")
		if [[ ${upstreams[i]} == refs/remotes/* ]]; then
			item_kinds+=(gone)
			item_suffixes+=("(원격 브랜치가 지워짐)")
		elif [[ $remote_names == *" ${names[i]} "* ]]; then
			item_kinds+=(local)
			item_suffixes+=("(upstream 설정 안 됨)")
		else
			item_kinds+=(local)
			item_suffixes+=("(원격 브랜치 없음)")
		fi
	done

	if [ $on_branch -eq 0 ]; then
		local head_oid
		head_oid=$(git rev-parse -q --verify HEAD 2> /dev/null)
		if [ -n "$head_oid" ]; then
			COUNT=$(git rev-list --count "$head_oid" --not --branches --remotes 2> /dev/null)
			[[ $COUNT =~ ^[0-9]+$ ]] || COUNT=0
			if [ "$COUNT" -gt 0 ]; then
				item_names+=("분리된 HEAD")
				item_oids+=("$head_oid")
				item_kinds+=(detached)
				item_counts+=("$COUNT")
				item_suffixes+=("(브랜치에 없음)")
			fi
		fi
	fi

	if [ ${#item_names[@]} -eq 0 ]; then
		clear_state "$state_file"
		return 0
	fi

	# 상태: 브랜치마다 "이름<탭>끝 커밋<탭>종류" 한 줄. for-each-ref가 이름 순으로 주므로 순서가 늘 같다.
	local state=""
	for i in "${!item_names[@]}"; do
		state+="${item_names[i]}"$'\t'"${item_oids[i]}"$'\t'"${item_kinds[i]}"$'\n'
	done
	local old_state=""
	[ -f "$state_file" ] && IFS= read -r -d '' old_state < "$state_file"
	[ "$old_state" = "$state" ] && return 0

	# 상태를 적지 못하면 알리지 않는다. 적지 못한 채 알리면 응답마다 같은 알림이 뜬다.
	[ -d "$state_dir" ] || mkdir -p "$state_dir" 2> /dev/null || return 0
	printf '%s' "$state" 2> /dev/null > "$state_file" || return 0

	local shown=()
	for i in "${!item_names[@]}"; do
		[ ${#shown[@]} -lt "$MAX_LISTED_BRANCHES" ] || break
		if [ -z "${item_counts[i]}" ]; then
			count_not_on_remotes "${item_oids[i]}"
			item_counts[i]=$COUNT
		fi
		shown+=("${item_names[i]} ${item_counts[i]}개${item_suffixes[i]}")
	done
	join_by ", " "${shown[@]}"
	local message="push하지 않은 커밋이 있습니다: $JOINED_TEXT"
	[ ${#item_names[@]} -gt ${#shown[@]} ] && message+=" 외 $((${#item_names[@]} - ${#shown[@]}))개 브랜치"
	message+=". 다른 컴퓨터로 옮기기 전에 push하세요."
	clip_text "$message" "$MAX_MESSAGE_CHARS"
	json_escape "$CLIPPED_TEXT"
	printf -v RESULT_JSON '{"systemMessage":"%s"}' "$JSON_TEXT"
}

# main의 stdout은 버린다. 결과는 RESULT_JSON으로만 받아서, 어떤 명령이 실수로 무엇을 찍어도 JSON이 깨지지 않게 한다.
main > /dev/null
[ -n "$RESULT_JSON" ] && printf '%s\n' "$RESULT_JSON"
exit 0
