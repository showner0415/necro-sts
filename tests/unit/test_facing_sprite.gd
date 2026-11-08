extends TestCase
## 방향별 정지 그림·걷기 애니메이션·역재생·재생 속도 (FacingSprite). 만든 SpriteFrames를 그대로 쓰고, 트리에 넣지 않고 함수만 부른다.

const FRAMES_PATH: String = "res://assets/necromancer/anim/necromancer_frames.tres"
const WALK_SPEED: float = 80.0
const WALK_FRAMES: int = 8
const WALK_FRAME_SIZE: Vector2 = Vector2(40, 40)
const IDLE_SIZE: Vector2 = Vector2(32, 32)

var _sprite: FacingSprite


func before_each() -> void:
	_sprite = FacingSprite.new()
	_sprite.sprite_frames = load(FRAMES_PATH)


func after_each() -> void:
	_sprite.free()


func test_frames_have_idle_and_walk_for_every_direction() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	for direction: String in FacingSprite.DIRECTION_NAMES:
		var idle: StringName = StringName(FacingSprite.IDLE_PREFIX + direction)
		var walk: StringName = StringName(FacingSprite.WALK_PREFIX + direction)
		assert_eq(frames.get_frame_count(idle), 1, "%s 정지 그림 한 장" % direction)
		assert_eq(frames.get_frame_texture(idle, 0).get_size(), IDLE_SIZE, "%s 정지 그림 크기" % direction)
		assert_eq(frames.get_frame_count(walk), WALK_FRAMES, "%s 걷기 프레임 수" % direction)
		assert_true(frames.get_animation_loop(walk), "%s 걷기는 반복" % direction)
		for i: int in WALK_FRAMES:
			assert_eq(frames.get_frame_texture(walk, i).get_size(), WALK_FRAME_SIZE, "%s 걷기 %d 크기" % [direction, i])


func test_still_shows_idle_of_facing_direction() -> void:
	_sprite.face(Vector2(-1, -1))
	_sprite.update_motion(Vector2.ZERO, WALK_SPEED)
	assert_eq(_sprite.animation, &"idle_north_west", "북서 정지 그림")
	assert_eq(_sprite.offset, _sprite.idle_offset, "정지 그림 기준점")


func test_zero_direction_keeps_current() -> void:
	_sprite.face(Vector2.LEFT)
	_sprite.face(Vector2.ZERO)
	assert_eq(_sprite.get_direction_index(), 4, "영 벡터면 서쪽 그대로")


func test_walking_forward_plays_walk_at_speed_ratio() -> void:
	_sprite.face(Vector2.RIGHT)
	_sprite.update_motion(Vector2(WALK_SPEED, 0), WALK_SPEED)
	assert_eq(_sprite.animation, &"walk_east", "동쪽 걷기")
	assert_true(_sprite.is_playing(), "재생 중")
	assert_eq(_sprite.offset, _sprite.walk_offset, "걷기 프레임 기준점")
	assert_almost_eq(_sprite.speed_scale, 1.0, 0.001, "걷는 속도면 배율 1")
	_sprite.update_motion(Vector2(WALK_SPEED * 1.625, 0), WALK_SPEED)
	assert_almost_eq(_sprite.speed_scale, 1.625, 0.001, "뛰면 빨라짐")
	_sprite.update_motion(Vector2(WALK_SPEED * 10.0, 0), WALK_SPEED)
	assert_almost_eq(_sprite.speed_scale, _sprite.max_speed_scale, 0.001, "최대 배율에서 멈춤")
	_sprite.update_motion(Vector2(WALK_SPEED * 0.1, 0), WALK_SPEED)
	assert_almost_eq(_sprite.speed_scale, _sprite.min_speed_scale, 0.001, "최소 배율에서 멈춤")


func test_walking_away_from_facing_plays_backwards() -> void:
	_sprite.face(Vector2.RIGHT)
	_sprite.update_motion(Vector2(-WALK_SPEED, 0), WALK_SPEED)
	assert_eq(_sprite.animation, &"walk_east", "몸은 바라보는 쪽(동) 그대로")
	assert_almost_eq(_sprite.speed_scale, -1.0, 0.001, "반대로 걸으면 거꾸로 재생")
	_sprite.update_motion(Vector2(0, WALK_SPEED), WALK_SPEED)
	assert_almost_eq(_sprite.speed_scale, 1.0, 0.001, "옆으로(90도) 걸으면 앞으로 재생")


func test_turning_while_walking_keeps_frame() -> void:
	_sprite.face(Vector2.RIGHT)
	_sprite.update_motion(Vector2(WALK_SPEED, 0), WALK_SPEED)
	_sprite.set_frame_and_progress(5, 0.25)
	_sprite.face(Vector2.DOWN)
	_sprite.update_motion(Vector2(0, WALK_SPEED), WALK_SPEED)
	assert_eq(_sprite.animation, &"walk_south", "남쪽 걷기로 바뀜")
	assert_eq(_sprite.frame, 5, "걸음 프레임을 이어감")


func test_stopping_returns_to_idle() -> void:
	_sprite.face(Vector2.RIGHT)
	_sprite.update_motion(Vector2(-WALK_SPEED, 0), WALK_SPEED)
	_sprite.update_motion(Vector2.ZERO, WALK_SPEED)
	assert_eq(_sprite.animation, &"idle_east", "멈추면 정지 그림")
	assert_almost_eq(_sprite.speed_scale, 1.0, 0.001, "배율 되돌림")
	assert_eq(_sprite.offset, _sprite.idle_offset, "정지 그림 기준점")
