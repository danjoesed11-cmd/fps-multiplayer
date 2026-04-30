class_name CaptureTheFlag
extends GameModeBase

var flag_carriers: Dictionary = {}
var flag_positions: Dictionary = {}
var flag_nodes: Dictionary = {}
var flag_stands: Dictionary = {}
var _flag_at_base: Dictionary = {}

func _ready() -> void:
	mode_id = "ctf"
	score_limit = 3
	team_count = 2
	super._ready()

func _setup_objectives() -> void:
	if not _map:
		return
	var obj_root := _map.get_node_or_null("ObjectivePoints")
	if not obj_root:
		return
	for marker in obj_root.get_children():
		if marker.is_in_group("flag_stand"):
			var team: int = int(marker.get_meta("team_id", 0))
			flag_stands[team] = marker.global_position
			flag_positions[team] = marker.global_position
			_flag_at_base[team] = true
			flag_carriers[team] = -1

func _on_player_killed(victim_id: int, killer_id: int, weapon_id: String) -> void:
	super._on_player_killed(victim_id, killer_id, weapon_id)
	for team in flag_carriers:
		if flag_carriers[team] == victim_id:
			_drop_flag(team, GameManager.get_player_node(victim_id).global_position if GameManager.get_player_node(victim_id) else flag_positions[team])

func _drop_flag(flag_team: int, drop_pos: Vector3) -> void:
	flag_carriers[flag_team] = -1
	flag_positions[flag_team] = drop_pos
	_flag_at_base[flag_team] = false
	EventBus.flag_dropped.emit(flag_team, drop_pos)
	_sync_flag_dropped.rpc(flag_team, drop_pos)

func try_pickup_flag(player_id: int, flag_team: int) -> void:
	if not multiplayer.is_server():
		return
	var info := PlayerRegistry.get_info(player_id)
	if not info or info.team_id == flag_team:
		return
	if flag_carriers[flag_team] != -1:
		return
	flag_carriers[flag_team] = player_id
	EventBus.flag_picked_up.emit(player_id, flag_team)
	_sync_flag_picked_up.rpc(player_id, flag_team)

func try_capture_flag(player_id: int) -> void:
	if not multiplayer.is_server():
		return
	var info := PlayerRegistry.get_info(player_id)
	if not info:
		return
	var my_team := info.team_id
	for flag_team in flag_carriers:
		if flag_carriers[flag_team] == player_id:
			# Carrying enemy flag — are we at our base?
			if _flag_at_base[my_team]:
				_capture_flag(my_team, flag_team)

func _capture_flag(capturing_team: int, flag_team: int) -> void:
	flag_carriers[flag_team] = -1
	flag_positions[flag_team] = flag_stands[flag_team]
	_flag_at_base[flag_team] = true
	_add_score(capturing_team, 1)
	EconomyManager.server_add_coins(_last_carrier_of(flag_team), coins_per_objective)
	EventBus.flag_captured.emit(capturing_team)
	_sync_flag_captured.rpc(capturing_team, flag_team)

func _last_carrier_of(_flag_team: int) -> int:
	return -1

func _check_win_condition() -> void:
	for i in team_count:
		if team_scores[i] >= score_limit:
			GameManager.end_match(i)
			return

@rpc("authority", "call_local", "reliable")
func _sync_flag_picked_up(player_id: int, flag_team: int) -> void:
	EventBus.flag_picked_up.emit(player_id, flag_team)

@rpc("authority", "call_local", "reliable")
func _sync_flag_dropped(flag_team: int, drop_pos: Vector3) -> void:
	EventBus.flag_dropped.emit(flag_team, drop_pos)

@rpc("authority", "call_local", "reliable")
func _sync_flag_captured(capturing_team: int, _flag_team: int) -> void:
	EventBus.flag_captured.emit(capturing_team)
