extends TestCase
## 방향별 그림·탄 나가는 자리·들썩임 (FacingSprite). 트리에 넣지 않고 함수만 부른다.

var _sprite: FacingSprite
var _textures: Array[Texture2D] = []


func before_each() -> void:
	_sprite = FacingSprite.new()
	_textures.clear()
	for i: int in 8:
		_textures.append(PlaceholderTexture2D.new())
	_sprite.direction_textures = _textures
	_sprite.direction_muzzles = [Vector2(0, -1), Vector2(1, -1), Vector2(2, -1), Vector2(3, -1), Vector2(4, -1), Vector2(5, -1), Vector2(6, -1), Vector2(7, -1)] as Array[Vector2]


func after_each() -> void:
	_sprite.free()


func test_face_picks_texture_and_muzzle() -> void:
	_sprite.face(Vector2.DOWN)
	assert_eq(_sprite.texture, _textures[2], "남쪽 그림")
	assert_eq(_sprite.get_muzzle_offset(), Vector2(2, -1), "남쪽 탄 자리")
	_sprite.face(Vector2(-1, -1))
	assert_eq(_sprite.texture, _textures[5], "북서 그림")
	assert_eq(_sprite.get_muzzle_offset(), Vector2(5, -1), "북서 탄 자리")


func test_zero_direction_keeps_current() -> void:
	_sprite.face(Vector2.LEFT)
	_sprite.face(Vector2.ZERO)
	assert_eq(_sprite.texture, _textures[4], "영 벡터면 서쪽 그대로")
	assert_eq(_sprite.get_muzzle_offset(), Vector2(4, -1))


func test_no_direction_yet_gives_zero_muzzle() -> void:
	assert_eq(_sprite.get_muzzle_offset(), Vector2.ZERO, "아직 방향을 정하지 않음")


func test_bob_lifts_sprite_and_muzzle_by_whole_pixels() -> void:
	_sprite.face(Vector2.RIGHT)
	# 걷는 속도로 반 걸음(주기의 1/4 = 첫 걸음의 꼭대기)만큼 진행
	_sprite.update_bob(0.5 / _sprite.bob_steps_per_second, 1.0)
	assert_eq(_sprite.get_bob_lift(), _sprite.bob_height, "꼭대기에서 bob_height만큼 올라감")
	assert_eq(_sprite.get_muzzle_offset(), Vector2(0, -1 - _sprite.bob_height), "탄 자리도 같이 올라감")
	_sprite.update_bob(0.1, 0.0)
	assert_eq(_sprite.get_bob_lift(), 0.0, "멈추면 제자리")
