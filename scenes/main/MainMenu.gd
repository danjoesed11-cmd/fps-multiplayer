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

func _ready() -> void:
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	singleplayer_button.pressed.connect(_on_singleplayer)
	quit_button.pressed.connect(get_tree().quit)
	name_input.text = SettingsManager.get_setting("display_name", "Player")
	ip_input.text = "127.0.0.1"
	port_input.text = str(NetworkManager.PORT)
	status_label.text = ""

func _on_host() -> void:
	_save_name()
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.PORT
	var err := NetworkManager.create_server(port)
	if err == OK:
		_register_self()
		GameManager.transition_to_lobby()
	else:
		status_label.text = "Failed to host server"

func _on_join() -> void:
	_save_name()
	var ip := ip_input.text.strip_edges()
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.PORT
	status_label.text = "Connecting..."
	NetworkManager.join_server(ip, port)
	NetworkManager.joined_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	NetworkManager.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)

func _on_connected_to_server(_peer_id: int) -> void:
	_register_self()
	GameManager.transition_to_lobby()

func _on_connection_failed() -> void:
	status_label.text = "Connection failed"

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
