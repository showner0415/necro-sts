---
name: balance-measure
description: 밸런스·몬스터 AI·언데드 능력치를 숫자로 잴 때 사용. 플레이어 봇과 실력·시야 옵션, 싸움 측정(run_balance), 언데드 대 적(run_undead_duel), 실제 맵 지나가기(run_map_route), 원인 진단(run_diagnose), 사람이 같은 싸움을 직접 해 보기(play_case), 결과 저장(tests/balance/results/)과 전후 비교표. "밸런스", "측정", "재 봐", "몇 초에 잡아", "죽는 비율", "봇", "언데드 대결", "교착", "전후 비교", "AI를 바꿨다", "너무 세다", "너무 약하다" 같은 말이 나오면 쓴다.
---

# 밸런스 측정

`tests/balance/`의 스크립트가 실제 게임 규칙 그대로 싸움을 여러 번 돌려 숫자로 낸다. 판정이 없어서 `tests/run_all.sh`에는 넣지 않는다.
몬스터를 추가하면 `TARGETS`에 넣는 규칙과, 측정 결과를 보고할 때 `tests/balance/results/`에 저장하는 규칙은 CLAUDE.md에 있다.
고블린 투석병 데이터는 `run_balance.gd`·`run_undead_duel.gd`에서 인자로 측정 안에서만 바꿀 수 있다 (메모리의 데이터만 바꾸고 실제 .tres는 그대로, `tests/scenario_test.gd`의 `apply_goblin_args`): `--burst`(`throw_burst_count`), `--burst_interval`(`throw_burst_interval`), `--stone_damage`(`contact_damage`), `--stone_cooldown`(`attack_cooldown`), `--goblin_undead_health_ratio`·`--goblin_undead_damage_ratio`(`undead_health_ratio_override`·`undead_damage_ratio_override`). 예: `bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_undead_duel.gd -- --monsters=goblin_slinger --goblin_undead_damage_ratio=0.5`
스크립트마다 옵션 전체는 그 파일 맨 위 주석에 있다. 길목·벽 모서리 걷기(`run_choke_walk.gd`, `run_stuck_walk.gd`)는 맵 검사라 `map-edit` 스킬에 있다. 몬스터 처리 부하(프레임 시간·길찾기 횟수, 쥐 32 + 멧돼지 8이 측정 굴에서 쫓음)는 `bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_path_load.gd`로 잰다 (결과 예: `tests/balance/results/2026-11-14_path_load.md`).

## 1. 봇과 싸움 측정 (run_balance)

- 플레이어 봇(`tests/balance/player_bot.gd`)이 실제 입력만 흉내 내서 싸우고, `run_balance.gd`가 대상 × 조건(혼자 / 쥐 언데드 2마리) × 실력(숙련·보통·초보)마다 여러 번 싸워 잡는 시간·받은 피해·죽은 비율·명중률을 표로 낸다. 실력 이름은 `skilled`·`normal`·`novice`다.
- 봇의 시야는 `--sight=full`(기본, 시야와 상관없이 모든 몬스터·돌의 위치를 안다)과 `--sight=cone`(플레이어나 언데드 시야에 보이는 몬스터·돌만 앎)이 있다. cone이면 겨눌 몬스터가 없으면 걷는 방향을 보며 실력마다 정한 간격으로 좌우를 둘러본다 (`player_bot.gd`의 `look_around`).
- 전부: `bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_balance.gd` (약 1분)
- 일부: `-- --targets=boar,bat_pack --skills=normal --undead=0 --runs=5`, 거리 두기를 끄려면 `--keep=0`, 무리 동시 공격(박쥐 동시 돌진)을 처음 N번 일부러 못 피하게 하려면 `--miss_pack=N` (놓친 동시 공격 피해·직후 마나·최저 마나·언데드 죽음/해제 열로 "실수 한 번의 값"을 본다)
- 창으로 보기: `bash tools/godot.sh --path . -s tests/balance/run_balance.gd -- --targets=boar --skills=normal --undead=0 --runs=1`
- 표 아래에 잡은 시간·받은 피해·죽음의 95% 오차 범위 표가 함께 나온다. 전후를 비교할 때는 이 범위를 같이 본다.
- 판마다 시작할 때 씬과 몬스터 수를 검사한다 (`check_fight_start`). 틀리면 `[실패] 판 시작 검사`를 남기고 그 판을 빼며, 측정은 계속하되 종료 코드 1로 끝난다.

## 2. 언데드 대 적 (run_undead_duel)

