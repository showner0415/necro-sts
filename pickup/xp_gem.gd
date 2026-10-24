extends Pickup

@export var xp_value: float = 1.0


func _collect() -> void:
	var experience: Node = get_tree().get_first_node_in_group("experience")
	if experience != null and experience.has_method("add_xp"):
		experience.add_xp(xp_value)


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -7),
		Vector2(6, 0),
		Vector2(0, 7),
		Vector2(-6, 0),
	]), Color(0.35, 0.9, 1.0))
