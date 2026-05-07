extends CanvasLayer

func _ready() -> void:
	layer = 40

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.02, 0.14, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchor_and_offset(SIDE_LEFT,   0.5, -300)
	root.set_anchor_and_offset(SIDE_RIGHT,  0.5,  300)
	root.set_anchor_and_offset(SIDE_TOP,    0.5, -180)
	root.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  180)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 24)
	add_child(root)

	var waffle_icon := Label.new()
	waffle_icon.text = "🧇"
	waffle_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waffle_icon.add_theme_font_size_override("font_size", 72)
	root.add_child(waffle_icon)

	var question := Label.new()
	question.text = "Did you eat toaster waffles today?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.add_theme_font_size_override("font_size", 36)
	question.add_theme_color_override("font_color", Color(1.0, 0.92, 0.15))
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(question)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	root.add_child(btn_row)

	var yes_btn := _make_btn("Yes! 🧇", Color(0.85, 0.55, 0.05))
	yes_btn.pressed.connect(_on_yes)
	btn_row.add_child(yes_btn)

	var no_btn := _make_btn("No...", Color(0.25, 0.25, 0.35))
	no_btn.pressed.connect(_on_no)
	btn_row.add_child(no_btn)

func _make_btn(label: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(160, 56)
	btn.add_theme_font_size_override("font_size", 18)
	for state in [["normal", col], ["hover", col.lightened(0.15)], ["pressed", col.darkened(0.1)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = state[1]
		sb.corner_radius_top_left = 14; sb.corner_radius_top_right = 14
		sb.corner_radius_bottom_left = 14; sb.corner_radius_bottom_right = 14
		btn.add_theme_stylebox_override(state[0], sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	return btn

func _on_yes() -> void:
	_show_response("Great! You're ready to Flashpoint.", Color(0.3, 1.0, 0.5))

func _on_no() -> void:
	_show_response("Go eat some. We'll wait.", Color(1.0, 0.5, 0.2))

func _show_response(msg: String, col: Color) -> void:
	for child in get_children():
		if child != get_child(0):  # keep bg
			child.queue_free()

	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", col)
	add_child(lbl)

	await get_tree().create_timer(2.2).timeout
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		queue_free()
