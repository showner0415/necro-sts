extends TestCase
## data/ 안의 머리뼈·몬스터 데이터가 서로 맞는지 검사한다.
## 머리뼈는 원본 몬스터를 id로 가리키므로(순환 참조 회피), 오타가 있으면 여기서 잡는다.

const SKULL_DIR: String = "res://data/skulls"
const MONSTER_DIR: String = "res://data/monsters"


func _load_all(dir: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for file_name: String in ResourceLoader.list_directory(dir):
		if file_name.get_extension() == "tres":
			result.append(load(dir.path_join(file_name)))
	return result


func _monster_ids() -> Dictionary[StringName, MonsterData]:
	var ids: Dictionary[StringName, MonsterData] = {}
	for resource: Resource in _load_all(MONSTER_DIR):
		var monster: MonsterData = resource as MonsterData
		if monster != null:
			ids[monster.id] = monster
	return ids


func test_skull_data_exists() -> void:
	assert_true(not _load_all(SKULL_DIR).is_empty(), "%s에 머리뼈 데이터가 있다" % SKULL_DIR)


func test_every_skull_points_to_existing_monster() -> void:
	var monsters: Dictionary[StringName, MonsterData] = _monster_ids()
	for resource: Resource in _load_all(SKULL_DIR):
		var skull: SkullData = resource as SkullData
		assert_true(skull != null, "%s는 SkullData여야 한다" % resource.resource_path)
		if skull == null:
			continue
		assert_true(monsters.has(skull.source_monster_id), "%s의 source_monster_id '%s'인 몬스터가 있다" % [skull.id, skull.source_monster_id])
		assert_true(skull.max_durability > 0.0, "%s의 최대 내구도는 0보다 크다" % skull.id)


func test_monsters_drop_only_their_own_skull() -> void:
	for monster: MonsterData in _monster_ids().values():
		for entry: DropEntry in monster.drops:
			var skull: SkullData = entry.item as SkullData
			if skull != null:
				assert_eq(skull.source_monster_id, monster.id, "%s가 떨어뜨리는 %s는 자기 머리뼈여야 한다" % [monster.id, skull.id])


func test_rat_drops_match_design() -> void:
	var rat: MonsterData = _monster_ids().get(&"rat")
	assert_true(rat != null, "쥐 데이터가 있다")
	if rat == null:
		return
	var found: Dictionary = {}
	for entry: DropEntry in rat.drops:
		found[entry.item.id] = [entry.count, entry.chance]
	assert_eq(found.get(&"bone"), [2, 1.0], "뼈 2개, 100%")
	assert_eq(found.get(&"rat_skull"), [1, 0.5], "쥐의 머리뼈 1개, 50%")
