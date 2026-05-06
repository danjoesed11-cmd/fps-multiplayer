class_name TeamDeathmatch
extends GameModeBase

const BOT_SCENE := "res://scenes/player/BotPlayer.tscn"
const BOT_COUNT := 6

func _ready() -> void:
	mode_id = "tdm"
	score_limit = 15
	match_duration = 300.0
	team_count = 2
	super._ready()

func _on_match_start() -> void:
	_spawn_bots()

func _spawn_bots() -> void:
	var bot_scene := load(BOT_SCENE) as PackedScene
	if not bot_scene:
		return
	var half := BOT_COUNT / 2
	for i in BOT_COUNT:
		var bot: Node = bot_scene.instantiate()
		bot.set("peer_id", -(i + 1))
		bot.set("team_id", 0 if i < half else 1)
		bot.name = str(-(i + 1))
		GameManager.players_root.add_child(bot)
		bot.set("global_position", _get_team_spawn(0 if i < half else 1))

func _get_team_spawn(team_id: int) -> Vector3:
	if not _map:
		return Vector3(randf_range(-8, 8), 4, randf_range(-8, 8))
	var spawn_node := _map.get_node_or_null("SpawnPoints_Team%d" % team_id)
	if spawn_node and spawn_node.get_child_count() > 0:
		var markers := spawn_node.get_children()
		return markers[randi() % markers.size()].global_position + Vector3.UP
	return Vector3(randf_range(-8, 8), 4, randf_range(-8, 8))

func get_spawn_position(peer_id: int) -> Vector3:
	if peer_id < 0:
		return _get_team_spawn(1)
	return _get_team_spawn(0)

func _on_player_killed(victim_id: int, killer_id: int, _weapon_id: String) -> void:
	super._on_player_killed(victim_id, killer_id, _weapon_id)
	if killer_id == victim_id:
		return
	var victim_node = GameManager.get_player_node(victim_id)
	if victim_node:
		_add_score(1 - (victim_node.team_id as int), 1)

func _check_win_condition() -> void:
	for i in team_count:
		if team_scores[i] >= score_limit:
			if i == 0:
				var pts: int = SettingsManager.get_setting("cosmetic_points", 0)
				SettingsManager.set_setting("cosmetic_points", pts + 500)
			GameManager.end_match(i)
			return
