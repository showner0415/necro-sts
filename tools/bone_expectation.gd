extends SceneTree
## 지역 씬 하나에서 한 번 들어가 얻는 몬스터 뼈의 기대값을 종마다 출력한다 (계획 7a). 상자의 뼈는 세지 않는다.
## 씬에 놓인 몬스터는 한 마리씩, 무리 자리(PackSpawn)는 무리원 수의 가운데((최소 + 최대) / 2)로 센다.
## 마리당 뼈 = 드랍 목록의 뼈 줄마다 확률 × (기대값 expected_count, 없으면 count). 대장은 뼈를 더 주지 않는다.
## bash tools/godot.sh --headless --path . -s tools/bone_expectation.gd [-- --scene=res://regions/shallow_cave.tscn]
## 마지막 줄: "합계 뼈 기대값 <값> (몬스터 <N>마리)"

const DEFAULT_SCENE: String = "res://regions/shallow_cave.tscn"
const BONE_ID: StringName = &"bone"


## 오토로드(GameState)가 생긴 뒤에 지역 씬을 불러야 지역 스크립트가 컴파일된다 (_init은 너무 이르다)
func _initialize() -> void:
	var scene_path: String = DEFAULT_SCENE
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
	var root_node: Node = (load(scene_path) as PackedScene).instantiate()
	# 종 id → [마릿수, 마리당 뼈]
	var species: Dictionary = {}
	for node: Node in root_node.find_children("*", "", true, false):
		if node is Monster and (node as Monster).data != null:
			_add(species, (node as Monster).data, 1.0)
		elif node is PackSpawn and (node as PackSpawn).pack != null:
			for member: PackMember in (node as PackSpawn).pack.members:
				_add(species, member.monster, (member.min_count + member.max_count) / 2.0)
	var total: float = 0.0
	var count: float = 0.0
	print("지역 씬: %s" % scene_path)
	for id: StringName in species:
		var entry: Array = species[id]
		var bones: float = entry[0] * entry[1]
		total += bones
		count += entry[0]
		print("%s: %.1f마리 × 마리당 %.2f = %.2f" % [id, entry[0], entry[1], bones])
	print("합계 뼈 기대값 %.2f (몬스터 %.1f마리)" % [total, count])
	root_node.free()
	quit()


func _add(species: Dictionary, data: MonsterData, amount: float) -> void:
	if not species.has(data.id):
		species[data.id] = [0.0, _bones_per_monster(data)]
	species[data.id][0] += amount


## 마리당 뼈 기대값
static func _bones_per_monster(data: MonsterData) -> float:
	var bones: float = 0.0
	for entry: DropEntry in data.drops:
		if entry == null or entry.item == null or entry.item.id != BONE_ID:
			continue
		bones += entry.chance * (entry.expected_count if entry.expected_count > 0.0 else float(entry.count))
	return bones
