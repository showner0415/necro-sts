extends ScenarioTest
## 시나리오: 플레이어 시야 (Vision). 시험 통로(regions/test_corridor.tscn, limit_vision 켬)에서 시작한다.
## 1. 시야가 붙어 있다 (지형을 어둡게 그리는 것은 창 검사 tests/view_3d/check_vision_3d.gd가 본다)
## 2. 마우스를 동쪽으로 두면: 정면 쥐는 보이고, 부채꼴 안이어도 벽 뒤 쥐·뒤쪽 쥐·부채꼴 밖 쥐는 안 보이며, 몸 바로 뒤(둘레 원 안) 쥐는 보인다
## 3. 마우스를 서쪽으로 돌리면 정면이던 쥐는 안 보이고 뒤쪽이던 쥐가 보인다
## 4. 내 언데드는 부채꼴 밖에서도 보인다
## 4-1. 언데드 시야: 플레이어가 반대쪽을 봐도 언데드가 보는 쪽의 쥐는 보인다, 언데드 시야도 벽 뒤는 안 보인다, 해제하면 다시 안 보인다
## 5. 시야를 끄면 모두 보인다 (개발용 키와 같은 set_active)
## 6. 매 프레임 시야 계산 시간을 출력한다
## 7. 거점(limit_vision 끔)에는 시야가 없다
## (쥐는 데이터 복사로 움직이지 않고 피해를 주지 않게 고정)

const CORRIDOR_SCENE: String = "res://regions/test_corridor.tscn"
const BASE_REGION: String = "res://data/regions/base.tres"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const RAT_PATH: String = "res://data/monsters/rat.tres"
const RAT_SKULL_PATH: String = "res://data/skulls/rat_skull.tres"
const BONE_PATH: String = "res://data/items/bone.tres"
const TILE: float = 32.0
## 시험 통로 칸: 위쪽 가로 통로(줄 2~3)에 네크로맨서, 그 아래 벽(줄 4) 너머 작은 굴(줄 5~6)
const NECRO_TILE: Vector2 = Vector2(5, 3)
const FRONT_TILE: Vector2 = Vector2(10, 3)
const BEHIND_WALL_TILE: Vector2 = Vector2(13, 6)
const BACK_TILE: Vector2 = Vector2(2, 3)
const NEAR_TILE: Vector2 = Vector2(4, 3)
const SIDE_TILE: Vector2 = Vector2(4, 6.5)
## 나타나고 사라지는 시간(0.15초)보다 넉넉히
const SETTLE_FRAMES: int = 15
const TIMING_FRAMES: int = 60

var _walls: Node2D
var _rats: Dictionary = {}


func get_start_scene() -> String:
	return CORRIDOR_SCENE


func _on_scene_ready() -> void:
	_run()


func _check(step_name: String, ok: bool, evidence: String) -> bool:
	if ok:
		pass_step(step_name, evidence)
	else:
		fail_step(step_name, evidence)
		finish(false)
	return ok


func _tile(tile: Vector2) -> Vector2:
	return _walls.global_position + tile * TILE


