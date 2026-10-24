extends CanvasLayer

@export var pieces: Array[PieceData] = []
@export var undead_scene: PackedScene

var _pending: int = 0
var _open: bool = false
var _remaining_label: Label
var _card_row: HBoxContainer
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕"])
	_font = system_font
	_build_ui()
	hide()
	call_deferred("_bind_experience")


func _bind_experience() -> void:
	var experience: Node = get_tree().get_first_node_in_group("experience")
	if experience == null or not experience.has_signal("level_up"):
		return
	if not experience.level_up.is_connected(_on_level_up):
		experience.level_up.connect(_on_level_up)


func _on_level_up(_new_level: int) -> void:
	if pieces.is_empty() or undead_scene == null:
		return
	_pending += 1
	if _open:
		_refresh_remaining()
		return
	_show_choice()


func _show_choice() -> void:
	_open = true
	_fill_cards()
	_refresh_remaining()
	show()
	get_tree().paused = true


func _refresh_remaining() -> void:
	_remaining_label.text = "남은 선택 %d" % _pending


func _on_piece_pressed(piece: PieceData) -> void:
	summon_piece(piece)
	_pending -= 1
	if _pending > 0:
		_fill_cards()
		_refresh_remaining()
		return
	_open = false
	hide()
	get_tree().paused = false


func summon_piece(piece: PieceData) -> void:
	if piece == null or undead_scene == null:
		return
	var undead: Node = undead_scene.instantiate()
	get_tree().current_scene.add_child(undead)
	if undead is Node2D:
		(undead as Node2D).global_position = _summon_position()
	if undead.has_method("apply_piece"):
		undead.apply_piece(piece)


func _summon_position() -> Vector2:
	var origin := Vector2.ZERO
	var player: Node = get_tree().get_first_node_in_group("player")
	if player is Node2D:
		origin = (player as Node2D).global_position
	var count: int = get_tree().get_nodes_in_group("undead").size()
	return origin + Vector2.from_angle(float(count) * TAU / 6.0) * 72.0


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	var title := Label.new()
	title.text = "기물 선택"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(title)
	column.add_child(title)

	_remaining_label = Label.new()
	_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_remaining_label)
	column.add_child(_remaining_label)

	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 16)
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_card_row)


func _fill_cards() -> void:
	for child: Node in _card_row.get_children():
		_card_row.remove_child(child)
		child.queue_free()
	for piece: PieceData in _pick_pieces():
		_card_row.add_child(_make_card(piece))


func _pick_pieces() -> Array[PieceData]:
	var pool: Array[PieceData] = []
	for piece: PieceData in pieces:
		if piece == null or pool.has(piece):
			continue
		pool.append(piece)
	var offer: Array[PieceData] = []
	var count: int = mini(pool.size(), 3)
	for _i: int in count:
		var index: int = randi() % pool.size()
		offer.append(pool[index])
		pool.remove_at(index)
	return offer


func _make_card(piece: PieceData) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(210, 300)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = "%s\n%s\n체력 %.0f\n공격 %.0f\n쿨타임 %.2f초\n부활 %.0f초" % [
		piece.piece_name,
		piece.family,
		piece.max_hp,
		piece.attack_damage,
		piece.attack_cooldown,
		piece.respawn_time,
	]
	button.add_theme_color_override("font_color", piece.color)
	button.add_theme_font_size_override("font_size", 18)
	_apply_font(button)
	button.pressed.connect(_on_piece_pressed.bind(piece))

	var shape := _make_shape(piece)
	shape.position = Vector2(69, 168)
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(shape)
	return button


func _make_shape(piece: PieceData) -> Control:
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(72, 72)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if piece.cells.is_empty():
		return preview
	var min_cell := piece.cells[0]
	for cell: Vector2i in piece.cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
	var cell_size := 18
	for cell: Vector2i in piece.cells:
		var block := ColorRect.new()
		block.color = piece.color
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.position = Vector2(cell - min_cell) * float(cell_size + 2)
		block.size = Vector2(cell_size, cell_size)
		preview.add_child(block)
	return preview


func _apply_font(control: Control) -> void:
	control.add_theme_font_override("font", _font)
