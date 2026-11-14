extends RefCounted
## 스크린샷 준비: 길목 돌아가기. 길목 시험 동굴(tests/choke_test_cave.tscn)의 위 구역(아래에 3칸 폭 통로가 있어 돌아가는 길이 짧은 길목)에서
## 쥐 4마리가 길목 너머 네크로맨서를 쫓는다. 공격권이 없는 쥐는 길목에 들어가지 않고 아래 통로로 돌아서 오른쪽 굴로 온다. 쥐는 실제 속도(40px/s)다.
## 디버그 표시(F3)를 켠다 (공격권을 든 쥐는 발밑에 흰 점). 시야는 끈다:
## 창으로 지켜보려면 --seconds를 길게 (예: 30): bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=30 --scene=res://tests/choke_test_cave.tscn --setup=res://tools/screenshot_setups/choke_detour.gd --out=<경로>

const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
## 네크로맨서는 오른쪽 굴 (화면이 아래 통로 출구를 보게), 쥐는 왼쪽 굴 (위 구역)
const NECROMANCER_SPOT: Vector2 = Vector2(1150, 192)
const RAT_SPOTS: Array[Vector2] = [Vector2(80, 80), Vector2(80, 240), Vector2(140, 80), Vector2(140, 240)]
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
