# 봇 계획 재개 전 점검: 2.5D 전환 뒤 측정 재현 (2026-11-10)

코드: `336aca3` (2.5D 이전 8단계 합친 main). 봇은 지금의 측정 봇(회피 성공률 방식), full 시야, 실력마다 50판.

명령:
- `bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_balance.gd -- --runs=50` (9분 33초)
- `bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_undead_duel.gd -- --runs=50` (3분 29초)

## 결과

`2026-11-10_rat_undead_no_windup.md`의 "전체" 표와 "언데드 대결" 표의 51줄(제목 줄 포함)이 글자까지 같다. 출력에 `SCRIPT ERROR`·`ERROR:`·`[실패]`는 없다.

그 파일에서 일치하지 않은 7줄은 손으로 만든 전후 비교 표이고, 측정 출력에 없는 표다.

결론: 시험 지역 측정(`run_balance.gd`, `run_undead_duel.gd`)은 2.5D 전환의 영향을 받지 않았다. 계획서의 "지금" 값은 그대로 쓸 수 있다. 얕은 굴 2배 맵의 기준값은 여전히 없다 (`2026-11-10_map_route_2x_partial.md`).

## 맵 측정 동작 확인 (판 수가 적어 기준값이 아니다)

`bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_map_route.gd -- --routes=bat --skills=normal --undead=0 --runs=2` (9.4초)

| 길 | 조건 | 실력 | 판 | 죽음 | 지나간 시간 | 받은 피해 평균 / 최대 | 잡은 수 / 남긴 몬스터 | 시간 초과 | 명중률 |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| 박쥐 길 | 혼자 | 보통 | 2 | 0% | 121.4초 | 4.5 / 6.0 | 3.0 / 3 | 0 | 64% |

## 3D 층이 붙었을 때의 이동 입력

`scenario_view_3d_boundary.gd` 통과. `press_moves(Vector2.UP)`로 20프레임에 (-18.86, -18.86) 이동했다. 3D 층이 있으면 `press_moves`는 화면 기준이므로, 월드 방향을 넣는 봇은 창으로 볼 때 45도 틀어져 걷는다. 헤드리스에는 3D 층이 없어 측정에는 영향이 없다.
