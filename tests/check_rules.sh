#!/usr/bin/env bash
# 저장소 규칙 검사. Godot 없이 몇 초 안에 끝난다. tests/run_all.sh가 맨 처음에 돌리고, 혼자 돌려도 된다.
# 검사마다 함수 하나(check_<내용>)이고, 결과는 검사마다 한 줄이다. 자세한 줄은 그 아래에 들여 써서 보여 준다.
#   [통과] <이름>
#   [실패] <이름>: <무엇이 문제인지와 고치는 법>
# 마지막 줄은 "규칙 검사 결과: 통과" 또는 "규칙 검사 결과: 실패 (<이름들>)". 하나라도 실패하면 종료 코드 1.
# 검사를 더하려면: check_<내용> 함수를 만들어 그 안에서 pass_check나 fail_check를 한 번 부르고, 맨 아래 CHECKS 목록에 넣는다.
# 사용 예: bash tests/check_rules.sh

cd "$(dirname "$0")/.." || exit 1

# CLAUDE.md 크기 한도 (바이트). 2026-11-13에 나눈 뒤의 크기(18052)에 약 40% 여유를 두고 반올림한 값
CLAUDE_MD_MAX_BYTES=25000
# 시나리오 설명 주석은 파일 맨 위 이 줄 수 안에서 시작해야 한다 (tools/list_scenarios.sh와 같다)
SCENARIO_HEADER_LINES=5
# 문서에 적었지만 저장소에 없어도 되는 경로. 컴퓨터마다 만드는 파일이라 .gitignore에 있다. 경로마다 이유를 적는다.
MISSING_OK_PATHS=(
	"regions/shallow_cave_terrain.res" # 구운 동굴 지형. tools/map_png/make_cave_outline.gd로 만든다
)
# 경로로 보는 확장자. / 없이 파일 이름만 적은 것도 이 확장자로 끝나면 저장소에서 그 이름의 파일을 찾는다
PATH_EXTENSIONS="gd|tscn|tres|res|md|sh|png|json|cfg|hex|zip|svg|import|uid|py|blend|txt|godot"

failed=()

# 인자: 이름, (있으면) 자세한 줄들
pass_check() {
	echo "[통과] $1"
	shift
	local line
	for line in "$@"; do
		echo "    $line"
	done
}

# 인자: 이름, 무엇이 문제인지와 고치는 법, (있으면) 자세한 줄들
fail_check() {
	local name="$1"
	echo "[실패] $name: $2"
	shift 2
	local line
	for line in "$@"; do
		echo "    $line"
	done
	failed+=("$name")
}

# 저장소 파일 목록: git이 보는 파일(올린 것 + 아직 안 올렸지만 무시하지 않는 것). git이 없으면 find로 찾는다.
list_repo_files() {
	if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
		git -c core.quotePath=false ls-files --cached --others --exclude-standard
	else
		find . \( -name .git -o -name .godot \) -prune -o -type f -print | sed 's|^\./||'
	fi
}

# CLAUDE.md는 모든 세션이 읽는다. 언제나 지킬 규칙과 매번 쓰는 명령만 두어 짧게 유지한다.
check_claude_md_size() {
	local name="CLAUDE.md 크기"
	if [ ! -f CLAUDE.md ]; then
		fail_check "$name" "CLAUDE.md가 없다"
		return
	fi
	local size
	size=$(wc -c < CLAUDE.md)
	size=$((size))
	if [ "$size" -gt "$CLAUDE_MD_MAX_BYTES" ]; then
		fail_check "$name" "${size}바이트로 한도 ${CLAUDE_MD_MAX_BYTES}바이트를 넘었다. 특정 작업에만 필요한 설명은 맞는 스킬(.claude/skills/<이름>/SKILL.md)이나 도구의 머리 주석으로 옮기고, CLAUDE.md에는 언제나 지켜야 하는 규칙과 매번 쓰는 명령만 남긴다"
	else
		pass_check "$name" "${size} / ${CLAUDE_MD_MAX_BYTES}바이트"
	fi
}

