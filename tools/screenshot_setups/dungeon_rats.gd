extends RefCounted
## 스크린샷 준비: 시험 던전(tests/dungeon_test_a.tscn·b.tscn)의 쥐 무리가 화면에 들게 네크로맨서를 무리 아래로 옮긴다 (쥐 감지 범위 80 밖).
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --scene=res://tests/dungeon_test_a.tscn --setup=res://tools/screenshot_setups/dungeon_rats.gd --out=<경로>

const NECROMANCER_SPOT: Vector2 = Vector2(0, -40)


static func run(scene: Node) -> void:
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	necromancer.global_position = NECROMANCER_SPOT
