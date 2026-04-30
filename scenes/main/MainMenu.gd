class_name MainMenu
extends Control

@onready var name_input: LineEdit    = %NameInput
@onready var host_button: Button     = %HostButton
@onready var join_button: Button     = %JoinButton
@onready var ip_input: LineEdit      = %IPInput
@onready var port_input: LineEdit    = %PortInput
@onready var status_label: Label     = %StatusLabel
@onready var play_ai_button: Button  = %PlayAIButton
@onready var quit_button: Button     = %QuitButton
@onready var panel: PanelContainer   = $CenterContainer/Panel

func _ready() -> void:
	play_ai_button.pressed.connect(_on_play_ai)
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	quit_button.pressed.connect(get_tree().quit)

	name_input.text = SettingsManager.get_setting("display_name", "Player")
	ip_input.text   = SettingsManager.get_setting("last_ip", "127.0.0.1")
	port_input.text = str(NetworkManager.PORT)
	status_label.text = ""

	_style_button(play_ai_button,
		Color(1.0, 0.75, 0.0), Color(0.75, 0.35, 0.0), Color(0.08, 0.04, 0.0))
	_style_button(host_button,
		Color(0.18, 0.82, 0.45), Color(0.22, 0.95, 0.55), Color(1, 1, 1))
	_style_button(join_button,
		Color(0.2, 0.55, 1.0), Color(0.3, 0.65, 1.0), Color(1, 1, 1))

	_animate_in()

# ── Button styling ─────────────────────────────────────────

func _style_button(btn: Button, normal_color: Color, hover_color: Color, font_color: Color) -> void:
	for state in [["normal", normal_color], ["hover", hover_color], ["pressed", normal_color.darkened(0.1)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color       = state[1]
		sb.corner_radius_top_left    = 12
		sb.corner_radius_top_right   = 12
		sb.corner_radius_bottom_right = 12
		sb.corner_radius_bottom_left  = 12
		sb.content_margin_left  = 14
		sb.content_margin_right = 14
		btn.add_theme_stylebox_override(state[0], sb)
	btn.add_theme_color_override("font_color",         font_color)
	btn.add_theme_color_override("font_hover_color",   font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)

# ── Intro animation ────────────────────────────────────────

func _animate_in() -> void:
	panel.modulate   = Color(1, 1, 1, 0)
	panel.position.y += 50
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.55)
	tw.parallel().tween_property(panel, "position:y", 0.0, 0.55)

# ── Actions ────────────────────────────────────────────────

func _on_play_ai() -> void:
	_save_settings()
	var err := NetworkManager.create_server(NetworkManager.PORT, 1)
	if err == OK:
		_register_self()
		GameManager.start_match("singleplayer", "arena01")
	else:
		_show_status("Couldn't start game — try again!", Color(1, 0.4, 0.3))

func _on_host() -> void:
	_save_settings()
	var port := _get_port()
	var err := NetworkManager.create_server(port)
	if err == OK:
		_register_self()
		GameManager.transition_to_lobby()
	else:
		_show_status("Couldn't host — port may be in use", Color(1, 0.4, 0.3))

func _on_join() -> void:
	_save_settings()
	var ip   := ip_input.text.strip_edges()
	var port := _get_port()
	_show_status("Connecting to %s:%d..." % [ip, port], Color(0.4, 0.9, 1.0))
	NetworkManager.join_server(ip, port)
	NetworkManager.joined_server.connect(_on_connected, CONNECT_ONE_SHOT)
	NetworkManager.connection_failed.connect(_on_failed, CONNECT_ONE_SHOT)

func _on_connected(_id: int) -> void:
	_register_self()
	GameManager.transition_to_lobby()

func _on_failed() -> void:
	_show_status("Connection failed — check the IP address", Color(1, 0.4, 0.3))

func _show_status(msg: String, color: Color) -> void:
	status_label.text    = msg
	status_label.modulate = color
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(func(): status_label.text = "")

func _register_self() -> void:
	var display_name := name_input.text.strip_edges()
	if display_name.is_empty():
		display_name = "Player"
	PlayerRegistry.request_register.rpc_id(1, display_name, SettingsManager.get_cosmetics())

func _get_port() -> int:
	return int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.PORT

func _save_settings() -> void:
	var name_val := name_input.text.strip_edges()
	if not name_val.is_empty():
		SettingsManager.set_setting("display_name", name_val)
	SettingsManager.set_setting("last_ip", ip_input.text.strip_edges())
