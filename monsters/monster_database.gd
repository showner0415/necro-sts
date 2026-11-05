class_name MonsterDatabase
extends RefCounted
## id로 MonsterData를 찾는다. data/monsters/ 폴더의 .tres를 처음 찾을 때 한 번 모두 불러 둔다.
## 머리뼈는 원본 몬스터를 id(source_monster_id)로만 가리키므로, 언데드 능력치를 알려면 여기서 찾는다.
## 새 몬스터는 .tres를 폴더에 추가하기만 하면 찾을 수 있다.

const MONSTER_DIR: String = "res://data/monsters"

static var _by_id: Dictionary[StringName, MonsterData] = {}
static var _loaded: bool = false


## 그 id의 몬스터. 없으면 null.
static func find(id: StringName) -> MonsterData:
	if not _loaded:
		_load_all()
	return _by_id.get(id)


static func _load_all() -> void:
	_loaded = true
	for file_name: String in DirAccess.get_files_at(MONSTER_DIR):
		# 내보낸 게임에서는 파일 이름 뒤에 .remap이 붙는다.
		var path: String = MONSTER_DIR.path_join(file_name.trim_suffix(".remap"))
		if path.get_extension() != "tres" and path.get_extension() != "res":
			continue
		var data: MonsterData = load(path) as MonsterData
		if data != null:
			_by_id[data.id] = data
