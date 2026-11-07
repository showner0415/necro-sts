# 에셋 목록

모든 에셋을 여기에 기록한다. 상태는 `임시` / `검토 중` / `확정` 중 하나.
`확정` 에셋은 사용자에게 묻지 않고 덮어쓰지 않는다.

| 이름 | 결과물 경로 | 원본·생성 스크립트 | 주요 파라미터 | 상태 | 메모 |
|---|---|---|---|---|---|
| Endesga 32 팔레트 | `assets/palette/endesga-32.hex` | Lospec에서 받음 (ENDESGA, https://lospec.com/palette-list/endesga-32.hex) | 32색 | 확정 | 모든 에셋이 이 색만 쓴다 (`docs/art-direction.md`). 2026-11-06에 Resurrect 64(Kerrie Lake)에서 바꿈. Lospec 페이지에 라이선스·사용 조건이 적혀 있지 않다 (2026-11-06 확인). 출시 전에 ENDESGA에게 확인하고 크레딧에 ENDESGA 표기 |
| 네크로맨서 8방향 정지 그림 | `assets/necromancer/necromancer_<방향>.png` (east, south_east, south, south_west, west, north_west, north, north_east) | `art_src/necromancer/Create_a_high-quality_si-pallete.zip` (PixelLab에서 만듦, 2026-11-06. 안의 `pallete/rotations/<방향>.png`, 만들 때 쓴 설명은 `metadata.json`) | 32×32, 8방향, 애니메이션 없음, 12색, 반투명 픽셀 없음. 발이 y=28 → `Sprite2D` offset (-16, -28) | 검토 중 | 변환 방법: 압축을 풀어 `pallete/rotations/<방향>.png`을 그대로 복사하고 이름만 `necromancer_<방향>.png`(하이픈 → 밑줄)로 바꾼다. 처음부터 Endesga 32 색이라 색 변환은 하지 않았다 (`tools/check_palette.gd` 통과). 필터는 프로젝트 기본값 Nearest. 나중에 같은 캐릭터로 애니메이션을 추가하면 압축 파일과 같은 폴더에 둔다. 탄이 나가는 자리(`necromancer.tscn`의 Sprite `direction_muzzles`, 발밑 기준)는 방향마다 보석 색(2ce8f5·0099db) 픽셀이 이어진 가장 큰 덩어리의 가운데를 반올림해 쟀다 (`tools/measure_sprite_point.gd -- --prefix=res://assets/necromancer/necromancer_ --colors=2ce8f5,0099db --origin=16,28`): 동 (3,-17), 남동 (-3,-16), 남 (-8,-17), 남서 (-8,-18), 북서 (7,-23), 북 (9,-19), 북동 (8,-19). 서쪽은 지팡이가 몸 뒤에 가려져 동쪽을 좌우로 뒤집은 (-3,-17)을 쓴다 (사용자 결정). 그림을 바꾸면 다시 잰다 |
| 조준점 커서 | `assets/ui/aim_cursor/aim_cursor_x<배율>.png` (배율 1~6, 11×11 ~ 66×66) | `tools/asset_gen/aim_cursor.gd` (`bash tools/godot.sh --headless --path . -s tools/asset_gen/aim_cursor.gd`) | 십자 9×9(`CROSS_SIZE`), 가운데 빈 칸 3(`CENTER_GAP`), 팔 두께 1, 테두리 1, 밝은 색 ffffff·테두리 181425(팔레트 번호로 지정), 최대 배율 6 | 검토 중 | 게임 화면 위의 시스템 커서(`ui/aim_cursor.tscn`, HUD 안). 가운데 픽셀이 마우스 위치(hotspot). 테두리는 가운데 빈 칸에는 두르지 않는다(두르면 가운데가 막혀 보임). 바닥 위 미리보기: `tools/screenshot_setups/aim_cursor_preview.gd` |
