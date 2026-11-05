extends RefCounted
## 스크린샷 준비: 시험 지역 서쪽의 박쥐 무리(3마리) 앞에 네크로맨서를 세운다. 박쥐들이 다가오거나 예고하는 장면.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=0.8 --scene=res://regions/test_region.tscn --setup=res://tools/screenshot_setups/bat_pack.gd --out=<경로>

## 박쥐 무리에게서 이만큼 떨어져 선다 (감지 범위 110 안)
const NECROMANCER_POSITION: Vector2 = Vector2(-270, 0)


static func run(scene: Node) -> void:
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	necromancer.global_position = NECROMANCER_POSITION
