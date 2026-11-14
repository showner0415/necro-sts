#!/usr/bin/env bash
# Codex CLI의 그림 생성($imagegen)으로 UI 그림 후보를 뽑아 작업 폴더로 가져온다.
# ChatGPT 구독 한도를 쓰고 API 키는 쓰지 않는다. ui-designer 에이전트(.claude/agents/ui-designer.md)가 쓴다.
#
# 사용법 (저장소 폴더에서):
#   bash tools/ui_gen/codex_image.sh --prompt-file=<요청문.txt> --out-dir=<폴더> --name=<부품> [--count=3] [--ref=<기준 그림.png>]... [--timeout=300]
#     --prompt-file  요청문이 든 UTF-8 글 파일. 요청문은 영어로 쓴다 (한글을 명령 인자로 넘기면 Windows에서 깨질 수 있다).
#                    앞에 $imagegen이 없으면 붙이고, "그림 하나만, 파일은 고치지 말 것"을 덧붙인다
#     --out-dir      받은 그림을 둘 폴더 (보통 art_src/ui/inbox/<화면 id>/). 없으면 만든다
#     --name         부품 이름. 저장 이름은 <부품>_<후보 번호>.png (이미 있는 번호는 건너뛴다)
#     --count        후보 수. Codex를 이 횟수만큼 따로 부른다 (기본 3). 한 장마다 구독 한도를 쓴다
#     --ref          함께 넣을 기준 그림. 여러 번 줄 수 있다 (Codex의 -i)
#     --timeout      한 장을 기다리는 초 (기본 300)
#
# 출력: 받은 그림마다 "저장: <경로>", 마지막 줄 "결과: <받은 수>/<요청 수>장".
# 종료 코드: 0 = 한 장 이상 받음, 1 = 한 장도 못 받음, 2 = 인자 오류, 3 = codex 명령이 없음.
#
# 어떻게 가져오나: Codex는 만든 그림을 <CODEX_HOME>/generated_images/ 아래에 저장한다 (CODEX_HOME이 없으면 홈 폴더의 .codex).
#   부르기 직전에 표시 파일을 만들고, 부른 뒤 그 폴더에서 표시 파일보다 새 그림을 찾아 복사한다. 원본은 그대로 둔다.
#   다른 Codex 창에서 같은 때에 그림을 만들면 그것도 딸려 올 수 있다. 붙이기 검사에서 걸러진다.
# Codex는 읽기 전용 샌드박스로 부른다 (저장소 파일을 고치지 못하게). 버전에 따라 옵션이 다르면
#   CODEX_IMAGE_FLAGS 환경 변수로 바꾼다 (기본 "--sandbox read-only". 예: CODEX_IMAGE_FLAGS="--sandbox read-only --enable image_generation").
set -u

COUNT=3
TIMEOUT_SEC=300
PROMPT_FILE=""
OUT_DIR=""
NAME=""
REFS=()
DEFAULT_FLAGS="--sandbox read-only"
# 요청문 끝에 늘 붙이는 말: 한 번에 한 장만, Codex가 파일을 고치지 않게
SUFFIX=$'\n\nGenerate exactly one image. Do not create, edit or delete any files in the workspace.'

die_usage() { echo "인자 오류: $1" >&2; sed -n '5,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

for arg in "$@"; do
	case "$arg" in
		--prompt-file=*) PROMPT_FILE="${arg#*=}" ;;
		--out-dir=*) OUT_DIR="${arg#*=}" ;;
		--name=*) NAME="${arg#*=}" ;;
		--count=*) COUNT="${arg#*=}" ;;
		--ref=*) REFS+=("${arg#*=}") ;;
		--timeout=*) TIMEOUT_SEC="${arg#*=}" ;;
		*) die_usage "모르는 인자 $arg" ;;
	esac
done

