class_name Domination
extends GameModeBase

const ZONE_RADIUS        := 5.0
const POINTS_PER_SECOND  := 1
const WIN_SCORE          := 200
const CAPTURE_TIME       := 4.0  # seconds of uncontested presence to capture

var _zones: Array[Dictionary] = []   # each: {pos, owner_team, capture_progress, marker}
var _control_accum: float = 0.0

func _ready() -> void:
	super._ready()
	mode_id = "domination"
	match_duration = 600.0
	score_limit = WIN_SCORE

func _setup_objectives() -> void:
	var positions: Array[Vector3] = []
	if _map:
		var sp0 := _map.get_node_or_null("SpawnPoints_Team0")
		var sp1 := _map.get_node_or_null("SpawnPoints_Team1")
		if sp0 and sp1 and sp0.get_child_count() > 0 and sp1.get_child_count() > 0:
			var a: Vector3 = sp0.get_child(0).global_position
			var b: Vector3 = sp1.get_child(0).global_position
			var mid := (a + b) * 0.5
			var perp := (b - a).normalized().rotated(Vector3.UP, PI * 0.5)
			positions = [a + (b - a) * 0.25, mid, b - (b - a) * 0.25]
	if positions.is_empty():
		positions = [Vector3(-16, 1, 0), Vector3(0, 1, 0), Vector3(16, 1, 0)]

	for i in positions.size():
		var entry := {
			"pos": positions[i],
			"owner_team": -1,
			"capture_progress": 0.0,
			"capturing_team": -1,
			"marker": null,
		}
		_zones.append(entry)
		_spawn_zone_marker(entry, i)

func _spawn_zone_marker(zone: Dictionary, idx: int) -> void:
	var marker := Node3D.new()
	marker.global_position = zone.pos
	get_tree().root.add_child(marker)
	zone["marker"] = marker

	var label_chars := ["A", "B", "C"]

	# Disc
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius    = ZONE_RADIUS
	dm.bottom_radius = ZONE_RADIUS
	dm.height        = 0.12
	disc.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.5, 0.5, 0.5, 0.35)
	dmat.emission_enabled = true
	dmat.emission = Color(0.6, 0.6, 0.6, 1)
	dmat.emission_energy_multiplier = 1.5
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc.material_override = dmat
	disc.name = "Disc"
	marker.add_child(disc)

	# Beam
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius    = 0.4
	bm.bottom_radius = 0.4
	bm.height        = 50.0
	beam.mesh = bm
	beam.position.y = 25.0
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.5, 0.5, 0.5, 0.05)
	bmat.emission_enabled = true
	bmat.emission = Color(0.6, 0.6, 0.6, 1)
	bmat.emission_energy_multiplier = 1.2
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bmat
	beam.name = "Beam"
	marker.add_child(beam)

func _process(delta: float) -> void:
	super._process(delta)
	if match_state != MatchState.ACTIVE:
		return

	_update_zones(delta)

	_control_accum += delta
	while _control_accum >= 1.0:
		_control_accum -= 1.0
		for i in _zones.size():
			var owner: int = _zones[i].owner_team
			if owner >= 0:
				_add_score(owner, POINTS_PER_SECOND)

func _update_zones(delta: float) -> void:
	for zone in _zones:
		var counts := {}
		for node in GameManager.get_all_player_nodes():
			if not node is Player:
				continue
			var p := node as Player
			if not p.is_alive:
				continue
			if p.global_position.distance_to(zone.pos) <= ZONE_RADIUS:
				counts[p.team_id] = counts.get(p.team_id, 0) + 1

		var contesting_team := -1
		if counts.size() == 1:
			contesting_team = counts.keys()[0]

		if contesting_team >= 0 and contesting_team != zone.owner_team:
			zone.capture_progress = clampf(zone.capture_progress + delta / CAPTURE_TIME, 0.0, 1.0)
			zone.capturing_team = contesting_team
			if zone.capture_progress >= 1.0:
				zone.owner_team = contesting_team
				zone.capture_progress = 0.0
				_update_zone_color(zone)
				_sync_zone_owner.rpc(_zones.find(zone), contesting_team)
		elif contesting_team < 0 or contesting_team == zone.owner_team:
			zone.capture_progress = maxf(zone.capture_progress - delta / CAPTURE_TIME, 0.0)
			zone.capturing_team = -1

func _update_zone_color(zone: Dictionary) -> void:
	if not zone.marker or not is_instance_valid(zone.marker):
		return
	var team_colors := [Color(0.2, 0.5, 1.0), Color(1.0, 0.25, 0.15), Color(0.5, 0.5, 0.5)]
	var col: Color = team_colors[clampi(zone.owner_team, -1, 1) + 1]
	var disc: MeshInstance3D = zone.marker.get_node_or_null("Disc") as MeshInstance3D
	if disc:
		var mat := disc.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(col.r, col.g, col.b, 0.4)
			mat.emission = col
	var beam: MeshInstance3D = zone.marker.get_node_or_null("Beam") as MeshInstance3D
	if beam:
		var mat := beam.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(col.r, col.g, col.b, 0.07)
			mat.emission = col

@rpc("authority", "call_local", "reliable")
func _sync_zone_owner(zone_idx: int, team: int) -> void:
	if zone_idx < _zones.size():
		_zones[zone_idx].owner_team = team
		_update_zone_color(_zones[zone_idx])

func get_nearest_objective(from_pos: Vector3, team_id: int) -> Vector3:
	var best_dist := INF
	var best_pos := Vector3.ZERO
	for zone in _zones:
		if zone.owner_team == team_id:
			continue
		var d := from_pos.distance_to(zone.pos)
		if d < best_dist:
			best_dist = d
			best_pos = zone.pos
	return best_pos

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

func _check_win_condition() -> void:
	for i in team_count:
		if team_scores[i] >= WIN_SCORE:
			GameManager.end_match(i)
