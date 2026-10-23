extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 1.5
@export var min_spawn_interval: float = 0.25
@export var interval_decay_per_second: float = 0.04
@export var spawn_margin: float = 32.0
@export var spawn_ring_width: float = 80.0

var _elapsed: float = 0.0
var _cooldown: float = 0.0


func _process(delta: float) -> void:
	if enemy_scene == null:
		return
	_elapsed += delta
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_spawn()
	var interval: float = maxf(min_spawn_interval, spawn_interval - _elapsed * interval_decay_per_second)
	_cooldown = interval


func _spawn() -> void:
	var enemy: Node = enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	if enemy is Node2D:
		(enemy as Node2D).global_position = _spawn_position()


func _spawn_position() -> Vector2:
	var viewport: Viewport = get_viewport()
	var visible_size: Vector2 = viewport.get_visible_rect().size
	var center: Vector2 = Vector2.ZERO
	var camera: Camera2D = viewport.get_camera_2d()
	if camera != null:
		center = camera.get_screen_center_position()
		visible_size /= camera.zoom
	else:
		var player: Node = get_tree().get_first_node_in_group("player")
		if player is Node2D:
			center = (player as Node2D).global_position
	var inner: float = visible_size.length() * 0.5 + spawn_margin
	var outer: float = inner + maxf(spawn_ring_width, 0.0)
	return center + Vector2.from_angle(randf() * TAU) * randf_range(inner, outer)
