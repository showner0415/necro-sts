extends View3DCheck
## 몸과 앞벽 처리 검사 (3D 층). 창을 띄운다. run_all.sh에는 넣지 않는다.
## bash tools/godot.sh --fixed-fps 60 --path . -s tests/view_3d/check_bodies_3d.gd
## 1. 네크로맨서·쥐 그림이 원본 프레임과 픽셀까지 같다
## 2. 그림 없는 몸(멧돼지 임시 도형), 시체, 줍는 물건이 2D와 같은 색으로 그려진다
## 3. 맞았을 때 번쩍임이 그림에 보인다
## 4. 쥐 그림 가운데를 8방향에서 조준해 쏘면 맞는다
## 5. 벽에 가린 몸 앞만 반투명하고, 플레이어 앞 벽은 잘린다
## 6. 시야 밖 몬스터·물건은 벽을 반투명하게 하지 않고, 언데드는 시야 밖에서도 반투명하게 한다

const SETTLE_FRAMES: int = 20
const OPEN_SPOT: Vector2 = Vector2(5, 5) * ViewSpace.TILE
const RAT_SPOT: Vector2 = Vector2(8, 5) * ViewSpace.TILE
const BOAR_SPOT: Vector2 = Vector2(5, 9) * ViewSpace.TILE
const CORPSE_SPOT: Vector2 = Vector2(8, 9) * ViewSpace.TILE
const PICKUP_SPOT: Vector2 = Vector2(4, 11) * ViewSpace.TILE
## 조준 검사에서 쥐를 두는 곳. 여기서 SHOT_DISTANCE 떨어진 8방향 자리가 모두 트인 바닥이어야 한다 (가장 가까운 벽까지 30px 넘게).
## 2026-11-14 옮김: 예전 자리 (14.5, 5)에서는 270도·135도 자리가 벽 안이라 네크로맨서가 밀려나고 탄이 곧바로 벽에 맞았다.
const AIM_CENTER: Vector2 = Vector2(16.5, 10.5) * ViewSpace.TILE
## 조준 검사 자리 확인: 네크로맨서가 놓은 자리에서 이만큼(픽셀) 넘게 밀려나면 자리가 벽에 걸린 것이다
const PLACE_TOLERANCE: float = 0.5
## 탄이 부딪히는 벽의 충돌층 (Bolt.wall_mask의 기본값과 같게)
const SHOT_WALL_MASK: int = 1
const SHOT_DISTANCE: float = 110.0
const DIRECTIONS: int = 8
const HIT_TIMEOUT_FRAMES: int = 90
const SHOT_REST_FRAMES: int = 30
## 쥐 그림 가운데: 발밑에서 화면 위로 이만큼 (픽셀, 시제품 검사와 같은 값)
const RAT_SCREEN_CENTER: float = 8.0
const FLASH: float = 3.0
const FADE_FRAMES: int = 40
const NEARBY_GROW: int = 64
## 남쪽 벽에 가린 쥐와 그때 네크로맨서가 설 자리 (쥐 기준)
const HIDDEN_RAT: Vector2 = Vector2(12.5, 14.7) * ViewSpace.TILE
const HIDDEN_NECROMANCER: Vector2 = Vector2(-128, -102)
## 남쪽 벽 앞에 설 자리 (앞벽이 플레이어를 가리는 곳)
const BEHIND_WALL_SPOT: Vector2 = Vector2(6.5, 14.0) * ViewSpace.TILE
const RAT_DATA: String = "res://data/monsters/rat.tres"
const BOAR_DATA: String = "res://data/monsters/boar.tres"
const BONE_DATA: String = "res://data/items/bone.tres"
const MONSTER_SCENE: String = "res://monsters/monster.tscn"
const CORPSE_SCENE: String = "res://monsters/corpse.tscn"
const UNDEAD_SCENE: String = "res://undead/undead.tscn"
const RAT_SKULL: String = "res://data/skulls/rat_skull.tres"
## 시야와 반투명 검사에서 쥐 곁에 놓는 자리
const UNDEAD_FROM_RAT: Vector2 = Vector2(0, 24)
const PICKUP_FROM_RAT: Vector2 = Vector2(0, -24)
## 부채꼴 안·밖을 만드는 방향
const AWAY: Vector2 = Vector2.LEFT

