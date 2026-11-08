extends ChargeBehavior
## 밸런스 시험용 "돌진하기": 돌진 방향 앞쪽에 있는 상대만 맞힌다 (게임에는 쓰지 않는다).
## 원래 조각은 돌진하는 동안 몸에서 hit_radius 안이면 방향과 상관없이 맞혀서, 멧돼지에 붙어 싸우던 언데드가 뒤·옆에서도 함께 맞았다.
## 여기서는 상대가 멧돼지 몸 가운데에서 돌진 방향 쪽 반(내적 > 0)에 있을 때만 맞힌다. 나머지 판정(한 번만, 밀쳐내기)은 같다.
## tests/balance/run_map_route.gd의 --charge_front=1이 멧돼지 데이터 복사본에 넣는다.


func _hit_hostiles(body: CharacterBody2D, stats: CombatStats) -> void:
	for hostile: Node2D in body.call(&"get_hostiles"):
		if _hit.has(hostile) or body.global_position.distance_to(hostile.global_position) > hit_radius:
			continue
		if (hostile.global_position - body.global_position).dot(get_direction()) <= 0.0:
			continue
		_hit.append(hostile)
		hostile.call(&"take_damage", stats.contact_damage, body)
		var push: Vector2 = body.global_position.direction_to(hostile.global_position)
		if push == Vector2.ZERO:
			push = get_direction()
		if hostile.has_method(&"knock_back"):
			hostile.call(&"knock_back", push * knockback_distance, knockback_duration)


## source(원래 돌진 조각)의 값을 모두 옮긴 이 조각을 만든다.
static func copy_from(source: ChargeBehavior) -> ChargeBehavior:
	var front: ChargeBehavior = (load("res://tests/balance/front_charge_behavior.gd") as GDScript).new()
	for property: Dictionary in source.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE:
			front.set(property.name, source.get(property.name))
	return front
