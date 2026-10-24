extends CharacterBody2D

signal died(position: Vector2)

@export var speed: float = 90.0
@export var max_hp: float = 30.0
@export var contact_damage: float = 10.0
@export var contact_radius: float = 22.0
@export var damage_interval: float = 0.5
@export var separation_radius: float = 20.0
@export var separation_weight: float = 8.0

static var _undead_frame: int = -1
static var _undead_nodes: Array[Node] = []
static var _grid_frame: int = -1
static var _grid_cell: float = 20.0
static var _grid: Dictionary = {}

var hp: float = 0.0

var _player: Node2D = null
var _contact_radius_sq: float = 0.0
var _cooldowns: Dictionary = {}


func _ready() -> void:
	add_to_group("enemies")
	# 접촉은 거리로만 본다. 물리 레이어에 올리면 플레이어가 적에게 막힌다.
	collision_layer = 0
	collision_mask = 0
	hp = max_hp
	_contact_radius_sq = contact_radius * contact_radius
	_acquire_player()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_acquire_player()
	var target: Node2D = _nearest_target()
	var chase := Vector2.ZERO
	if target != null:
		var offset: Vector2 = target.global_position - global_position
		if offset.length_squared() > 0.001:
			chase = offset.normalized()
	var steer: Vector2 = chase + _separation_push() * separation_weight
	if steer.length_squared() > 0.001:
		velocity = steer.normalized() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if target != null:
		_apply_contact(target, delta)


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		died.emit(global_position)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color(0.85, 0.25, 0.25))


func _acquire_player() -> void:
	var found: Node = get_tree().get_first_node_in_group("player")
	_player = found as Node2D


func _nearest_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist_sq: float = 0.0
	if is_instance_valid(_player):
		nearest = _player
		nearest_dist_sq = global_position.distance_squared_to(_player.global_position)
	for node: Node in _living_undead():
		if not is_instance_valid(node) or not node is Node2D:
			continue
		var body: Node2D = node as Node2D
		if _is_downed(body):
			continue
		var dist_sq: float = global_position.distance_squared_to(body.global_position)
		if nearest == null or dist_sq < nearest_dist_sq:
			nearest = body
			nearest_dist_sq = dist_sq
	return nearest


func _is_downed(body: Node) -> bool:
	var current: Variant = body.get("hp")
	if current == null:
		return false
	return float(current) <= 0.0


func _apply_contact(target: Node2D, delta: float) -> void:
	if not is_instance_valid(target):
		_cooldowns.erase(target)
		return
	if global_position.distance_squared_to(target.global_position) > _contact_radius_sq:
		return
	var remaining: float = float(_cooldowns.get(target, 0.0)) - delta
	if remaining <= 0.0:
		if target.has_method("take_damage"):
			target.take_damage(contact_damage)
		remaining = damage_interval
	_cooldowns[target] = remaining


func _separation_push() -> Vector2:
	_ensure_separation_grid()
	var push := Vector2.ZERO
	var origin := Vector2i(
		floori(global_position.x / _grid_cell),
		floori(global_position.y / _grid_cell)
	)
	var radius_sq := separation_radius * separation_radius
	for y: int in range(origin.y - 1, origin.y + 2):
		for x: int in range(origin.x - 1, origin.x + 2):
			var bucket: Variant = _grid.get(Vector2i(x, y))
			if bucket == null:
				continue
			for other: Variant in bucket:
				var body := other as Node2D
				if body == null or body == self or not is_instance_valid(body):
					continue
				var away := global_position - body.global_position
				var dist_sq := away.length_squared()
				if dist_sq >= radius_sq:
					continue
				var dist := sqrt(dist_sq)
				if dist <= 0.001:
					away = Vector2.from_angle(float(get_instance_id() % 360) * TAU / 360.0)
					dist = 0.001
				else:
					away /= dist
				push += away * (separation_radius - dist) / separation_radius
	return push.limit_length(1.0)


func _ensure_separation_grid() -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _grid_frame:
		return
	_grid_frame = frame
	_grid_cell = maxf(separation_radius, 1.0)
	_grid.clear()
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if not node is Node2D:
			continue
		var body := node as Node2D
		var key := Vector2i(
			floori(body.global_position.x / _grid_cell),
			floori(body.global_position.y / _grid_cell)
		)
		if not _grid.has(key):
			_grid[key] = []
		(_grid[key] as Array).append(body)


func _living_undead() -> Array[Node]:
	var frame: int = Engine.get_physics_frames()
	if frame != _undead_frame:
		_undead_frame = frame
		_undead_nodes.assign(get_tree().get_nodes_in_group("undead"))
	return _undead_nodes
