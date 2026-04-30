class_name TeamDeathmatch
extends GameModeBase

func _ready() -> void:
	mode_id = "tdm"
	score_limit = 30
	match_duration = 600.0
	team_count = 2
	super._ready()

func _on_player_killed(victim_id: int, killer_id: int, weapon_id: String) -> void:
	super._on_player_killed(victim_id, killer_id, weapon_id)
	if killer_id == victim_id:
		return
	var info := PlayerRegistry.get_info(killer_id)
	if info and info.team_id >= 0:
		_add_score(info.team_id, 1)

func _check_win_condition() -> void:
	for i in team_count:
		if team_scores[i] >= score_limit:
			GameManager.end_match(i)
			return
