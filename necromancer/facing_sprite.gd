class_name FacingSprite
extends AnimatedSprite2D
## 바라보는 방향(8방향)에 맞는 그림을 보여 준다. 멈춰 있으면 정지 그림, 움직이면 걷기 애니메이션이다.
## 그림은 SpriteFrames에 들어 있다 (tools/asset_gen/necromancer_anim.gd가 만든다): idle_<방향>, walk_<방향>.
## 방향 이름은 DIRECTION_NAMES 순서이고, Facing 규칙의 번호와 같다.
## - 바라보는 방향은 face()로 정한다 (네크로맨서는 조준 방향). 이동 방향이 바라보는 방향과 reverse_angle보다 크게 다르면
##   걷기를 거꾸로 재생한다 (뒷걸음질)
## - 걷기 재생 속도는 이동 속도 / 걷는 속도에 비례한다 (speed_scale). 뛰거나 구르면 빨라지고, 쏘며 걸으면 느려진다
## - 정지 그림(32×32)과 걷기 프레임(40×40)은 캔버스 크기가 달라서, 같은 발밑에 서도록 기준점 offset을 따로 둔다
## - 걷기 애니메이션이 없으면(몬스터 그림) 움직여도 바라보는 방향의 정지 그림을 보여 준다

const DIRECTION_NAMES: Array[String] = ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
const IDLE_PREFIX: String = "idle_"
const WALK_PREFIX: String = "walk_"
## 딱 reverse_angle인 이동(예: 동쪽을 보고 남쪽으로)을 계산 오차로 거꾸로 재생하지 않게 두는 여유 (도)
const ANGLE_EPSILON: float = 0.01

## 정지 그림의 기준점(발밑) offset. 발이 32×32 캔버스의 y=28에 있다 (assets/ASSETS.md)
@export var idle_offset: Vector2 = Vector2(-16, -28)
## 걷기 프레임의 기준점(발밑) offset. 40×40 캔버스에 사방 4px 여백이 붙어 발이 y=32에 있다
@export var walk_offset: Vector2 = Vector2(-20, -32)
## 이동 방향과 바라보는 방향이 이 각도(도)보다 크게 다르면 걷기를 거꾸로 재생한다
@export var reverse_angle: float = 90.0
## 재생 속도 배율의 범위. 배율 = 이동 속도 / 걷는 속도 (쏘며 걷기 50/80 = 0.6, 뛰기 130/80 = 1.6, 구르기는 더 빠르다)
@export var min_speed_scale: float = 0.5
@export var max_speed_scale: float = 2.0

## 지금 바라보는 방향 번호 (Facing 규칙). 처음에는 남쪽
var _direction_index: int = 2


func _ready() -> void:
	_show_idle()


## direction 쪽을 바라본다. 영(0) 벡터면 그대로 둔다. 애니메이션은 update_motion에서 바꾼다.
func face(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	_direction_index = Facing.index_for(direction, DIRECTION_NAMES.size())


## 지금 바라보는 방향 번호 (Facing 규칙)
func get_direction_index() -> int:
	return _direction_index


## 프레임마다 부른다. velocity: 지금 이동 속도 (멈추면 ZERO), walk_speed: 걷는 속도 (배율 1의 기준).
func update_motion(velocity: Vector2, walk_speed: float) -> void:
	if velocity == Vector2.ZERO or walk_speed <= 0.0:
		_show_idle()
		return
	var walk: StringName = StringName(WALK_PREFIX + DIRECTION_NAMES[_direction_index])
	# 걷기 애니메이션이 없는 그림(쥐 등)은 움직여도 바라보는 방향의 정지 그림이다.
	if sprite_frames == null or not sprite_frames.has_animation(walk):
		_show_idle()
		return
	if animation != walk:
		# 걷는 중에 방향만 바뀌면 걸음이 끊기지 않게 같은 프레임에서 잇는다.
		var keep: bool = String(animation).begins_with(WALK_PREFIX)
		var kept_frame: int = frame
		var kept_progress: float = frame_progress
		play(walk)
		if keep:
			set_frame_and_progress(kept_frame, kept_progress)
	offset = walk_offset
	var facing: Vector2 = Vector2.from_angle(_direction_index * TAU / DIRECTION_NAMES.size())
	var backwards: bool = absf(rad_to_deg(facing.angle_to(velocity))) > reverse_angle + ANGLE_EPSILON
	var ratio: float = clampf(velocity.length() / walk_speed, min_speed_scale, max_speed_scale)
	speed_scale = -ratio if backwards else ratio
	if not is_playing():
		play()


func _show_idle() -> void:
	var idle: StringName = StringName(IDLE_PREFIX + DIRECTION_NAMES[_direction_index])
	if sprite_frames == null or not sprite_frames.has_animation(idle):
		return
	if animation != idle:
		play(idle)
	speed_scale = 1.0
	offset = idle_offset
