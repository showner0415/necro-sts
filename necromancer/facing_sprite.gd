class_name FacingSprite
extends Sprite2D
## 바라보는 방향에 맞는 그림(8방향 정지 그림)을 보여 주고, 걸을 때 위아래로 살짝 들썩인다.
## 들썩임은 걷기 애니메이션이 생기기 전까지 쓰는 임시 움직임이다.
## 기준점(발밑)은 씬에서 정한 offset이다. 들썩임은 그 위에 더한다.

## 동쪽부터 화면 시계 방향 순서의 그림: 동, 남동, 남, 남서, 서, 북서, 북, 북동 (Facing 규칙의 번호 순서)
@export var direction_textures: Array[Texture2D] = []
## 방향마다 탄이 나가는 자리 (지팡이 보석). 노드 위치(발밑)에서의 오프셋이고, direction_textures와 같은 순서다.
## 그림에서 보석이 가려진 방향은 보이는 방향에서 짐작한 자리를 쓴다 (assets/ASSETS.md).
@export var direction_muzzles: Array[Vector2] = []
## 들썩일 때 올라가는 높이 (픽셀, 임시값)
@export var bob_height: float = 1.0
## 걷는 속도로 움직일 때 1초에 들썩이는 횟수. 더 빠르면 그만큼 잦아진다 (임시값)
@export var bob_steps_per_second: float = 4.0

var _base_offset: Vector2
## 들썩임 주기 안의 위치 (0~1). 한 주기에 두 걸음.
var _bob_phase: float = 0.0
## 지금 보여 주는 방향 번호 (Facing 규칙). 처음에는 씬에 넣어 둔 그림 그대로라 -1.
var _direction_index: int = -1


func _ready() -> void:
	_base_offset = offset


## direction 쪽을 바라보는 그림으로 바꾼다. 영(0) 벡터면 그대로 둔다.
func face(direction: Vector2) -> void:
	if direction == Vector2.ZERO or direction_textures.is_empty():
		return
	_direction_index = Facing.index_for(direction, direction_textures.size())
	texture = direction_textures[_direction_index]


## 지금 방향의 탄이 나가는 자리 (노드 위치에서의 오프셋, 들썩임 포함). 아직 방향을 정하지 않았거나 자리가 없으면 ZERO.
func get_muzzle_offset() -> Vector2:
	if _direction_index < 0 or _direction_index >= direction_muzzles.size():
		return Vector2.ZERO
	return direction_muzzles[_direction_index] + (offset - _base_offset)


## speed_ratio: 걷는 속도에 대한 지금 속도의 비율. 0이면 멈춘 것이고, 들썩임도 멈추고 제자리로 돌아온다.
func update_bob(delta: float, speed_ratio: float) -> void:
	if speed_ratio <= 0.0:
		_bob_phase = 0.0
	else:
		_bob_phase = fmod(_bob_phase + delta * bob_steps_per_second * speed_ratio / 2.0, 1.0)
	# 걸음마다 한 번 올라갔다 내려온다. 픽셀이 흐려지지 않게 정수 픽셀로 끊는다.
	offset = _base_offset + Vector2(0.0, -roundf(absf(sin(_bob_phase * TAU)) * bob_height))


## 지금 들썩여 올라가 있는 높이 (픽셀). 확인용.
func get_bob_lift() -> float:
	return _base_offset.y - offset.y