func _run() -> void:
	_walls = current_scene.get_node("Walls")
	for node: Node in get_nodes_in_group(&"monsters"):
		node.queue_free()
	await wait_frames(2)
	var vision: Vision = current_scene.call(&"get_vision")
	var actors: Node2D = find_necromancer().get_parent()
	if not _check("시야가 붙음", vision != null and vision.active, "Vision %s, 켜짐 %s" % [vision, vision.active if vision != null else false]):
		return
	var necro: Necromancer = find_necromancer()
	necro.global_position = _tile(NECRO_TILE)
	var harmless: MonsterData = (load(RAT_PATH) as MonsterData).duplicate()
	harmless.move_speed = 0.0
	harmless.wander_speed = 0.0
	harmless.contact_damage = 0.0
	harmless.detect_range = 0.0
	for spot: Array in [["정면", FRONT_TILE], ["벽 뒤", BEHIND_WALL_TILE], ["뒤쪽", BACK_TILE], ["몸 바로 뒤", NEAR_TILE], ["부채꼴 밖", SIDE_TILE]]:
		var rat: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
		rat.data = harmless
		rat.position = _tile(spot[1])
		actors.add_child(rat)
		_rats[spot[0]] = rat
	aim_mouse_at(necro.get_body_center() + Vector2(200, 0))
	await wait_frames(SETTLE_FRAMES)
	var east: Dictionary = _seen()
	if not _check("동쪽을 보면", east["정면"] and not east["벽 뒤"] and not east["뒤쪽"] and east["몸 바로 뒤"] and not east["부채꼴 밖"], "보임 %s" % east):
		return
	aim_mouse_at(necro.get_body_center() + Vector2(-200, 0))
	await wait_frames(SETTLE_FRAMES)
	var west: Dictionary = _seen()
	if not _check("서쪽으로 돌리면", not west["정면"] and west["뒤쪽"] and west["몸 바로 뒤"], "보임 %s" % west):
		return
	# 내 언데드는 부채꼴 밖(네크로맨서 동쪽 뒤, 서쪽을 보는 중)에서도 보인다.
	necro.inventory.try_add(ItemStack.of_item(load(BONE_PATH), 20))
	var skull: Skull = Skull.create(load(RAT_SKULL_PATH))
	necro.inventory.try_add(ItemStack.of_skull(skull))
	var hotbar: Hotbar = root.get_node("GameState").hotbar
	hotbar.assign(0, skull)
	hotbar.select(0)
	necro.summoner.toggle_selected()
	await wait_frames(SETTLE_FRAMES)
	var undead: Node2D = get_first_node_in_group(&"undead") as Node2D
	if undead != null:
		undead.global_position = _tile(FRONT_TILE + Vector2(-1, 0))
	await wait_frames(SETTLE_FRAMES)
	if not _check("언데드는 부채꼴 밖에서도 보임", undead != null and undead.visible and not vision.is_visible_at(undead.global_position), "언데드 %s, visible %s, 그 자리 시야 안 %s" % [undead, undead.visible if undead != null else false, vision.is_visible_at(undead.global_position) if undead != null else false]):
		return
	# 언데드 시야: 언데드를 정면 쥐 바로 서쪽에 세워 두고(움직이지 않게) 동쪽을 보게 한다. 플레이어는 서쪽을 보는 중이다.
	var sighted: Undead = undead as Undead
	sighted.process_mode = Node.PROCESS_MODE_DISABLED
	sighted.global_position = _tile(FRONT_TILE + Vector2(-2, 0))
	sighted.facing = Vector2.RIGHT
	await wait_frames(SETTLE_FRAMES)
	var front: Vector2 = (_rats["정면"] as Node2D).global_position
	if not _check("언데드가 보는 쪽은 보임", _seen()["정면"] and not vision.is_visible_to_player(front) and vision.get_undead_sight_count() == 1, "정면 쥐 보임 %s, 플레이어 시야 안 %s, 언데드 시야 %d개" % [_seen()["정면"], vision.is_visible_to_player(front), vision.get_undead_sight_count()]):
		return
	var behind_wall: Vector2 = (_rats["벽 뒤"] as Node2D).global_position
	sighted.facing = sighted.get_sight_origin().direction_to(behind_wall)
	await wait_frames(SETTLE_FRAMES)
	if not _check("언데드 시야도 벽 뒤는 안 보임", not _seen()["벽 뒤"] and sighted.get_sight_origin().distance_to(behind_wall) < sighted.data.get_undead_sight().view_range, "벽 뒤 쥐 보임 %s, 언데드에서 거리 %.0f (보는 거리 %.0f)" % [_seen()["벽 뒤"], sighted.get_sight_origin().distance_to(behind_wall), sighted.data.get_undead_sight().view_range]):
		return
	sighted.facing = Vector2.RIGHT
	necro.summoner.toggle_selected()
	await wait_frames(SETTLE_FRAMES)
	if not _check("언데드를 해제하면 다시 안 보임", not _seen()["정면"] and vision.get_undead_sight_count() == 0, "정면 쥐 보임 %s, 언데드 시야 %d개" % [_seen()["정면"], vision.get_undead_sight_count()]):
		return
	vision.set_active(false)
	await wait_frames(SETTLE_FRAMES)
	var off: Dictionary = _seen()
	var all_seen: bool = off.values().all(func(v: bool) -> bool: return v)
	if not _check("시야를 끄면 모두 보임", all_seen, "보임 %s" % off):
		return
	vision.set_active(true)
	var worst: int = 0
	var total: int = 0
	for i: int in TIMING_FRAMES:
		aim_mouse_at(necro.get_body_center() + Vector2.from_angle(i * TAU / TIMING_FRAMES) * 200.0)
		await wait_frames(1)
		worst = maxi(worst, vision.last_update_usec)
		total += vision.last_update_usec
	pass_step("시야 처리 시간", "%d프레임 평균 %.3fms, 가장 길 때 %.3fms (물체 판정, 그리기 제외)" % [TIMING_FRAMES, total / 1000.0 / TIMING_FRAMES, worst / 1000.0])
	current_scene.call(&"travel_to", load(BASE_REGION))
	var frames: int = 0
	while frames < 300 and (current_scene == null or current_scene.scene_file_path == CORRIDOR_SCENE or not current_scene.is_node_ready()):
		await wait_frames(1)
		frames += 1
	await wait_frames(SETTLE_FRAMES)
	var base_vision: Variant = current_scene.call(&"get_vision") if current_scene != null else null
	_check("거점에는 시야가 없음", current_scene != null and current_scene.scene_file_path != CORRIDOR_SCENE and base_vision == null, "지금 씬 %s, Vision %s" % [current_scene.scene_file_path if current_scene != null else "-", base_vision])
	finish(true)


func _seen() -> Dictionary:
	var seen: Dictionary = {}
	for key: String in _rats:
		seen[key] = (_rats[key] as Monster).visible
	return seen
