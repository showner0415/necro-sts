extends Node

signal level_up(new_level: int)
signal xp_changed(current: float, required: float, level: int)

@export var base_xp: float = 10.0
@export var xp_growth: float = 1.5
@export var xp_multiplier: float = 1.0

var level: int = 1
var xp: float = 0.0


func _ready() -> void:
	add_to_group("experience")


func xp_to_next_level() -> float:
	var growth: float = maxf(xp_growth, 1.0)
	var required: float = base_xp * pow(growth, float(level - 1))
	return maxf(required, 1.0)


func add_xp(amount: float) -> void:
	if amount <= 0.0:
		return
	xp += amount * xp_multiplier
	_apply_level_ups()
	xp_changed.emit(xp, xp_to_next_level(), level)


func fill_to_next_level() -> void:
	var required: float = xp_to_next_level()
	if xp < required:
		xp = required
	_apply_level_ups()
	xp_changed.emit(xp, xp_to_next_level(), level)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_F1:
		return
	fill_to_next_level()
	get_viewport().set_input_as_handled()


func _apply_level_ups() -> void:
	var required: float = xp_to_next_level()
	while xp >= required:
		xp -= required
		level += 1
		level_up.emit(level)
		required = xp_to_next_level()
