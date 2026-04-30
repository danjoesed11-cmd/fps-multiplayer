class_name TeamWipeout
extends GameModeBase

const ROUNDS_TO_WIN := 3

var alive_counts: Array[int] = []
var round_wins: Array[int] = []
var _round_active: bool = false

func _ready() -> void:
	mode_id = "wipeout"
	team_count = 2
	super._ready()

func _on_match_start() -> void:
	round_wins.resize(team_count)
	round_wins.fill(0)
	_start_round()

func _start_round() -> void:
	alive_counts.resize(team_count)
	alive_counts.fill(0)
	for pid in PlayerRegistry.players:
		var info := PlayerRegistry.get_info(pid)
		if info and info.team_id >= 0 and info.team_id < team_count:
			alive_counts[info.team_id] += 1
			GameManager.respawn_player(pid)
	_round_active = true
	match_state = MatchState.ACTIVE
	_sync_round_start.rpc(alive_counts)

func _on_player_killed(victim_id: int, killer_id: int, weapon_id: String) -> void:
	super._on_player_killed(victim_id, killer_id, weapon_id)
	if not _round_active:
		return
	var info := PlayerRegistry.get_info(victim_id)
	if not info or info.team_id < 0:
		return
	alive_counts[info.team_id] = maxi(0, alive_counts[info.team_id] - 1)
	_sync_alive_counts.rpc(alive_counts)
	_check_round_over()

func _check_round_over() -> void:
	var teams_alive: int = 0
	var surviving_team: int = -1
	for i in team_count:
		if alive_counts[i] > 0:
			teams_alive += 1
			surviving_team = i
	if teams_alive <= 1 and surviving_team >= 0:
		_end_round(surviving_team)

func _end_round(winning_team: int) -> void:
	_round_active = false
	round_wins[winning_team] += 1
	for pid in PlayerRegistry.get_all_on_team(winning_team):
		EconomyManager.server_add_coins(pid.peer_id, coins_per_round_win)
	match_state = MatchState.POST_ROUND
	EventBus.round_ended.emit(winning_team)
	_sync_round_ended.rpc(winning_team, round_wins)
	if round_wins[winning_team] >= ROUNDS_TO_WIN:
		GameManager.end_match(winning_team)
	else:
		await get_tree().create_timer(5.0).timeout
		_start_round()

func _check_win_condition() -> void:
	pass

@rpc("authority", "call_local", "reliable")
func _sync_round_start(counts: Array) -> void:
	alive_counts.assign(counts)

@rpc("authority", "call_local", "reliable")
func _sync_alive_counts(counts: Array) -> void:
	alive_counts.assign(counts)

@rpc("authority", "call_local", "reliable")
func _sync_round_ended(winning_team: int, wins: Array) -> void:
	round_wins.assign(wins)
	EventBus.round_ended.emit(winning_team)
