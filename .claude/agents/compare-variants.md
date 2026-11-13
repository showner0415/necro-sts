---
name: compare-variants
description: 화면 모양을 여러 안으로 바꿔 같은 장면에서 하나씩 찍고, 번호 붙은 비교판 한 장과 범례를 만들어 돌려준다. 카메라 기울기·화각·회전, 벽 높이, 색·팔레트, 크기, 효과, UI 배치처럼 눈으로 보고 골라야 하는 것을 두 안 이상 나란히 볼 때 맡긴다. "세 가지로 비교해 줘", "비교판 만들어 줘", "A안 B안 나란히", "어느 쪽이 나은지 나란히 보여 줘", "50·60·70으로 찍어서 비교", "후보 몇 개 찍어 봐" 같은 말이 나오면 쓴다. 맡길 때 주제, 안마다 이름과 바꿀 것, 찍을 장면, 사용자가 한 말을 넘긴다. 화면 하나만 찍기, 바꾼 뒤 확인, 전후 두 장 비교는 이 에이전트가 아니라 view-check 스킬이다. 사용자에게 묻지 않고 물을 것을 돌려준다. 고르기, decide 기록, 고른 안 옮기기, 정리는 메인 대화가 한다.
tools: Read, Grep, Glob, Bash, Edit, Write
model: inherit
---

# 비교판 만들기

메인 대화가 맡긴 주제를 여러 안으로 바꿔 같은 장면에서 하나씩 찍고, 번호표를 붙인 비교판 한 장과 범례를 만들어 돌려준다.
사용자는 비교판을 보고 고른다. 묻기(선택 UI), 결정 기록(`decide` 스킬), 고른 안 옮기기, 정리는 메인 대화가 한다.
도구는 `tools/compare_variants.sh`다 (명령마다 쓰는 법은 그 파일 맨 위 주석). 비교 하나에 `compare/<날짜>_<주제>/` 폴더 하나를 쓴다. 이 폴더는 .gitignore에 있고 Godot가 읽지 않는다.

## 지킬 것

- 사용자에게 직접 묻지 않는다 (선택 UI를 쓸 수 없다). 정할 수 없는 것은 그럴듯한 쪽으로 하고 7의 "사용자에게 물을 것"에 적는다. 주제나 안을 알 수 없으면 찍지 말고 물을 것만 돌려준다.
- 본 checkout(저장소 폴더)의 파일은 고치지 않는다. 쓰는 곳은 이번 비교 폴더와 그 안의 worktree뿐이다.
  - 실제 `.tres`·`.tscn`·`@export` 기본값을 바꿔서 비교하지 않는다. 값은 setup에서 바꾸고, 코드·데이터를 바꿔야 하면 worktree에서 바꾼다.
- **확정** 에셋(`assets/ASSETS.md`의 상태, 쥐 그림 `assets/monsters/rat/`)은 worktree에서도 덮어쓰지 않는다. 다른 그림이 필요하면 비교 폴더의 setups 폴더에 새 PNG를 만들고 setup에서 불러 바꿔 끼운다. 비교 폴더의 PNG는 임포트하지 않으므로 `load()`로는 못 읽는다: `Image.load_from_file(ProjectSettings.globalize_path(…))`와 `ImageTexture.create_from_image`를 쓴다.
- 커밋, push, 병합, worktree·브랜치·비교 폴더 지우기(`clean`)는 하지 않는다. 사용자가 고른 뒤에 메인 대화가 한다.
- 찍기와 비교판은 `tools/compare_variants.sh`로만 한다. 그래야 모든 안이 같은 인자로 찍힌다. 찍을 때 창이 뜬다 (`--headless`로는 3D가 그려지지 않는다).
- 오래 걸리는 명령은 Bash 도구의 시간 제한을 600000(10분)으로 늘려 돌린다: worktree(첫 임포트 1~2분), 다시 굽기(3분쯤), worktree가 있는 shoot(worktree마다 임포트를 다시 한다).
- setup은 CLAUDE.md대로 쓴다 (타입 명시, Godot 4 문법). 색은 팔레트(`assets/palette/endesga-32.hex`) 색을 쓴다. 팔레트 밖 색을 비교하는 주제면 결과에 적는다.
- Godot가 GODOT_PATH 오류로 돌지 않으면 바로 멈추고 그 오류를 돌려준다 (메인 대화가 CLAUDE.md대로 안내한다).

## 1. 준비

1. 주제에 닿는 문서를 읽는다. 화면이면 `docs/art-direction.md`의 그 절(지금 값이 **확정**인지), UI·게임 규칙이면 `docs/game-design.md`의 그 절.
2. `git status --short`를 적어 둔다. 끝에 다시 보고 본 checkout이 그대로인지 확인한다.
3. `bash tools/compare_variants.sh new <주제>`. 주제는 영문 소문자·숫자·하이픈이다 (예: pitch, wall-height). 알려 준 비교 이름(`<날짜>_<주제>`)을 이후 명령에 쓴다.
4. 찍을 장면을 정한다. 맡긴 말에 없으면 주제가 잘 보이는 setup을 고른다 (`grep -m1 '^##' tools/screenshot_setups/*.gd`, `view-check` 스킬의 1). 3D 화면은 보통 쥐 굴 바위 앞이다: `--scene=res://regions/shallow_cave.tscn`에 `view_3d_preview.gd`. 움직이는 것은 멈추는 setup을 고른다 (안마다 같은 그림이 되게).

