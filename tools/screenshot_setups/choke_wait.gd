extends RefCounted
## 스크린샷 준비: 길목 대기. 길목 시험 동굴(tests/choke_test_cave.tscn)의 아래 구역(돌아갈 길 없는 길목)에서
## 쥐 4마리가 길목 너머 네크로맨서를 쫓는다. 공격권(쥐 2)을 받은 쥐는 길목에 들어가고, 나머지는 왼쪽 입구 밖 대기 자리에서 기다린다. 쥐는 실제 속도(40px/s)다 (시나리오는 120).
## 디버그 표시(F3)를 켠다 (공격권을 든 쥐는 발밑에 흰 점). 시야는 끈다:
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=4 --scene=res://tests/choke_test_cave.tscn --setup=res://tools/screenshot_setups/choke_wait.gd --out=<경로> (창으로 지켜보려면 --seconds=30처럼 길게)

const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
## 네크로맨서는 길목 안 왼쪽 입구 가까이(기다리는 쥐와 한 화면에 들게), 쥐는 왼쪽 굴 (아래 구역)
const NECROMANCER_SPOT: Vector2 = Vector2(440, 480)
const RAT_SPOTS: Array[Vector2] = [Vector2(80, 420), Vector2(80, 560), Vector2(140, 420), Vector2(140, 560)]
## 무리가 없어도 몸이 준비된 뒤에 맞힌다 (초)
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
	var data: MonsterData = (load(RAT_PATH) as MonsterData).duplicate()
	data.wander_speed = 0.0
	data.max_health = 100000.0
	data.chase_attacker_limit = 0.0
	data.chase_lost_time = 0.0
	var rats: Array[Monster] = []
	for spot: Vector2 in RAT_SPOTS:
		var rat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		rat.data = data
		rat.position = spot
		scene.get_node("Actors").add_child(rat)
		rats.append(rat)
	tree.create_timer(HIT_DELAY, true, true).timeout.connect(func() -> void:
		for rat: Monster in rats:
			rat.take_damage(0.01, necromancer))
