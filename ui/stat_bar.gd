class_name StatBar
extends ProgressBar
## 체력·마나처럼 "현재 / 최대"를 보여주는 바. 바 위에 흰 글씨로 숫자를 쓴다.

## 프레임마다 조금씩 더한 값은 1.9999처럼 정수에 살짝 못 미칠 수 있다.
## 이 단위로 반올림한 뒤에 내림·올림해서, 그런 값이 1로 보이지 않게 한다.
const DISPLAY_TOLERANCE: float = 0.001

## 채워진 부분의 색
@export var fill_color: Color = Color.WHITE
## true면 현재 값을 올림해서 보여준다 (체력이 0.5 남았을 때 0으로 보이지 않게)
@export var round_current_up: bool = false

@onready var _value_label: Label = %ValueLabel


func _ready() -> void:
	# 같은 씬을 여러 개 써도 색이 섞이지 않게 스타일을 복사해서 바꾼다.
	var fill: StyleBoxFlat = get_theme_stylebox("fill").duplicate()
	fill.bg_color = fill_color
	add_theme_stylebox_override("fill", fill)


func set_values(current: float, maximum: float) -> void:
	max_value = maximum
	value = current
	var snapped_current: float = snappedf(current, DISPLAY_TOLERANCE)
	var shown: int = ceili(snapped_current) if round_current_up else floori(snapped_current)
	_value_label.text = "%d / %d" % [shown, ceili(maximum)]
