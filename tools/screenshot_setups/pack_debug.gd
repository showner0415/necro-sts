extends RefCounted
## 스크린샷 준비: 무리 디버그 표시(F3)를 켠 무리 시험 지역. 세 무리가 서로 다른 상태다.
## - 쥐 패거리(위): 평소. 무리원마다 발밑 고리와 배회 기준점까지 선, 기준점 둘레(반지름 64)
## - 동쪽 쥐 무리(오른쪽): 경보. 굵은 고리와 노리는 대상(네크로맨서)까지 선
## - 섞인 무리(왼쪽): 신호 중. 신호를 내는 쥐는 채운 원 (찍는 동안 신호가 이어지도록 그 쥐만 신호 시간을 길게 한 데이터 복사본)
## 시야는 끈다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/test_pack.tscn --setup=res://tools/screenshot_setups/pack_debug.gd --out=<경로>

## 네크로맨서 자리 (어느 무리의 감지 범위에도 들지 않게)
const NECROMANCER_SPOT: Vector2 = Vector2(0, -20)
const LONG_SIGNAL: float = 30.0
## 무리가 멤버를 묶는 첫 물리 프레임 뒤에 맞힌다 (초)
const HIT_DELAY: float = 0.2


static func run(scene: Node) -> void:
	var tree: SceneTree = scene.get_tree()
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	necromancer.global_position = NECROMANCER_SPOT
	MonsterPack.set_debug_visible(true)
	var vision: Node = scene.call(&"get_vision")
	if vision != null:
		vision.call(&"set_active", false)
	var east: Monster = scene.get_node("Actors/EastRat1")
	var mixed: Monster = scene.get_node("Actors/MixedRat1")
	var data: MonsterData = mixed.data.duplicate()
	data.alarm_signal_time = LONG_SIGNAL
	mixed.data = data
	tree.create_timer(HIT_DELAY, true, true).timeout.connect(func() -> void:
		east.take_damage(0.1, necromancer)
		mixed.take_damage(0.1, necromancer))
