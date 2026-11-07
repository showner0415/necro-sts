class_name RegionExit
extends InteractZone
## 거점의 출구 지점. 네크로맨서가 원 안에서 F를 누르면 travel_requested로 알린다.
## 실제로 지역으로 가는 일은 지역 씬(Region)이 한다.

signal travel_requested(destination: RegionData)

## 나가면 갈 지역
@export var destination: RegionData
## 개발용 출구(시험 지역, 시험 통로 등)면 true. 릴리스 빌드(디버그가 아닌 내보내기)에서는 스스로 없어진다.
## 에디터·디버그 내보내기·테스트 실행에서는 그대로 있다.
@export var debug_only: bool = false

@export_group("임시 도형")
@export var fill_color: Color = Color(0.24313726, 0.15294118, 0.19215687, 1)
@export var ring_color: Color = Color(0.70980394, 0.3137255, 0.53333336, 1)
@export var ring_width: float = 1.0


func _ready() -> void:
	if not is_available(OS.is_debug_build()):
		queue_free()
		return
	super()
	interacted.connect(func() -> void: travel_requested.emit(destination))


## debug_build인 실행에서 이 출구가 있어야 하는지. 개발용 출구는 디버그 실행에서만 있다.
func is_available(debug_build: bool) -> bool:
	return debug_build or not debug_only


func get_prompt_label() -> String:
	return "%s(으)로" % destination.display_name


func _draw() -> void:
	# 그림이 생기기 전까지 쓰는 임시 도형: 바닥에 칠한 원과 테두리.
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius - ring_width / 2.0, 0.0, TAU, 48, ring_color, ring_width)
