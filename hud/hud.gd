extends CanvasLayer

var _level_label: Label
var _xp_bar: ProgressBar
var _hp_bar: ProgressBar


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_level_label = Label.new()
	_level_label.position = Vector2(16, 8)
	_level_label.text = "Lv 1"
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_label.add_theme_font_size_override("font_size", 18)
	root.add_child(_level_label)

	_xp_bar = _make_bar(root, "EXP", 36.0, Color(0.25, 0.72, 0.95))
	_hp_bar = _make_bar(root, "HP", 60.0, Color(0.82, 0.28, 0.28))


func _process(_delta: float) -> void:
	var bar_width: float = get_viewport().get_visible_rect().size.x - 68.0
	_xp_bar.size.x = maxf(bar_width, 40.0)
	_hp_bar.size.x = maxf(bar_width, 40.0)
	_refresh_health()
	_refresh_xp()


func _make_bar(parent: Control, title: String, top: float, fill_color: Color) -> ProgressBar:
	var caption := Label.new()
	caption.text = title
	caption.position = Vector2(16, top)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(caption)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.position = Vector2(56, top + 2.0)
	bar.size = Vector2(280, 16)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.05, 0.05, 0.7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _refresh_health() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var max_hp: float = maxf(float(player.get("max_hp")), 1.0)
	_hp_bar.max_value = max_hp
	_hp_bar.value = float(player.get("hp"))


func _refresh_xp() -> void:
	var experience: Node = get_tree().get_first_node_in_group("experience")
	if experience == null or not experience.has_method("xp_to_next_level"):
		return
	var current_level: int = int(experience.get("level"))
	var current_xp: float = float(experience.get("xp"))
	var required: float = float(experience.call("xp_to_next_level"))
	_level_label.text = "Lv %d" % current_level
	_xp_bar.max_value = required
	_xp_bar.value = current_xp
