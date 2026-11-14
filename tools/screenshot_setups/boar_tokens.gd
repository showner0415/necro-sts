extends RefCounted
## 스크린샷 준비: 멧돼지 공격권. 무리 시험 지역의 섞인 무리(멧돼지 1 + 쥐 2) 옆에 멧돼지를 하나 더 놓고(따로 무리), 둘 다 네크로맨서를 노리게 한다.
## 멧돼지 공격권은 대상 하나에 1이므로, 한 마리가 예고·돌진하는 동안 다른 멧돼지는 맴도는 거리(96)쯤에서 돈다. 쥐 공격권은 따로 센다.
## 디버그 표시(F3)를 켠다: 공격권을 든 몸은 발밑에 흰 점(추가 공격권은 노랑). 시야는 끈다:
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=3 --scene=res://regions/test_pack.tscn --setup=res://tools/screenshot_setups/boar_tokens.gd --out=<경로>

const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const BOAR_PATH: String = "res://data/monsters/boar.tres"
## 네크로맨서 자리 (섞인 무리에서 멧돼지 감지 범위 밖)
const NECROMANCER_SPOT: Vector2 = Vector2(-200, 80)
## 더 놓는 멧돼지 자리
const EXTRA_BOAR_SPOT: Vector2 = Vector2(-330, 60)
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
	var boar: Monster = scene.get_node("Actors/MixedBoar")
	var extra: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	extra.data = load(BOAR_PATH)
	extra.position = EXTRA_BOAR_SPOT
	scene.get_node("Actors").add_child(extra)
	tree.create_timer(HIT_DELAY, true, true).timeout.connect(func() -> void:
		boar.take_damage(0.1, necromancer)
		extra.take_damage(0.1, necromancer))
