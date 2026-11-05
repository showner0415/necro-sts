extends RefCounted
## 스크린샷 준비 (거점): 스태미나를 --stamina=<비율>(0~1, 기본 0.6)로 맞추고 회복을 멈춘 뒤, 카메라를 4배로 당겨 도넛을 크게 보여준다.
## 도넛은 12시에서 시계 방향으로 남은 비율만큼 채워진다 (줄어든 부분은 12시 왼쪽부터 비어 보인다).
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --setup=res://tools/screenshot_setups/stamina_ring.gd --stamina=0.25 --out=<경로>

const DEFAULT_RATIO: float = 0.6
const ZOOM: Vector2 = Vector2(4, 4)


static func run(scene: Node) -> void:
	var ratio: float = DEFAULT_RATIO
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stamina="):
			ratio = arg.trim_prefix("--stamina=").to_float()
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	var stamina: Stamina = necromancer.stamina
	stamina.regen_per_second = 0.0
	# 뛰기로 줄인 것처럼 줄인다 (규칙 클래스의 공개 함수만 쓴다).
	stamina.process(stamina.maximum * (1.0 - ratio) / stamina.run_cost_per_second, true, false)
	stamina.release_run()
	(necromancer.get_node("Camera2D") as Camera2D).zoom = ZOOM
