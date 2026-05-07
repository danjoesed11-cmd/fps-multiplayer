class_name KingOfTheHill
extends GameModeBase

const ZONE_RADIUS        := 6.0
const POINTS_PER_SECOND  := 1
const WIN_SCORE          := 120
const ZONE_MOVE_INTERVAL := 40.0

var zone_pos: Vector3 = Vector3.ZERO
var _controlling_team: int = -1
var _control_accum: float = 0.0
var _zone_timer: float = 0.0
var _zone_positions: Array[Vector3] = []
var _zone_index: int = 0
var _zone_marker: Node3D = null

func _ready() -> void:
	super._ready()
	mode_id = "koth"
	match_duration = 480.0
	score_limit = WIN_SCORE

func _setup_objectives() -> void:
	# Build zone ring from map spawn midpoints, or use defaults
	var map := _map
	if map:
		var sp0 := map.get_node_or_null("SpawnPoints_Team0")
		var sp1 := map.get_node_or_null("SpawnPoints_Team1")
		if sp0 and sp1 and sp0.get_child_count() > 0 and sp1.get_child_count() > 0:
			var a: Vector3 = sp0.get_child(0).global_position
			var b: Vector3 = sp1.get_child(0).global_position
			var mid := (a + b) * 0.5
			var off := (b - a).normalized().rotated(Vector3.UP, PI * 0.5) * 10.0
			_zone_positions = [mid, mid + off, mid - off,
				mid + (b - a).normalized() * 8.0, mid - (b - a).normalized() * 8.0]
	if _zone_positions.is_empty():
		_zone_positions = [
			Vector3(0, 1, 0), Vector3(14, 1, 0), Vector3(-14, 1, 0),
			Vector3(0, 1, 14), Vector3(0, 1, -14)
		]
	zone_pos = _zone_positions[0]
	_spawn_zone_marker(zone_pos)

func _spawn_zone_marker(pos: Vector3) -> void:
	if _zone_marker and is_instance_valid(_zone_marker):
		_zone_marker.queue_free()
	_zone_marker = Node3D.new()
	_zone_marker.global_position = pos
	get_tree().root.add_child(_zone_marker)

	# Glowing disc on the ground
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius    = ZONE_RADIUS
	disc_mesh.bottom_radius = ZONE_RADIUS
	disc_mesh.height        = 0.12
	disc.mesh = disc_mesh
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(1.0, 0.85, 0.0, 0.35)
	dmat.emission_enabled = true
	dmat.emission = Color(1.0, 0.8, 0.0, 1)
	dmat.emission_energy_multiplier = 2.5
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc.material_override = dmat
	_zone_marker.add_child(disc)

	# Tall vertical beam
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius    = 0.5
	bm.bottom_radius = 0.5
	bm.height        = 60.0
	beam.mesh = bm
	beam.position.y = 30.0
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.85, 0.0, 0.06)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.8, 0.0, 1)
	bmat.emission_energy_multiplier = 1.5
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bmat
	_zone_marker.add_child(beam)

func _process(delta: float) -> void:
	super._process(delta)
	if match_state != MatchState.ACTIVE:
		return

	_zone_timer += delta
	if _zone_timer >= ZONE_MOVE_INTERVAL:
		_zone_timer = 0.0
		_move_zone()

	_update_control(delta)

func _update_control(delta: float) -> void:
	var counts := {}
	for node in GameManager.get_all_player_nodes():
		if not node is Player:
			continue
		var p := node as Player
		if not p.is_alive:
			continue
		if p.global_position.distance_to(zone_pos) <= ZONE_RADIUS:
			counts[p.team_id] = counts.get(p.team_id, 0) + 1

	if counts.size() == 1:
		var controlling_team: int = counts.keys()[0]
		_control_accum += delta
		while _control_accum >= 1.0:
			_control_accum -= 1.0
			_add_score(controlling_team, POINTS_PER_SECOND)
	else:
		_control_accum = 0.0

func _move_zone() -> void:
	_zone_index = (_zone_index + 1) % _zone_positions.size()
	var new_pos := _zone_positions[_zone_index]
	zone_pos = new_pos
	_sync_zone.rpc(new_pos)
	if _zone_marker and is_instance_valid(_zone_marker):
		_zone_marker.global_position = new_pos

@rpc("authority", "call_local", "reliable")
func _sync_zone(pos: Vector3) -> void:
	zone_pos = pos
	if _zone_marker and is_instance_valid(_zone_marker):
		_zone_marker.global_position = pos

func _check_win_condition() -> void:
	for i in team_count:
		if team_scores[i] >= WIN_SCORE:
			GameManager.end_match(i)

func _on_match_start() -> void:
	_maybe_spawn_bots()

func _maybe_spawn_bots() -> void:
	if not multiplayer.is_server():
		return
	if PlayerRegistry.players.size() > 1:
		return
	const BOT_SCENE := "res://scenes/player/BotPlayer.tscn"
	var bot_scene := load(BOT_SCENE) as PackedScene
	if not bot_scene:
		return
	for i in 6:
		var bot := bot_scene.instantiate()
		bot.set("peer_id", -(i + 1))
		bot.set("team_id", 0 if i < 3 else 1)
		bot.name = str(-(i + 1))
		GameManager.players_root.add_child(bot)
		bot.set("global_position", get_spawn_position(-(i + 1)))

func _on_player_killed(victim_id: int, killer_id: int, weapon_id: String) -> void:
	super._on_player_killed(victim_id, killer_id, weapon_id)