# 스킬(.claude/skills/<폴더>/SKILL.md)은 맨 위 머리말의 name과 description으로 불린다.
check_skill_frontmatter() {
	local name="스킬 머리말"
	local problems=() skills=() files=()
	local dir file
	for dir in .claude/skills/*/; do
		[ -d "$dir" ] || continue
		file="${dir}SKILL.md"
		if [ ! -s "$file" ]; then
			problems+=("${file}: 파일이 없거나 비어 있다")
			continue
		fi
		files+=("$file")
	done
	local where state skill_name has_description folder
	if [ ${#files[@]} -gt 0 ]; then
		# 파일마다 한 줄: "<파일>\t<머리말 상태>\t<name>\t<description 있음>"
		# 머리말 상태: 1 = --- 로 열고 닫음, 0 = 닫는 --- 가 없음, -1 = 첫 줄이 --- 가 아님
		while IFS=$'\t' read -r where state skill_name has_description; do
			folder="${where%/SKILL.md}"
			folder="${folder##*/}"
			if [ "$state" = "-1" ]; then
				problems+=("${where}: 첫 줄이 --- 가 아니다 (머리말이 없다)")
				continue
			fi
			if [ "$state" = "0" ]; then
				problems+=("${where}: 머리말을 닫는 --- 줄이 없다")
				continue
			fi
			if [ -z "$skill_name" ]; then
				problems+=("${where}: name이 없다")
			elif [ "$skill_name" != "$folder" ]; then
				problems+=("${where}: name(${skill_name})이 폴더 이름(${folder})과 다르다")
			elif [[ ! "$skill_name" =~ ^[a-z0-9-]+$ ]]; then
				problems+=("${where}: name은 소문자·숫자·하이픈만 쓴다 (${skill_name})")
			fi
			if [ "$has_description" != "1" ]; then
				problems+=("${where}: description이 없다")
			fi
			skills+=("$folder")
		done < <(awk -v q="'" '
			function report() {
				if (file == "") return
				printf "%s\t%d\t%s\t%d\n", file, (state == 2 ? 1 : (state == -1 ? -1 : 0)), skill_name, has_description
			}
			{ sub(/\r$/, "") }
			FNR == 1 {
				report()
				file = FILENAME
				skill_name = ""
				has_description = 0
				block = 0
				state = ($0 == "---") ? 1 : -1
				next
			}
			state != 1 { next }
			$0 == "---" { state = 2; next }
			block && /^[ \t]+[^ \t]/ { has_description = 1; next }
			{ block = 0 }
			/^name:/ {
				value = $0
				sub(/^name:[ \t]*/, "", value)
				sub(/[ \t]+$/, "", value)
				gsub("^[\"" q "]|[\"" q "]$", "", value)
				skill_name = value
				next
			}
			/^description:/ {
				value = $0
				sub(/^description:[ \t]*/, "", value)
				sub(/[ \t]+$/, "", value)
				if (value ~ /^[>|][-+]?$/) block = 1
				else if (value != "" && value != "\"\"" && value != q q) has_description = 1
			}
			END { report() }
		' "${files[@]}")
	fi
	if [ ${#problems[@]} -gt 0 ]; then
		fail_check "$name" "머리말이 잘못된 스킬이 있다. SKILL.md 맨 위를 '---', 'name: <폴더 이름>', 'description: <언제 쓰는지와 그때 나오는 말>', '---' 순서로 쓴다" "${problems[@]}"
	else
		pass_check "$name" "스킬 ${#skills[@]}개: ${skills[*]}"
	fi
}

# 문서의 백틱(`…`) 안에서 저장소 경로로 보이는 것을 뽑는다. ``` 코드 블록 안은 건너뛴다.
# 출력: "<파일>:<줄>\t<종류>\t<경로>". 종류 path는 저장소 기준 경로(res:// 는 뗀다), name은 경로 없이 적은 파일 이름.
# 자리표시(< > * { } $ | …)가 든 것, URL, 한글이 든 것, / 도 확장자도 없는 낱말은 경로로 보지 않는다.
# 인자: 최상위 폴더 정규식(art_src|assets|...), 문서 파일들
extract_doc_paths() {
	local top_dirs="$1"
	shift
	awk -v top_dirs="$top_dirs" -v exts="$PATH_EXTENSIONS" -v q="'" '
		BEGIN {
			ext_re = "[.](" exts ")$"
			top_re = "^(" top_dirs ")(/|$)"
			lead_re = "^[(" q "\"]+"
			trail_re = "[)" q "\",.:;]+$"
		}
		function check_word(w) {
			gsub(lead_re, "", w)
			gsub(trail_re, "", w)
			if (w == "" || w ~ /[<>*{}$|]/ || index(w, "…") > 0) return
			if (w ~ /^res:\/\//) {
				sub(/^res:\/\//, "", w)
				if (w != "") print FILENAME ":" FNR "\tpath\t" w
				return
			}
			if (w ~ /:\/\//) return
			if (w !~ /^[A-Za-z0-9_.][A-Za-z0-9_.\/-]*$/) return
			if (index(w, "/") > 0) {
				if (w ~ top_re || w ~ ext_re) print FILENAME ":" FNR "\tpath\t" w
				return
			}
			if (w ~ /^[A-Za-z0-9_][A-Za-z0-9_.-]*$/ && w ~ ext_re) print FILENAME ":" FNR "\tname\t" w
		}
		FNR == 1 { in_block = 0 }
		{ sub(/\r$/, "") }
		/^[ \t]*```/ { in_block = !in_block; next }
		in_block { next }
		{
			rest = $0
			while (match(rest, /`[^`]+`/)) {
				span = substr(rest, RSTART + 1, RLENGTH - 2)
				rest = substr(rest, RSTART + RLENGTH)
				count = split(span, words, /[ \t=]+/)
				for (i = 1; i <= count; i++) check_word(words[i])
			}
		}
	' "$@"
}

# CLAUDE.md와 스킬에 적은 경로(파일·폴더·res://)가 저장소에 있는지. 파일을 옮기거나 이름을 바꾼 뒤 문서가 낡으면 잡는다.
check_doc_paths() {
	local name="문서 속 경로"
	local docs=() file
	[ -f CLAUDE.md ] && docs+=("CLAUDE.md")
	for file in .claude/skills/*/SKILL.md; do
		[ -f "$file" ] && docs+=("$file")
	done
	if [ ${#docs[@]} -eq 0 ]; then
		fail_check "$name" "검사할 문서(CLAUDE.md, 스킬)가 없다"
		return
	fi
	# 저장소의 파일·폴더·파일 이름. git이 보는 것만 센다: .gitignore에 있는 파일은 컴퓨터마다 있거나 없어서,
	# 디스크로 보면 한 컴퓨터에서만 통과한다. 그런 파일은 MISSING_OK_PATHS에 넣는다.
	local -A repo_files=() repo_dirs=() repo_names=()
	local type listed
	while IFS=$'\t' read -r type listed; do
		if [ "$type" = "F" ]; then
			repo_files["$listed"]=1
			repo_names["${listed##*/}"]=1
		else
			repo_dirs["$listed"]=1
		fi
	done < <(list_repo_files | awk '{
		print "F\t" $0
		count = split($0, parts, "/")
		dir = ""
		for (i = 1; i < count; i++) {
			dir = dir parts[i]
			if (!(dir in seen)) { seen[dir] = 1; print "D\t" dir }
			dir = dir "/"
		}
	}')
	# 최상위 폴더 이름. 점은 [.]로 바꿔 정규식에서 글자 그대로 본다 (awk -v는 \ 를 지우므로 쓰지 않는다)
	local top_dirs="" entry
	for entry in * .claude; do
		[ -d "$entry" ] && top_dirs="${top_dirs}|${entry//./[.]}"
	done
	top_dirs="${top_dirs#|}"
	local missing=() checked=0 where kind path bare ok_path allowed
	while IFS=$'\t' read -r where kind path; do
		allowed=0
		for ok_path in "${MISSING_OK_PATHS[@]}"; do
			[ "$path" = "$ok_path" ] && allowed=1
		done
		[ $allowed -eq 1 ] && continue
		checked=$((checked + 1))
		if [ "$kind" = "name" ]; then
			[ -n "${repo_names[$path]:-}" ] || missing+=("${where}: ${path} (이 이름의 파일이 저장소에 없다)")
			continue
		fi
		bare="${path%/}"
		if [ -n "${repo_files[$bare]:-}" ] && [ -f "$bare" ]; then
			continue
		fi
		if [ -n "${repo_dirs[$bare]:-}" ] && [ -d "$bare" ]; then
			continue
		fi
		if [ -e "$bare" ]; then
			missing+=("${where}: ${path} (디스크에는 있지만 .gitignore에 있거나 빈 폴더라 다른 컴퓨터에는 없다)")
		else
			missing+=("${where}: ${path}")
		fi
	done < <(extract_doc_paths "$top_dirs" "${docs[@]}")
	if [ ${#missing[@]} -gt 0 ]; then
		fail_check "$name" "없는 경로 ${#missing[@]}개. 문서의 경로를 실제 위치로 고친다. 일부러 저장소에 없는 파일이면 tests/check_rules.sh의 MISSING_OK_PATHS에 이유와 함께 넣는다" "${missing[@]}"
	else
		pass_check "$name" "경로 ${checked}개 확인 (문서 ${#docs[@]}개)"
	fi
}

# 시나리오마다 무엇을 확인하는지는 파일 맨 위 ## 주석에 적는다 (tools/list_scenarios.sh가 이것을 목록으로 보여 준다).
check_scenario_headers() {
	local name="시나리오 설명 주석"
	local files=() file
	for file in tests/scenarios/scenario_*.gd; do
		[ -f "$file" ] && files+=("$file")
	done
	if [ ${#files[@]} -eq 0 ]; then
		pass_check "$name" "시나리오 없음"
		return
	fi
	local -A has_header=()
	local found
	while IFS= read -r found; do
		has_header["$found"]=1
	done < <(awk -v head="$SCENARIO_HEADER_LINES" '
		{ sub(/\r$/, "") }
		FNR <= head && !(FILENAME in seen) && /^##[ \t]*[^ \t#]/ { seen[FILENAME] = 1; print FILENAME }
	' "${files[@]}")
	local missing=()
	for file in "${files[@]}"; do
		[ -n "${has_header[$file]:-}" ] || missing+=("$file")
	done
	if [ ${#missing[@]} -gt 0 ]; then
		fail_check "$name" "맨 위 ${SCENARIO_HEADER_LINES}줄 안에 ## 설명 주석이 없는 시나리오 ${#missing[@]}개. extends 줄 바로 아래에 '## 시나리오: <무엇을 확인하는지>'와 단계 흐름을 적는다" "${missing[@]}"
	else
		pass_check "$name" "시나리오 ${#files[@]}개"
	fi
}

CHECKS=(
	check_claude_md_size
	check_skill_frontmatter
	check_doc_paths
	check_scenario_headers
)

for check in "${CHECKS[@]}"; do
	"$check"
done

if [ ${#failed[@]} -eq 0 ]; then
	echo "규칙 검사 결과: 통과"
	exit 0
fi
joined=$(printf '%s, ' "${failed[@]}")
echo "규칙 검사 결과: 실패 (${joined%, })"
exit 1
