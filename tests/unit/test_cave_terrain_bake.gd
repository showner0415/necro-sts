extends TestCase
## 구운 동굴 지형의 지문 (CaveTerrainBake). 원본이나 메시를 만드는 코드가 바뀌었는데 다시 굽지 않았으면 실패한다.
## 구운 파일이 없는 컴퓨터에서는(저장소에 올리지 않는 파일이다) 굽는 방법만 출력하고 넘어간다.

## [씬, 구울 때 쓰는 명령에 덧붙일 인자]
const SCENES: Array[Array] = [["res://regions/shallow_cave.tscn", ""], ["res://tests/view_3d/wall_test_cave.tscn", " --in="], ["res://tests/choke_test_cave.tscn", " --in="]]
const WALL_HEIGHT: float = 128.0
const CAP_HEIGHT: float = 6.08
const TEMP_SCRIPT: String = "user://test_cave_terrain_bake_script.txt"
## 굽기에 쓰는 코드가 가리키지만 메시 모양을 정하지 않는 클래스와 그 이유
const NOT_BAKE_CLASSES: Dictionary[String, String] = {
	"CaveTerrainBake": "구운 결과를 담기만 한다",
	"CaveOutlineSettings": "값은 지문에 따로 들어간다",
	"RegionView3D": "벽 높이 값만 읽고, 값은 지문에 따로 들어간다",
	"PlaceholderGround": "구운 지형은 벽(from_walls)만 읽는다",
	"ChokeFinder": "길목 데이터만 만들고 메시 모양은 정하지 않는다 (구운 길목이 맞는지는 test_outline_chokes_match_finder가 본다)",
	"ChokeData": "길목 데이터를 담기만 한다",
}

var _walls: PlaceholderWalls


func before_each() -> void:
	_walls = PlaceholderWalls.new()
	_walls.layout = PackedStringArray(["####", "#..#", "####"])


func after_each() -> void:
	_walls.free()
	DirAccess.remove_absolute(TEMP_SCRIPT)


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


