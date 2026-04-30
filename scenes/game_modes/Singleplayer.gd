class_name Singleplayer
extends GameModeBase

const BOT_SCENE := "res://scenes/player/BotPlayer.tscn"
const BOT_COUNT := 5

func _ready() -> void:
	mode_id = "singleplayer"
	team_count = 2
	score_limit = 20
	super._ready()

func _on_match_start() -> void:
	_spawn_bots()

func _spawn_bots() -> void:
	for i in BOT_COUNT:
		var bot_scene := load(BOT_SCENE) as PackedScene
		if not bot_scene:
			return
		var bot := bot_scene.instantiate()
		bot.peer_id = -(i + 1)
		bot.team_id = 1
		GameManager.players_root.add_child(bot)
		var spawn := get_spawn_position(bot.peer_id)
		bot.global_position = spawn

func _on_player_killed(victim_id: int, killer_id: int, weapon_id: String) -> void:
	super._on_player_killed(victim_id, killer_id, weapon_id)
	if victim_id > 0 and killer_id < 0:
		_add_score(1, 1)
	elif victim_id < 0 and killer_id > 0:
		_add_score(0, 1)

func _check_win_condition() -> void:
	for i in team_count:
		if team_scores[i] >= score_limit:
			GameManager.end_match(i)
			return
