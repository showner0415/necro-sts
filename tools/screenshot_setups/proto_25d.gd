extends RefCounted
## 시제품(2.5D) 스크린샷 상태. 명령줄: --view=ortho,nopalette,nowalls,fov35,fov40,yaw0,look,south,dark,rat,behind (쉼표로 여럿)
## - 기본: 원근 30도, 팔레트 켬, 앞벽 처리 켬, 화면 회전 45도. look: 마우스를 화면 오른쪽 위에 둔 앞서 가기
## - south: 네크로맨서를 남쪽 벽 바로 위에 세운다, dark: 기둥이 빛 밖에 있는 자리, rat: 쥐를 네크로맨서 동쪽 가까이에 둔다
## - behind: 쥐를 남쪽 벽 바로 북쪽(벽에 가린 자리)에 두고 시야 안에 넣는다 (rat과 함께 쓰지 않는다)
## 조준은 동쪽을 본다 (aim_override).


static func run(scene: Node) -> void:
	var view: View3D = scene.get_node("View3D") as View3D
	var necromancer: Necromancer = scene.get_node("Actors/Necromancer") as Necromancer
	var rat: Node2D = scene.get_node("Actors/Rat") as Node2D
	rat.process_mode = Node.PROCESS_MODE_DISABLED
	var options: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			options = arg.trim_prefix("--view=").split(",")
	view.perspective = not options.has("ortho")
	view.palette_on = not options.has("nopalette")
	view.front_walls_on = not options.has("nowalls")
	view.perspective_fov = 35.0 if options.has("fov35") else (40.0 if options.has("fov40") else 30.0)
	view.yaw_degrees = 0.0 if options.has("yaw0") else 45.0
	if options.has("look"):
		view.mouse_override = Vector2(560, 60)
	if options.has("south"):
		# 굴의 남쪽 벽 바로 북쪽 (벽은 15번째 줄부터)
		necromancer.global_position = Vector2(6.5, 14.8) * View3D.TILE
	if options.has("dark"):
		# 기둥(10~12칸)이 빛 밖에 있도록 동쪽을 보고 선다. 어두운 지형의 벽과 바닥을 비교한다
		necromancer.global_position = Vector2(16.5, 8.5) * View3D.TILE
	if options.has("rat"):
		rat.global_position = necromancer.global_position + Vector2(100, 0)
	if options.has("behind"):
		necromancer.global_position = Vector2(8.5, 11.5) * View3D.TILE
		rat.global_position = Vector2(12.5, 14.7) * View3D.TILE
	view.aim_override = necromancer.get_body_center() + Vector2(200, 0)
	if options.has("behind"):
		view.aim_override = necromancer.get_body_center() + (rat.global_position - necromancer.get_body_center()).normalized() * 300.0
	view.call(&"_apply_view_mode")
