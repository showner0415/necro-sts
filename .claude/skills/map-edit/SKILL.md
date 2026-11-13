---
name: map-edit
description: 맵(지역 씬)을 만들거나 고칠 때 사용. 맵 배치 PNG → 지역 씬 변환(tools/map_from_png.gd), 벽 윤곽과 구운 지형 만들기·다시 굽기(make_cave_outline), 바닥 통계(map_stats), 길목 폭 재기(measure_chokes), 몸이 길목·벽 모서리를 실제로 지나가는지 걷기(run_choke_walk, run_stuck_walk), 맵 전체·전망 바위 스크린샷. "맵", "굴", "통로", "길목", "바위", "배치 PNG", "벽 윤곽", "지형 굽기", "다시 구워", "구운 지형", "벽에 걸림", "맵 통계" 같은 말이 나오면 쓴다.
---

# 맵 고치기

맵의 원본은 배치 PNG다 (얕은 굴: `art_src/maps/shallow_cave.png`). 만든 지역 씬은 손으로 고치지 않고 PNG를 고쳐 다시 변환한다 (CLAUDE.md).
도구마다 다른 맵을 넣는 인자와 옵션 전체는 그 도구 맨 위 주석에 있다.

## 1. 배치 PNG → 지역 씬

- `bash tools/godot.sh --headless --path . -s tools/map_from_png.gd` (기본은 얕은 굴).
- 픽셀 하나 = 타일 한 칸이고 색 규칙은 `docs/maps/map_png_rules.md`. 얕은 굴의 굴 배치와 기준은 `docs/maps/shallow_cave_design.md`에 있다.
- 만든 씬(`regions/shallow_cave.tscn`)은 손으로 고치지 않고 PNG를 고쳐 다시 변환한다.
- 변환할 때 굴마다 입구 수·이어진 굴·바위를 출력한다.
- 만든 씬의 길찾기(`NavigationGrid.wall_tiles`)는 막힌 칸을 물리 질의 대신 벽 타일에서 바로 계산한다 (같은 결과, 훨씬 빠름).

## 2. 벽 윤곽과 구운 지형

- `bash tools/godot.sh --headless --path . -s tools/map_png/make_cave_outline.gd` (약 3분).
- 얕은 굴의 충돌·길찾기·시야는 윤곽 파일(`regions/shallow_cave_outline.res`, 저장소에 있음)을 쓰고, 화면은 구운 지형(`regions/shallow_cave_terrain.res`, 저장소에 없음)을 쓴다.
- PNG를 고치면 `map_from_png.gd` 뒤에 이 명령을 돌린다. 컴퓨터를 옮기거나 메시 코드를 고쳐도 이 명령으로 다시 굽는다 (안 하면 경고와 `test_cave_terrain_bake.gd` 실패).
- 칸 지형과 비교: 사용자 인자 `--cell_terrain`

## 3. 맵 재기

- 바닥 통계: `bash tools/godot.sh --headless --path . -s tools/map_png/map_stats.gd` (굴·통로 비율, 통로마다 가장 넓은 곳·길목 칸 수)
- 길목 폭: `bash tools/godot.sh --headless --path . -s tools/map_png/measure_chokes.gd` (길목마다 PNG 칸·실제 충돌·화면 윤곽의 폭과 몸별 기하 통과, 약 2분 30초. `-- --map=1`은 어긋난 길목의 칸 그림)
- 실제로 걸어 보기: `bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_choke_walk.gd` (몸 종류마다 양쪽으로 물리와 길찾기로 걷기, 판정 있음, `run_all.sh`에는 없음)
- 벽 모서리에 걸리는지: `bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_stuck_walk.gd -- --hug=60` (굴 사이·벽에서 출발하는 길, 약 5분, 판정 없음, `--clearance=<픽셀>`로 길찾기 여유를 바꿔 비교)
- 맵을 지나가는 시간·피해를 봇으로 다시 재야 하면 `balance-measure` 스킬을 쓴다 (얕은 굴 2배 맵의 기준값이 아직 없다는 메모가 거기 있다).

## 4. 맵 스크린샷

CLAUDE.md의 스크린샷 명령에 붙인다. setup마다 맨 위 주석에 `--scene`까지 든 명령 예가 있다.
- 맵 전체 스크린샷: `-- --view_2d --setup=res://tools/screenshot_setups/map_overview.gd` (2D 카메라로 찍는다)
- 전망 바위에서 박쥐 둥지 보기: `--setup=res://tools/screenshot_setups/view_rock.gd`

## 5. 고친 뒤 확인

- `bash tests/run_all.sh`를 돌린다. 얕은 굴 시나리오(`scenario_shallow_cave.gd` 구조, `scenario_shallow_cave_walk.gd` 걷기, `scenario_shallow_cave_undead.gd`·`scenario_shallow_cave_undead_2.gd` 언데드 따라오기)가 씬이 PNG와 같은지, 굴 연결, 걷기 시간, 언데드가 따라오는지 본다.
