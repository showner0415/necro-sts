extends RefCounted
## 스크린샷 준비: 공격권. 무리 시험 지역의 쥐 패거리(4마리)와 동쪽 쥐 무리(3마리)가 함께 네크로맨서를 노린다. 디버그 표시(F3)를 켠다.
## 쥐 7마리가 한 대상을 노리므로 공격권(쥐 2 + 추가 1)이 없는 쥐는 네크로맨서에게서 맴도는 거리(64)쯤에서 돈다.
## 공격권을 든 쥐는 발밑에 흰 점(추가 공격권은 노랑)이 있다. 시야는 끈다. 쥐들이 다 모이도록 늦게 찍는다:
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=5.5 --scene=res://regions/test_pack.tscn --setup=res://tools/screenshot_setups/attack_tokens.gd --out=<경로>

## 네크로맨서 자리: 두 무리 사이 (어느 쥐의 감지 범위 80에도 들지 않게)
const NECROMANCER_SPOT: Vector2 = Vector2(150, -60)
## 무리가 멤버를 묶는 첫 물리 프레임 뒤에 맞힌다 (초)
const HIT_DELAY: float = 0.2


static func run(scene: Node) -> void:
	var tree: SceneTree = scene.get_tree()
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	necromancer.max_health = 100000.0
	necromancer.health = necromancer.max_health
	necromancer.global_position = NECROMANCER_SPOT
	MonsterPack.set_debug_visible(true)
	var vision: Node = scene.call(&"get_vision")
	if vision != null:
		vision.call(&"set_active", false)
	var gang: Monster = scene.get_node("Actors/GangRat1")
	var east: Monster = scene.get_node("Actors/EastRat1")
	tree.create_timer(HIT_DELAY, true, true).timeout.connect(func() -> void:
		gang.take_damage(0.1, necromancer)
		east.take_damage(0.1, necromancer))
