class_name PackWander
extends RefCounted
## 무리가 함께 배회하는 규칙 (docs/game-design.md "몬스터 무리"). 노드에 의존하지 않는다.
## - 무리에 배회 기준점(anchor) 하나가 있다. 기준점은 interval초마다 방향을 새로 골라(rest_chance 확률로 멈춤) speed로 움직인다
## - 무리원은 기준점에서 radius 안이면 자기 배회를 하고, 밖이면 기준점 쪽으로 돌아온다 (is_outside)
## - 무리원이 따라오지 못하면(벽 등) 기준점이 무리 가운데에서 radius보다 멀어지지 않게 당긴다
## 방향을 고르는 무작위는 넣어 준 난수(RandomNumberGenerator)를 쓴다 (시드로 재현할 수 있게).

var anchor: Vector2
var radius: float
var interval: float
var rest_chance: float
var speed: float
var _rng: RandomNumberGenerator
var _direction: Vector2 = Vector2.ZERO
var _timer: float = 0.0


func _init(start: Vector2, wander_radius: float, turn_interval: float, rest_probability: float, anchor_speed: float, rng: RandomNumberGenerator) -> void:
	anchor = start
	radius = wander_radius
	interval = turn_interval
	rest_chance = rest_probability
	speed = anchor_speed
	_rng = rng


## 물리 프레임마다 부른다 (무리가 평소일 때만). center: 살아 있는 무리원의 가운데.
func update(delta: float, center: Vector2) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval
		_direction = Vector2.ZERO if _rng.randf() < rest_chance else Vector2.from_angle(_rng.randf() * TAU)
	anchor += _direction * speed * delta
	var offset: Vector2 = anchor - center
	if offset.length() > radius:
		anchor = center + offset.limit_length(radius)


## position(무리원 발밑)이 기준점에서 radius 밖인지. 밖이면 무리원은 기준점 쪽으로 돌아온다.
func is_outside(position: Vector2) -> bool:
	return position.distance_to(anchor) > radius


## 기준점을 at에 다시 두고 방향을 처음부터 고른다 (무리가 포기한 자리에서 다시 배회할 때).
func reset(at: Vector2) -> void:
	anchor = at
	_direction = Vector2.ZERO
	_timer = 0.0
