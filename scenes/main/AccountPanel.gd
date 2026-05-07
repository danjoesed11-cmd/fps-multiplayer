extends CanvasLayer

signal closed

var _user_input: LineEdit
var _pass_input: LineEdit
var _error_label: Label
var _content_root: VBoxContainer

func _ready() -> void:
	layer = 30
	_build()
	AccountManager.account_changed.connect(_refresh)

func _build() -> void:
	# Dim background
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Card
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 0)
	card.set_anchor_and_offset(SIDE_LEFT,   0.5, -210)
	card.set_anchor_and_offset(SIDE_RIGHT,  0.5,  210)
	card.set_anchor_and_offset(SIDE_TOP,    0.5, -220)
	card.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  220)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.02, 0.18, 0.98)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.4, 0.6, 1.0, 0.6)
	sb.corner_radius_top_left = 14; sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14; sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 28; sb.content_margin_right = 28
	sb.content_margin_top = 24; sb.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", sb)
	add_child(card)

	_content_root = VBoxContainer.new()
	_content_root.add_theme_constant_override("separation", 12)
	card.add_child(_content_root)

	_refresh()

func _refresh() -> void:
	for c in _content_root.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "MY ACCOUNT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	_content_root.add_child(title)
	_content_root.add_child(_sep())

	if AccountManager.is_logged_in():
		_build_logged_in()
	else:
		_build_login_form()

	_content_root.add_child(_sep())
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): closed.emit(); queue_free())
	_style_btn(close_btn, Color(0.3, 0.3, 0.4))
	_content_root.add_child(close_btn)

func _build_logged_in() -> void:
	var name_lbl := Label.new()
	name_lbl.text = "Signed in as:"
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_root.add_child(name_lbl)

	var user_lbl := Label.new()
	user_lbl.text = AccountManager.get_username()
	user_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	user_lbl.add_theme_font_size_override("font_size", 22)
	user_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	_content_root.add_child(user_lbl)

	_content_root.add_child(_sep())

	var stats := AccountManager.get_stats()
	var kd: float = float(stats.get("kills", 0)) / maxf(float(stats.get("deaths", 1)), 1.0)
	var stats_lbl := Label.new()
	stats_lbl.text = "Kills: %d    Deaths: %d    K/D: %.2f\nWins: %d    Matches: %d" % [
		stats.get("kills", 0), stats.get("deaths", 0), kd,
		stats.get("wins", 0), stats.get("matches", 0)
	]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_content_root.add_child(stats_lbl)

	var logout_btn := Button.new()
	logout_btn.text = "Sign Out"
	logout_btn.pressed.connect(func(): AccountManager.logout(); _refresh())
	_style_btn(logout_btn, Color(0.6, 0.15, 0.15))
	_content_root.add_child(logout_btn)

func _build_login_form() -> void:
	_error_label = Label.new()
	_error_label.text = ""
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_font_size_override("font_size", 12)
	_error_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_content_root.add_child(_error_label)

	_user_input = _make_input("Username")
	_content_root.add_child(_user_input)

	_pass_input = _make_input("Password")
	_pass_input.secret = true
	_content_root.add_child(_pass_input)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content_root.add_child(row)

	var login_btn := Button.new()
	login_btn.text = "Log In"
	login_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	login_btn.pressed.connect(_on_login)
	_style_btn(login_btn, Color(0.15, 0.45, 0.85))
	row.add_child(login_btn)

	var signup_btn := Button.new()
	signup_btn.text = "Create Account"
	signup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	signup_btn.pressed.connect(_on_signup)
	_style_btn(signup_btn, Color(0.1, 0.55, 0.3))
	row.add_child(signup_btn)

	var note := Label.new()
	note.text = "Accounts are saved in your browser.\nYou can friend anyone who has an account on the same device."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_root.add_child(note)

func _on_login() -> void:
	var err := AccountManager.login(_user_input.text, _pass_input.text)
	if err != "":
		_error_label.text = err
	else:
		_refresh()

func _on_signup() -> void:
	var err := AccountManager.signup(_user_input.text, _pass_input.text)
	if err != "":
		_error_label.text = err
	else:
		_refresh()

func _make_input(placeholder: String) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.custom_minimum_size = Vector2(0, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.07)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(1, 1, 1, 0.2)
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	input.add_theme_stylebox_override("normal", sb)
	input.add_theme_stylebox_override("focus", sb)
	input.add_theme_color_override("font_color", Color(1, 1, 1))
	input.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.35))
	input.add_theme_font_size_override("font_size", 14)
	return input

func _style_btn(btn: Button, col: Color) -> void:
	btn.custom_minimum_size = Vector2(0, 40)
	for state in [["normal", col], ["hover", col.lightened(0.12)], ["pressed", col.darkened(0.1)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = state[1]
		sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override(state[0], sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_font_size_override("font_size", 14)

func _sep() -> HSeparator:
	var s := HSeparator.new()
	s.modulate.a = 0.2
	return s

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		queue_free()
