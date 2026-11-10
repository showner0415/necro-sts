extends View3DCheck
## 실제 전투를 돌려 멧돼지 돌진 예고·고블린 돌·탄·스태미나 도넛이 한 화면에 보이는 순간을 3D로 찍는다 (눈으로 보려고 찍는 것이라 판정은 없다).
## bash tools/godot.sh --fixed-fps 60 --path . -s tools/shot_view_3d_combat.gd -- --out=<a.png>
## 2배로 키운 그림(<a>_x2.png)도 같이 저장한다. 시야는 끄고 찍는다 (시야 단계 전이라 빛이 없다).

const SCENE: String = "res://regions/test_region.tscn"
const BOAR_OFFSET: Vector2 = Vector2(-120, 40)
const GOBLIN_OFFSET: Vector2 = Vector2(120, -50)
const TIMEOUT_FRAMES: int = 900
const SAFE_HEALTH: float = 100000.0
const ZOOM: int = 2
## 찍을 때 돌이 날아간 비율 범위
const MID_AIR_START: float = 0.3
const MID_AIR_END: float = 0.7

var _out_path: String = ""


func get_start_scene() -> String:
	return SCENE


func _on_scene_ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
	var necromancer: Necromancer = find_necromancer()
	necromancer.health = SAFE_HEALTH
	var boar: Monster = current_scene.get_node("Actors/Boar1")
	var goblin: Monster = current_scene.get_node("Actors/Goblin1")
	for node: Node in get_nodes_in_group(&"monsters"):
		if node != boar and node != goblin:
			node.free()
	disable_vision()
	var view: RegionView3D = open_layer()
	(current_scene.get_node("HUD") as CanvasLayer).visible = true
	boar.global_position = necromancer.global_position + BOAR_OFFSET
	goblin.global_position = necromancer.global_position + GOBLIN_OFFSET
	view.aim_override = goblin.global_position
	press_mouse(true)
	var charge: ChargeBehavior = boar._behavior as ChargeBehavior
	for frame: int in TIMEOUT_FRAMES:
		await wait_frames(1)
		necromancer.health = SAFE_HEALTH
		boar.health = boar.data.max_health
		goblin.health = goblin.data.max_health
		view.aim_override = goblin.global_position
		if necromancer.stamina.is_full():
			necromancer.stamina.try_roll()
		if charge.get_state() == ChargeBehavior.State.WINDUP and _stone_mid_air() != null and _count(&"Bolt") > 0:
			var stone: Stone = _stone_mid_air()
			var image: Image = await capture()
			print("찍음: %d프레임, 돌 높이 %.0f (날아간 비율 %.2f), 탄 %d" % [frame, stone.get_view_height(), stone.get_traveled() / stone.max_distance, _count(&"Bolt")])
			image.save_png(_out_path)
			var large: Image = image.duplicate()
			large.resize(image.get_width() * ZOOM, image.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
			large.save_png(_out_path.get_basename() + "_x2.png")
			press_mouse(false)
			finish(true)
			return
	press_mouse(false)
	fail_step("찍기", "%d프레임 안에 예고·돌·탄이 함께 보이지 않음" % TIMEOUT_FRAMES)


## 던진 고블린에서 충분히 떨어져 포물선 가운데쯤 있는 돌 (없으면 null)
func _stone_mid_air() -> Stone:
	for child: Node in find_necromancer().get_parent().get_children():
		var stone: Stone = child as Stone
		if stone != null and not stone.is_queued_for_deletion() and stone.max_distance > 0.0:
			var progress: float = stone.get_traveled() / stone.max_distance
			if progress >= MID_AIR_START and progress <= MID_AIR_END:
				return stone
	return null


func _count(script_class: StringName) -> int:
	var count: int = 0
	for child: Node in find_necromancer().get_parent().get_children():
		if child.get_script() != null and (child.get_script() as Script).get_global_name() == script_class and not child.is_queued_for_deletion():
			count += 1
	return count
