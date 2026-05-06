class_name MainMenu
extends Control

@onready var name_input: LineEdit    = %NameInput
@onready var join_button: Button     = %JoinButton
@onready var ip_input: LineEdit      = %IPInput
@onready var port_input: LineEdit    = %PortInput
@onready var status_label: Label     = %StatusLabel
@onready var tdm_ai_button: Button   = %TDMAIButton
@onready var survival_button: Button = %SurvivalButton
@onready var zone_ai_button: Button  = %ZoneAIButton
@onready var quit_button: Button     = %QuitButton
@onready var settings_button: Button = %SettingsButton
@onready var panel: PanelContainer   = $CenterContainer/Panel

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false

	tdm_ai_button.pressed.connect(func(): _start_ai("tdm"))
	survival_button.pressed.connect(func(): _start_ai("wipeout"))
	zone_ai_button.pressed.connect(func(): _start_ai("zone_wars"))
	join_button.pressed.connect(_on_join)
	quit_button.pressed.connect(get_tree().quit)
	settings_button.pressed.connect(_on_settings)

	name_input.text = SettingsManager.get_setting("display_name", "Player")
	ip_input.text   = SettingsManager.get_setting("last_ip", "")
	port_input.text = str(NetworkManager.PORT)
	status_label.text = ""

	_style_button(tdm_ai_button,   Color(1.0, 0.45, 0.0), Color(1.0, 0.6, 0.1), Color(1, 1, 1))
	_style_button(survival_button, Color(0.7, 0.2, 0.8),  Color(0.85, 0.3, 1.0), Color(1, 1, 1))
	_style_button(zone_ai_button,  Color(0.1, 0.6, 0.9),  Color(0.2, 0.75, 1.0), Color(1, 1, 1))
	_style_button(join_button,     Color(0.2, 0.55, 1.0),   Color(0.3, 0.65, 1.0),   Color(1, 1, 1))

	_animate_in()

# ── Button styling ──────────────────────────────────────────

func _style_button(btn: Button, normal_color: Color, hover_color: Color, font_color: Color) -> void:
	for state in [["normal", normal_color], ["hover", hover_color], ["pressed", normal_color.darkened(0.1)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color                   = state[1]
		sb.corner_radius_top_left     = 12
		sb.corner_radius_top_right    = 12
		sb.corner_radius_bottom_right = 12
		sb.corner_radius_bottom_left  = 12
		sb.content_margin_left  = 14
		sb.content_margin_right = 14
		btn.add_theme_stylebox_override(state[0], sb)
	btn.add_theme_color_override("font_color",         font_color)
	btn.add_theme_color_override("font_hover_color",   font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)

# ── Intro animation ─────────────────────────────────────────

func _animate_in() -> void:
	panel.modulate.a = 0.0
	await get_tree().process_frame
	var natural_y := panel.position.y
	panel.position.y = natural_y + 60
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.55)
	tw.parallel().tween_property(panel, "position:y", natural_y, 0.55)

# ── AI modes ────────────────────────────────────────────────

func _start_ai(mode_id: String) -> void:
	_save_settings()
	var offline := OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = offline
	PlayerRegistry.request_register(_get_display_name(), SettingsManager.get_cosmetics())
	GameManager.start_match_offline(mode_id, "arena01")

# ── LAN join ────────────────────────────────────────────────

func _on_join() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		_show_status("Enter the host's local IP address", Color(1, 0.7, 0.3))
		return
	_save_settings()
	var port := _get_port()
	_show_status("Connecting to %s:%d..." % [ip, port], Color(0.4, 0.9, 1.0))
	NetworkManager.join_server(ip, port)
	NetworkManager.joined_server.connect(_on_connected, CONNECT_ONE_SHOT)
	NetworkManager.connection_failed.connect(_on_failed, CONNECT_ONE_SHOT)

func _on_connected(_id: int) -> void:
	PlayerRegistry.request_register.rpc_id(1, _get_display_name(), SettingsManager.get_cosmetics())
	GameManager.transition_to_lobby()

func _on_failed() -> void:
	_show_status("Connection failed — check the IP and make sure host is running", Color(1, 0.4, 0.3))

# ── Settings ────────────────────────────────────────────────

func _on_settings() -> void:
	UIManager.push_screen("res://scenes/main/SettingsScreen.tscn")

# ── Helpers ─────────────────────────────────────────────────

func _show_status(msg: String, color: Color) -> void:
	status_label.text     = msg
	status_label.modulate = color

func _get_display_name() -> String:
	var n := name_input.text.strip_edges()
	return n if not n.is_empty() else "Player"

func _get_port() -> int:
	return int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.PORT

func _save_settings() -> void:
	var name_val := name_input.text.strip_edges()
	if not name_val.is_empty():
		SettingsManager.set_setting("display_name", name_val)
	SettingsManager.set_setting("last_ip", ip_input.text.strip_edges())
