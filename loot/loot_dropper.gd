extends Node

@export var xp_gem_scene: PackedScene


func _ready() -> void:
	add_to_group("loot_dropper")


func watch_enemy(enemy: Node) -> void:
	if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)


func _on_enemy_died(drop_position: Vector2) -> void:
	_spawn_xp_gem(drop_position)


func _spawn_xp_gem(drop_position: Vector2) -> void:
	if xp_gem_scene == null:
		return
	var gem: Node = xp_gem_scene.instantiate()
	get_tree().current_scene.add_child(gem)
	if gem is Node2D:
		(gem as Node2D).global_position = drop_position
