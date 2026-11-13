#!/usr/bin/env bash
# 저장소 규칙 검사. Godot 없이 몇 초 안에 끝난다. tests/run_all.sh가 맨 처음에 돌리고, 혼자 돌려도 된다.
# CLAUDE.md의 "X하면 Y도 한다" 규칙 중 기계로 볼 수 있는 것을 본다. 검사 이름과 보는 것:
#   CLAUDE.md 크기: CLAUDE.md가 CLAUDE_MD_MAX_BYTES를 넘지 않는다
#   스킬 머리말: .claude/skills/<폴더>/SKILL.md 맨 위에 name(폴더 이름)과 description이 있다
#   문서 속 경로: CLAUDE.md·스킬에 백틱으로 적은 경로가 저장소에 있다
#   시나리오 설명 주석: tests/scenarios/scenario_*.gd 맨 위에 ## 설명 주석이 있다
#   그룹 목록: 코드·씬에 글자로 쓴 그룹 이름이 모두 CLAUDE.md "### 그룹 목록"에 있고, 목록의 그룹은 게임 코드가 쓴다
#   오토로드 목록: project.godot [autoload]의 이름과 CLAUDE.md "### 오토로드 목록"의 이름이 같다
#   밸런스 측정 대상: 몬스터 데이터(.tres)마다 tests/balance/run_balance.gd의 TARGETS에 있다
#   UI 시나리오: 클릭을 받는 ui/ 씬마다 그 씬을 쓰는 시나리오가 있다
#   Godot 3 문법: .gd에 export var, onready var, yield, KinematicBody, 세 인자 connect, setget, tool 줄이 없다
#   절대 경로: 저장소의 글 파일(코드, 씬, 데이터, 스크립트, 설정, 문서)에 한 컴퓨터에만 있는 경로가 없다
#   규칙 클래스 단위 테스트: 노드가 아닌 규칙 클래스마다 tests/unit/test_*.gd가 그 이름을 쓴다
#   Godot 버전 일치: tools/hooks/session_start.sh, CLAUDE.md "기술 환경", project.godot의 Godot 버전이 같다
# 검사마다 함수 하나(check_<내용>)이고, 결과는 검사마다 한 줄이다. 자세한 줄은 그 아래에 들여 써서 보여 준다.
#   [통과] <이름>
#   [실패] <이름>: <무엇이 문제인지와 고치는 법>
# 마지막 줄은 "규칙 검사 결과: 통과" 또는 "규칙 검사 결과: 실패 (<이름들>)". 하나라도 실패하면 종료 코드 1.
# 지금 어긋나 있지만 그대로 두기로 한 것은 아래 예외 목록에 이유와 함께 넣는다. 예외에 넣기 전에 사용자에게 묻는다.
# 고쳐서 예외가 필요 없어지면 그 검사가 실패해서 지우라고 알린다.
# 검사를 더하려면: check_<내용> 함수를 만들어 그 안에서 pass_check나 fail_check를 한 번 부르고, 맨 아래 CHECKS 목록에 넣는다.
# awk는 POSIX 기능만 쓴다 (이 컴퓨터들의 Git Bash는 gawk, 다른 곳은 mawk일 수 있다).
# 사용 예: bash tests/check_rules.sh

cd "$(dirname "$0")/.." || exit 1

# CLAUDE.md 크기 한도 (바이트). 2026-11-13에 나눈 뒤의 크기(18052)에 약 40% 여유를 두고 반올림한 값
CLAUDE_MD_MAX_BYTES=25000
# 시나리오 설명 주석은 파일 맨 위 이 줄 수 안에서 시작해야 한다 (tools/list_scenarios.sh와 같다)
SCENARIO_HEADER_LINES=5
# 경로로 보는 확장자. / 없이 파일 이름만 적은 것도 이 확장자로 끝나면 저장소에서 그 이름의 파일을 찾는다
PATH_EXTENSIONS="gd|tscn|tres|res|md|sh|png|json|cfg|hex|zip|svg|import|uid|py|blend|txt|godot"
# 절대 경로를 찾는 글 파일의 확장자. .gitignore처럼 점으로 시작하는 파일은 점 뒤 전체를 확장자로 본다
TEXT_EXTENSIONS="gd|gdshader|gdshaderinc|tscn|tres|godot|cfg|import|sh|py|ps1|bat|cmd|json|md|txt|csv|yml|yaml|toml|ini|gitignore|gitattributes|editorconfig"
# 다른 사람이 만든 플러그인 폴더. 이 저장소의 규칙을 따르지 않으므로 파일 내용을 보는 검사에서 뺀다
THIRD_PARTY_DIR="addons/"
# 클릭을 받는 Control 종류. ui/ 씬에 이 노드가 있거나, 씬의 스크립트가 이것을 코드로 만들면(Button.new() 등) 클릭을 받는 UI로 본다
CLICKABLE_TYPES="Button|TextureButton|CheckBox|CheckButton|LinkButton|MenuButton|OptionButton|ColorPickerButton|LineEdit|TextEdit|CodeEdit|SpinBox|HSlider|VSlider|ItemList|Tree|TabBar|TabContainer|MenuBar"
# 규칙 클래스를 가를 때 로직 함수로 세지 않는 함수 (엔진이 부르는 생성·속성 함수)
NON_LOGIC_FUNCS="_init|_to_string|_get|_set|_get_property_list|_validate_property|_property_can_revert|_property_get_revert|_notification"
# 검사가 읽는 파일. 옮기면 같이 고친다
BALANCE_SCRIPT="tests/balance/run_balance.gd"
SESSION_START_SCRIPT="tools/hooks/session_start.sh"

# ---- 예외 목록 ----
# 줄마다 끝에 이유를 적는다. 사용자에게 묻고 넣는다. 고쳐서 필요 없어진 줄은 검사가 알려 주면 지운다.

# 문서에 적었지만 저장소에 없어도 되는 경로. 컴퓨터마다 만드는 파일이라 .gitignore에 있다.
MISSING_OK_PATHS=(
	"regions/shallow_cave_terrain.res" # 구운 동굴 지형. tools/map_png/make_cave_outline.gd로 만든다
)
# tests/·tools/에서만 만들어 쓰는 그룹. 게임에 없는 그룹이라 CLAUDE.md 그룹 목록 대신 여기에 둔다. (지금은 없다)
TEST_ONLY_GROUPS=(
)
# run_balance.gd의 TARGETS에 넣지 않는 몬스터 데이터 (저장소 기준 경로, 예: data/monsters/<이름>.tres). (지금은 없다)
UNMEASURED_MONSTERS=(
)
# 클릭을 받지만 시나리오가 없어도 되는 ui/ 씬 (저장소 기준 경로, 예: ui/<이름>.tscn). (지금은 없다)
UI_WITHOUT_SCENARIO=(
)
# 있어도 되는 절대 경로. "<파일>|<경로>" 꼴로, 검사가 보여 준 경로를 그대로 적는다. \ 가 든 경로는 작은따옴표로 감싼다. (지금은 없다)
# 이 목록 안의 줄은 절대 경로 검사가 건너뛴다.
ABSOLUTE_PATH_OK=(
)
# 단위 테스트(tests/unit/test_*.gd)가 이름을 쓰지 않는 규칙 클래스. 2026-11-13에 이 검사를 만들 때 이미 있던 것이다.
# 새 규칙 클래스는 여기에 넣지 말고 단위 테스트를 만든다. 테스트가 맞지 않는 클래스면 사용자에게 묻고 넣는다.
UNTESTED_RULE_CLASSES=(
	"PathFollower"         # 씬 트리의 NavigationGrid와 물리 질의가 있어야 해서 scenario_pathfinding.gd·얕은 굴 걷기 시나리오로만 본다
	"MonsterDatabase"      # data/monsters/ 폴더를 읽어 id로 찾는다. 단위 테스트가 없다 (scenario_escape.gd·scenario_inventory_slots.gd가 쓴다)
	"AssignHotbarAction"   # 메뉴 항목. test_item_actions.gd가 rat_skull.tres에 붙은 항목(id assign_hotbar)으로 확인하고 클래스 이름은 쓰지 않는다
	"UnassignHotbarAction" # 메뉴 항목. test_item_actions.gd가 rat_skull.tres에 붙은 항목(id unassign_hotbar)으로 확인한다
	"HealSkullAction"      # 메뉴 항목. test_item_actions.gd가 rat_skull.tres에 붙은 항목(id heal_skull)으로 확인한다
	"RemoveBonesAction"    # 메뉴 항목. test_item_actions.gd가 rat_skull.tres에 붙은 항목(id remove_bones)으로 확인한다
	"DropItemAction"       # 메뉴 항목. test_item_actions.gd가 rat_skull.tres·bone.tres에 붙은 항목(id drop)으로 확인한다
)

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
# 맨 처음 한 번 읽어 REPO_FILE_LIST에 둔다 (Git Bash는 프로세스를 띄울 때마다 시간이 걸린다).
REPO_FILE_LIST=()
load_repo_files() {
	if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
		mapfile -t REPO_FILE_LIST < <(git -c core.quotePath=false ls-files --cached --others --exclude-standard)
	else
		mapfile -t REPO_FILE_LIST < <(find . \( -name .git -o -name .godot \) -prune -o -type f -print | sed 's|^\./||')
	fi
}

