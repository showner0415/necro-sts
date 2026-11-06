extends RefCounted
## 스크린샷 준비 (거점): 카메라를 4배로 당기고, 제자리에서 --rolls=<횟수>(기본 3)번 연속으로 구른 직후 상태를 만든다.
## 연속 구르기 비용(25 → 40 → 60)이 도넛에서 얼마나 크게 줄어 보이는지 확인할 때 쓴다.
## 실제 구르기(이동)는 하지 않고 스태미나 규칙만 굴린다. 구른 뒤에는 회복 지연 중인 상태로 두려고 회복을 멈춘다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --setup=res://tools/screenshot_setups/stamina_roll_chain.gd --rolls=2 --out=<경로>

const DEFAULT_ROLLS: int = 3
const ZOOM: Vector2 = Vector2(4, 4)
## 구르기 사이에 쉬는 시간 (초). 연속으로 보는 시간보다 짧아야 한다.
const REST_BETWEEN: float = 0.2


static func run(scene: Node) -> void:
	var rolls: int = DEFAULT_ROLLS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--rolls="):
			rolls = arg.trim_prefix("--rolls=").to_int()
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	var stamina: Stamina = necromancer.stamina
	var lines: PackedStringArray = []
	for i: int in rolls:
		var before: float = stamina.current
		if not stamina.try_roll():
			lines.append("%d번째: 못 구름 (남은 %.0f, 비용 %.0f)" % [i + 1, stamina.current, stamina.get_roll_cost()])
			break
		stamina.process(necromancer.roll_duration, false, true)
		stamina.process(REST_BETWEEN, false, false)
		lines.append("%d번째: %.0f → %.0f" % [i + 1, before, stamina.current])
	stamina.regen_per_second = 0.0
	print("연속 구르기: %s, 도넛 비율 %.2f" % [", ".join(lines), stamina.get_ratio()])
	(necromancer.get_node("Camera2D") as Camera2D).zoom = ZOOM
