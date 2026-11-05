class_name Knockback
extends RefCounted
## 밀쳐내기 규칙. start()로 offset만큼 duration초 동안 밀려나는 속도를 정하고, 그동안 is_active()가 true다.
## 쓰는 쪽(네크로맨서, 언데드, 몬스터)은 밀려나는 동안 자기 이동 대신 get_velocity()로 움직인다.
## 노드에 의존하지 않으므로 씬 없이 확인할 수 있다.

## 남은 시간이 이보다 작으면 끝난 것으로 본다 (프레임 시간을 빼며 쌓이는 부동소수점 오차 때문에 한 프레임 더 밀리지 않게)
const TIME_EPSILON: float = 0.0001

var _velocity: Vector2 = Vector2.ZERO
var _time_left: float = 0.0


## offset만큼 duration초 동안 밀려난다. 밀려나는 중이면 새것으로 바뀐다.
func start(offset: Vector2, duration: float) -> void:
	if duration <= 0.0 or offset == Vector2.ZERO:
		return
	_velocity = offset / duration
	_time_left = duration


## 물리 프레임마다, 그 프레임의 이동이 끝난 뒤 부른다.
func update(delta: float) -> void:
	_time_left -= delta
	if _time_left <= TIME_EPSILON:
		_time_left = 0.0
		_velocity = Vector2.ZERO


func is_active() -> bool:
	return _time_left > 0.0


func get_velocity() -> Vector2:
	return _velocity
