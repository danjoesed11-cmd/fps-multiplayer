class_name HideAndSeek
extends GameModeBase

const PROP_MESHES := [
	"res://assets/models/props/barrel.tres",
	"res://assets/models/props/crate.tres",
	"res://assets/models/props/chair.tres",
]

var seeker_ids: Array[int] = []
var hider_ids: Array[int] = []
var caught_hiders: Array[int] = []
var _seek_start_delay: float = 20.0
var _round_duration: float = 180.0

func _ready() -> void:
	mode_id = "hide_seek"
	team_count = 2
	super._ready()

func _on_match_start() -> void:
	_assign_roles()
	_start_hiding_phase()

func _assign_roles() -> void:
	var all_ids := PlayerRegistry.players.keys()
	all_ids.shuffle()
	var seeker_count := maxi(1, all_ids.size() / 4)
	seeker_ids.clear()
	hider_ids.clear()
	for i in all_ids.size():
		if i < seeker_count:
			seeker_ids.append(all_ids[i])
		else:
			hider_ids.append(all_ids[i])
	_sync_roles.rpc(seeker_ids, hider_ids)

func _start_hiding_phase() -> void:
	# Freeze seekers during hiding phase
	for pid in seeker_ids:
		var player := GameManager.get_player_node(pid)
		if player:
			player.set_process(false)
			player.set_physics_process(false)
	await get_tree().create_timer(_seek_start_delay).timeout
	_start_seek_phase()

func _start_seek_phase() -> void:
	for pid in seeker_ids:
		var player := GameManager.get_player_node(pid)
		if player:
			player.set_process(true)
			player.set_physics_process(true)
	_sync_seek_started.rpc()
	await get_tree().create_timer(_round_duration).timeout
	if match_state == MatchState.ACTIVE:
		_hiders_win()

func _on_player_killed(victim_id: int, killer_id: int, weapon_id: String) -> void:
	if victim_id in hider_ids and killer_id in seeker_ids:
		caught_hiders.append(victim_id)
		EconomyManager.server_add_coins(killer_id, coins_per_objective)
		_sync_hider_caught.rpc(victim_id)
		if caught_hiders.size() >= hider_ids.size():
			_seekers_win()

func _seekers_win() -> void:
	for pid in seeker_ids:
		EconomyManager.server_add_coins(pid, coins_per_round_win)
	GameManager.end_match(0)

func _hiders_win() -> void:
	for pid in hider_ids:
		if pid not in caught_hiders:
			EconomyManager.server_add_coins(pid, coins_per_round_win)
	GameManager.end_match(1)

@rpc("authority", "call_local", "reliable")
func _sync_roles(seekers: Array, hiders: Array) -> void:
	seeker_ids.assign(seekers)
	hider_ids.assign(hiders)

@rpc("authority", "call_local", "reliable")
func _sync_seek_started() -> void:
	pass

@rpc("authority", "call_local", "reliable")
func _sync_hider_caught(victim_id: int) -> void:
	caught_hiders.append(victim_id)
