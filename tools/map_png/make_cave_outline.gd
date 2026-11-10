extends SceneTree
## 맵 PNG(또는 씬의 벽 배치) → 동굴 벽 윤곽 파일과 구역별 지형 메시 파일. 지금은 화면(3D 층)에서만 쓴다. 지역 씬과 map_from_png.gd는 건드리지 않는다.
## 출력: 걸린 시간, 윤곽선 수, 바위가 PNG 바닥을 덮는 가장 깊은 곳, 좁은 바닥마다 지나갈 수 있는 폭, 구간별 메시 시간·삼각형 수.
##
## 실행 (기본값은 얕은 굴): bash tools/godot.sh --headless --path . -s tools/map_png/make_cave_outline.gd
## 다른 맵: -- --scene=res://regions/<맵>.tscn --in=res://art_src/maps/<맵>.png --settings=res://data/terrain/<값>.tres
## PNG가 없는 씬(검사용 등)은 --in을 비우면 그 씬의 벽 배치(layout)를 입력으로 쓴다: -- --scene=res://tests/view_3d/wall_test_cave.tscn --in=

const DEFAULT_SCENE: String = "res://regions/shallow_cave.tscn"
const DEFAULT_IN: String = "res://art_src/maps/shallow_cave.png"
const DEFAULT_SETTINGS: String = "res://data/terrain/shallow_cave_outline_settings.tres"
## 폭이 좁은 순서로 몇 곳까지 출력할지
const REPORT_TAIL: int = 12
const CHUNK_CELLS: int = 16


func _initialize() -> void:
	var args: Dictionary = {"scene": DEFAULT_SCENE, "in": DEFAULT_IN, "settings": DEFAULT_SETTINGS}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var scene: Node = (load(args.scene) as PackedScene).instantiate()
	var walls: PlaceholderWalls = scene.get_node("Walls")
	var rows: PackedStringArray = walls.layout
	if not (args["in"] as String).is_empty():
		var layout: MapLayout = MapLayout.from_file(args["in"])
		if not layout.errors.is_empty():
			for error: String in layout.errors:
				printerr("문제: ", error)
			scene.free()
			quit(1)
			return
		rows = layout.rows
	var started: int = Time.get_ticks_msec()
	var outline: CaveOutline = CaveOutline.new(rows, load(args.settings))
	var data: CaveOutlineData = outline.build()
	print("윤곽 계산: %dms, 격자 점 %s, 윤곽선 %d개, 윤곽선 점 %d개" % [Time.get_ticks_msec() - started, data.nodes(), data.loops.size(), _points(data)])
	var outline_path: String = "%s_outline.res" % (args.scene as String).get_basename()
	var error: int = ResourceSaver.save(data, outline_path, ResourceSaver.FLAG_COMPRESS)
	print("저장: %s (%s), 파일 %d KB" % [outline_path, error_string(error), FileAccess.get_file_as_bytes(outline_path).size() / 1024])
	print("바위가 바닥을 덮는 가장 깊은 곳 (입력 칸 기준): 격자 점으로 맵 전체 %.1fpx, 보호 구역 안 %.1fpx / 메시의 윤곽선으로 맵 전체 %.1fpx, 보호 구역 안 %.1fpx" % [outline.deepest_cover_px(), outline.deepest_cover_px(true), outline.deepest_loop_cover_px(data), outline.deepest_loop_cover_px(data, true)])
	var chokes: Array[Dictionary] = outline.choke_widths()
	chokes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.width < b.width)
	print("양쪽 끝이 있는 좁은 바닥 %d곳. 지나갈 수 있는 폭이 좁은 순서:" % chokes.size())
	for entry: Dictionary in chokes.slice(0, REPORT_TAIL):
		print("  칸 %s: %.0fpx (입력 칸 그대로면 %.0fpx)" % [entry.cell, entry.width, entry.png_width])
	error = maxi(error, _bake(args.scene, data, walls, args["in"], args.settings))
	scene.free()
	quit(0 if error == OK else 1)


## 구역별 메시를 구워 씬 옆에 저장한다.
func _bake(scene_path: String, data: CaveOutlineData, walls: PlaceholderWalls, png_path: String, settings_path: String) -> int:
	var view: RegionView3D = RegionView3D.new()
	var height: float = view.wall_height_px
	var cap: float = view.cut_cap_height_px
	view.free()
	var started: int = Time.get_ticks_msec()
	var cells: TerrainCells = TerrainCells.from_walls(walls)
	var bake: CaveTerrainBake = CaveTerrainBake.new()
	bake.meshes = CaveTerrainMesher.new().build(data, cells, walls, CHUNK_CELLS, height, cap)
	bake.shadow_meshes = TerrainMesher.new().build(cells, CHUNK_CELLS, height, cap)
	bake.triangles = CaveTerrainMesher.last_triangles
	bake.source_png = png_path
	bake.settings_path = settings_path
	bake.fingerprint = CaveTerrainBake.compute_fingerprint(walls, png_path, data.settings, height, cap)
	var stats: Dictionary = CaveTerrainMesher.stats
	print("메시: %dms, 구역 %d, 삼각형 %d, 벽이 윤곽선에서 들어간 가장 큰 거리 %.1fpx, 나누지 못한 다각형 %d" % [Time.get_ticks_msec() - started, bake.meshes.size(), bake.triangles, CaveTerrainMesher.last_max_lean, stats.failed_polygons])
	print("구간: 바닥 %dms %d삼각형 / 윗면 %dms %d삼각형 / 낮은 윗면 %dms %d삼각형 / 벽 면 %dms %d삼각형 (조각 %d) / 구역 메시 만들기 %dms" % [stats.floor_usec / 1000, stats.floor_tris, stats.top_usec / 1000, stats.top_tris, stats.cap_usec / 1000, stats.cap_tris, stats.face_usec / 1000, stats.face_tris, stats.faces, stats.mesh_usec / 1000])
	var path: String = CaveTerrainBake.file_for(scene_path)
	var error: int = ResourceSaver.save(bake, path, ResourceSaver.FLAG_COMPRESS)
	print("저장: %s (%s), 파일 %d KB" % [path, error_string(error), FileAccess.get_file_as_bytes(path).size() / 1024])
	return error


func _points(data: CaveOutlineData) -> int:
	var total: int = 0
	for line: PackedVector2Array in data.loops:
		total += line.size()
	return total
