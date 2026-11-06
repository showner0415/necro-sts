class_name EscapePoint
extends Area2D
## 지역의 탈출 지점. 네크로맨서가 원 안에 duration초 동안 있으면 escaped로 알린다 (거점으로 돌아가는 일은 지역 씬이 한다).
## 다 차기 전에 벗어나면 게이지가 처음으로 돌아간다. 게이지가 바뀌면 progress_changed로 알린다.
## 탈출 지점은 지역 씬에 직접 놓는다. 몇 개를 어디에 둘지는 지역마다 정한다.
## 바닥(Ground) 뒤, 캐릭터(Actors) 앞에 두어야 바닥 위·캐릭터 아래에 그려진다.

signal progress_changed(progress: float)
signal escaped(destination: RegionData)

## 탈출하면 갈 곳 (보통 거점)
@export var destination: RegionData
## 탈출에 필요한 시간 (초). 설계 확정: 3초
@export var duration: float = 3.0
## 원의 반지름. 그림과 판정에 같이 쓴다 (픽셀)
@export var radius: float = 20.0

@export_group("임시 도형")
@export var fill_color: Color = Color(0.09803922, 0.23529412, 0.24313726, 1)
@export var ring_color: Color = Color(0.17254902, 0.9098039, 0.9607843, 1)
@export var ring_width: float = 1.0

var _timer: EscapeTimer
var _last_progress: float = 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_timer = EscapeTimer.new(duration)
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	_collision.shape = shape


func _physics_process(delta: float) -> void:
	if _timer.update(delta, _has_necromancer_inside()):
		escaped.emit(destination)
	var progress: float = _timer.get_progress()
	if progress != _last_progress:
		_last_progress = progress
		progress_changed.emit(progress)


func get_progress() -> float:
	return _timer.get_progress()


func _has_necromancer_inside() -> bool:
	for body: Node2D in get_overlapping_bodies():
		if body is Necromancer:
			return true
	return false


func _draw() -> void:
	# 그림이 생기기 전까지 쓰는 임시 도형: 바닥에 칠한 원과 테두리.
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius - ring_width / 2.0, 0.0, TAU, 48, ring_color, ring_width)
