class_name PalettePass
extends CanvasLayer
## 3D 화면의 색을 팔레트로 맞추는 후처리. 몸 곁의 도넛·안내(ScreenAnchors)와 HUD 아래, 3D 화면 위에 그린다.
## 팔레트는 Endesga 32에 빛 없는 지형용 어두운 단계 4개를 더한 것이다 (어두운 곳에서 벽과 바닥이 뭉치지 않게).
## 개발 빌드에서 toggle_key로 켜고 끈다.

const SHADER_PATH: String = "res://view_3d/palette.gdshader"
const PALETTE_PATHS: Array[String] = ["res://assets/palette/endesga-32.hex", "res://view_3d/palette_dark_steps.hex"]

## 처음에 켤지. 지금은 끈다 (사용자 결정, 2026-11-10: 시야 가장자리가 끊어져서. 지형 에셋을 만든 뒤 디더링과 함께 다시 시험한다)
@export var start_enabled: bool = false
## 개발용 켜고 끄기 키
@export var toggle_key: Key = KEY_F4

var _rect: ColorRect


func _ready() -> void:
	# ScreenAnchors(-1)보다 아래다.
	layer = -2
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	material.set_shader_parameter(&"palette", _palette_colors())
	_rect.material = material
	add_child(_rect)
	visible = start_enabled


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == toggle_key and OS.is_debug_build():
		set_enabled(not is_enabled())
		get_viewport().set_input_as_handled()


func set_enabled(value: bool) -> void:
	visible = value


func is_enabled() -> bool:
	return visible


## 팔레트의 색들 (sRGB, 8비트 값이 아닌 0~1)
func get_colors() -> Array[Color]:
	var colors: Array[Color] = []
	for path: String in PALETTE_PATHS:
		for line: String in FileAccess.get_file_as_string(path).split("\n", false):
			colors.append(Color.html(line.strip_edges()))
	return colors


func _palette_colors() -> PackedVector3Array:
	var values: PackedVector3Array = PackedVector3Array()
	for color: Color in get_colors():
		values.append(Vector3(color.r, color.g, color.b))
	return values
