extends TestCase
## 구운 동굴 지형의 지문 (CaveTerrainBake). 원본이 바뀌었는데 다시 굽지 않았으면 실패한다.
## 구운 파일이 없는 컴퓨터에서는(저장소에 올리지 않는 파일이다) 굽는 방법만 출력하고 넘어간다.

## [씬, 구울 때 쓰는 명령에 덧붙일 인자]
const SCENES: Array[Array] = [["res://regions/shallow_cave.tscn", ""], ["res://tests/view_3d/wall_test_cave.tscn", " --in="]]
const WALL_HEIGHT: float = 128.0
const CAP_HEIGHT: float = 6.08

var _walls: PlaceholderWalls


func before_each() -> void:
	_walls = PlaceholderWalls.new()
	_walls.layout = PackedStringArray(["####", "#..#", "####"])


func after_each() -> void:
	_walls.free()


func _fingerprint(settings: CaveOutlineSettings, height: float = WALL_HEIGHT) -> String:
	return CaveTerrainBake.compute_fingerprint(_walls, "", settings, height, CAP_HEIGHT)


func test_same_sources_give_same_fingerprint() -> void:
	assert_eq(_fingerprint(CaveOutlineSettings.new()), _fingerprint(CaveOutlineSettings.new()), "원본이 같으면 지문이 같음")


func test_settings_change_fingerprint() -> void:
	var changed: CaveOutlineSettings = CaveOutlineSettings.new()
	changed.max_lean_px = 5.0
	assert_ne(_fingerprint(changed), _fingerprint(CaveOutlineSettings.new()), "값이 바뀌면 지문이 바뀜")


func test_layout_changes_fingerprint() -> void:
	var before: String = _fingerprint(CaveOutlineSettings.new())
	_walls.layout = PackedStringArray(["####", "##.#", "####"])
	assert_ne(_fingerprint(CaveOutlineSettings.new()), before, "벽 배치가 바뀌면 지문이 바뀜")


func test_wall_height_changes_fingerprint() -> void:
	assert_ne(_fingerprint(CaveOutlineSettings.new(), WALL_HEIGHT + 1.0), _fingerprint(CaveOutlineSettings.new()), "벽 높이가 바뀌면 지문이 바뀜")


func test_png_changes_fingerprint() -> void:
	var with_png: String = CaveTerrainBake.compute_fingerprint(_walls, "res://art_src/maps/shallow_cave.png", CaveOutlineSettings.new(), WALL_HEIGHT, CAP_HEIGHT)
	assert_ne(with_png, _fingerprint(CaveOutlineSettings.new()), "PNG가 지문에 들어감")


func test_baked_files_match_their_sources() -> void:
	var view: RegionView3D = RegionView3D.new()
	var height: float = view.wall_height_px
	var cap: float = view.cut_cap_height_px
	view.free()
	for entry: Array in SCENES:
		var scene_path: String = entry[0]
		var command: String = CaveTerrainBake.bake_command(scene_path) + entry[1]
		if not ResourceLoader.exists(CaveTerrainBake.file_for(scene_path)):
			print("[안내] 구운 지형 없음: %s. 굽기: %s" % [scene_path, command])
			continue
		var scene: Node = (load(scene_path) as PackedScene).instantiate()
		var bake: CaveTerrainBake = load(CaveTerrainBake.file_for(scene_path))
		assert_true(bake.is_current(scene.get_node("Walls"), height, cap), "%s: 원본이 바뀌었는데 다시 굽지 않음. 다시 굽기: %s" % [scene_path, command])
		scene.free()
