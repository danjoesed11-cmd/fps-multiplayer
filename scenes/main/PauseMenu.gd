class_name PauseMenu
extends CanvasLayer

signal resumed()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.02, 0.14, 0.95)
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
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.15, 1))
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.modulate.a = 0.3
	vbox.add_child(sep)

	_add_btn(vbox, "▶  RESUME", Color(0.15, 0.7, 0.3), _on_resume)
	_add_btn(vbox, "⚙  SETTINGS", Color(0.2, 0.4, 0.75), _on_settings)
	_add_btn(vbox, "🏠  QUIT TO MENU", Color(0.6, 0.15, 0.15), _on_quit)

func _add_btn(parent: VBoxContainer, text: String, color: Color, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 46)
	btn.add_theme_font_size_override("font_size", 15)
	for state in [["normal", color], ["hover", color.lightened(0.15)], ["pressed", color.darkened(0.1)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = state[1]
		sb.corner_radius_top_left = 10; sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10; sb.corner_radius_bottom_right = 10
		btn.add_theme_stylebox_override(state[0], sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _on_resume() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	resumed.emit()
	queue_free()

func _on_settings() -> void:
	UIManager.push_screen("res://scenes/main/SettingsScreen.tscn")

func _on_quit() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameManager.return_to_main_menu()
	queue_free()
