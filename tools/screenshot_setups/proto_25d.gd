extends RefCounted
## 시제품(2.5D) 스크린샷 상태. 명령줄: --view=persp,palette,cut1,cut2,south,rat (쉼표로 여럿)
## - persp: 원근, palette: 팔레트 후처리, cut1: 앞벽 반투명, cut2: 앞벽 잘라내기
## - south: 네크로맨서를 남쪽 벽 바로 위에 세운다 (앞벽 가림 확인), dark: 기둥이 빛 밖에 있는 자리, rat: 쥐를 네크로맨서 동쪽 가까이에 둔다
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
	view.perspective = options.has("persp")
	view.palette_on = options.has("palette")
	view.cut_mode = 2 if options.has("cut2") else (1 if options.has("cut1") else 0)
	if options.has("south"):
		# 굴의 남쪽 벽 바로 북쪽 (벽은 15번째 줄부터)
		necromancer.global_position = Vector2(6.5, 14.8) * View3D.TILE
	if options.has("dark"):
		# 기둥(10~12칸)이 빛 밖에 있도록 동쪽을 보고 선다. 어두운 지형의 벽과 바닥을 비교한다
		necromancer.global_position = Vector2(16.5, 8.5) * View3D.TILE
	if options.has("rat"):
		rat.global_position = necromancer.global_position + Vector2(100, 0)
	view.aim_override = necromancer.get_body_center() + Vector2(200, 0)
	view.call(&"_apply_view_mode")
