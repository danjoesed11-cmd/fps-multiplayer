class_name GameModeBase
extends Node

enum MatchState { WAITING, COUNTDOWN, ACTIVE, POST_ROUND, MATCH_OVER }

@export var mode_id: String = ""
@export var match_duration: float = 600.0
@export var score_limit: int = 50
@export var team_count: int = 2
@export var coins_per_kill: int = 100
@export var coins_per_objective: int = 250
@export var coins_per_round_win: int = 150
@export var respawn_delay: float = 3.0

# Plain var — no setter to avoid rpc → setter → rpc infinite recursion.
# Use _set_state() to change state; _sync_state.rpc() propagates to clients.
var match_state: MatchState = MatchState.WAITING

var team_scores: Array[int] = []
var _map: Node = null
var _elapsed: float = 0.0
var _countdown_time: float = 5.0

func _ready() -> void:
	EventBus.player_killed.connect(_on_player_killed)
	team_scores.resize(team_count)
	team_scores.fill(0)

func initialize(map: Node) -> void:
	_map = map
	_setup_objectives()
	PlayerRegistry.assign_teams(team_count)

func begin_match() -> void:
	_set_state(MatchState.COUNTDOWN)
	await get_tree().create_timer(_countdown_time).timeout
	_set_state(MatchState.ACTIVE)
	_on_match_start()

func _process(delta: float) -> void:
	if match_state != MatchState.ACTIVE:
		return
	_elapsed += delta
	if _elapsed >= match_duration:
		_time_up()

func _time_up() -> void:
	var winner := _get_leading_team()
	GameManager.end_match(winner)

func _get_leading_team() -> int:
	var best_score := -1
	var best_team := 0
	for i in team_count:
		if team_scores[i] > best_score:
			best_score = team_scores[i]
			best_team = i
	return best_team

# Server calls this to change state — sets locally then replicates to clients.
func _set_state(new_state: MatchState) -> void:
	match_state = new_state
	_on_state_changed(new_state)
	EventBus.match_state_changed.emit(new_state)
	_sync_state.rpc(new_state)  # no call_local → only clients receive this

func _add_score(team_id: int, amount: int) -> void:
	if team_id < 0 or team_id >= team_count:
		return
	team_scores[team_id] += amount
	EventBus.score_changed.emit(team_id, team_scores[team_id])
	_sync_scores.rpc(team_scores)
	_check_win_condition()

func _award_kill_coins(killer_id: int) -> void:
	EconomyManager.server_add_coins(killer_id, coins_per_kill)

func get_spawn_position(peer_id: int) -> Vector3:
	if not _map:
		return Vector3(randf_range(-5, 5), 2, randf_range(-5, 5))
	var info := PlayerRegistry.get_info(peer_id)
	var team := info.team_id if info else 0
	var spawn_node := _map.get_node_or_null("SpawnPoints_Team%d" % team)
	if not spawn_node or spawn_node.get_child_count() == 0:
		spawn_node = _map.get_node_or_null("SpawnPoints_Team0")
	if spawn_node and spawn_node.get_child_count() > 0:
		var markers := spawn_node.get_children()
		return markers[randi() % markers.size()].global_position + Vector3.UP
	return Vector3(randf_range(-5, 5), 2, randf_range(-5, 5))

# Virtual — override in subclasses
func _on_match_start() -> void: pass
func _on_player_killed(victim_id: int, killer_id: int, weapon_id: String) -> void:
	_award_kill_coins(killer_id)
func _setup_objectives() -> void: pass
func _check_win_condition() -> void: pass
func _on_state_changed(_state: MatchState) -> void: pass

# Clients-only: server state is set directly in _set_state()
@rpc("authority", "reliable")
func _sync_state(state: int) -> void:
	match_state = state as MatchState
	_on_state_changed(state)
	EventBus.match_state_changed.emit(state)

@rpc("authority", "call_local", "reliable")
func _sync_scores(scores: Array) -> void:
	for i in mini(scores.size(), team_scores.size()):
		team_scores[i] = scores[i]
	EventBus.score_changed.emit(-1, -1)