func _fingerprint_of_script(text: String) -> String:
	var file: FileAccess = FileAccess.open(TEMP_SCRIPT, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var scripts: Array[String] = [TEMP_SCRIPT]
	return CaveTerrainBake.compute_fingerprint(_walls, "", CaveOutlineSettings.new(), WALL_HEIGHT, CAP_HEIGHT, scripts)


func test_script_change_changes_fingerprint() -> void:
	assert_ne(_fingerprint_of_script("var a = 1\n"), _fingerprint_of_script("var a = 2\n"), "코드가 바뀌면 지문이 바뀜")


func test_line_endings_do_not_change_fingerprint() -> void:
	assert_eq(_fingerprint_of_script("var a = 1\r\nvar b = 2\r\n"), _fingerprint_of_script("var a = 1\nvar b = 2\n"), "줄바꿈만 다르면 지문이 같음")


func test_bake_scripts_exist() -> void:
	for path: String in CaveTerrainBake.BAKE_SCRIPTS:
		assert_true(FileAccess.file_exists(path), "있어야 함: %s" % path)


## 굽기에 쓰는 코드가 새 클래스를 쓰기 시작했는데 지문 목록에 넣지 않았으면 실패한다.
func test_bake_scripts_cover_their_classes() -> void:
	var missing: PackedStringArray = PackedStringArray()
	var word: RegEx = RegEx.create_from_string("\\b[A-Z][A-Za-z0-9]+\\b")
	var classes: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		classes[entry["class"]] = entry["path"]
	for path: String in CaveTerrainBake.BAKE_SCRIPTS:
		for found: RegExMatch in word.search_all(FileAccess.get_file_as_string(path)):
			var name: String = found.get_string()
			if classes.has(name) and not NOT_BAKE_CLASSES.has(name) and not CaveTerrainBake.BAKE_SCRIPTS.has(classes[name]) and not missing.has(name):
				missing.append(name)
	assert_eq(missing, PackedStringArray(), "BAKE_SCRIPTS에 넣거나 NOT_BAKE_CLASSES에 이유를 적어야 하는 클래스")


## 충돌·길찾기·시야가 윤곽 파일을 쓰므로, PNG를 고치고 윤곽을 다시 만들지 않으면 실패한다.
func test_outline_matches_png() -> void:
	var outline: CaveOutlineData = load("res://regions/shallow_cave_outline.res")
	assert_eq(outline.source_png_md5, FileAccess.get_md5("res://art_src/maps/shallow_cave.png"), "PNG를 고쳤으면 다시 만들기: %s" % CaveTerrainBake.BAKE_TOOL)


## 길목(chokes)도 윤곽 파일에 구워 둔다. 길목 찾기 코드나 값을 고치고 다시 굽지 않으면 실패한다.
func test_outline_chokes_match_finder() -> void:
	var outline: CaveOutlineData = load("res://regions/shallow_cave_outline.res")
	var rows: PackedStringArray = MapLayout.from_file("res://art_src/maps/shallow_cave.png").rows
	var fresh: Array[ChokeData] = ChokeFinder.from_settings(outline.settings).find(rows, outline.cell_px, MapLayout.WALL_CHARS)
	assert_true(outline.chokes.size() > 0, "구운 길목이 있다")
	assert_eq(outline.chokes.size(), fresh.size(), "길목 수가 같다. 다르면 다시 굽기: %s" % CaveTerrainBake.BAKE_TOOL)
	for i: int in mini(outline.chokes.size(), fresh.size()):
		var saved: ChokeData = outline.chokes[i]
		assert_eq(saved.cells, fresh[i].cells, "길목 %d의 칸" % i)
		assert_eq(saved.wait_spots, fresh[i].wait_spots, "길목 %d의 대기 자리" % i)
		assert_eq(saved.detour_ratios, fresh[i].detour_ratios, "길목 %d의 우회 비율" % i)


func _world_position(node: Node2D) -> Vector2:
	var position: Vector2 = node.position
	var parent: Node = node.get_parent()
	while parent is Node2D:
		position += (parent as Node2D).position
		parent = parent.get_parent()
	return position


func _collect_bodies(node: Node, found: Array[Node2D]) -> void:
	for child: Node in node.get_children():
		if child is Monster or child is Necromancer or child is LootChest or child is EscapePoint or child is PackSpawn:
			found.append(child)
		else:
			_collect_bodies(child, found)


## 윤곽은 넓은 곳에서 PNG 바닥을 덮기도 하므로, 씬의 몸과 물건(무리 자리 포함)이 바위에 묻히지 않았는지 본다.
func test_scene_objects_are_not_inside_rock() -> void:
	var scene: Node = (load("res://regions/shallow_cave.tscn") as PackedScene).instantiate()
	var outline: CaveOutlineData = (scene.get_node("Walls") as PlaceholderWalls).outline
	var found: Array[Node2D] = []
	_collect_bodies(scene, found)
	var buried: PackedStringArray = PackedStringArray()
	for node: Node2D in found:
		var center: Vector2 = _world_position(node)
		var half: Vector2 = Vector2.ONE
		if node is Monster:
			half = (node as Monster).data.get_placeholder_half_size()
			center += PlaceholderBody.center((node as Monster).data)
		elif node is Necromancer:
			half = Vector2.ONE * (node as Necromancer).body_radius
			center.y -= (node as Necromancer).body_radius
		if outline.box_has_rock(center, half):
			buried.append("%s %s" % [node.name, center])
	# 한 마리 몬스터 15·무리 자리 8·상자 12·탈출 지점 3·네크로맨서 1 = 39 (2026-11-14 무리 배치 뒤. 무리원은 실행 중에 생겨 씬에 없다)
	assert_true(found.size() > 35, "몸과 물건을 찾음: %d" % found.size())
	assert_eq(buried, PackedStringArray(), "바위에 묻힘")
	scene.free()


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
		assert_true(bake.is_current(scene.get_node("Walls"), height, cap), "%s: 원본이나 메시를 만드는 코드가 바뀌었는데 다시 굽지 않음. 다시 굽기: %s" % [scene_path, command])
		scene.free()
