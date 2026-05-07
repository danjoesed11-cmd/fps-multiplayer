class_name Lobby
extends Control

@onready var player_list: VBoxContainer  = %PlayerList
@onready var chat_panel: Control         = %ChatPanel
@onready var mode_option: OptionButton   = %ModeOption
@onready var map_option: OptionButton    = %MapOption
@onready var ready_button: Button        = %ReadyButton
@onready var start_button: Button        = %StartButton
@onready var player_count_label: Label   = %PlayerCountLabel
@onready var ip_label: Label             = %IPLabel

const MODES: Array[String] = ["tdm", "ctf", "zone_wars", "hide_seek", "wipeout", "koth", "domination"]
const MODE_NAMES: Array[String] = ["Team Deathmatch", "Capture the Flag", "Zone Wars", "Hide & Seek", "Team Wipeout", "King of the Hill", "Domination"]
const MAPS: Array[String] = ["arena01"]
const MAP_NAMES: Array[String] = ["Neon Nexus"]

const TEAM_COLORS: Array[Color] = [
	Color(0.2, 0.5, 1.0, 1),   # Team 0 — blue
	Color(1.0, 0.35, 0.1, 1),  # Team 1 — orange
]

func _ready() -> void:
	PlayerRegistry.registry_updated.connect(_refresh_player_list)
	NetworkManager.peer_connected.connect(func(_id): _refresh_player_list())
	NetworkManager.peer_disconnected.connect(func(_id): _refresh_player_list())

	ready_button.pressed.connect(_on_ready_pressed)
	start_button.pressed.connect(_on_start_pressed)
	start_button.visible = multiplayer.is_server()

	for name in MODE_NAMES:
		mode_option.add_item(name)
	for name in MAP_NAMES:
		map_option.add_item(name)

	# Show local IP for the host to share
	if multiplayer.is_server():
		var ip := _get_local_ip()
		ip_label.text = "Your IP: %s  (port %d)" % [ip, NetworkManager.PORT]
		ip_label.visible = true
	else:
		ip_label.visible = false

	_refresh_player_list()

func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "unknown"

func _refresh_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()

	var count := 0
	for peer_id in PlayerRegistry.players:
		var info := PlayerRegistry.get_info(peer_id)
		var card := _make_player_card(info)
		player_list.add_child(card)
		count += 1

	player_count_label.text = "%d / 16 players" % count

func _make_player_card(info: PlayerRegistry.PlayerInfo) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var team_col := TEAM_COLORS[info.team_id] if info.team_id >= 0 and info.team_id < TEAM_COLORS.size() else Color(0.5, 0.5, 0.5, 1)
	sb.bg_color = Color(team_col.r, team_col.g, team_col.b, 0.18)
	sb.border_width_left = 4
	sb.border_color = team_col
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	# Team badge
	var team_badge := Label.new()
	team_badge.text = "T%d" % (info.team_id if info.team_id >= 0 else "?")
	team_badge.add_theme_color_override("font_color", team_col)
	team_badge.add_theme_font_size_override("font_size", 11)
	team_badge.custom_minimum_size = Vector2(24, 0)
	row.add_child(team_badge)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = info.display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(name_lbl)

	# KD
	var kd_lbl := Label.new()
	kd_lbl.text = "%dK / %dD" % [info.kills, info.deaths]
	kd_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	kd_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(kd_lbl)

	# Ready status
	var ready_lbl := Label.new()
	if info.is_ready:
		ready_lbl.text = "✓ READY"
		ready_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1))
	else:
		ready_lbl.text = "○ WAITING"
		ready_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	ready_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(ready_lbl)

	return card

func _on_ready_pressed() -> void:
	PlayerRegistry.request_ready_toggle.rpc_id(1)

func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		return
	var mode: String = MODES[mode_option.selected]
	var map: String = MAPS[map_option.selected]
	GameManager.start_match(mode, map)
