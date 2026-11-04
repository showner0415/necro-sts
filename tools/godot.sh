#!/usr/bin/env bash
# 이 컴퓨터의 Godot를 실행한다. 경로는 저장소에 두지 않고,
# 컴퓨터마다 GODOT_PATH 환경 변수로 지정한다.
# 사용 예: bash tools/godot.sh --headless --path . --import

if [ -z "${GODOT_PATH:-}" ]; then
	echo "GODOT_PATH 환경 변수가 없습니다. 이 컴퓨터의 Godot console 실행 파일 경로로 설정한 뒤 Claude Code를 다시 시작하세요." >&2
	exit 1
fi

if [ ! -f "$GODOT_PATH" ]; then
	echo "GODOT_PATH가 가리키는 파일이 없습니다: $GODOT_PATH" >&2
	exit 1
fi

exec "$GODOT_PATH" "$@"
