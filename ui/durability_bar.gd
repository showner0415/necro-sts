class_name DurabilityBar
extends ProgressBar
## 머리뼈의 내구도 바. 현재 / 최대 비율만큼 채워지고, 비율에 따라 색이 세 단계로 바뀐다.
## 인벤토리 칸과 핫바 칸이 같이 쓴다.

@export var normal_color: Color = Color(0.11764706, 0.7372549, 0.4509804, 1)
## 비율이 이 값 이하이면 low 색 (0~1)
@export_range(0.0, 1.0) var low_ratio: float = 0.5
@export var low_color: Color = Color(0.9764706, 0.7607843, 0.16862746, 1)
## 비율이 이 값 이하이면 critical 색 (0~1)
@export_range(0.0, 1.0) var critical_ratio: float = 0.25
@export var critical_color: Color = Color(0.9098039, 0.23137255, 0.23137255, 1)


func _ready() -> void:
	# 바마다 색이 달라지므로 스타일을 복사해서 이 바만 바꾼다.
	add_theme_stylebox_override("fill", get_theme_stylebox("fill").duplicate())


## skull의 내구도를 보여준다. null이면 숨긴다.
func show_skull(skull: Skull) -> void:
	visible = skull != null
	if skull == null:
		return
	max_value = skull.data.max_durability
	value = skull.durability
	(get_theme_stylebox("fill") as StyleBoxFlat).bg_color = get_fill_color()


func get_fill_color() -> Color:
	if ratio <= critical_ratio:
		return critical_color
	if ratio <= low_ratio:
		return low_color
	return normal_color