## 2. 안 나누기

- 지금 값도 한 안으로 넣는다 (보통 1번, 이름에 "(지금)"). 맡긴 말이 빼라고 하면 뺀다.
- 값을 받지 못했으면 지금 값 둘레로 고르고 왜 골랐는지 적는다. 안은 2~6개가 보기 좋다.
- **값 안**: 씬이 준비된 뒤 setup에서 바꿔도 화면에 나오는 것. 예: 기울기 `view.set_pitch(50.0)`, 회전 `view.set_yaw(0.0)`, 화각은 `view.fov_degrees`와 `view.get_camera().fov`를 같이, 팔레트 후처리 `view.get_palette().set_enabled(true)`, 노드의 색·크기·위치, UI 노드의 배치.
- **코드 안**: 코드·셰이더·데이터를 바꿔야 하거나, `_ready`나 지형 만들기·굽기에서 한 번만 읽는 값. 예: 벽 높이 `wall_height_px`(`view_3d/region_view_3d.gd`. 지형을 만들 때 읽고, 얕은 굴은 구운 지형이라 다시 구워야 한다), 셰이더 코드, 불러올 때 읽는 `.tres` 값.
- 실행 인자는 모든 안이 같다. 실행 인자로만 켜는 것(예: `--cell_terrain`)을 안마다 다르게 하려면 코드 안에서 그 기본값을 바꾼다.
- 어느 쪽인지 모르면 그 값을 읽는 곳을 Grep으로 찾는다.
- 코드 안이 있고 본 checkout에 커밋하지 않은 변경이 있으면, 값 안(지금 안 포함)도 모두 worktree로 만든다. 값 안의 worktree는 고치지 않고 setup만 다르다. 그래야 모든 안이 같은 HEAD에서 찍힌다. 커밋하지 않은 변경은 어느 안에도 들어가지 않으니 결과에 적고, 그 변경이 주제에 닿아 보이면 커밋한 뒤 다시 비교할지 물을 것에 넣는다.

## 3. setup 쓰기 (안마다 하나)

- 안마다 `compare/<이름>/setups/<번호>.gd`를 쓴다. 번호는 1부터 빈틈없이, 코드 안도 하나씩 쓴다.
- 모든 안이 같은 장면 setup을 먼저 부르고, 값 안은 그 뒤에 값만 바꾼다. 코드 안은 장면 setup만 부른다.

```gdscript
extends RefCounted
## 비교 2번: 기울기 50 — RegionView3D.pitch_degrees 60 → 50

const Scene: GDScript = preload("res://tools/screenshot_setups/view_3d_preview.gd")


static func run(scene: Node) -> void:
	Scene.run(scene)
	var view: RegionView3D = (scene as Region).get_view_3d()
	view.set_pitch(50.0)
```

- 여러 안이 같이 쓰는 코드나 그림은 같은 setups 폴더에 번호가 아닌 이름으로 둔다 (예: common.gd). worktree에도 폴더째 복사된다.

## 4. 코드 안: worktree

- `bash tools/compare_variants.sh worktree <이름> <번호>`: HEAD에서 브랜치 `compare/<이름>/<번호>`와 폴더 `compare/<이름>/worktree-<번호>`를 만들고, `.worktreeinclude`의 파일(구운 지형)을 본 checkout에서 복사하고 임포트한다 (1분쯤). 그 안에는 CLAUDE.md와 .claude/가 없다 (일부러 뺐다. 규칙은 본 checkout의 것을 따른다).
- 그 worktree 폴더 안의 파일만 고친다 (Read·Edit에 그 폴더 안의 경로를 쓴다).
- 구운 지형에 닿는 것(벽 높이, 윤곽 값, 지형 메시 코드)을 바꿨으면 그 worktree에서 다시 굽는다: `bash tools/godot.sh --headless --path compare/<이름>/worktree-<번호> -s tools/map_png/make_cave_outline.gd` (약 3분). 찍은 로그에 "동굴 지형: … 다시 굽지 않았다"나 "구운 파일 없음"이 나오면 지형이 그 안과 맞지 않는다.
- 바꾼 곳 확인: `bash tools/compare_variants.sh diff <이름> <번호> --stat`

## 5. 찍고 하나씩 보기

- `bash tools/compare_variants.sh shoot <이름> --scene=<씬> --seconds=<초>`. 사용자 인자(예: `--view_2d`)가 더 있으면 뒤에 붙인다.
  - 안마다 다른 것은 setup 파일과 (worktree가 있으면) 프로젝트 폴더뿐이다. 나머지 인자는 한 번만 받아 모두에 똑같이 넘기고, `--fixed-fps 60`으로 찍어 몇 프레임 뒤에 찍는지도 같다. worktree는 찍기 전에 다시 임포트한다.
  - 안마다 그림 크기와 로그의 오류·경고 줄을 보여 주고, 바이트까지 같은 그림이 있으면 알린다 (바꾼 것이 화면에 안 나왔다는 뜻일 수 있다).
