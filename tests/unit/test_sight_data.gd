extends TestCase
## SightData (언데드 시야 값): 판정 규칙으로 옮기기, 기본값 파일.


func test_make_rules_copies_values() -> void:
	var sight: SightData = SightData.new()
	sight.view_range = 200.0
	sight.full_angle = 23.0
	sight.total_angle = 35.0
	sight.near_radius = 0.0
	var rules: VisionRules = sight.make_rules()
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, Vector2(150, 0)), 0, "정면 150은 보임")
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, Vector2(210, 0)), rules.hidden_level(), "보는 거리 200 밖은 안 보임")
	assert_eq(rules.level_for(Vector2.ZERO, Vector2.RIGHT, Vector2(-10, 0)), rules.hidden_level(), "둘레 원이 없어 바로 뒤도 안 보임")


func test_default_file() -> void:
	var sight: SightData = load("res://data/sight/undead_default.tres")
	assert_eq(sight.id, &"undead_default", "id")
	assert_almost_eq(sight.view_range, 200.0, 0.001, "보는 거리 200 (사용자 확정)")
	assert_almost_eq(sight.total_angle * 2.0, 70.0, 0.001, "전체 70도")
	assert_almost_eq(sight.full_angle * 2.0, 46.0, 0.001, "완전히 밝은 46도")
	assert_almost_eq(sight.brightness, 0.75, 0.001, "지형 밝기 75%")
	assert_almost_eq(sight.near_radius, 0.0, 0.001, "둘레 원 없음")


func test_monster_without_sight_uses_default() -> void:
	var data: MonsterData = (load("res://data/monsters/rat.tres") as MonsterData).duplicate()
	data.undead_sight = null
	assert_eq(data.get_undead_sight().id, &"undead_default", "비어 있으면 기본값")
