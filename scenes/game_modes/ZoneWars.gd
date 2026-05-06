class_name ZoneWars
extends GameModeBase

# Zone Wars: One hot zone in the center. Teams score while they hold it.
# Zone shifts to a new position every ZONE_SHIFT_INTERVAL seconds.
# Kill to earn extra points. First to 100 wins.

const BOT_SCENE := "res://scenes/player/BotPlayer.tscn"
const BOT_COUNT := 6
const ZONE_RADIUS := 10.0
const ZONE_SHIFT_INTERVAL := 45.0
const SCORE_TICK_INTERVAL := 1.0
const ZONE_POSITIONS: Array = [
	Vector3(0, 0.5, 0),
	Vector3(20, 0.5, 0),
	Vector3(-20, 0.5, 0),
	Vector3(0, 0.5, 20),
	Vector3(0, 0.5, -20),
	Vector3(15, 0.5, 15),
	Vector3(-15, 0.5, -15),
]

var zone_pos: Vector3 = Vector3.ZERO
var _score_timer: float = 0.0
var _shift_timer: float = 0.0
var _zone_marker: Node3D = null

func _ready() -> void:
	mode_id = "zone_wars"
	score_limit = 100
	match_duration = 600.0
	team_count = 2
	super._ready()

func _on_match_start() -> void:
	_spawn_bots()
	_shift_zone()

func _spawn_bots() -> void:
	var bot_scene := load(BOT_SCENE) as PackedScene
	if not bot_scene:
		return
	var half := BOT_COUNT / 2
	for i in BOT_COUNT:
		var bot := bot_scene.instantiate() as BotPlayer
		bot.peer_id = -(i + 1)
		bot.team_id = 0 if i < half else 1
		bot.name = str(bot.peer_id)
		GameManager.players_root.add_child(bot)
		bot.global_position = _get_team_spawn(bot.team_id)

func _get_team_spawn(team_id: int) -> Vector3:
	if not _map:
		return Vector3((1 - team_id * 2) * 12.0, 4, 0)
	var spawn_node := _map.get_node_or_null("SpawnPoints_Team%d" % team_id)
	if spawn_node and spawn_node.get_child_count() > 0:
		var markers := spawn_node.get_children()
		return markers[randi() % markers.size()].global_position + Vector3.UP
	return Vector3((1 - team_id * 2) * 12.0, 4, 0)

func get_spawn_position(peer_id: int) -> Vector3:
	return _get_team_spawn(0 if peer_id >= 0 else 1)

func _shift_zone() -> void:
	var idx := randi() % ZONE_POSITIONS.size()
	zone_pos = ZONE_POSITIONS[idx]
	_shift_timer = ZONE_SHIFT_INTERVAL
	_update_zone_marker()
	_sync_zone.rpc(zone_pos)

func _update_zone_marker() -> void:
	if _zone_marker and is_instance_valid(_zone_marker):
		_zone_marker.queue_free()
	_zone_marker = Node3D.new()
	get_tree().root.add_child(_zone_marker)
	_zone_marker.global_position = zone_pos
	# Pulsing ring drawn via MeshInstance3D
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = ZONE_RADIUS - 0.4
	torus.outer_radius = ZONE_RADIUS
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.1, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.0, 1)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	_zone_marker.add_child(ring)

func _process(delta: float) -> void:
	super._process(delta)
	if match_state != MatchState.ACTIVE:
		return

	_shift_timer -= delta
	if _shift_timer <= 0:
		_shift_zone()

	_score_timer += delta
	if _score_timer >= SCORE_TICK_INTERVAL:
		_score_timer = 0.0
		_tick_zone_score()

	# Pulse zone marker
	if _zone_marker and is_instance_valid(_zone_marker):
		var s := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.004)
		_zone_marker.scale = Vector3(s, 1.0, s)

func _tick_zone_score() -> void:
	var counts := [0, 0]
	for node in GameManager.get_all_player_nodes():
		if not node is Player:
			continue
		var p := node as Player
		if not p.is_alive:
			continue
		var flat_dist := Vector2(p.global_position.x - zone_pos.x, p.global_position.z - zone_pos.z).length()
		if flat_dist <= ZONE_RADIUS and p.team_id >= 0 and p.team_id < 2:
			counts[p.team_id] += 1
	# Only the dominant team (non-contested) scores
	if counts[0] > counts[1]:
		_add_score(0, 2)
	elif counts[1] > counts[0]:
		_add_score(1, 2)

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
				SettingsManager.set_setting("cosmetic_points", pts + 750)
			GameManager.end_match(i)
			return

@rpc("authority", "call_local", "reliable")
func _sync_zone(pos: Vector3) -> void:
	zone_pos = pos
	_update_zone_marker()