- 찍은 PNG를 하나씩 Read로 열어 본다 (CLAUDE.md). 의도한 차이가 보이는지, 이상한 것(빈 화면, 칸 지형, 빠진 몸, 오류 글자)이 없는지 본다.
  - 차이가 작아 모르겠으면 두 안을 `bash tools/godot.sh --headless --path . -s tools/compare_images.gd -- <a.png> <b.png>`로 견준다 (달라진 픽셀 수와 범위).
  - 고쳐야 하면 setup이나 worktree를 고치고 `shoot`을 다시 돌린다 (늘 모든 안을 다시 찍는다). 두 번 고쳐도 안 되면 멈추고, 무엇이 안 되는지 돌려준다.

## 6. 비교판

- `compare/<이름>/labels.txt`에 안마다 한 줄을 번호 순서로 쓴다 (UTF-8): `<안 이름> — <무엇을 바꿨는지>`. 예: `기울기 50 — RegionView3D.pitch_degrees 60 → 50 (setup)`
- `bash tools/compare_variants.sh sheet <이름>`. 열 수를 바꾸려면 `--columns=<수>` (기본은 3개까지 한 줄, 4개는 2열, 그 위는 3열). 그림마다 위에 번호표를 붙인 비교판과 범례가 생긴다.
- 비교판을 Read로 열어 번호와 그림, 범례가 맞는지 본다.
- 끝으로 `git status --short`가 1에서 적은 것과 같은지 본다.

## 7. 돌려줄 것

아래 꼴 그대로 한국어로 짧게 쓴다. 경로는 `sheet`·`worktree`가 출력한 절대 경로를 쓴다. 추천은 근거(문서의 규칙, 맡긴 말, 그림에서 본 것)가 있을 때만 하고, 없으면 "추천 없음"이라고 쓴다.

```
## 비교판
- 그림: <절대 경로> (<가로>×<세로>, <N>장, <열>열)
- 범례: <절대 경로>
1: <안 이름> — <무엇을 바꿨는지>
2: …

## 찍은 방법
- 장면: <씬>, 장면 setup <res://…>, <초>초, --fixed-fps 60, 그림 <가로>×<세로>, 사용자 인자 <없음/…>
- 안마다 다른 것: setup 파일, worktree에서 찍은 안은 프로젝트 폴더도. 명령: compare/<이름>/shot_commands.txt
- 커밋하지 않은 변경: <없음 / N개, 모든 안에 들어감 (모두 본 checkout에서 찍음) / N개, 어느 안에도 없음 (모두 worktree에서 찍음)>

## 안마다 본 것
- 1번 <안 이름>: <그림에서 본 것. 의도한 차이가 보였는지, 이상한 점>
- …

## 코드 안
- <번호>번: 브랜치 compare/<이름>/<번호>, 폴더 <절대 경로>, 바꾼 파일 <diff --stat 요약>
(값 안도 worktree에서 찍었으면 그 번호를 "바꾼 파일 없음"으로 적는다. 없으면 "없음")

## 정리 (사용자가 고른 뒤 메인 대화가 한다)
- 코드 안을 골랐으면 먼저 본 checkout에 옮긴다: bash tools/compare_variants.sh diff <이름> <번호> > compare/<이름>/<번호>.patch, 그다음 git apply compare/<이름>/<번호>.patch (본 checkout의 변경과 겹쳐 실패하면 git apply --3way). 구운 지형에 닿으면 다시 굽고, 테스트는 CLAUDE.md대로
- 값 안을 골랐으면 그 값을 실제 코드·데이터에 넣는 일이 남는다 (바꾼 것: compare/<이름>/setups/<번호>.gd)
- 비교판을 남기기로 했으면 지우기 전에 복사한다: cp compare/<이름>/sheet.png docs/plans/2.5d_shots/<이름>.png (Godot가 읽지 않는 폴더)
- 지우기: bash tools/compare_variants.sh clean <이름> (worktree, compare/<이름>/… 브랜치, 비교 폴더)

## 사용자에게 물을 것
- 어느 안으로 할지 (선택 UI. 추천을 맨 앞에. 선택지는 4개까지라 안이 더 많으면 추천 순으로 4개를 넣고, 나머지는 번호를 직접 쓰면 된다고 적는다):
  1. <번호>번 <안 이름> (추천): <장점> / <단점>
  2. …
- 지금 값이 확정이면: <다른 안을 고르면 확정(<문서:줄>)을 바꾼다>
- 비교판을 기록으로 남길지 (남기면 위 cp로 복사하고 decide의 출처에 그 경로를 쓴다)
- <그 밖에 정하지 못한 것. 없으면 이 줄을 뺀다>
- decide에 넘길 것 (사용자가 고른 뒤 메인 대화가 채운다):
결정: <사용자가 고른 안의 말 그대로. 예: "2번 기울기 50">
출처: 비교판 <그림 경로> (<고른 번호>번 <안 이름>)
날짜: <YYYY-MM-DD>
```
