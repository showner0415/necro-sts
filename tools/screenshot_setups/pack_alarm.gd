extends RefCounted
## 스크린샷 준비: 무리 시험 지역의 쥐 패거리(4마리) 중 한 마리가 무리에 알리는 신호(멈춤·깜빡임)를 내는 장면.
## 네크로맨서를 패거리 아래(쥐 감지 밖)에 두고 한 마리를 맞힌다. 찍는 동안 신호가 이어지도록 그 쥐만 신호 시간을 길게 한 데이터 복사본을 쓰고,
## 깜빡임 간격을 0으로 해서 계속 밝게 한다 (실제 깜빡임은 0.1초마다 밝아졌다 돌아온다). 다른 쥐는 아직 평소다. 시야는 끈다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=1 --scene=res://regions/test_pack.tscn --setup=res://tools/screenshot_setups/pack_alarm.gd --out=<경로>

## 네크로맨서를 패거리 가운데에서 이만큼 아래에 둔다 (쥐 감지 80 밖)
const NECROMANCER_OFFSET: Vector2 = Vector2(0, 110)
## 찍는 동안 신호가 끝나지 않을 만큼의 신호 시간 (초)
const LONG_SIGNAL: float = 30.0
## 무리가 멤버를 묶는 첫 물리 프레임 뒤에 맞힌다 (초)
const HIT_DELAY: float = 0.2


static func run(scene: Node) -> void:
	var tree: SceneTree = scene.get_tree()
	var necromancer: Necromancer = tree.get_first_node_in_group(&"necromancer")
	var rat: Monster = scene.get_node("Actors/GangRat1")
	var center: Vector2 = Vector2.ZERO
	for name: String in ["GangRat1", "GangRat2", "GangRat3", "GangRat4"]:
		center += (scene.get_node("Actors/" + name) as Node2D).global_position / 4.0
	necromancer.global_position = center + NECROMANCER_OFFSET
	var data: MonsterData = rat.data.duplicate()
	data.alarm_signal_time = LONG_SIGNAL
	rat.data = data
	rat.alarm_blink_interval = 0.0
	var vision: Node = scene.call(&"get_vision")
	if vision != null:
		vision.call(&"set_active", false)
	tree.create_timer(HIT_DELAY, true, true).timeout.connect(func() -> void: rat.take_damage(0.1, necromancer))
