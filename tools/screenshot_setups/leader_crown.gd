extends RefCounted
## 스크린샷 준비: 무리 대장 왕관. 시험 던전 A(tests/dungeon_test_a.tscn)의 쥐 패거리 자리(RatGang)에서 첫 무리원을 대장으로 보이게 하고,
## 네크로맨서를 무리 아래로 옮긴다 (쥐 감지 범위 80 밖). 대장 확률과 상관없이 왕관 모양만 본다 (강화는 바꾸지 않는다).
## 무리 디버그 표시(F3)도 켜서 대장의 바깥 왕관 색 고리를 같이 본다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --scene=res://tests/dungeon_test_a.tscn --setup=res://tools/screenshot_setups/leader_crown.gd --out=<경로>

const NECROMANCER_SPOT: Vector2 = Vector2(0, -20)


static func run(scene: Node) -> void:
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	necromancer.global_position = NECROMANCER_SPOT
	var members: Array[Monster] = (scene.get_node("RatGang") as PackSpawn).get_members()
	if not members.is_empty():
		members[0].is_leader = true
	MonsterPack.set_debug_visible(true)
