class_name Singleplayer
extends GameModeBase

const BOT_SCENE := "res://scenes/player/BotPlayer.tscn"
const BOT_COUNT := 6

# Set before begin_match() to change rules
var variant: String = "survival"  # "survival" or "tdm"

func _ready() -> void:
	mode_id = "singleplayer"
	team_count = 2
	score_limit = 10
	match_duration = 99999.0   # score-only ending; no timer
	_countdown_time = 1.0
	super._ready()

func _on_match_start() -> void:
	_spawn_bots()

func _spawn_bots() -> void:
	var bot_scene := load(BOT_SCENE) as PackedScene
	if not bot_scene:
		push_error("BotPlayer scene not found")
		return
	# First half go on team 0 (friendly), second half on team 1 (enemy)
	var friendly_count := BOT_COUNT / 2
	for i in BOT_COUNT:
		var bot: Node = bot_scene.instantiate()
		bot.set("peer_id", -(i + 1))
		bot.set("team_id", 0 if i < friendly_count else 1)
		bot.name = str(-(i + 1))
		GameManager.players_root.add_child(bot)
		bot.set("global_position", _get_team_spawn(0 if i < friendly_count else 1))

func _get_team_spawn(team_id: int) -> Vector3:
	if not _map:
		return Vector3(randf_range(-5, 5), 4, randf_range(-5, 5))
	var spawn_node := _map.get_node_or_null("SpawnPoints_Team%d" % team_id)
	if spawn_node and spawn_node.get_child_count() > 0:
		var markers := spawn_node.get_children()
		return markers[randi() % markers.size()].global_position + Vector3.UP
	return Vector3(randf_range(-5, 5), 4, randf_range(-5, 5))

func get_spawn_position(peer_id: int) -> Vector3:
	# Bots (negative IDs) use team 1 spawn, player uses team 0
	if peer_id < 0:
		return _get_team_spawn(1)
	return _get_team_spawn(0)

func _on_player_killed(victim_id: int, killer_id: int, weapon_id: String) -> void:
	super._on_player_killed(victim_id, killer_id, weapon_id)
	# Score based on which team the victim was on
	var victim_node = GameManager.get_player_node(victim_id)
	if not victim_node:
		return
	var victim_team: int = victim_node.team_id
	# Killing an enemy team 1 member scores for team 0, and vice versa
	if victim_team == 1:
		_add_score(0, 1)
	elif victim_team == 0:
		_add_score(1, 1)

func _check_win_condition() -> void:
	for i in team_count:
		if team_scores[i] >= score_limit:
			if i == 0:  # player's team won — award cosmetic points
				var pts: int = SettingsManager.get_setting("cosmetic_points", 0)
				SettingsManager.set_setting("cosmetic_points", pts + 500)
				EventBus.coins_changed.emit(-99, pts + 500)  # signal UI to refresh
			GameManager.end_match(i)
			return
