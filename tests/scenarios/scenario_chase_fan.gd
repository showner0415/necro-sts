extends ScenarioTest
## 시나리오: 쫓을 때 퍼지기 (줄 서기 고치기, docs/game-design.md "쫓을 때 퍼지기"). 테스트 싸움터(벽 없음)에서 쥐 패거리(4)를 코드로 만든다.
## 네크로맨서가 쥐와 같은 속도로 동쪽으로 곧게 걸어 물러나는 동안, 쫓는 쥐들이 옆으로 얼마나 벌어지는지(가로 폭) 잰다.
## 1. 퍼지기를 끈 쥐(데이터 복사로 각도 0·예측 0): 모두 쫓고, 좁은 다발로 따라온다 (가로 폭이 NARROW_WIDTH 이하. 재는 방법이 줄 서기를 알아보는지 확인)
## → 2. 실제 쥐 데이터: 모두 쫓고, 가로 폭이 WIDE_WIDTH 이상으로 벌어진다 → 3. 벌어져도 쫓기를 그만두지 않는다 (끝까지 네 마리 모두 네크로맨서를 노리고, 가장 먼 쥐가 추격 포기 거리 안)
## 쥐는 데이터 복사로 배회 0·체력 크게만 한다 (추격 포기 조건은 실제 값). 실제 .tres는 바꾸지 않는다. 가로 폭은 tests/balance/run_conga.gd의 measure_shape로 잰다.

const Conga: GDScript = preload("res://tests/balance/run_conga.gd")
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const TOUGH_HEALTH: float = 1000.0
const RUN_SEED: int = 7100
## 네크로맨서 출발 자리와 걷는 방향 (동쪽). 쥐 패거리는 출발 자리 서쪽 PACK_OFFSET에, 무리 자리의 간격(16px)으로 놓는다
const NECRO_START: Vector2 = Vector2(-300, 0)
const WALK_DIRECTION: Vector2 = Vector2.RIGHT
const PACK_OFFSET: Vector2 = Vector2(-110, 0)
const RAT_OFFSETS: Array[Vector2] = [Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)]
## 쫓기 시작한 뒤 모양이 잡히기를 기다리는 시간과 재는 시간 (초)
const SETTLE_SECONDS: float = 5.0
const MEASURE_SECONDS: float = 6.0
## 1. 퍼지기를 끈 쥐의 가로 폭은 이 값(픽셀) 이하다 (2026-11-18 잰 값 21.4. 재는 방법이 줄 서기를 알아보는지 보는 값이라 넉넉히 둔다)
const NARROW_WIDTH: float = 45.0
## 2. 실제 쥐의 가로 폭은 이 값(픽셀) 이상이다 (사용자 결정 2026-11-18: 60px 이상. 그날 잰 값 105.7, 끈 쥐 21.4)
const WIDE_WIDTH: float = 60.0

var _necromancer: Necromancer
var _rats: Array[Monster] = []


func get_start_scene() -> String:
	return TEST_REGION_SCENE


func _on_scene_ready() -> void:
	_run()


func _run() -> void:
	var plain: MonsterData = _tough(RAT_PATH)
	plain.chase_fan_step_degrees = 0.0
	plain.chase_lead_ratio = 0.0
	var narrow: Dictionary = await _chase(plain)
	if not _check("1. 퍼지기를 끄면 모두 쫓는다", narrow["chasing"] == RAT_OFFSETS.size(), "쫓는 쥐 %d/%d" % [narrow["chasing"], RAT_OFFSETS.size()]):
		return
	if not _check("1. 퍼지기를 끄면 좁은 다발로 따라온다", narrow["width"] <= NARROW_WIDTH,
			"가로 폭 평균 %.1fpx (기준 %.0f 이하), 세로 길이 %.1fpx, 들어오는 각도 범위 %.0f도" % [narrow["width"], NARROW_WIDTH, narrow["length"], narrow["arc"]]):
		return
	var wide: Dictionary = await _chase(_tough(RAT_PATH))
	if not _check("2. 실제 쥐도 모두 쫓는다", wide["chasing"] == RAT_OFFSETS.size(), "쫓는 쥐 %d/%d" % [wide["chasing"], RAT_OFFSETS.size()]):
		return
	if not _check("2. 실제 쥐는 옆으로 벌어져 따라온다", wide["width"] >= WIDE_WIDTH,
			"가로 폭 평균 %.1fpx (기준 %.0f 이상, 끈 쥐 %.1fpx), 세로 길이 %.1fpx, 들어오는 각도 범위 %.0f도 (끈 쥐 %.0f도)" % [wide["width"], WIDE_WIDTH, narrow["width"], wide["length"], wide["arc"], narrow["arc"]]):
		return
	var limit: float = (load(RAT_PATH) as MonsterData).chase_attacker_limit
	if not _check("3. 벌어져도 쫓기를 그만두지 않는다", wide["chasing_end"] == RAT_OFFSETS.size() and wide["farthest_end"] < limit,
			"끝날 때 네크로맨서를 노리는 쥐 %d/%d, 가장 먼 쥐 %.0fpx (추격 포기 %.0fpx, 끈 쥐는 %.0fpx)" % [wide["chasing_end"], RAT_OFFSETS.size(), wide["farthest_end"], limit, narrow["farthest_end"]]):
		return
	finish(true)


