---
name: view-check
description: 화면을 찍거나 눈으로 확인할 때 사용. 스크린샷 setup 고르기, --view_2d 평면 보기, 3D 층 화면, 3D 화면 검사를 하나씩 돌리기(tests/view_3d/check_*.gd), 전투 장면 촬영, 시야 스크린샷·연속 스크린샷·프레임 시간, 박쥐 무리 경로 그림, 두 PNG 비교, 여러 장 붙이기. "스크린샷", "찍어 줘", "화면 확인", "화면 보여 줘", "3D 화면", "앞벽", "벽 가림", "흔들림", "일렁임", "깜빡임", "시야가 어떻게 보여", "프레임 시간", "전후 사진 비교" 같은 말이 나오면 쓴다. 여러 안을 나란히 찍어 고르게 하는 비교판은 이 스킬이 아니라 compare-variants 에이전트가 한다.
---

# 화면 확인

화면에 보이는 것을 바꾼 뒤 확인하거나, 사용자가 화면을 보여 달라고 하면 이 방법을 쓴다.
기본 스크린샷 명령, 언제 찍는지, 저장한 PNG를 직접 열어 보고 무엇이 보였는지 보고하는 규칙은 CLAUDE.md의 "검증"에 있다.
창을 띄우는 명령에는 `--headless`를 붙이지 않는다 (3D가 그려지지 않는다). 조작감·화면 배치는 사용자에게 확인을 부탁한다.

## 1. 스크린샷 setup과 보기 방식

- setup은 `tools/screenshot_setups/`에 있다. 파일마다 맨 위 주석에 무엇을 찍는지와 명령 예가 있다. 목록: `grep -m1 '^##' tools/screenshot_setups/*.gd`
- 지역 데이터의 `view_3d`가 켜진 지역은 창에서 3D로 그린다. 사용자 인자에 `--view_2d`를 더하면 평면 디버그 보기다 (시야 없이 전부 보임, 규칙과 화면이 어긋날 때 비교용).
- 3D 층 화면 (조준 고정): `--setup=res://tools/screenshot_setups/view_3d_on.gd`, 쥐 굴 바위 앞: `--scene=res://regions/shallow_cave.tscn --setup=res://tools/screenshot_setups/view_3d_preview.gd`
- 맵 전체·전망 바위 스크린샷은 `map-edit` 스킬, 쥐 그림 확인은 CLAUDE.md의 "에셋", 네크로맨서 걷기 그림 확인은 `assets/ASSETS.md`에 있다.

## 2. 3D 화면 검사 하나씩

전체는 `bash tests/run_view_3d.sh`다 (CLAUDE.md). 하나만 다시 볼 때는 `tests/view_3d/`의 검사를 따로 돌린다. 창을 띄우고, `run_all.sh`에는 없다.
- 3D 지형: `bash tools/godot.sh --fixed-fps 60 --path . -s tests/view_3d/check_terrain_3d.gd -- --scene=<씬>` (칸 색이 2D와 같은지, 구역 경계 틈, 화면 밖 구역을 안 그리는지)
- 아래 검사도 같은 꼴로 돌린다 (`bash tools/godot.sh --fixed-fps 60 --path . -s tests/view_3d/<파일>`, 사용자 인자는 `--` 뒤).
  - 몸과 앞벽 처리: `check_bodies_3d.gd` (그림 픽셀 일치, 임시 도형·시체·물건 색, 번쩍임, 8방향 조준, 반투명·잘라내기, 시야와 반투명)
  - 바닥 표시·탄·돌·도넛·상자·키 안내: `check_marks_3d.gd -- --scene=<씬>`
  - 시야: `check_vision_3d.gd` (2D 판정과 밝기 일치, 어두운 곳·빛 밝기, 상자, 반경 키, 언데드 8마리 프레임 시간. `-- --marks --out=<png>`는 앞벽 뒤 예고가 보이는지만 잰다)
  - 그린 화면의 벽 가림: `check_wall_occlusion.gd` (화면 회전 0/45도, 앞벽 끔/켬, 둘레 안 점을 잘라내기 자리별로 나눠 출력)
  - 걷는 동안 몸·바닥 흔들림: `check_camera_motion.gd`
  - 벽 픽셀 흔들림: `check_wall_flicker.gd` (`--target=layer|terrain --mode=static|poses`, 찍은 순간의 카메라·발밑 위치를 출력)
- 전투 장면 촬영 (예고·돌·탄·도넛, 판정 없음): `bash tools/godot.sh --fixed-fps 60 --path . -s tools/shot_view_3d_combat.gd -- --out=<a.png>`

## 3. 시야

- 개발 빌드에서 F2로 켜고 끈다 (배포판에서는 동작하지 않음).
- 스크린샷: `--scene=res://regions/shallow_cave.tscn --setup=res://tools/screenshot_setups/vision_preview.gd` (쥐 둥지 바위 앞, 동쪽을 봄. 쥐 넷: 정면·바위 뒤·부채꼴 밖·몸 바로 뒤)
- 움직이는 모습 연속 스크린샷: `bash tools/godot.sh --path . -s tools/record_vision_sequence.gd -- --out=<scratchpad 경로>/seq` (제자리 돌기·걷기·바위 옆 지나가기, 장면마다 12장을 모은 한 장과 낱장)
- 언데드 시야와 빛 겹침 스크린샷: `--scene=res://regions/shallow_cave.tscn --setup=res://tools/screenshot_setups/vision_undead_overlap.gd` (쥐 언데드 둘: 플레이어와 같은 쪽을 봄(겹침) / 다른 쪽을 봄)
- 프레임 시간: `tests/view_3d/check_vision_3d.gd`의 [측정] 줄 (트인 곳·벽이 촘촘한 곳, 언데드 0·8마리)
- 언데드 시야 값은 `SightData`(`data/sight/`)에 둔다. 몬스터 데이터의 `undead_sight`가 비어 있으면 `undead_default.tres`를 쓴다.

## 4. 박쥐 무리 경로 그림

- `bash tools/godot.sh --headless --fixed-fps 60 --path . -s tools/record_pack_paths.gd -- --seconds=12 --out=<scratchpad 경로>/pack_paths.png`
- 네크로맨서를 세워 두고 박쥐 3마리의 경로를 3초씩 칸으로 나눠 그린다(흰 테두리 점은 동시 돌진 예고).
- 도는 방향 바꾼 횟수, 박쥐끼리 가장 가까운 거리, 동시 돌진 시작 때 박쥐 사이 각도를 출력한다.

## 5. PNG 비교와 붙이기

- 두 PNG 비교: `bash tools/godot.sh --headless --path . -s tools/compare_images.gd -- <a.png> <b.png>` (달라진 픽셀 수·범위. 같으면 종료 코드 0)
- 여러 장 붙이기: `bash tools/godot.sh --headless --path . -s tools/contact_sheet.gd -- --out=<a.png> --columns=2 <1.png> <2.png> ...` (크기가 달라도 된다. `--numbers`는 그림마다 번호표, `--labels=<UTF-8 글 파일>`은 번호표와 범례 `<a>_legend.txt`)
- 여러 안을 같은 장면에서 찍어 나란히 보고 고르게 할 때(비교판)는 직접 찍지 말고 `compare-variants` 에이전트에 맡긴다 (`tools/compare_variants.sh`로 안마다 setup이나 worktree를 만들어 같은 인자로 찍는다). 사용자가 고른 것은 `decide` 스킬로 기록한다.