- 같은 몬스터끼리: `bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_undead_duel.gd` (일부: `-- --monsters=rat,boar --cases=1,3 --runs=10 --skill=normal`).
- 경우 1 언데드 1 vs 적 1(목표: 진다), 2 언데드 1 + 네크로맨서(봇) vs 적 1(목표: 이긴다), 3 언데드 2 vs 적 1(목표: 이긴다). 1·3은 네크로맨서가 구경만 하고 마나가 바닥나지 않는다
- 대결 표의 "교착"은 시간 초과인데 적과 언데드가 5초 넘게 서로 노리지 않은 판이다. 원인 추적: `--monsters=rat --cases=3 --trace=rat` (시간 초과 판의 거리 변화), `--monsters=boar --cases=2 --trace=boar` (돌진 뒤 누구를 노리는지, `--no_turn_away=1` 적만·`2` 둘 다·`3` 언데드만 거리 벌리기를 끈다)

## 3. 실제 맵에서 지나가기 (run_map_route)

- `bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_map_route.gd` (얕은 굴의 박쥐 길(둥지 가운데로·입구 → 출구 기본 길·몰래 가는 길)·멧돼지 쪽 지나가기·멧돼지 잡으러, 약 3분. 일부: `-- --routes=bat --skills=normal --undead=0 --runs=3`. 물러나기도 재려면 `--retreat=0,1,2`: 1은 언데드를 모두 잃거나 체력이 절반 이하면, 2는 체력이 절반 이하일 때만 싸움을 그만두고 탈출 B로 간다. 1이나 2 중 하나만 줘도 둘 다 나란히 잰다. 시험용으로 실제 데이터를 바꾸지 않고 `--undead_attack_range=<px>`(쥐 언데드 공격 거리)를 줄 수 있다. 시간 초과한 판은 멈춘 자리와 노리는 몬스터 상태를 출력한다. 다른 판의 맵과 비교하려면 `--scene=<씬> --png=<배치 PNG>`)
- 걸려 온 몬스터만 봇이 상대하고 나머지는 길찾기로 걷는다. 지나간 시간·피해·죽은 비율·물러나 탈출한 비율·잡은 수·언데드 죽음·언데드가 같은 프레임에 함께 죽은 판을 낸다
- 얕은 굴 2배 맵의 새 기준값은 아직 없다 (`tests/balance/results/2026-11-10_map_route_2x_partial.md`, 사용자가 측정을 멈춤). 맵·밸런스 작업에서 이 측정이 필요해지면 먼저 사용자에게 다시 재자고 말한다.

## 4. 원인 진단 (run_diagnose)

- `bash tools/godot.sh --headless --fixed-fps 60 --path . -s tests/balance/run_diagnose.gd -- --mode=charge_sight --runs=10` (돌진 시작 때 봇이 멧돼지를 봤는지, 그 돌진에 맞았는지. `--skills=skilled --runs=1 --trace=1`이면 0.2초마다 상태 출력)
- `--mode=goblin_time --runs=50` (고블린이 살아 있는 동안 봇이 무엇을 했는지, 누가 때렸는지. `--no_retreat=1`은 테스트 안에서만 물러나기를 끈다)
- `--mode=aim_sight --runs=50` (박쥐 혼자·고블린+쥐 언데드 2에서 겨눈 몬스터와 화면 방향의 차이, 시야가 튄 횟수, 공격이 시작될 때 봤는지와 맞았는지. `--no_vision=1`은 시야를 끄고 잰다)

## 5. 사람이 같은 상황을 직접 해 보기 (play_case)

- `bash tools/godot.sh --path . -s tools/play_case.gd -- --target=bat_pack` (고블린+쥐 언데드 2는 `--target=goblin_pair --undead=2`, 소환은 1 → G, 2 → G). 측정과 같은 싸움터이고 몬스터는 동쪽에 있다

## 6. 결과 저장과 전후 비교

- 측정 결과를 사용자에게 보고할 때 저장하는 곳과 이름: `tests/balance/results/<날짜>_<내용>.md` (CLAUDE.md 규칙). 지난 결과도 이 폴더에 있다.
- 전후 비교 기준 결과표는 `tests/balance/results/<날짜>_<내용>.md`에 저장한다 (두 컴퓨터에서 본다). AI 전후 비교표에는 언데드 대결(언데드 1 vs 적 1, 언데드 1 + 네크로맨서, 언데드 2 vs 적 1, 몬스터 전부)을 항상 포함한다.