## 쥐 패거리(4)를 data로 만들어 한 대씩 맞힌 뒤, 네크로맨서가 쥐와 같은 속도로 동쪽으로 걷는 동안의 모양을 잰다.
## 결과: chasing(재는 동안 늘 쫓던 쥐 수의 최솟값), width·length·arc(재는 동안의 평균), chasing_end(끝날 때 네크로맨서를 노리는 쥐 수), farthest_end(끝날 때 가장 먼 쥐까지 거리)
func _chase(data: MonsterData) -> Dictionary:
	await reload_fight_scene(TEST_REGION_SCENE, RUN_SEED)
	seed(RUN_SEED)
	_necromancer = find_necromancer()
	for node: Node in get_nodes_in_group(&"monsters"):
		node.free()
	for node: Node in current_scene.find_children("*", "EscapePoint", true, false):
		node.free()
	for node: Node in current_scene.get_children():
		if node is MonsterPack:
			node.free()
	_necromancer.max_health = TOUGH_HEALTH
	_necromancer.health = TOUGH_HEALTH
	_necromancer.global_position = NECRO_START
	# 쥐와 같은 속도로 걸어, 쥐가 따라붙지도 뒤처지지도 않는 곧은 추격을 만든다 (공격권을 묻는 거리 밖에서 다가오는 동안만 퍼진다).
	_necromancer.move_speed = data.move_speed
	_rats.clear()
	for offset: Vector2 in RAT_OFFSETS:
		var rat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		rat.data = data
		rat.position = NECRO_START + PACK_OFFSET + offset
		_necromancer.get_parent().add_child(rat)
		_rats.append(rat)
	var pack: MonsterPack = MonsterPack.new()
	pack.set_members(_rats)
	current_scene.add_child(pack)
	await wait_frames(3)
	for rat: Monster in _rats:
		rat.take_damage(0.01, _necromancer)
	var ticks: int = Engine.physics_ticks_per_second
	press_moves(WALK_DIRECTION)
	await wait_frames(roundi(SETTLE_SECONDS * ticks))
	var frames: int = roundi(MEASURE_SECONDS * ticks)
	var chasing_min: int = _rats.size()
	var sums: Dictionary = {"width": 0.0, "length": 0.0, "arc": 0.0}
	for frame: int in frames:
		var points: Array[Vector2] = []
		for rat: Monster in _rats:
			if rat.get_target() == _necromancer:
				points.append(rat.global_position)
		chasing_min = mini(chasing_min, points.size())
		if points.size() >= 2:
			var shape: Dictionary = Conga.measure_shape(points, _necromancer.global_position)
			for key: String in sums:
				sums[key] += shape[key]
		await wait_frames(1)
	press_moves(Vector2.ZERO)
	var chasing_end: int = 0
	var farthest: float = 0.0
	for rat: Monster in _rats:
		if rat.get_target() == _necromancer:
			chasing_end += 1
		farthest = maxf(farthest, rat.global_position.distance_to(_necromancer.global_position))
	return {"chasing": chasing_min, "width": sums["width"] / frames, "length": sums["length"] / frames, "arc": sums["arc"] / frames,
		"chasing_end": chasing_end, "farthest_end": farthest}


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
	return ok


func _tough(path: String) -> MonsterData:
	var data: MonsterData = (load(path) as MonsterData).duplicate()
	data.wander_speed = 0.0
	data.max_health = TOUGH_HEALTH
	return data
