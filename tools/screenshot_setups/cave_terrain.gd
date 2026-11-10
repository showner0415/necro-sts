extends RefCounted
## 스크린샷 준비: 얕은 굴에서 지금 지형과 새 동굴 지형(CaveTerrainMesher)을 같은 자리에서 비교한다. 시야는 끄고 몬스터는 치운다.
## bash tools/godot.sh --path . -s tools/screenshot.gd -- --seconds=2 --scene=res://regions/shallow_cave.tscn --setup=res://tools/screenshot_setups/cave_terrain.gd --out=<경로>
## 사용자 인자:
##   --cave_terrain    새 지형을 쓴다 (없으면 지금 지형. 지역이 3D 층을 먼저 붙이므로 실행 인자로 켠다)
##   --collision=1     지금 칸 충돌 경계를 빨간 선으로 겹쳐 그린다
##   --at=<x,y>        네크로맨서를 세울 칸. 없으면 view_3d_preview와 같은 쥐 굴 바위 앞
##   --vision=1        시야를 켠 채 찍는다 (없으면 지형을 잘 보려고 끈다)
##   --aim=<x,y>       조준할 월드 방향 (없으면 동쪽). 앞벽 잘라내기 확인에 쓴다

const VisionPreview: GDScript = preload("res://tools/screenshot_setups/vision_preview.gd")
const TILE: float = 32.0
const AIM_DISTANCE: float = 128.0
## 충돌 경계 선의 높이 (픽셀)와 색 (e43b44)
const LINE_HEIGHT: float = 7.0
const LINE_COLOR: Color = Color(0.89411765, 0.23137255, 0.26666668, 1)


static func run(scene: Node) -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var necromancer: Necromancer = scene.get_tree().get_first_node_in_group(&"necromancer")
	VisionPreview.run(scene)
	if args.has("at"):
		var cell: PackedStringArray = (args["at"] as String).split(",")
		necromancer.global_position = (Vector2(cell[0].to_float(), cell[1].to_float()) + Vector2(0.5, 0.5)) * TILE
	var aim: Vector2 = Vector2.RIGHT
	if args.has("aim"):
		var direction: PackedStringArray = (args["aim"] as String).split(",")
		aim = Vector2(direction[0].to_float(), direction[1].to_float()).normalized()
	var view: RegionView3D = scene.call(&"add_view_3d")
	view.aim_override = necromancer.get_body_center() + aim * AIM_DISTANCE
	if args.get("vision", "0") != "1" and (scene as Region).get_vision() != null:
		(scene as Region).get_vision().set_active(false)
	if args.get("collision", "0") == "1":
		view.add_child(_collision_lines(scene.get_node("Walls") as PlaceholderWalls))
	print("지형: 새 지형 %s, 준비 시간 %dms, 구역 %d" % [RegionView3D.use_cave_terrain, view.get_terrain_build_usec() / 1000, view.get_terrain_chunks().size()])


## 벽 칸과 바닥 칸 사이의 변마다 선을 긋는다.
static func _collision_lines(walls: PlaceholderWalls) -> MeshInstance3D:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = LINE_COLOR
	material.no_depth_test = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var size: Vector2i = walls.grid_size()
	for y: int in size.y:
		for x: int in size.x:
			var here: bool = walls.is_wall(Vector2i(x, y))
			if x + 1 < size.x and here != walls.is_wall(Vector2i(x + 1, y)):
				_line(mesh, Vector2(x + 1, y), Vector2(x + 1, y + 1))
			if y + 1 < size.y and here != walls.is_wall(Vector2i(x, y + 1)):
				_line(mesh, Vector2(x, y + 1), Vector2(x + 1, y + 1))
	mesh.surface_end()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _line(mesh: ImmediateMesh, from: Vector2, to: Vector2) -> void:
	mesh.surface_add_vertex(ViewSpace.to_3d(from * TILE, LINE_HEIGHT))
	mesh.surface_add_vertex(ViewSpace.to_3d(to * TILE, LINE_HEIGHT))