[ -n "$PROMPT_FILE" ] || die_usage "--prompt-file이 없다"
[ -f "$PROMPT_FILE" ] || die_usage "요청문 파일이 없다: $PROMPT_FILE"
[ -n "$OUT_DIR" ] || die_usage "--out-dir이 없다"
[ -n "$NAME" ] || die_usage "--name이 없다"
case "$NAME" in *[!a-z0-9_]*) die_usage "--name은 영문 소문자·숫자·밑줄만 쓴다: $NAME" ;; esac
case "$COUNT" in ''|*[!0-9]*|0) die_usage "--count는 1 이상의 정수다: $COUNT" ;; esac
case "$TIMEOUT_SEC" in ''|*[!0-9]*|0) die_usage "--timeout은 1 이상의 정수다: $TIMEOUT_SEC" ;; esac
for ref in ${REFS[@]+"${REFS[@]}"}; do
	[ -f "$ref" ] || die_usage "기준 그림이 없다: $ref"
done

if ! command -v codex >/dev/null 2>&1; then
	echo "codex 명령이 없다. 이 컴퓨터에 Codex CLI를 설치하고 codex login으로 ChatGPT 계정에 로그인한다." >&2
	echo "그 전에는 요청문을 ChatGPT에 직접 넣고 받은 그림을 $OUT_DIR 에 넣는다 (docs/ui-designer-guide.md)." >&2
	exit 3
fi

CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
GEN_DIR="$CODEX_DIR/generated_images"
mkdir -p "$OUT_DIR"

PROMPT="$(cat "$PROMPT_FILE")"
case "$PROMPT" in *'$imagegen'*) ;; *) PROMPT="\$imagegen $PROMPT" ;; esac
PROMPT="$PROMPT$SUFFIX"

read -r -a FLAGS <<< "${CODEX_IMAGE_FLAGS:-$DEFAULT_FLAGS}"
REF_ARGS=()
for ref in ${REFS[@]+"${REFS[@]}"}; do REF_ARGS+=(-i "$ref"); done

TIMEOUT_CMD=()
if command -v timeout >/dev/null 2>&1; then TIMEOUT_CMD=(timeout -k 10 "$TIMEOUT_SEC"); fi

LOG_DIR="$OUT_DIR/codex_logs"
mkdir -p "$LOG_DIR"
MARK="$(mktemp)"
trap 'rm -f "$MARK"' EXIT

# 다음에 쓸 후보 번호 (이미 있는 번호는 건너뛴다)
next_index() {
	local i=1
	while [ -e "$OUT_DIR/${NAME}_$i.png" ]; do i=$((i + 1)); done
	echo "$i"
}

got=0
for ((n = 1; n <= COUNT; n++)); do
	touch "$MARK"
	sleep 1  # 표시 파일과 새 그림의 시각이 같은 초로 겹치지 않게
	log="$LOG_DIR/${NAME}_try$n.log"
	# -i는 값을 여러 개 받으므로(-i <FILE>...) 요청문 앞에 --를 둔다. 없으면 요청문까지 그림 경로로 먹혀 "No prompt provided"로 끝난다
	"${TIMEOUT_CMD[@]}" codex exec "${FLAGS[@]}" ${REF_ARGS[@]+"${REF_ARGS[@]}"} -- "$PROMPT" > "$log" 2>&1 < /dev/null
	status=$?
	found=0
	if [ -d "$GEN_DIR" ]; then
		while IFS= read -r img; do
			[ -n "$img" ] || continue
			idx="$(next_index)"
			ext="${img##*.}"
			dest="$OUT_DIR/${NAME}_$idx.$(printf '%s' "$ext" | tr 'A-Z' 'a-z')"
			# PNG가 아니면 확장자 그대로 둔다. 붙이기 검사가 PNG로 바꾸거나 거른다
			cp "$img" "$dest" && echo "저장: $dest" && found=$((found + 1))
		done < <(find "$GEN_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -newer "$MARK" 2>/dev/null | sort)
	fi
	if [ "$found" -eq 0 ]; then
		echo "실패 ($n번째): 새 그림이 없다. codex 종료 코드 $status, 로그 $log" >&2
		[ "$status" -eq 124 ] && echo "  ${TIMEOUT_SEC}초 안에 끝나지 않았다. --timeout을 늘린다." >&2
		tail -n 5 "$log" | sed 's/^/  | /' >&2
	fi
	got=$((got + found))
done

echo "결과: $got/${COUNT}장"
[ "$got" -gt 0 ] || exit 1
exit 0
