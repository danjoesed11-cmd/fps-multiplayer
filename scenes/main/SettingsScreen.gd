class_name SettingsScreen
extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.02, 0.16, 0.97)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(1, 1, 1, 0.2)
	sb.corner_radius_top_left = 16; sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16; sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 28; sb.content_margin_right = 28
	sb.content_margin_top = 28; sb.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.15, 1))
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.modulate.a = 0.3
	vbox.add_child(sep)

	# Camera perspective
	_section_label(vbox, "CAMERA PERSPECTIVE")
	var cam_row := HBoxContainer.new()
	cam_row.add_theme_constant_override("separation", 8)
	vbox.add_child(cam_row)
	var current_mode: String = SettingsManager.get_setting("camera_mode", "fps")
	for mode_id in ["fps", "tps", "far"]:
		var label_map := {"fps": "First Person", "tps": "Third Person", "far": "Far (Top-Down)"}
		var btn := Button.new()
		btn.text = label_map[mode_id]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 38)
		btn.add_theme_font_size_override("font_size", 13)
		var active := (mode_id == current_mode)
		_style_toggle(btn, active)
		btn.pressed.connect(_on_camera_mode.bind(mode_id, cam_row))
		cam_row.add_child(btn)

	# Sensitivity
	_section_label(vbox, "MOUSE SENSITIVITY")
	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 10)
	vbox.add_child(sens_row)
	var sens_slider := HSlider.new()
	sens_slider.min_value = 0.0005
	sens_slider.max_value = 0.008
	sens_slider.step = 0.0001
	sens_slider.value = SettingsManager.get_sensitivity()
	sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens_row.add_child(sens_slider)
	var sens_val_lbl := Label.new()
	sens_val_lbl.text = "%.4f" % sens_slider.value
	sens_val_lbl.custom_minimum_size = Vector2(60, 0)
	sens_row.add_child(sens_val_lbl)
	sens_slider.value_changed.connect(func(v):
		SettingsManager.set_setting("mouse_sensitivity", v)
		sens_val_lbl.text = "%.4f" % v
	)

	# FOV
	_section_label(vbox, "FIELD OF VIEW")
	var fov_row := HBoxContainer.new()
	fov_row.add_theme_constant_override("separation", 10)
	vbox.add_child(fov_row)
	var fov_slider := HSlider.new()
	fov_slider.min_value = 60.0
	fov_slider.max_value = 120.0
	fov_slider.step = 1.0
	fov_slider.value = SettingsManager.get_setting("fov", 90.0)
	fov_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fov_row.add_child(fov_slider)
	var fov_val_lbl := Label.new()
	fov_val_lbl.text = "%d°" % int(fov_slider.value)
	fov_val_lbl.custom_minimum_size = Vector2(40, 0)
	fov_row.add_child(fov_val_lbl)
	fov_slider.value_changed.connect(func(v):
		SettingsManager.set_setting("fov", v)
		fov_val_lbl.text = "%d°" % int(v)
	)

	var sep2 := HSeparator.new()
	sep2.modulate.a = 0.3
	vbox.add_child(sep2)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "✓  DONE"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.add_theme_font_size_override("font_size", 15)
	_style_btn_solid(close_btn, Color(0.18, 0.55, 0.82))
	close_btn.pressed.connect(_on_close)
	vbox.add_child(close_btn)

func _section_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	parent.add_child(lbl)

func _style_toggle(btn: Button, active: bool) -> void:
	var col := Color(0.25, 0.55, 0.9) if active else Color(0.15, 0.15, 0.25)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col if state == "normal" else col.lightened(0.1)
		sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
		sb.border_width_left = 1; sb.border_width_right = 1
		sb.border_width_top = 1; sb.border_width_bottom = 1
		sb.border_color = Color(1, 1, 1, 0.25 if active else 0.1)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1.0 if active else 0.55))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))

func _style_btn_solid(btn: Button, color: Color) -> void:
	for state in [["normal", color], ["hover", color.lightened(0.15)], ["pressed", color.darkened(0.1)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = state[1]
		sb.corner_radius_top_left = 10; sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10; sb.corner_radius_bottom_right = 10
		btn.add_theme_stylebox_override(state[0], sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))

func _on_camera_mode(mode_id: String, cam_row: HBoxContainer) -> void:
	SettingsManager.set_setting("camera_mode", mode_id)
	var mode_map := {"fps": 0, "tps": 1, "far": 2}
	var idx := 0
	for btn in cam_row.get_children():
		_style_toggle(btn, idx == mode_map.get(mode_id, 0))
		idx += 1

func _on_close() -> void:
	UIManager.pop_screen()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_just_pressed("ui_cancel"):
		_on_close()
