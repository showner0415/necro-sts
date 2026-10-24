extends Resource
class_name PieceData

@export var id: String = ""
@export var piece_name: String = ""
@export var family: String = ""
@export var cells: Array[Vector2i] = []
@export var max_hp: float = 80.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 0.45
@export var respawn_time: float = 8.0
@export var color: Color = Color(0.45, 0.72, 0.95, 1.0)