list_repo_files() {
	[ ${#REPO_FILE_LIST[@]} -eq 0 ] || printf '%s\n' "${REPO_FILE_LIST[@]}"
}

# 파일 내용을 보는 검사가 쓰는 목록. 디스크에 있는 파일만 넣고 THIRD_PARTY_DIR은 뺀다.
GD_FILES=()   # .gd
TSCN_FILES=() # .tscn
TRES_FILES=() # .tres
TEXT_FILES=() # TEXT_EXTENSIONS (절대 경로 검사)
classify_repo_files() {
	local file base ext
	local -A seen=()
	for file in "${REPO_FILE_LIST[@]}"; do
		[[ $file == "$THIRD_PARTY_DIR"* ]] && continue
		base="${file##*/}"
		ext="${base##*.}"
		[ "$ext" = "$base" ] && continue
		[[ $ext =~ ^($TEXT_EXTENSIONS)$ ]] || continue
		[ -n "${seen[$file]:-}" ] && continue
		seen["$file"]=1
		[ -f "$file" ] || continue
		TEXT_FILES+=("$file")
		case "$ext" in
			gd) GD_FILES+=("$file") ;;
			tscn) TSCN_FILES+=("$file") ;;
			tres) TRES_FILES+=("$file") ;;
		esac
	done
}

# awk 함수 gd_code(줄, blank): GDScript 한 줄에서 # 주석을 떼어 돌려준다. 따옴표 안의 # 은 주석으로 보지 않는다.
# blank가 1이면 문자열 안의 글자도 지우고 따옴표는 모두 " 로 바꾼다 ('abc' → ""). awk에 -v SQ="'"를 넘겨야 한다.
# 여러 줄에 걸친 세 따옴표 문자열은 줄마다 따로 본다 (저장소에는 없다).
AWK_GD_CODE='
function gd_code(line, blank,    out, i, n, c, quote) {
	if (index(line, "#") == 0) {
		if (!blank) return line
		if (index(line, "\"") == 0 && index(line, SQ) == 0) return line
	}
	out = ""
	quote = ""
	n = length(line)
	for (i = 1; i <= n; i++) {
		c = substr(line, i, 1)
		if (quote != "") {
			if (c == "\\") {
				if (!blank) out = out c substr(line, i + 1, 1)
				i++
				continue
			}
			if (c == quote) {
				quote = ""
				out = out (blank ? "\"" : c)
			} else if (!blank) {
				out = out c
			}
			continue
		}
		if (c == "#") break
		if (c == "\"" || c == SQ) {
			quote = c
			out = out (blank ? "\"" : c)
			continue
		}
		out = out c
	}
	return out
}
'

