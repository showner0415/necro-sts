extends CharacterBody2D

@export var speed: float = 260.0
@export var max_hp: float = 80.0
@export var respawn_time: float = 8.0
@export var follow_distance: float = 64.0
@export var leash_radius: float = 300.0
@export var attack_range: float = 28.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 0.45

var hp: float = 0.0
var body_color: Color = Color(0.45, 0.72, 0.95, 1.0)

var _player: Node2D = null
var _attack_timer: float = 0.0
var _respawn_timer: float = 0.0
var _returning: bool = false


func _ready() -> void:
	add_to_group("undead")
	collision_layer = 0
	collision_mask = 0
	hp = max_hp


func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			hp = max_hp
			queue_redraw()
	if _attack_timer > 0.0:
		_attack_timer = maxf(_attack_timer - delta, 0.0)
	if not is_instance_valid(_player):
		_acquire_player()
	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if hp <= 0.0:
		_move_toward(_player.global_position, follow_distance)
		move_and_slide()
		return

	var player_dist_sq: float = global_position.distance_squared_to(_player.global_position)
	if player_dist_sq > leash_radius * leash_radius:
		_returning = true
	elif player_dist_sq <= follow_distance * follow_distance:
		_returning = false
	if _returning:
		_move_toward(_player.global_position, follow_distance)
		move_and_slide()
		return

	var target: Node2D = _nearest_enemy_in_leash()
	if target == null:
		_move_toward(_player.global_position, follow_distance)
	elif global_position.distance_squared_to(target.global_position) <= attack_range * attack_range:
		velocity = Vector2.ZERO
		_try_attack(target)
	else:
		_move_toward(target.global_position, 0.0)
	move_and_slide()


func apply_piece(piece: PieceData) -> void:
	if piece == null:
		return
	max_hp = piece.max_hp
	hp = max_hp
	attack_damage = piece.attack_damage
	attack_cooldown = piece.attack_cooldown
	respawn_time = piece.respawn_time
	body_color = piece.color
	body_color.a = 1.0
	queue_redraw()


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		_respawn_timer = respawn_time
		queue_redraw()


func _draw() -> void:
	var color := body_color
	if hp <= 0.0:
		color.a = 0.35
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -14),
		Vector2(12, 12),
		Vector2(-12, 12),
	]), color)


func _acquire_player() -> void:
	var found: Node = get_tree().get_first_node_in_group("player")
	_player = found as Node2D


func _nearest_enemy_in_leash() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist_sq: float = 0.0
	var leash_sq: float = leash_radius * leash_radius
	var player_pos: Vector2 = _player.global_position
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not node is Node2D:
			continue
		var body: Node2D = node as Node2D
		if player_pos.distance_squared_to(body.global_position) > leash_sq:
			continue
		var dist_sq: float = global_position.distance_squared_to(body.global_position)
		if nearest == null or dist_sq < nearest_dist_sq:
			nearest = body
			nearest_dist_sq = dist_sq
	return nearest


func _move_toward(point: Vector2, stop_distance: float) -> void:
	var offset: Vector2 = point - global_position
	if offset.length_squared() <= stop_distance * stop_distance:
		velocity = Vector2.ZERO
		return
	velocity = offset.normalized() * speed


func _try_attack(target: Node2D) -> void:
	if _attack_timer > 0.0 or not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	_attack_timer = attack_cooldown