var _view: RegionView3D
var _necromancer: Necromancer
var _rat: Monster
var _vision: Vision


func get_start_scene() -> String:
	return TEST_CAVE_SCENE


func _on_scene_ready() -> void:
	_necromancer = find_necromancer()
	_rat = current_scene.get_node("Actors/Rat")
	freeze_monster(_rat)
	_vision = current_scene.call(&"get_vision")
	_vision.set_active(false)
	_view = open_layer()
	_necromancer.global_position = OPEN_SPOT
	_rat.global_position = RAT_SPOT
	_view.aim_override = _necromancer.get_body_center() + Vector2.RIGHT * SHOT_DISTANCE
	await wait_frames(SETTLE_FRAMES)
	await _check_sprite("네크로맨서", _necromancer)
	await _check_sprite("쥐", _rat)
	await _check_placeholders()
	await _check_flash()
	await _check_aim()
	await _check_front_walls()
	await _check_vision_rule()
	finish(true)


func _sprite_of(node: Node2D) -> FacingSprite:
	for child: Node in node.get_children():
		if child is FacingSprite:
			return child as FacingSprite
	return null


func _check_sprite(label: String, body: Node2D) -> void:
	var image: Image = await capture()
	var sprite: FacingSprite = _sprite_of(body)
	var source: Image = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_image()
	var top_left: Vector2i = Vector2i(_view.world_to_screen(body.global_position, 0.0).round() + sprite.offset)
	var opaque: int = 0
	var wrong: int = 0
	for y: int in source.get_height():
		for x: int in source.get_width():
			var expected: Color = source.get_pixel(x, y)
			if expected.a < 1.0:
				continue
			opaque += 1
			if not colors_close(image.get_pixelv(top_left + Vector2i(x, y)), expected):
				wrong += 1
	if opaque == 0 or wrong > 0:
		fail_step(label, "불투명 픽셀 %d개 중 %d개가 원본과 다름" % [opaque, wrong])
		return
	pass_step(label, "불투명 픽셀 %d개가 원본 프레임과 같음" % opaque)


func _check_placeholders() -> void:
	var boar: Monster = (load(MONSTER_SCENE) as PackedScene).instantiate()
	boar.data = load(BOAR_DATA)
	boar.process_mode = Node.PROCESS_MODE_DISABLED
	_rat.get_parent().add_child(boar)
	boar.global_position = BOAR_SPOT
	var corpse: Corpse = (load(CORPSE_SCENE) as PackedScene).instantiate()
	var bone: ItemData = load(BONE_DATA)
	corpse.setup(load(RAT_DATA), CorpseLoot.new([ItemStack.of_item(bone, 1)] as Array[ItemStack], 1.0))
	_rat.get_parent().add_child(corpse)
	corpse.global_position = CORPSE_SPOT
	var pickup: Pickup = _necromancer.pickup_scene.instantiate()
	pickup.stack = ItemStack.of_item(bone, 1)
	_rat.get_parent().add_child(pickup)
	pickup.global_position = PICKUP_SPOT
	await wait_frames(SETTLE_FRAMES)
	var image: Image = await capture()
	for entry: Array in [["멧돼지 임시 도형", boar, boar.get_placeholder_tint()], ["시체", corpse, corpse.get_placeholder_tint()], ["줍는 물건", pickup, bone.placeholder_color]]:
		var body: Node2D = entry[1]
		var center: Vector2i = Vector2i(_view.get_see_rect(body).get_center())
		var actual: Color = image.get_pixelv(center)
		if not colors_close(actual, entry[2]):
			fail_step(entry[0], "화면 %s, 기대 %s, 자리 %s" % [actual.to_html(false), (entry[2] as Color).to_html(false), center])
			return
		pass_step(entry[0], "가운데 픽셀이 2D 색 %s와 같음" % actual.to_html(false))
	boar.free()
	corpse.free()
	pickup.free()


