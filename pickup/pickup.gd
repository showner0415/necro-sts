extends Node2D
class_name Pickup

@export var attract_radius: float = 90.0
@export var attract_speed: float = 320.0
@export var collect_radius: float = 18.0

var _player: Node2D = null
var _attracted: bool = false


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		var found: Node = get_tree().get_first_node_in_group("player")
		_player = found as Node2D
	if _player == null:
		return
	var offset: Vector2 = _player.global_position - global_position
	var dist_sq: float = offset.length_squared()
	if dist_sq <= attract_radius * attract_radius:
		_attracted = true
	if not _attracted:
		return
	if dist_sq <= collect_radius * collect_radius:
		_collect()
		queue_free()
		return
	if dist_sq > 0.001:
		global_position += offset.normalized() * attract_speed * delta


func _collect() -> void:
	pass
