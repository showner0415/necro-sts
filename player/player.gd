extends CharacterBody2D

@export var speed: float = 200.0
@export var max_hp: float = 100.0

var hp: float = 0.0


func _ready() -> void:
	add_to_group("player")
	hp = max_hp


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		get_tree().reload_current_scene()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(0.55, 0.85, 0.45))