func _check_flash() -> void:
	_rat.modulate = Color(FLASH, FLASH, FLASH, 1.0)
	await wait_frames(SETTLE_FRAMES)
	var image: Image = await capture()
	_rat.modulate = Color.WHITE
	var sprite: FacingSprite = _sprite_of(_rat)
	var source: Image = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_image()
	var top_left: Vector2i = Vector2i(_view.world_to_screen(_rat.global_position, 0.0).round() + sprite.offset)
	var wrong: int = 0
	var opaque: int = 0
	for y: int in source.get_height():
		for x: int in source.get_width():
			var color: Color = source.get_pixel(x, y)
			if color.a < 1.0:
				continue
			opaque += 1
			var expected: Color = Color(minf(color.r * FLASH, 1.0), minf(color.g * FLASH, 1.0), minf(color.b * FLASH, 1.0))
			if not colors_close(image.get_pixelv(top_left + Vector2i(x, y)), expected):
				wrong += 1
	if wrong > 0:
		fail_step("번쩍임", "%d / %d 픽셀이 3배 밝기와 다름" % [wrong, opaque])
		return
	pass_step("번쩍임", "불투명 픽셀 %d개가 2D처럼 3배 밝기" % opaque)


func _check_aim() -> void:
	_rat.global_position = AIM_CENTER
	var hits: int = 0
	var results: PackedStringArray = []
	for i: int in DIRECTIONS:
		var direction: Vector2 = Vector2.from_angle(i * TAU / DIRECTIONS)
		var spot: Vector2 = AIM_CENTER + direction * SHOT_DISTANCE
		_necromancer.global_position = spot
		_rat.health = 1000.0
		_necromancer.mana.current = _necromancer.mana.maximum
		await wait_frames(4)
		_view.aim_override = _view.aim_from_screen(_view.world_to_screen(_rat.global_position, 0.0) - Vector2(0, RAT_SCREEN_CENTER))
		# 검사 자리부터 본다: 자리가 벽에 걸려 밀려났거나 쏘는 선에 벽이 있으면 조준과 상관없이 빗나가므로 따로 알린다.
		var origin: Vector2 = _necromancer.get_shot_origin()
		var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, _view.aim_override, SHOT_WALL_MASK)
		var wall: Dictionary = _necromancer.get_world_2d().direct_space_state.intersect_ray(ray)
		if _necromancer.global_position.distance_to(spot) > PLACE_TOLERANCE or not wall.is_empty():
			fail_step("조준", "%d도: 검사 자리가 벽에 막힘 (놓은 자리 %s, 지금 %s, 쏘는 선의 벽 %s). AIM_CENTER를 트인 곳으로 옮긴다" % [
					i * 360 / DIRECTIONS, spot, _necromancer.global_position, wall.get("position", "없음")])
			return
		var before: float = _rat.health
		press_mouse(true)
		var frames: int = 0
		while _rat.health == before and frames < HIT_TIMEOUT_FRAMES:
			await wait_frames(1)
			frames += 1
		press_mouse(false)
		var hit: bool = _rat.health < before
		hits += 1 if hit else 0
		results.append("%d도 %s" % [i * 360 / DIRECTIONS, "맞음" if hit else "빗나감"])
		await wait_frames(SHOT_REST_FRAMES)
	if hits != DIRECTIONS:
		fail_step("조준", "%d / %d: %s" % [hits, DIRECTIONS, ", ".join(results)])
		return
	pass_step("조준", "쥐 그림 가운데를 조준해 8방향 모두 맞음")


