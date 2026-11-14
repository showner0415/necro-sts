extends ScenarioTest
## 시나리오: 맵 PNG 무리 자리 (계획 5b-2). 무리 색 다섯을 하나씩 찍은 시험 맵(art_src/maps/pack_test.png → tests/pack_test_map.tscn)을 연다.
## 1. 만든 씬의 무리 자리(PackSpawn) 수가 PNG의 무리 색 픽셀 수(5)와 같고, 자리마다 무리 종류가 색 표대로다
## 2. 지역이 시작하면 자리마다 무리 종류의 범위 안의 수만큼 무리원이 생기고, 구성(종)이 맞으며, 모두 자리에서 흩어 놓는 반지름 안이고 무리(MonsterPack)로 묶인다
## 시험 맵을 고치려면 tools/map_png/make_pack_test_png.gd를 고쳐 PNG를 다시 만들고 tools/map_from_png.gd로 다시 바꾼다 (그 파일 머리 주석).

const MAP_SCENE: String = "res://tests/pack_test_map.tscn"
const PNG_SPOTS: int = 5
## 색 표 (docs/maps/map_png_rules.md): 자리 이름 앞부분 → 무리 종류 id
const EXPECTED: Dictionary = {
	"RatBigSpot": &"rat_big",
	"RatGangSpot": &"rat_gang",
	"BoarPackSpot": &"boar_pack",
	"GoblinPackSpot": &"goblin_pack",
	"MixedPackSpot": &"mixed_boar_rats",
}


func get_start_scene() -> String:
	return MAP_SCENE


func _on_scene_ready() -> void:
	await wait_frames(3)
	var spawns: Array[PackSpawn] = []
	for node: Node in RegionSnapshot.nodes_of(current_scene, PackSpawn):
		spawns.append(node as PackSpawn)
	var kinds_ok: bool = true
	var kinds: PackedStringArray = []
	for spawn: PackSpawn in spawns:
		var prefix: String = spawn.name.rstrip("0123456789")
		kinds.append("%s=%s" % [spawn.name, spawn.pack.id])
		if EXPECTED.get(prefix, &"") != spawn.pack.id:
			kinds_ok = false
	var count_ok: bool = spawns.size() == PNG_SPOTS
	if count_ok and kinds_ok:
		pass_step("무리 자리", "PackSpawn %d개 (PNG 무리 색 %d): %s" % [spawns.size(), PNG_SPOTS, ", ".join(kinds)])
	else:
		fail_step("무리 자리", "PackSpawn %d개 (기대 %d), 종류 %s" % [spawns.size(), PNG_SPOTS, ", ".join(kinds)])
		finish(false)
		return
	var all_ok: bool = true
	var lines: PackedStringArray = []
	for spawn: PackSpawn in spawns:
		var members: Array[Monster] = spawn.get_members()
		var ok: bool = not members.is_empty()
		# 종마다 범위 안인지
		var per_kind: Dictionary = {}
		for monster: Monster in members:
			per_kind[monster.data.id] = per_kind.get(monster.data.id, 0) + 1
			if monster.global_position.distance_to(spawn.global_position) > spawn.spread_radius + 0.01:
				ok = false
		for member: PackMember in spawn.pack.members:
			var n: int = per_kind.get(member.monster.id, 0)
			if n < member.min_count or n > member.max_count:
				ok = false
		var pack: MonsterPack = current_scene.get_node_or_null("%sPack" % spawn.name)
		ok = ok and pack != null
		all_ok = all_ok and ok
		lines.append("%s %s (무리 %s)" % [spawn.name, per_kind, "있음" if pack != null else "없음"])
	if all_ok:
		pass_step("무리 만들기", "자리마다 범위 안의 수, 반지름 안, 무리로 묶임: %s" % "; ".join(lines))
	else:
		fail_step("무리 만들기", "; ".join(lines))
	finish(all_ok)
