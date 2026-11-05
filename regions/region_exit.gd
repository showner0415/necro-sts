class_name RegionExit
extends InteractZone
## 거점의 출구 지점. 네크로맨서가 원 안에서 F를 누르면 travel_requested로 알린다.
## 실제로 지역으로 가는 일은 지역 씬(Region)이 한다.

signal travel_requested(destination: RegionData)

## 나가면 갈 지역
@export var destination: RegionData

@export_group("임시 도형")
@export var fill_color: Color = Color(0.27058825, 0.16078432, 0.24705882, 1)
@export var ring_color: Color = Color(0.65882355, 0.5176471, 0.9529412, 1)
@export var ring_width: float = 1.0


func _ready() -> void:
	super()
	interacted.connect(func() -> void: travel_requested.emit(destination))


func get_prompt_label() -> String:
	return "%s(으)로" % destination.display_name


func _draw() -> void:
	# 그림이 생기기 전까지 쓰는 임시 도형: 바닥에 칠한 원과 테두리.
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius - ring_width / 2.0, 0.0, TAU, 48, ring_color, ring_width)
