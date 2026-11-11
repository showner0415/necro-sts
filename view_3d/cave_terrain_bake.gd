class_name CaveTerrainBake
extends Resource
## 미리 구운 동굴 지형 메시 (tools/map_png/make_cave_outline.gd가 만든다). 지역에 들어갈 때 불러오기만 한다.
## 구운 파일에는 원본(맵 PNG, 씬의 벽 배치와 색, 윤곽 값, 벽 높이)과 메시를 만드는 코드의 지문이 들어 있다. 둘 중 하나가 바뀌었는데 다시 굽지 않았으면 경고하고, test_cave_terrain_bake.gd가 실패한다.

## 그림자를 끄는 실행 인자 (확인용): --cave_shadow=off
const SHADOW_ARG: String = "--cave_shadow="
const BAKE_TOOL: String = "bash tools/godot.sh --headless --path . -s tools/map_png/make_cave_outline.gd"
## 메시 모양을 정하는 코드. 내용이 지문에 들어간다 (주석만 고쳐도 다시 구워야 한다). 빠뜨리면 test_cave_terrain_bake.gd가 알려 준다
const BAKE_SCRIPTS: Array[String] = [
	"res://tools/map_png/make_cave_outline.gd",
	"res://tools/map_png/cave_outline.gd",
	"res://tools/map_png/map_layout.gd",
	"res://view_3d/cave_outline_data.gd",
	"res://view_3d/cave_terrain_mesher.gd",
	"res://view_3d/terrain_cells.gd",
	"res://view_3d/view_space.gd",
	"res://regions/placeholder_walls.gd",
]

## 구역마다 눈에 보이는 메시
@export var meshes: Array[ArrayMesh] = []
@export var triangles: int = 0
## 구울 때의 원본 지문, 맵 PNG 경로 (씬의 벽 배치만 썼으면 빈 값), 윤곽 값 파일 경로
@export var fingerprint: String = ""
@export var source_png: String = ""
@export var settings_path: String = ""


## 씬 경로로 구운 파일을 찾는다. 없으면 굽는 방법을 알리고 null, 원본이나 코드가 바뀌었으면 경고하고 그대로 쓴다.
## 배포판에는 맵 PNG와 스크립트 원문이 없어 지문을 잴 수 없으므로 검사하지 않는다.
static func load_for(scene_path: String, walls: PlaceholderWalls, wall_height_px: float, cap_height_px: float) -> CaveTerrainBake:
	var path: String = file_for(scene_path)
	if not ResourceLoader.exists(path):
		push_warning("동굴 지형: 구운 파일 없음 (%s). 칸 지형을 그대로 쓴다. 굽기: %s" % [path, bake_command(scene_path)])
		return null
	var bake: CaveTerrainBake = load(path)
	if not OS.has_feature("template") and not bake.is_current(walls, wall_height_px, cap_height_px):
		push_warning("동굴 지형: 원본이나 메시를 만드는 코드가 바뀌었는데 다시 굽지 않았다 (%s). 다시 굽기: %s" % [path, bake_command(scene_path)])
	return bake


static func file_for(scene_path: String) -> String:
	return "%s_terrain.res" % scene_path.get_basename()


## 이 씬을 굽는 명령. PNG 없이 씬의 벽 배치만 쓰는 씬은 뒤에 --in=을 붙인다.
static func bake_command(scene_path: String) -> String:
	return "%s -- --scene=%s" % [BAKE_TOOL, scene_path]


## 지금 원본과 코드의 지문이 구울 때와 같은지
func is_current(walls: PlaceholderWalls, wall_height_px: float, cap_height_px: float) -> bool:
	return fingerprint == compute_fingerprint(walls, source_png, load(settings_path), wall_height_px, cap_height_px)


## 메시 모양과 색을 정하는 원본과 코드의 지문
static func compute_fingerprint(walls: PlaceholderWalls, png_path: String, settings: CaveOutlineSettings, wall_height_px: float, cap_height_px: float, scripts: Array[String] = BAKE_SCRIPTS) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(FileAccess.get_md5(png_path) if not png_path.is_empty() else "")
	parts.append("\n".join(walls.layout))
	for value: Variant in [walls.wall_chars, walls.wall_colors, walls.floor_colors, walls.top_color, walls.face_color, wall_height_px, cap_height_px]:
		parts.append(var_to_str(value))
	for property: Dictionary in settings.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			parts.append("%s=%s" % [property.name, var_to_str(settings.get(property.name))])
	for script_path: String in scripts:
		# 컴퓨터마다 줄바꿈이 달라도 지문은 같아야 한다.
		parts.append(FileAccess.get_file_as_string(script_path).replace("\r\n", "\n"))
	return "|".join(parts).sha256_text()


## 지금 쓸 그림자 메시들. 규칙의 시야도 윤곽 기준이므로 눈에 보이는 메시 그대로 쓴다.
func active_shadow_meshes() -> Array[ArrayMesh]:
	if OS.get_cmdline_user_args().has(SHADOW_ARG + "off"):
		return []
	return meshes