func _check_front_walls() -> void:
	var walls: FrontWalls = _view.get_front_walls()
	_rat.global_position = HIDDEN_RAT
	_necromancer.global_position = HIDDEN_RAT + HIDDEN_NECROMANCER
	_view.aim_override = _necromancer.get_body_center() + Vector2(0, -200)
	walls.see_through_on = true
	await wait_frames(FADE_FRAMES)
	var on_image: Image = await capture()
	var weight: float = walls.get_see_weight(_rat)
	walls.see_through_on = false
	await wait_frames(FADE_FRAMES)
	var off_image: Image = await capture()
	walls.see_through_on = true
	var rect: Rect2i = Rect2i(_view.get_see_rect(_rat))
	var nearby: Rect2i = rect.grow(NEARBY_GROW)
	var changed: Array[Vector2i] = ImageDiff.changed_pixels(on_image, off_image)
	var inside: int = changed.filter(func(point: Vector2i) -> bool: return rect.grow(5).has_point(point)).size()
	var around: int = changed.filter(func(point: Vector2i) -> bool: return nearby.has_point(point) and not rect.grow(5).has_point(point)).size()
	if weight <= 0.99 or inside == 0 or around > 0:
		fail_step("반투명", "세기 %.2f, 그림 안 바뀐 픽셀 %d, 그림 주변 %d" % [weight, inside, around])
		return
	pass_step("반투명", "세기 %.2f, 그림 안 바뀐 픽셀 %d개, 그림 주변 0개" % [weight, inside])
	_necromancer.global_position = BEHIND_WALL_SPOT
	_rat.global_position = OPEN_SPOT
	_view.aim_override = _necromancer.get_body_center() + Vector2(0, -200)
	walls.enabled = true
	await wait_frames(FADE_FRAMES)
	var cut_image: Image = await capture()
	walls.enabled = false
	await wait_frames(FADE_FRAMES)
	var whole_image: Image = await capture()
	walls.enabled = true
	await wait_frames(FADE_FRAMES)
	var feet: Vector2i = Vector2i(_view.world_to_screen(_necromancer.global_position, 0.0))
	var cut: int = ImageDiff.changed_pixels(cut_image, whole_image, Rect2i(feet - Vector2i(70, 90), Vector2i(140, 180))).size()
	if cut == 0:
		fail_step("잘라내기", "남쪽 벽 앞에 섰는데 앞벽이 달라지지 않음")
		return
	pass_step("잘라내기", "플레이어 앞 벽 %d픽셀이 잘림" % cut)


func _check_vision_rule() -> void:
	var walls: FrontWalls = _view.get_front_walls()
	_vision.set_active(true)
	_necromancer.global_position = OPEN_SPOT
	_rat.global_position = RAT_SPOT
	var undead: Undead = (load(UNDEAD_SCENE) as PackedScene).instantiate()
	undead.setup(Skull.create(load(RAT_SKULL)), load(RAT_DATA), _necromancer)
	undead.process_mode = Node.PROCESS_MODE_DISABLED
	_rat.get_parent().add_child(undead)
	undead.global_position = RAT_SPOT + UNDEAD_FROM_RAT
	var pickup: Pickup = _necromancer.pickup_scene.instantiate()
	pickup.stack = ItemStack.of_item(load(BONE_DATA), 1)
	_rat.get_parent().add_child(pickup)
	pickup.global_position = RAT_SPOT + PICKUP_FROM_RAT
	_view.aim_override = _necromancer.get_body_center() + AWAY * SHOT_DISTANCE
	await wait_frames(FADE_FRAMES)
	var outside: Array[float] = [walls.get_see_weight(_rat), walls.get_see_weight(pickup), walls.get_see_weight(undead)]
	_view.aim_override = _necromancer.get_body_center() + Vector2.RIGHT * SHOT_DISTANCE
	await wait_frames(FADE_FRAMES)
	var inside: Array[float] = [walls.get_see_weight(_rat), walls.get_see_weight(pickup), walls.get_see_weight(undead)]
	undead.free()
	pickup.free()
	if outside[0] > 0.0 or outside[1] > 0.0 or outside[2] < 0.99 or inside.min() < 0.99:
		fail_step("시야와 반투명", "시야 밖 (쥐, 물건, 언데드) %s, 시야 안 %s" % [outside, inside])
		return
	pass_step("시야와 반투명", "시야 밖 (쥐, 물건, 언데드) %s, 시야 안 %s" % [outside, inside])
