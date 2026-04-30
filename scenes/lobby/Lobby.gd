class_name Lobby
extends Control

@onready var player_list: VBoxContainer = %PlayerList
@onready var chat_panel: Control = %ChatPanel
@onready var mode_option: OptionButton = %ModeOption
@onready var map_option: OptionButton = %MapOption
@onready var ready_button: Button = %ReadyButton
@onready var start_button: Button = %StartButton
@onready var player_count_label: Label = %PlayerCountLabel

const MODES := ["tdm", "ctf", "zone_wars", "hide_seek", "wipeout", "singleplayer"]
const MAPS := ["arena01", "urban", "forest"]

func _ready() -> void:
	PlayerRegistry.registry_updated.connect(_refresh_player_list)
	ready_button.pressed.connect(_on_ready_pressed)
	start_button.pressed.connect(_on_start_pressed)
	start_button.visible = multiplayer.is_server()

	for m in MODES:
		mode_option.add_item(m.to_upper().replace("_", " "))
	for mp in MAPS:
		map_option.add_item(mp.to_upper().replace("_", " "))

	_refresh_player_list()

func _refresh_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()
	var count := 0
	for peer_id in PlayerRegistry.players:
		var info := PlayerRegistry.get_info(peer_id)
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = info.display_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ready_lbl := Label.new()
		ready_lbl.text = "[READY]" if info.is_ready else "[NOT READY]"
		ready_lbl.modulate = Color.GREEN if info.is_ready else Color.RED
		var team_lbl := Label.new()
		team_lbl.text = "Team %d" % info.team_id if info.team_id >= 0 else "Unassigned"
		row.add_child(name_lbl)
		row.add_child(team_lbl)
		row.add_child(ready_lbl)
		player_list.add_child(row)
		count += 1
	player_count_label.text = "%d players" % count

func _on_ready_pressed() -> void:
	PlayerRegistry.request_ready_toggle.rpc_id(1)

func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		return
	var mode: String = MODES[mode_option.selected]
	var map: String = MAPS[map_option.selected]
	GameManager.start_match(mode, map)
