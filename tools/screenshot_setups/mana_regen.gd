extends RefCounted
## 스크린샷 준비 (거점): 마나를 쓰고 언데드는 없는 상태. 마나 바 오른쪽에 "+1.0"(자연 회복)이 보인다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --setup=res://tools/screenshot_setups/mana_regen.gd --out=<경로>

## 마나를 이만큼 써 둔다 (가득 차 있으면 숫자가 숨겨지므로)
const SPENT_MANA: float = 8.0


static func run(scene: Node) -> void:
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	necromancer.mana.try_spend(SPENT_MANA)
