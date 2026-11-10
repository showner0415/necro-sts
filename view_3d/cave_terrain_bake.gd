class_name CaveTerrainBake
extends Resource
## 미리 구운 동굴 지형 메시 (tools/map_png/make_cave_outline.gd가 만든다). 지역에 들어갈 때 불러오기만 한다.

## 그림자 방식을 고르는 실행 인자 (확인용): --cave_shadow=off 그림자 없음, --cave_shadow=terrain 새 지형으로 그림자
const SHADOW_ARG: String = "--cave_shadow="

## 구역마다 눈에 보이는 메시
@export var meshes: Array[ArrayMesh] = []
## 구역마다 그림자 전용 메시 (칸 상자 메시. 시야 판정이 칸 기준이라 그쪽과 맞춘다)
@export var shadow_meshes: Array[ArrayMesh] = []
@export var triangles: int = 0


## 씬 경로로 구운 파일을 찾는다. 없으면 null.
static func load_for(scene_path: String) -> CaveTerrainBake:
	var path: String = file_for(scene_path)
	if not ResourceLoader.exists(path):
		push_warning("동굴 지형: 구운 파일 없음 (%s). 칸 지형을 그대로 쓴다" % path)
		return null
	return load(path)


static func file_for(scene_path: String) -> String:
	return "%s_terrain.res" % scene_path.get_basename()


## 지금 쓸 그림자 메시들
func active_shadow_meshes() -> Array[ArrayMesh]:
	for arg: String in OS.get_cmdline_user_args():
		if arg == SHADOW_ARG + "off":
			return []
		if arg == SHADOW_ARG + "terrain":
			return meshes
	return shadow_meshes