# awk 함수 claude_list_line(): CLAUDE.md의 줄마다 부른다. heading(예: "### 그룹 목록") 바로 아래 목록 줄 "- `이름`…"의
# 이름을 "L\tCLAUDE.md:<줄>\t<이름>"으로 낸다. 다음 # 제목에서 목록이 끝난다. 들여 쓴 줄(설명)은 건너뛴다.
AWK_CLAUDE_LIST='
function claude_list_line(    text, entry) {
	text = $0
	sub(/[ \t]+$/, "", text)
	if (text ~ /^#/) {
		in_list = (text == heading)
		return
	}
	if (!in_list || text !~ /^- `[^`]+`/) return
	entry = text
	sub(/^- `/, "", entry)
	sub(/`.*/, "", entry)
	print "L\t" FILENAME ":" FNR "\t" entry
}
'

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

# 그룹 이름을 새로 쓰면 CLAUDE.md "### 그룹 목록"에 적는다.
# 코드(.gd)에서 그룹 함수(add_to_group, remove_from_group, is_in_group, get_nodes_in_group, get_first_node_in_group,
# get_node_count_in_group, has_group, call_group, notify_group, set_group, 끝에 _flags가 붙은 것)에 글자로 넘긴
# 이름(&"x", "x")과 씬(.tscn)의 groups=[...]를 모은다. 변수나 식으로 넘긴 이름은 알 수 없어 보지 않는다. 주석은 보지 않는다.
# - tests/·tools/가 쓰는 그룹도 목록에 있어야 한다. 이름을 잘못 쓰면 빈 목록이 나와도 모르고 지나가기 때문이다.
#   테스트에서만 만들어 쓰는 그룹은 CLAUDE.md 대신 TEST_ONLY_GROUPS에 넣는다.
# - 목록의 그룹은 게임 코드(tests/·tools/ 밖)가 써야 한다. 게임이 쓰지 않으면 낡은 줄이다.
check_group_list() {
	local name="그룹 목록"
	if [ ! -f CLAUDE.md ]; then
		fail_check "$name" "CLAUDE.md가 없다"
		return
	fi
	local -A listed=() first_use=() use_count=() game_use=() test_only=()
	local listed_order=() used_order=() problems=()
	local kind where group entry total=0 line
	for entry in "${TEST_ONLY_GROUPS[@]}"; do
		test_only["$entry"]=1
	done
	while IFS=$'\t' read -r kind where group; do
		if [ "$kind" = "L" ]; then
			listed["$group"]="$where"
			listed_order+=("$group")
			continue
		fi
		total=$((total + 1))
		if [ -z "${first_use[$group]:-}" ]; then
			first_use["$group"]="$where"
			used_order+=("$group")
		fi
		use_count["$group"]=$(( ${use_count[$group]:-0} + 1 ))
		case "$where" in
			tests/*|tools/*) ;;
			*) [ -n "${game_use[$group]:-}" ] || game_use["$group"]="$where" ;;
		esac
	done < <(awk -v SQ="'" -v heading="### 그룹 목록" "$AWK_GD_CODE$AWK_CLAUDE_LIST"'
		{ sub(/\r$/, "") }
		FNR == 1 { is_scene = (FILENAME ~ /[.]tscn$/) }
		FILENAME == "CLAUDE.md" { claude_list_line(); next }
		is_scene {
			if ($0 !~ /^\[node / || index($0, " groups=[") == 0) next
			list = $0
			sub(/.* groups=\[/, "", list)
			sub(/\].*/, "", list)
			count = split(list, parts, ",")
			for (i = 1; i <= count; i++) {
				group = parts[i]
				sub(/^[ \t]+/, "", group)
				sub(/[ \t]+$/, "", group)
				sub(/^&/, "", group)
				if (group ~ /^".*"$/) group = substr(group, 2, length(group) - 2)
				if (group != "") print "U\t" FILENAME ":" FNR "\t" group
			}
			next
		}
		index($0, "group") == 0 || /^[ \t]*#/ { next }
		{
			line = gd_code($0, 0)
			while (match(line, /(add_to_group|remove_from_group|is_in_group|get_nodes_in_group|get_first_node_in_group|get_node_count_in_group|has_group|call_group|notify_group|set_group)(_flags)?[ \t]*[(]/)) {
				before = (RSTART > 1) ? substr(line, RSTART - 1, 1) : ""
				call = substr(line, RSTART, RLENGTH)
				line = substr(line, RSTART + RLENGTH)
				if (before ~ /[A-Za-z0-9_]/) continue
				arg = line
				# _flags 함수는 첫 인자가 플래그이고 그룹은 두 번째다
				if (call ~ /_flags/) {
					comma = index(arg, ",")
					if (comma == 0) continue
					arg = substr(arg, comma + 1)
				}
				sub(/^[ \t]+/, "", arg)
				if (substr(arg, 1, 1) == "&") arg = substr(arg, 2)
				quote = substr(arg, 1, 1)
				if (quote != "\"" && quote != SQ) continue
				arg = substr(arg, 2)
				end = index(arg, quote)
				if (end <= 1) continue
				group = substr(arg, 1, end - 1)
				# 글자 하나로 된 인자만 센다 ("a" + b 같은 식은 건너뛴다)
				after = substr(arg, end + 1)
				sub(/^[ \t]+/, "", after)
				if (substr(after, 1, 1) != "," && substr(after, 1, 1) != ")") continue
				print "U\t" FILENAME ":" FNR "\t" group
			}
		}
	' CLAUDE.md "${GD_FILES[@]}" "${TSCN_FILES[@]}")
	for group in "${used_order[@]}"; do
		if [ -n "${test_only[$group]:-}" ]; then
			if [ -n "${game_use[$group]:-}" ]; then
				printf -v line '`%s` (%s): TEST_ONLY_GROUPS에 있지만 게임 코드가 쓴다. tests/check_rules.sh의 TEST_ONLY_GROUPS에서 빼고 CLAUDE.md 그룹 목록에 넣는다' "$group" "${game_use[$group]}"
				problems+=("$line")
			fi
			continue
		fi
		[ -n "${listed[$group]:-}" ] && continue
		printf -v line '`%s` (%s, 모두 %d곳): CLAUDE.md 그룹 목록에 없다. "### 그룹 목록"에 "- `%s`: <무엇을 넣는 그룹인지, 누가 찾는지>" 한 줄을 넣는다. 이름을 잘못 쓴 것이면 코드를 고친다' \
			"$group" "${first_use[$group]}" "${use_count[$group]}" "$group"
		if [ -z "${game_use[$group]:-}" ]; then
			line+=" (tests/·tools/에서만 쓴다. 테스트에서만 만드는 그룹이면 사용자에게 묻고 CLAUDE.md 대신 tests/check_rules.sh의 TEST_ONLY_GROUPS에 이유와 함께 넣는다)"
		fi
		problems+=("$line")
	done
	for group in "${listed_order[@]}"; do
		[ -n "${game_use[$group]:-}" ] && continue
		printf -v line '`%s` (%s): 게임 코드(tests/·tools/ 밖)가 쓰지 않는다. 그룹을 없앴으면 이 줄을 지운다' "$group" "${listed[$group]}"
		if [ -n "${first_use[$group]:-}" ]; then
			line+=" (tests/·tools/에는 남아 있다: ${first_use[$group]}. 그곳도 고친다)"
		fi
		problems+=("$line")
	done
	for group in "${TEST_ONLY_GROUPS[@]}"; do
		[ -n "${first_use[$group]:-}" ] && continue
		printf -v line '`%s`: TEST_ONLY_GROUPS에 있지만 아무 데서도 쓰지 않는다. tests/check_rules.sh의 TEST_ONLY_GROUPS에서 지운다' "$group"
		problems+=("$line")
	done
	if [ ${#problems[@]} -gt 0 ]; then
		fail_check "$name" "코드·씬의 그룹 이름과 CLAUDE.md \"### 그룹 목록\"이 맞지 않는다. 줄마다 고치는 법을 적었다" "${problems[@]}"
	elif [ ${#listed_order[@]} -eq 0 ]; then
		fail_check "$name" "CLAUDE.md에서 \"### 그룹 목록\"과 그 아래 \"- \`이름\`: …\" 줄을 찾지 못했다. 제목이나 줄 모양을 바꿨으면 tests/check_rules.sh의 check_group_list도 고친다"
	else
		pass_check "$name" "그룹 ${#listed_order[@]}개 (${listed_order[*]}), 코드·씬에서 쓴 곳 ${total}곳"
	fi
}

# 오토로드를 추가하면 CLAUDE.md "### 오토로드 목록"에 기록한다. project.godot [autoload]의 이름과 목록의 이름이 같은지 본다.
check_autoload_list() {
	local name="오토로드 목록"
	local file
	for file in project.godot CLAUDE.md; do
		if [ ! -f "$file" ]; then
			fail_check "$name" "${file}가 없다"
			return
		fi
	done
	local -A in_project=() in_doc=()
	local project_order=() doc_order=() problems=()
	local kind where autoload line
	while IFS=$'\t' read -r kind where autoload; do
		if [ "$kind" = "P" ]; then
			in_project["$autoload"]="$where"
			project_order+=("$autoload")
		else
			in_doc["$autoload"]="$where"
			doc_order+=("$autoload")
		fi
	done < <(awk -v heading="### 오토로드 목록" "$AWK_CLAUDE_LIST"'
		{ sub(/\r$/, "") }
		FILENAME == "CLAUDE.md" { claude_list_line(); next }
		/^\[/ {
			section = $0
			sub(/[ \t]+$/, "", section)
			next
		}
		section == "[autoload]" && /^[A-Za-z_][A-Za-z0-9_]*[ \t]*=/ {
			entry = $0
			sub(/[ \t]*=.*/, "", entry)
			print "P\t" FILENAME ":" FNR "\t" entry
		}
	' project.godot CLAUDE.md)
	for autoload in "${project_order[@]}"; do
		[ -n "${in_doc[$autoload]:-}" ] && continue
		printf -v line '`%s` (%s): CLAUDE.md 오토로드 목록에 없다. "### 오토로드 목록"에 "- `%s` (`<씬이나 스크립트 경로>`): <무엇을 하는지>" 한 줄을 넣는다. 오토로드는 꼭 필요할 때만 쓴다' "$autoload" "${in_project[$autoload]}" "$autoload"
		problems+=("$line")
	done
	for autoload in "${doc_order[@]}"; do
		[ -n "${in_project[$autoload]:-}" ] && continue
		printf -v line '`%s` (%s): project.godot [autoload]에 없다. 오토로드를 뺐으면 이 줄과 그 아래 들여 쓴 설명을 지우고, 이름을 바꿨으면 목록의 이름도 바꾼다' "$autoload" "${in_doc[$autoload]}"
		problems+=("$line")
	done
	if [ ${#problems[@]} -gt 0 ]; then
		fail_check "$name" "project.godot [autoload]와 CLAUDE.md \"### 오토로드 목록\"이 맞지 않는다" "${problems[@]}"
	else
		if [ ${#project_order[@]} -eq 0 ]; then
			pass_check "$name" "오토로드 없음"
		else
			pass_check "$name" "오토로드 ${#project_order[@]}개 (${project_order[*]})"
		fi
	fi
}

# 몬스터를 추가하면 tests/balance/run_balance.gd의 TARGETS에 넣고 다시 잰다 (CLAUDE.md 밸런스 측정).
# 몬스터 데이터: data/monsters/ 아래의 .tres, 그리고 그 밖(tests/·tools/ 제외)에서 첫 줄이 script_class="MonsterData"인 .tres.
# TARGETS는 run_balance.gd의 "const TARGETS" 줄부터 첫 칸의 } 까지에서 "data": "res://<경로>"를 모은다.
# TARGETS에 적은 파일이 저장소에 없어도 알린다.
check_balance_targets() {
	local name="밸런스 측정 대상"
	if [ ! -f "$BALANCE_SCRIPT" ]; then
		fail_check "$name" "${BALANCE_SCRIPT}가 없다. 옮겼으면 tests/check_rules.sh의 BALANCE_SCRIPT를 고친다"
		return
	fi
	local -A is_monster=() targeted=() skipped=()
	local monsters=() others=() problems=() names=()
	local file kind where path entry block_found=0 line stem
	for file in "${TRES_FILES[@]}"; do
		case "$file" in
			data/monsters/*)
				is_monster["$file"]=1
				monsters+=("$file")
				;;
			tests/*|tools/*) ;;
			*) others+=("$file") ;;
		esac
	done
	for entry in "${UNMEASURED_MONSTERS[@]}"; do
		skipped["$entry"]=1
	done
	while IFS=$'\t' read -r kind where path; do
		case "$kind" in
			B) block_found=1 ;;
			T)
				targeted["$path"]=1
				[ -f "$path" ] || problems+=("${where}: TARGETS의 res://${path}가 저장소에 없다. 경로를 고치거나 그 대상을 지운다")
				;;
			M)
				if [ -z "${is_monster[$path]:-}" ]; then
					is_monster["$path"]=1
					monsters+=("$path")
				fi
				;;
		esac
	done < <(awk -v balance="$BALANCE_SCRIPT" '
		{ sub(/\r$/, "") }
		FILENAME == balance {
			if (!in_block && $0 ~ /^const[ \t]+TARGETS[ \t:=]/) {
				in_block = 1
				print "B\t" FILENAME ":" FNR "\t-"
			} else if (in_block && $0 ~ /^[A-Za-z@]/) {
				in_block = 0
			}
			if (!in_block || $0 ~ /^[ \t]*#/) next
			rest = $0
			while (match(rest, /"data"[ \t]*:[ \t]*"res:\/\/[^"]*"/)) {
				path = substr(rest, RSTART, RLENGTH)
				rest = substr(rest, RSTART + RLENGTH)
				sub(/^"data"[ \t]*:[ \t]*"res:\/\//, "", path)
				sub(/"$/, "", path)
				print "T\t" FILENAME ":" FNR "\t" path
			}
			if ($0 ~ /^[}]/) in_block = 0
			next
		}
		FNR == 1 && /script_class="MonsterData"/ { print "M\t" FILENAME ":1\t" FILENAME }
	' "$BALANCE_SCRIPT" "${others[@]}")
	if [ $block_found -eq 0 ]; then
		fail_check "$name" "${BALANCE_SCRIPT}에서 const TARGETS를 찾지 못했다. 이름이나 모양을 바꿨으면 tests/check_rules.sh의 check_balance_targets도 고친다"
		return
	fi
	for file in "${monsters[@]}"; do
		stem="${file##*/}"
		stem="${stem%.tres}"
		if [ -n "${skipped[$file]:-}" ]; then
			if [ -n "${targeted[$file]:-}" ]; then
				problems+=("UNMEASURED_MONSTERS의 ${file}: 이제 TARGETS에 있다. tests/check_rules.sh에서 그 줄을 지운다")
			fi
			continue
		fi
		if [ -z "${targeted[$file]:-}" ]; then
			printf -v line '%s: TARGETS에 없다. %s의 TARGETS에 &"%s": {"name": "<이름> 1마리", "data": "res://%s", "offsets": [Vector2.ZERO]}를 넣고 balance-measure 스킬대로 다시 잰다. 재지 않을 몬스터면 사용자에게 묻고 tests/check_rules.sh의 UNMEASURED_MONSTERS에 이유와 함께 넣는다' \
				"$file" "$BALANCE_SCRIPT" "$stem" "$file"
			problems+=("$line")
			continue
		fi
		names+=("$stem")
	done
	for entry in "${UNMEASURED_MONSTERS[@]}"; do
		[ -n "${is_monster[$entry]:-}" ] && continue
		problems+=("UNMEASURED_MONSTERS의 ${entry}: 몬스터 데이터 파일이 아니다(없다). tests/check_rules.sh에서 그 줄을 지운다")
	done
	if [ ${#problems[@]} -gt 0 ]; then
		fail_check "$name" "몬스터 데이터와 ${BALANCE_SCRIPT}의 TARGETS가 맞지 않는다. 몬스터를 추가하면 TARGETS에 넣고 다시 잰다" "${problems[@]}"
	else
		local detail="몬스터 데이터 ${#monsters[@]}개 모두 TARGETS에 있다 (${names[*]})"
		[ ${#UNMEASURED_MONSTERS[@]} -gt 0 ] && detail="몬스터 데이터 ${#monsters[@]}개: TARGETS ${#names[@]}개 (${names[*]}), UNMEASURED_MONSTERS ${#UNMEASURED_MONSTERS[@]}개"
		[ ${#monsters[@]} -eq 0 ] && detail="몬스터 데이터 없음"
		pass_check "$name" "$detail"
	fi
}

# 새 UI를 만들면 scenario_ui_click.gd(거점에만 있는 UI는 거점에서 시작하는 그 기능의 시나리오)에
# 그 UI를 클릭해도 공격이 나가지 않는 단계를 넣는다 (CLAUDE.md 코드 구조).
# 클릭을 받는 UI 씬: ui/ 아래 .tscn 중 CLICKABLE_TYPES 노드가 있거나, 씬에 붙은 스크립트가 _gui_input을 만들거나
# gui_input에 연결하거나 CLICKABLE_TYPES를 코드로 만드는 것. 글자·게이지처럼 클릭을 받지 않는 UI는 보지 않는다.
# 버튼 없이 창(Panel 등)만으로 클릭을 막는 UI는 가려내지 못한다.
# 시나리오(tests/scenarios/*.gd와 tests/ 바로 아래 공용 스크립트)의 주석이 아닌 줄이 씬 파일 이름(확장자 없이),
# 루트 노드 이름, 루트 노드 스크립트의 class_name 중 하나를 쓰면 시나리오가 있다고 본다.
# 칸처럼 다른 ui/ 씬에 들어가는 부품(그 씬이 ext_resource로 넣거나, 그 씬의 스크립트가 res://ui/…tscn으로 불러오는 것)은
# 그 씬에 시나리오가 있으면 된다 (시나리오는 화면의 get_slot_control() 등으로 칸을 누른다).
check_ui_scenarios() {
	local name="UI 시나리오"
	local scenes=() sources=() file
	for file in "${TSCN_FILES[@]}"; do
		[[ $file == ui/* ]] && scenes+=("$file")
	done
	if [ ${#scenes[@]} -eq 0 ]; then
		pass_check "$name" "ui/ 씬 없음"
		return
	fi
	# 처음 쓴 곳을 보여 줄 때 scenario_ui_click.gd를 먼저 보도록 맨 앞에 둔다
	[ -f tests/scenarios/scenario_ui_click.gd ] && sources+=("tests/scenarios/scenario_ui_click.gd")
	for file in "${GD_FILES[@]}"; do
		[ "$file" = "tests/scenarios/scenario_ui_click.gd" ] && continue
		if [[ $file == tests/scenarios/*.gd || ( $file == tests/*.gd && ${file#tests/} != */* ) ]]; then
			sources+=("$file")
		fi
	done
	local -A allowed=() interactive=()
	local entry scene why how line stem covered=()
	for entry in "${UI_WITHOUT_SCENARIO[@]}"; do
		allowed["$entry"]=1
	done
	local problems=()
	while IFS=$'\t' read -r scene why how; do
		[ "$why" = "-" ] && continue
		interactive["$scene"]=1
		if [ "$how" != "-" ]; then
			if [ -n "${allowed[$scene]:-}" ]; then
				problems+=("UI_WITHOUT_SCENARIO의 ${scene}: 이제 시나리오가 있다 (${how}). tests/check_rules.sh에서 그 줄을 지운다")
			fi
			stem="${scene#ui/}"
			stem="${stem%.tscn}"
			case "$how" in
				*" 안") covered+=("${stem}(${how})") ;;
				*) covered+=("$stem") ;;
			esac
			continue
		fi
		[ -n "${allowed[$scene]:-}" ] && continue
		printf -v line '%s (%s): 이 씬을 쓰는 시나리오가 없다. scenario_ui_click.gd에 이 UI를 클릭해도 공격이 나가지 않는 단계를 넣는다 (거점에만 있는 UI면 거점에서 시작하는 그 기능의 시나리오에). 시나리오 없이 두려면 사용자에게 묻고 tests/check_rules.sh의 UI_WITHOUT_SCENARIO에 이유와 함께 넣는다' "$scene" "$why"
		problems+=("$line")
	done < <(awk -v SQ="'" -v clickable="$CLICKABLE_TYPES" "$AWK_GD_CODE"'
		BEGIN {
			count = split(clickable, names, "|")
			for (i = 1; i <= count; i++) click_type[names[i]] = 1
			new_re = "(^|[^A-Za-z0-9_.])(" clickable ")[.]new[ \t]*[(]"
		}
		# 씬 파일의 [ext_resource …]·[node …] 줄에서 key="값"의 값
		function attr(line, key) {
			if (!match(line, " " key "=\"[^\"]*\"")) return ""
			return substr(line, RSTART + length(key) + 3, RLENGTH - length(key) - 4)
		}
		function first_mention(names_list,    count, parts, i) {
			count = split(names_list, parts, " ")
			for (i = 1; i <= count; i++) if (parts[i] in mention) return mention[parts[i]] " (" parts[i] ")"
			return ""
		}
		{ sub(/\r$/, "") }
		# 스크립트: class_name과, 클릭을 직접 받는지
		phase == "gd" {
			if (FNR == 1) script = "res://" FILENAME
			if ($0 ~ /^class_name[ \t]/) {
				text = $0
				sub(/^class_name[ \t]+/, "", text)
				sub(/[^A-Za-z0-9_].*/, "", text)
				class_of[script] = text
				next
			}
			if ($0 ~ /^[ \t]*#/) next
			# 스크립트가 preload·load로 쓰는 ui/ 씬도 그 스크립트가 붙은 씬의 부품으로 본다
			rest = $0
			while (match(rest, /res:\/\/ui\/[A-Za-z0-9_.\/-]+[.]tscn/)) {
				script_parts[script] = script_parts[script] " " substr(rest, RSTART + 6, RLENGTH - 6)
				rest = substr(rest, RSTART + RLENGTH)
			}
			if (script in clicky) next
			if ($0 ~ /func[ \t]+_gui_input[ \t]*[(]/) clicky[script] = "_gui_input"
			else if ($0 ~ /gui_input[.]connect[ \t]*[(]/) clicky[script] = "gui_input.connect"
			else if (match($0, new_re)) {
				text = substr($0, RSTART, RLENGTH)
				sub(/^[^A-Za-z]+/, "", text)
				sub(/[ \t]*[(]$/, "()", text)
				clicky[script] = text
			}
			next
		}
		# ui/ 씬: 루트 노드 이름과 스크립트, 노드 종류, 붙은 스크립트, 안에 넣은 ui/ 씬
		phase == "ui" {
			scene = FILENAME
			if (FNR == 1) {
				scenes[++scene_count] = scene
				is_scene[scene] = 1
				in_root = 0
			}
			if ($0 ~ /^\[ext_resource /) {
				type = attr($0, "type")
				path = attr($0, "path")
				ext_path[scene, attr($0, "id")] = path
				if (type == "Script") scripts[scene] = scripts[scene] " " path
				if (type == "PackedScene" && path ~ /^res:\/\/ui\/.*[.]tscn$/) parts[scene] = parts[scene] " " substr(path, 7)
				next
			}
			if ($0 ~ /^\[node /) {
				type = attr($0, "type")
				if ((type in click_type) && !(scene in click_node)) click_node[scene] = type
				in_root = !(scene in root_name)
				if (in_root) root_name[scene] = attr($0, "name")
				next
			}
			if ($0 ~ /^\[/) {
				in_root = 0
				next
			}
			if (in_root && $0 ~ /^script[ \t]*=[ \t]*ExtResource[(]/) {
				id = $0
				sub(/^script[ \t]*=[ \t]*ExtResource[(][ \t]*"/, "", id)
				sub(/".*/, "", id)
				root_script[scene] = ext_path[scene, id]
			}
			next
		}
		# 시나리오: 주석이 아닌 줄의 낱말
		phase == "scenario" {
			if ($0 ~ /^[ \t]*#/) next
			count = split(gd_code($0, 0), words, /[^A-Za-z0-9_]+/)
			for (i = 1; i <= count; i++) if (words[i] != "" && !(words[i] in mention)) mention[words[i]] = FILENAME ":" FNR
			next
		}
		END {
			for (k = 1; k <= scene_count; k++) {
				scene = scenes[k]
				stem = scene
				sub(/^.*\//, "", stem)
				sub(/[.]tscn$/, "", stem)
				names_list = stem " " root_name[scene]
				if (root_script[scene] in class_of) names_list = names_list " " class_of[root_script[scene]]
				how[scene] = first_mention(names_list)
				why[scene] = ""
				if (scene in click_node) why[scene] = click_node[scene] " 노드"
				count = split(scripts[scene], list, " ")
				for (j = 1; j <= count; j++) {
					if (list[j] in script_parts) parts[scene] = parts[scene] script_parts[list[j]]
					if (why[scene] == "" && (list[j] in clicky)) why[scene] = substr(list[j], 7) "의 " clicky[list[j]]
				}
			}
			# 시나리오가 있는 씬 안의 ui/ 씬(부품)도 시나리오가 있다고 본다. 여러 겹이면 될 때까지 되풀이한다
			changed = 1
			while (changed) {
				changed = 0
				for (k = 1; k <= scene_count; k++) {
					scene = scenes[k]
					if (how[scene] == "") continue
					count = split(parts[scene], list, " ")
					for (j = 1; j <= count; j++) {
						if ((list[j] in is_scene) && how[list[j]] == "") {
							how[list[j]] = scene " 안"
							changed = 1
						}
					}
				}
			}
			for (k = 1; k <= scene_count; k++) {
				scene = scenes[k]
				printf "%s\t%s\t%s\n", scene, (why[scene] == "" ? "-" : why[scene]), (how[scene] == "" ? "-" : how[scene])
			}
		}
	' phase=gd "${GD_FILES[@]}" phase=ui "${scenes[@]}" phase=scenario "${sources[@]}")
	for entry in "${UI_WITHOUT_SCENARIO[@]}"; do
		[ -n "${interactive[$entry]:-}" ] && continue
		problems+=("UI_WITHOUT_SCENARIO의 ${entry}: 클릭을 받는 ui/ 씬이 아니다(없다). tests/check_rules.sh에서 그 줄을 지운다")
	done
	if [ ${#problems[@]} -gt 0 ]; then
		fail_check "$name" "클릭을 받는 UI에 시나리오가 없다. 시나리오가 씬 파일 이름, 루트 노드 이름, 루트 스크립트의 class_name 중 하나를 쓰면 찾는다. 다른 ui/ 씬 안에 넣는 부품이면 그 씬을 쓰는 시나리오가 있어도 된다" "${problems[@]}"
	else
		local detail="ui/ 씬 ${#scenes[@]}개 중 클릭을 받는 것 ${#covered[@]}개 모두 시나리오가 있다: ${covered[*]}"
		if [ ${#interactive[@]} -eq 0 ]; then
			detail="ui/ 씬 ${#scenes[@]}개 중 클릭을 받는 것 없음"
		elif [ ${#interactive[@]} -gt ${#covered[@]} ]; then
			detail="ui/ 씬 ${#scenes[@]}개 중 클릭을 받는 것 ${#interactive[@]}개: 시나리오가 있는 것 ${#covered[@]}개 (${covered[*]}), UI_WITHOUT_SCENARIO $(( ${#interactive[@]} - ${#covered[@]} ))개"
		fi
		pass_check "$name" "$detail"
	fi
}

# Godot 3 문법 금지 (CLAUDE.md 기술 환경). 주석 줄과 문자열 안은 보지 않는다. 한 줄에서 처음 찾은 것만 알린다.
check_godot3_syntax() {
	local name="Godot 3 문법"
	if [ ${#GD_FILES[@]} -eq 0 ]; then
		pass_check "$name" "스크립트 없음"
		return
	fi
	local problems=() where kind code hint
	while IFS=$'\t' read -r where kind code; do
		case "$kind" in
			export) hint="export var는 Godot 3 문법이다. @export var로 쓴다" ;;
			onready) hint="onready var는 Godot 3 문법이다. @onready var로 쓴다" ;;
			tool) hint="tool 줄은 Godot 3 문법이다. @tool로 쓴다" ;;
			yield) hint="yield(…)는 Godot 3 문법이다. await <시그널>로 쓴다" ;;
			kinematic) hint="KinematicBody는 Godot 3 클래스다. CharacterBody2D(3D는 CharacterBody3D)를 쓴다" ;;
			connect) hint="connect(\"시그널\", 대상, \"함수\")는 Godot 3 문법이다. <시그널>.connect(<함수>)로 쓴다" ;;
			setget) hint="setget은 Godot 3 문법이다. var x: int: set = _set_x, get = _get_x (또는 set(value): 블록)로 쓴다" ;;
			*) hint="Godot 3 문법이다" ;;
		esac
		problems+=("${where}: ${hint} | ${code}")
	done < <(awk -v SQ="'" "$AWK_GD_CODE"'
		{ sub(/\r$/, "") }
		/^[ \t]*#/ || !/export|onready|yield|KinematicBody|connect|setget|tool/ { next }
		{
			code = gd_code($0, 1)
			kind = ""
			if (code ~ /^[ \t]*(onready[ \t]+)?export([ \t]|[(])/ && code ~ /(^|[ \t)])var[ \t]/) kind = "export"
			else if (code ~ /^[ \t]*onready[ \t]+var[ \t]/) kind = "onready"
			else if (code ~ /^tool[ \t]*$/) kind = "tool"
			else if (code ~ /(^|[^A-Za-z0-9_])yield[ \t]*[(]/) kind = "yield"
			else if (code ~ /(^|[^A-Za-z0-9_])KinematicBody(2D|3D)?([^A-Za-z0-9_]|$)/) kind = "kinematic"
			else if (code ~ /(^|[^A-Za-z0-9_])(connect|disconnect|is_connected)[ \t]*[(][ \t]*""[ \t]*,[ \t]*(self[ \t]*[,)]|[A-Za-z_][A-Za-z0-9_.]*[ \t]*,[ \t]*"")/) kind = "connect"
			else if (code ~ /(^|[^A-Za-z0-9_])setget([^A-Za-z0-9_]|$)/) kind = "setget"
			if (kind == "") next
			text = $0
			sub(/^[ \t]+/, "", text)
			print FILENAME ":" FNR "\t" kind "\t" text
		}
	' "${GD_FILES[@]}")
	if [ ${#problems[@]} -gt 0 ]; then
		fail_check "$name" "Godot 3 문법 ${#problems[@]}곳. Godot 4 문법으로 고친다" "${problems[@]}"
	else
		pass_check "$name" "스크립트 ${#GD_FILES[@]}개"
	fi
}

# 저장소 안에 절대 경로를 쓰지 않는다 (CLAUDE.md 검증). 두 컴퓨터의 경로가 다르기 때문이다.
# 찾는 것: 드라이브 글자 경로(글자, 콜론, \ 나 /), 맥의 사용자 폴더(/Users 아래), 리눅스의 사용자 폴더(/home/<이름> 아래),
# Git Bash의 드라이브 경로(/ 와 드라이브 글자와 / 로 시작하는 낱말), WSL의 드라이브 경로(/mnt/<글자> 아래). 주석 안도 본다.
# 예외는 ABSOLUTE_PATH_OK에 "<파일>|<경로>"로 넣는다. 이 파일의 ABSOLUTE_PATH_OK 목록 안은 건너뛴다.
# 이 파일의 주석과 정규식에는 찾는 꼴 그대로의 경로를 쓰지 않는다 (예: 슬래시는 [/]로 쓴다). 쓰면 이 검사가 이 파일을 잡는다.
check_absolute_paths() {
	local name="절대 경로"
	local -A allowed=() seen_ok=()
	local entry problems=() where file token
	for entry in "${ABSOLUTE_PATH_OK[@]}"; do
		allowed["$entry"]=1
	done
	if [ ${#TEXT_FILES[@]} -gt 0 ]; then
		while IFS=$'\t' read -r where file token; do
			if [ -n "${allowed[$file|$token]:-}" ]; then
				seen_ok["$file|$token"]=1
				continue
			fi
			problems+=("${where}: ${token}")
		done < <(awk -v SQ="'" -v self="tests/check_rules.sh" '
			BEGIN {
				delims = " \t\"" SQ "`()<>[]{},;|="
				gitbash_re = "(^|[ \t\"" SQ "`=(,:])/[A-Za-z]/[A-Za-z0-9_]"
			}
			# at 글자가 든 낱말 (구분 글자 delims 사이)
			function token_at(line, at,    first, last, n) {
				n = length(line)
				first = at
				while (first > 1 && index(delims, substr(line, first - 1, 1)) == 0) first--
				last = at
				while (last < n && index(delims, substr(line, last + 1, 1)) == 0) last++
				return substr(line, first, last - first + 1)
			}
			# re에 맞는 곳마다 그 낱말을 낸다. skip_lead가 1이면 맞은 곳의 첫 글자는 앞 경계 글자일 수 있다
			function find_paths(line, re, skip_lead,    rest, offset, at, token) {
				rest = line
				offset = 0
				while (match(rest, re)) {
					at = offset + RSTART
					if (skip_lead && substr(rest, RSTART, 1) !~ /[A-Za-z\/]/) at++
					token = token_at(line, at)
					if (!((FILENAME, FNR, token) in found)) {
						found[FILENAME, FNR, token] = 1
						print FILENAME ":" FNR "\t" FILENAME "\t" token
					}
					offset += RSTART + RLENGTH - 1
					rest = substr(rest, RSTART + RLENGTH)
				}
			}
			{ sub(/\r$/, "") }
			FILENAME == self && /^ABSOLUTE_PATH_OK=[(]/ { skip_block = 1 }
			skip_block {
				if ($0 ~ /^[)]/) skip_block = 0
				next
			}
			!/:[\\\/]|\/Users\/|\/home\/|\/mnt\/|\/[A-Za-z]\// { next }
			{
				find_paths($0, "(^|[^A-Za-z0-9_])[A-Za-z]:[\\\\/]", 1)
				find_paths($0, "[/]Users[/]", 0)
				find_paths($0, "[/]home[/][A-Za-z0-9._-]+[/]", 0)
				find_paths($0, "[/]mnt[/][A-Za-z][/]", 0)
				find_paths($0, gitbash_re, 1)
			}
		' "${TEXT_FILES[@]}")
	fi
	for entry in "${ABSOLUTE_PATH_OK[@]}"; do
		[ -n "${seen_ok[$entry]:-}" ] && continue
		problems+=("ABSOLUTE_PATH_OK의 ${entry}: 그 파일에 이 경로가 없다. tests/check_rules.sh에서 그 줄을 지운다")
	done
	if [ ${#problems[@]} -gt 0 ]; then
		fail_check "$name" "한 컴퓨터에만 있는 경로가 있다. 저장소 안 파일은 상대 경로나 res://로 가리키고, Godot는 bash tools/godot.sh로 부른다(GODOT_PATH). 예시로 꼭 적어야 하면 사용자에게 묻고 tests/check_rules.sh의 ABSOLUTE_PATH_OK에 \"<파일>|<경로>\"를 이유와 함께 넣는다" "${problems[@]}"
	else
		pass_check "$name" "글 파일 ${#TEXT_FILES[@]}개"
	fi
}

# 규칙 클래스를 새로 만들거나 바꾸면 단위 테스트도 같이 만들거나 고친다 (CLAUDE.md 규칙 단위 테스트).
# 규칙 클래스: tests/·tools/ 밖의 class_name 스크립트 중 노드가 아닌 것(extends RefCounted·Object·Resource, extends가 없음,
# 또는 그런 class_name을 잇는 것)이면서 로직 함수(NON_LOGIC_FUNCS 밖의 func)가 하나라도 있는 것.
# 함수 없이 @export 값만 있는 데이터 클래스(ItemData 등)는 보지 않는다. 엔진의 다른 Resource 종류(Texture2D 등)를 잇는 것도 보지 않는다.
# tests/unit/test_*.gd의 주석이 아닌 줄이 클래스 이름을 쓰거나 스크립트를 res:// 경로로 불러오면 테스트가 있다고 본다.
check_rule_class_tests() {
	local name="규칙 클래스 단위 테스트"
	local code_files=() test_files=() file
	for file in "${GD_FILES[@]}"; do
		case "$file" in
			tests/unit/test_*.gd) test_files+=("$file") ;;
			tests/*|tools/*) ;;
			*) code_files+=("$file") ;;
		esac
	done
	if [ ${#code_files[@]} -eq 0 ]; then
		pass_check "$name" "스크립트 없음"
		return
	fi
	local -A excepted=() rule_class=()
	local entry class root where problems=() line stem
	local rule_count=0 tested_count=0 excepted_found=()
	for entry in "${UNTESTED_RULE_CLASSES[@]}"; do
		excepted["$entry"]=1
	done
	while IFS=$'\t' read -r class file root where; do
		rule_count=$((rule_count + 1))
		rule_class["$class"]=1
		if [ "$where" != "-" ]; then
			tested_count=$((tested_count + 1))
			if [ -n "${excepted[$class]:-}" ]; then
				problems+=("UNTESTED_RULE_CLASSES의 ${class}: 이제 단위 테스트가 쓴다 (${where}). tests/check_rules.sh에서 그 줄을 지운다")
			fi
			continue
		fi
		if [ -n "${excepted[$class]:-}" ]; then
			excepted_found+=("$class")
			continue
		fi
		stem="${file##*/}"
		stem="${stem%.gd}"
		printf -v line '%s (%s, %s를 잇는다): 이름을 쓰는 단위 테스트가 없다. tests/unit/test_%s.gd를 만든다 (extends TestCase, CLAUDE.md 규칙 단위 테스트). 단위 테스트가 맞지 않는 클래스면 사용자에게 묻고 tests/check_rules.sh의 UNTESTED_RULE_CLASSES에 이유와 함께 넣는다' \
			"$class" "$file" "$root" "$stem"
		problems+=("$line")
	done < <(awk -v SQ="'" -v nonlogic="$NON_LOGIC_FUNCS" "$AWK_GD_CODE"'
		BEGIN {
			count = split(nonlogic, names, "|")
			for (i = 1; i <= count; i++) skip_func[names[i]] = 1
		}
		# extends 뒤의 이름. "res://…" 경로로 이으면 "path:<저장소 경로>"
		function base_name(text) {
			sub(/^[ \t]+/, "", text)
			if (substr(text, 1, 1) == "\"") {
				text = substr(text, 2)
				sub(/".*/, "", text)
				sub(/^res:\/\//, "", text)
				return "path:" text
			}
			sub(/[^A-Za-z0-9_.].*/, "", text)
			return text
		}
		# 저장소 밖(엔진)의 맨 위 부모 클래스. extends가 없으면 RefCounted
		function root_base(file,    base, steps, path) {
			base = extends_of[file]
			for (steps = 0; steps < 64; steps++) {
				if (base == "") return "RefCounted"
				if (substr(base, 1, 5) == "path:") {
					path = substr(base, 6)
					if (!(path in extends_of)) return base
					base = extends_of[path]
					continue
				}
				if (!(base in file_of)) return base
				base = extends_of[file_of[base]]
			}
			return "?"
		}
		{ sub(/\r$/, "") }
		phase == "code" {
			if (FNR == 1) {
				file = FILENAME
				files[++file_count] = file
				extends_of[file] = ""
				logic[file] = 0
			}
			if ($0 ~ /^class_name[ \t]/) {
				text = $0
				sub(/^class_name[ \t]+/, "", text)
				cls = text
				sub(/[^A-Za-z0-9_].*/, "", cls)
				class_of[file] = cls
				file_of[cls] = file
				if (text ~ /[ \t]extends[ \t]/) {
					sub(/.*[ \t]extends[ \t]+/, "", text)
					extends_of[file] = base_name(text)
				}
				next
			}
			if ($0 ~ /^extends[ \t]/) {
				text = $0
				sub(/^extends[ \t]+/, "", text)
				extends_of[file] = base_name(text)
				next
			}
			if ($0 ~ /^(static[ \t]+)?func[ \t]/) {
				text = $0
				sub(/^(static[ \t]+)?func[ \t]+/, "", text)
				sub(/[^A-Za-z0-9_].*/, "", text)
				if (!(text in skip_func)) logic[file]++
			}
			next
		}
		phase == "test" {
			if ($0 ~ /^[ \t]*#/) next
			line = gd_code($0, 0)
			count = split(line, words, /[^A-Za-z0-9_]+/)
			for (i = 1; i <= count; i++) if (words[i] != "" && !(words[i] in used)) used[words[i]] = FILENAME ":" FNR
			while (match(line, /res:\/\/[A-Za-z0-9_.\/-]+[.]gd/)) {
				path = substr(line, RSTART + 6, RLENGTH - 6)
				if (!(path in used_path)) used_path[path] = FILENAME ":" FNR
				line = substr(line, RSTART + RLENGTH)
			}
			next
		}
		END {
			for (k = 1; k <= file_count; k++) {
				file = files[k]
				cls = class_of[file]
				if (cls == "" || logic[file] == 0) continue
				root = root_base(file)
				if (root != "RefCounted" && root != "Object" && root != "Resource") continue
				where = "-"
				if (cls in used) where = used[cls]
				else if (file in used_path) where = used_path[file]
				print cls "\t" file "\t" root "\t" where
			}
		}
	' phase=code "${code_files[@]}" phase=test "${test_files[@]}")
	for entry in "${UNTESTED_RULE_CLASSES[@]}"; do
		[ -n "${rule_class[$entry]:-}" ] && continue
		problems+=("UNTESTED_RULE_CLASSES의 ${entry}: 그런 규칙 클래스가 없다 (이름이 바뀌었거나, 지웠거나, 노드나 데이터 클래스가 됐다). tests/check_rules.sh에서 그 줄을 지운다")
	done
	if [ ${#problems[@]} -gt 0 ]; then
		fail_check "$name" "단위 테스트가 없는 규칙 클래스가 있거나 예외 목록이 낡았다. 규칙 클래스를 새로 만들면 단위 테스트도 같이 만든다" "${problems[@]}"
	else
		pass_check "$name" "규칙 클래스 ${rule_count}개: 단위 테스트가 쓰는 것 ${tested_count}개, UNTESTED_RULE_CLASSES ${#excepted_found[@]}개 (${excepted_found[*]})"
	fi
}

# Godot 버전은 세 곳에 있다. 하나만 바꾸면 세션 시작 점검이나 문서가 틀린 버전을 가리킨다.
# tools/hooks/session_start.sh의 GODOT_VERSION_REQUIRED(예: 4.7.2.stable), CLAUDE.md "기술 환경"의 "Godot <주.부> (<버전> <상태>)",
# project.godot의 config/features 안 "<주.부>".
check_godot_version() {
	local name="Godot 버전 일치"
	local file
	for file in "$SESSION_START_SCRIPT" CLAUDE.md project.godot; do
		if [ ! -f "$file" ]; then
			fail_check "$name" "${file}가 없다"
			return
		fi
	done
	local kind where value required="" required_at="" doc="" doc_at="" features="" features_at=""
	while IFS=$'\t' read -r kind where value; do
		case "$kind" in
			R) required="$value"; required_at="$where" ;;
			C) doc="$value"; doc_at="$where" ;;
			F) features="$value"; features_at="$where" ;;
		esac
	done < <(awk -v hook="$SESSION_START_SCRIPT" '
		{ sub(/\r$/, "") }
		FILENAME == hook && /^GODOT_VERSION_REQUIRED=/ {
			if (match($0, /[0-9][0-9A-Za-z.]*/)) print "R\t" FILENAME ":" FNR "\t" substr($0, RSTART, RLENGTH)
			next
		}
		FILENAME == "CLAUDE.md" && !claude_found && match($0, /Godot [0-9]+[.][0-9]+ [(][0-9]+[.][0-9]+([.][0-9]+)? [A-Za-z0-9]+[)]/) {
			claude_found = 1
			print "C\t" FILENAME ":" FNR "\t" substr($0, RSTART, RLENGTH)
			next
		}
		FILENAME == "project.godot" && /^config\/features=/ {
			if (match($0, /"[0-9]+[.][0-9]+"/)) print "F\t" FILENAME ":" FNR "\t" substr($0, RSTART + 1, RLENGTH - 2)
		}
	' "$SESSION_START_SCRIPT" CLAUDE.md project.godot)
	local fix="Godot를 바꾸면 ${SESSION_START_SCRIPT}의 GODOT_VERSION_REQUIRED, CLAUDE.md \"기술 환경\"의 \"Godot <주.부> (<버전> stable)\" 줄, project.godot의 config/features(새 버전 에디터로 프로젝트를 열고 저장하면 바뀐다)를 같이 고친다"
	local problems=()
	[ -n "$required" ] || problems+=("${SESSION_START_SCRIPT}: GODOT_VERSION_REQUIRED=\"<버전>.<상태>\" 줄을 찾지 못했다")
	[ -n "$doc" ] || problems+=("CLAUDE.md: \"Godot <주.부> (<버전> <상태>)\" 꼴의 줄(예: 기술 환경의 Godot 줄)을 찾지 못했다")
	[ -n "$features" ] || problems+=("project.godot: config/features에서 \"<주.부>\"를 찾지 못했다")
	if [ ${#problems[@]} -gt 0 ]; then
		fail_check "$name" "버전을 적은 줄을 찾지 못했다. ${fix}" "${problems[@]}"
		return
	fi
	local re_required='^([0-9]+)\.([0-9]+)(\.[0-9]+)?\.([A-Za-z0-9_]+)$'
	local re_doc='^Godot ([0-9]+\.[0-9]+) \(([0-9]+\.[0-9]+)(\.[0-9]+)? ([A-Za-z0-9]+)\)$'
	local required_short required_full required_status doc_short doc_full doc_full_short doc_status
	if [[ ! $required =~ $re_required ]]; then
		fail_check "$name" "${required_at}의 GODOT_VERSION_REQUIRED(${required})가 <주>.<부>[.<패치>].<상태> 꼴(예: 4.7.2.stable)이 아니다. ${fix}"
		return
	fi
	required_short="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
	required_full="${required_short}${BASH_REMATCH[3]}"
	required_status="${BASH_REMATCH[4]}"
	[[ $doc =~ $re_doc ]]
	doc_short="${BASH_REMATCH[1]}"
	doc_full_short="${BASH_REMATCH[2]}"
	doc_full="${doc_full_short}${BASH_REMATCH[3]}"
	doc_status="${BASH_REMATCH[4]}"
	if [ "$doc_short" != "$doc_full_short" ]; then
		problems+=("${doc_at}: \"${doc}\"의 앞 버전 ${doc_short}와 괄호 안 ${doc_full}가 다르다")
	fi
	if [ "$required_full $required_status" != "$doc_full $doc_status" ]; then
		problems+=("${required_at}의 ${required}(${required_full} ${required_status})와 ${doc_at}의 \"${doc}\"(${doc_full} ${doc_status})가 다르다")
	fi
	if [ "$features" != "$required_short" ]; then
		problems+=("${features_at}의 config/features \"${features}\"가 ${required_at}의 ${required}(${required_short})와 다르다")
	fi
	if [ ${#problems[@]} -gt 0 ]; then
		fail_check "$name" "Godot 버전이 서로 다르다. ${fix}" "${problems[@]}"
	else
		pass_check "$name" "${required} (${required_at}) = \"${doc}\" (${doc_at}) = \"${features}\" (${features_at})"
	fi
}

CHECKS=(
	check_claude_md_size
	check_skill_frontmatter
	check_doc_paths
	check_scenario_headers
	check_group_list
	check_autoload_list
	check_balance_targets
	check_ui_scenarios
	check_godot3_syntax
	check_absolute_paths
	check_rule_class_tests
	check_godot_version
)

load_repo_files
classify_repo_files
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
