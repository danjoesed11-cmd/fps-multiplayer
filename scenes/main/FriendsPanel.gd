extends CanvasLayer

signal closed

var _add_input: LineEdit
var _feedback_label: Label
var _list_root: VBoxContainer

func _ready() -> void:
	layer = 30
	_build()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)
	card.set_anchor_and_offset(SIDE_LEFT,   0.5, -190)
	card.set_anchor_and_offset(SIDE_RIGHT,  0.5,  190)
	card.set_anchor_and_offset(SIDE_TOP,    0.5, -260)
	card.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  260)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.02, 0.16, 0.98)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.3, 1.0, 0.6, 0.5)
	sb.corner_radius_top_left = 14; sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14; sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 24; sb.content_margin_right = 24
	sb.content_margin_top = 20; sb.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", sb)
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "FRIENDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	vbox.add_child(title)

	var sep1 := HSeparator.new()
	sep1.modulate.a = 0.2
	vbox.add_child(sep1)

	# Add friend row
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	vbox.add_child(add_row)

	_add_input = LineEdit.new()
	_add_input.placeholder_text = "Friend's username..."
	_add_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_input.custom_minimum_size = Vector2(0, 38)
	_style_input(_add_input)
	add_row.add_child(_add_input)

	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.custom_minimum_size = Vector2(60, 38)
	_style_btn(add_btn, Color(0.1, 0.55, 0.3))
	add_btn.pressed.connect(_on_add_friend)
	add_row.add_child(add_btn)

	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_feedback_label)

	var sep2 := HSeparator.new()
	sep2.modulate.a = 0.2
	vbox.add_child(sep2)

	# Scrollable friend list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list_root = VBoxContainer.new()
	_list_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_root.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_root)

	_refresh_list()

	var sep3 := HSeparator.new()
	sep3.modulate.a = 0.2
	vbox.add_child(sep3)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): closed.emit(); queue_free())
	_style_btn(close_btn, Color(0.3, 0.3, 0.4))
	vbox.add_child(close_btn)

func _refresh_list() -> void:
	for c in _list_root.get_children():
		c.queue_free()

	var friends := AccountManager.get_friends()
	if friends.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No friends yet. Add some!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		empty_lbl.add_theme_font_size_override("font_size", 13)
		_list_root.add_child(empty_lbl)
		return

	for friend_name in friends:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_list_root.add_child(row)

		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		dot.add_theme_font_size_override("font_size", 10)
		dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(dot)

		var name_lbl := Label.new()
		name_lbl.text = friend_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		row.add_child(name_lbl)

		var remove_btn := Button.new()
		remove_btn.text = "✕"
		remove_btn.flat = true
		remove_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 0.7))
		remove_btn.add_theme_color_override("font_hover_color", Color(1, 0.4, 0.4, 1.0))
		remove_btn.add_theme_font_size_override("font_size", 12)
		remove_btn.pressed.connect(func():
			AccountManager.remove_friend(friend_name)
			_refresh_list())
		row.add_child(remove_btn)

func _on_add_friend() -> void:
	var target := _add_input.text.strip_edges()
	if target.is_empty():
		return
	var err := AccountManager.add_friend(target)
	if err != "":
		_feedback_label.text = err
		_feedback_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	else:
		_feedback_label.text = "Added %s!" % target
		_feedback_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		_add_input.text = ""
		_refresh_list()

func _style_input(input: LineEdit) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.07)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	input.add_theme_stylebox_override("normal", sb)
	input.add_theme_stylebox_override("focus", sb)
	input.add_theme_color_override("font_color", Color(1, 1, 1))
	input.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.35))
	input.add_theme_font_size_override("font_size", 13)

func _style_btn(btn: Button, col: Color) -> void:
	btn.custom_minimum_size.y = 38
	for state in [["normal", col], ["hover", col.lightened(0.12)], ["pressed", col.darkened(0.1)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = state[1]
		sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override(state[0], sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		queue_free()
