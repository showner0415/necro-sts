extends SceneTree
## 밸런스 측정과 같은 상황을 창으로 띄워 사람이 직접 해 본다 (게임 조작 그대로).
##   박쥐 혼자:          bash tools/godot.sh --path . -s tools/play_case.gd -- --target=bat_pack
##   고블린 + 쥐 언데드 2: bash tools/godot.sh --path . -s tools/play_case.gd -- --target=goblin_pair --undead=2
## 언데드는 핫바에 들어 있으니 1 → G, 2 → G로 소환한다. 죽으면 거점으로 가므로 다시 하려면 창을 닫고 다시 실행한다.

const TEST_REGION: String = "res://regions/test_region.tscn"
const SETUP: GDScript = preload("res://tools/screenshot_setups/balance_case.gd")

var _setup_done: bool = false


func _initialize() -> void:
	change_scene_to_file(TEST_REGION)


func _process(_delta: float) -> bool:
	if not _setup_done and current_scene != null:
		_setup_done = true
		SETUP.run(current_scene)
	return false
