class_name MainMenu
extends Control

@onready var name_input: LineEdit = %NameInput
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var ip_input: LineEdit = %IPInput
@onready var port_input: LineEdit = %PortInput
@onready var status_label: Label = %StatusLabel
@onready var singleplayer_button: Button = %SingleplayerButton
@onready var quit_button: Button = %QuitButton
@onready var bg1: ColorRect = $BgGradient
@onready var bg2: ColorRect = $BgGradient2

const BTN_COLORS := [
	Color(1.0, 0.55, 0.0),
	Color(0.2, 0.85, 0.45),
	Color(0.15, 0.6, 1.0),
	Color(0.85, 0.15, 0.65),
]

var _t: float = 0.0

func _ready() -> void:
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	singleplayer_button.pressed.connect(_on_singleplayer)
	quit_button.pressed.connect(get_tree().quit)
	name_input.text = SettingsManager.get_setting("display_name", "Player")
	ip_input.text = "127.0.0.1"
	port_input.text = str(NetworkManager.PORT)
	status_label.text = ""

	_style_button(singleplayer_button, Color(1.0, 0.65, 0.0), Color(0.12, 0.06, 0.0))
	_style_button(host_button, Color(0.15, 0.78, 0.42), Color(1, 1, 1))
	_style_button(join_button, Color(0.18, 0.55, 1.0), Color(1, 1, 1))

	_animate_in()

func _process(delta: float) -> void:
	_t += delta * 0.4
	var c1 := Color.from_hsv(fmod(_t * 0.08, 1.0), 0.82, 0.45)
	var c2 := Color.from_hsv(fmod(_t * 0.08 + 0.35, 1.0), 0.9, 0.55)
	bg1.color = c1
	bg2.color = Color(c2.r, c2.g, c2.b, 0.55)

func _animate_in() -> void:
	var panel := $CenterContainer/Panel
	panel.modulate = Color(1, 1, 1, 0)
	panel.position.y += 40
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(panel, "position:y", 0.0, 0.5)

func _style_button(btn: Button, bg: Color, fg: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_right = 10
	normal.corner_radius_bottom_left = 10
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg.lightened(0.15)
	hover.corner_radius_top_left = 10
	hover.corner_radius_top_right = 10
	hover.corner_radius_bottom_right = 10
	hover.corner_radius_bottom_left = 10
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = bg.darkened(0.15)
	pressed.corner_radius_top_left = 10
	pressed.corner_radius_top_right = 10
	pressed.corner_radius_bottom_right = 10
	pressed.corner_radius_bottom_left = 10
	pressed.content_margin_left = 12
	pressed.content_margin_right = 12
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)

func _on_host() -> void:
	_save_name()
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.PORT
	var err := NetworkManager.create_server(port)
	if err == OK:
		_register_self()
		GameManager.transition_to_lobby()
	else:
		_show_error("Failed to host server")

func _on_join() -> void:
	_save_name()
	var ip := ip_input.text.strip_edges()
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.PORT
	status_label.text = "Connecting..."
	status_label.modulate = Color(0.4, 0.9, 1.0)
	NetworkManager.join_server(ip, port)
	NetworkManager.joined_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	NetworkManager.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)

func _on_connected_to_server(_peer_id: int) -> void:
	_register_self()
	GameManager.transition_to_lobby()

func _on_connection_failed() -> void:
	_show_error("Connection failed — check the IP and port")

func _show_error(msg: String) -> void:
	status_label.text = msg
	status_label.modulate = Color(1.0, 0.4, 0.3)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(func(): status_label.text = "")

func _on_singleplayer() -> void:
	_save_name()
	NetworkManager.create_server(NetworkManager.PORT, 1)
	_register_self()
	GameManager.start_match("singleplayer", "arena01")

func _register_self() -> void:
	var display_name := name_input.text.strip_edges()
	if display_name.is_empty():
		display_name = "Player"
	SettingsManager.set_setting("display_name", display_name)
	var cosmetics := SettingsManager.get_cosmetics()
	PlayerRegistry.request_register.rpc_id(1, display_name, cosmetics)

func _save_name() -> void:
	SettingsManager.set_setting("display_name", name_input.text.strip_edges())
