class_name CaptureTheFlag
extends GameModeBase

var flag_carriers: Dictionary = {}
var flag_positions: Dictionary = {}
var flag_nodes: Dictionary = {}
var flag_stands: Dictionary = {}
var _flag_at_base: Dictionary = {}

func _ready() -> void:
	mode_id = "ctf"
	score_limit = 3
	team_count = 2
	super._ready()

func _setup_objectives() -> void:
	var placed_from_map := false
	if _map:
		var obj_root := _map.get_node_or_null("ObjectivePoints")
		if obj_root:
			for marker in obj_root.get_children():
				if marker.is_in_group("flag_stand"):
					var team: int = int(marker.get_meta("team_id", 0))
					_init_flag(team, marker.global_position)
					placed_from_map = true

	if not placed_from_map:
		for team_id in [0, 1]:
			_init_flag(team_id, _default_flag_pos(team_id))

func _default_flag_pos(team_id: int) -> Vector3:
	if _map:
		var spawn_node := _map.get_node_or_null("SpawnPoints_Team%d" % team_id)
		if spawn_node and spawn_node.get_child_count() > 0:
			return spawn_node.get_child(0).global_position + Vector3(0, 0.5, 3.0)
	return Vector3((1 - team_id * 2) * 15.0, 1.0, 0)

func _init_flag(team_id: int, pos: Vector3) -> void:
	flag_stands[team_id]    = pos
	flag_positions[team_id] = pos
	_flag_at_base[team_id]  = true
	flag_carriers[team_id]  = -1
	_sync_spawn_flag.rpc(team_id, pos)

@rpc("authority", "call_local", "reliable")
func _sync_spawn_flag(team_id: int, pos: Vector3) -> void:
	flag_stands[team_id]    = pos
	flag_positions[team_id] = pos
	_flag_at_base[team_id]  = true
	flag_carriers[team_id]  = -1
	_spawn_flag_visual(team_id, pos)
	if multiplayer.is_server():
		_setup_flag_area(team_id)

func _spawn_flag_visual(team_id: int, pos: Vector3) -> void:
	var color := Color(0.2, 0.45, 1.0) if team_id == 0 else Color(1.0, 0.2, 0.2)

	var node := Node3D.new()
	node.name = "FlagNode_%d" % team_id
	get_tree().root.add_child(node)
	node.global_position = pos
	flag_nodes[team_id] = node

	# Pole
	var pole := MeshInstance3D.new()
	pole.mesh = CylinderMesh.new()
	(pole.mesh as CylinderMesh).top_radius    = 0.04
	(pole.mesh as CylinderMesh).bottom_radius = 0.06
	(pole.mesh as CylinderMesh).height        = 2.8
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.65, 0.65, 0.65)
	pole.material_override = pmat
	pole.position.y = 1.4
	node.add_child(pole)

	# Banner
	var banner := MeshInstance3D.new()
	banner.mesh = BoxMesh.new()
	(banner.mesh as BoxMesh).size = Vector3(0.9, 0.55, 0.07)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = color
	bmat.emission_enabled = true
	bmat.emission = color
	bmat.emission_energy_multiplier = 1.8
	banner.material_override = bmat
	banner.position = Vector3(0.45, 2.55, 0)
	node.add_child(banner)

	# Glowing base disc
	var disc := MeshInstance3D.new()
	disc.mesh = CylinderMesh.new()
	(disc.mesh as CylinderMesh).top_radius    = 1.2
	(disc.mesh as CylinderMesh).bottom_radius = 1.2
	(disc.mesh as CylinderMesh).height        = 0.1
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	dmat.emission_enabled = true
	dmat.emission = color
	dmat.emission_energy_multiplier = 2.5
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = dmat
	node.add_child(disc)

func _setup_flag_area(team_id: int) -> void:
	var flag_node = flag_nodes.get(team_id)
	if not flag_node or not is_instance_valid(flag_node):
		return
	var area := Area3D.new()
	area.name = "FlagArea"
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	cs.shape = sphere
	area.add_child(cs)
	flag_node.add_child(area)
	area.body_entered.connect(_on_flag_area_entered.bind(team_id))

func _on_flag_area_entered(body: Node, flag_team: int) -> void:
	if not multiplayer.is_server():
		return
	var node: Node = body
	while node and not node is Player:
		node = node.get_parent()
	if not node is Player:
		return
	var p := node as Player
	if not p.is_alive:
		return

	if p.team_id == flag_team:
		# Own team entering their flag's area
		if not _flag_at_base.get(flag_team, true):
			_return_flag(flag_team)   # return dropped own flag
		try_capture_flag(p.peer_id)   # capture if carrying enemy flag
	else:
		# Enemy entering flag area — attempt pickup
		try_pickup_flag(p.peer_id, flag_team)

func _return_flag(flag_team: int) -> void:
	if not flag_stands.has(flag_team):
		return
	flag_positions[flag_team] = flag_stands[flag_team]
	_flag_at_base[flag_team]  = true
	flag_carriers[flag_team]  = -1
	_sync_flag_returned.rpc(flag_team)

@rpc("authority", "call_local", "reliable")
func _sync_flag_returned(flag_team: int) -> void:
	_flag_at_base[flag_team]  = true
	flag_carriers[flag_team]  = -1
	flag_positions[flag_team] = flag_stands.get(flag_team, Vector3.ZERO)
	var fn = flag_nodes.get(flag_team)
	if fn and is_instance_valid(fn):
		fn.global_position = flag_positions[flag_team]
		fn.show()

func _on_player_killed(victim_id: int, killer_id: int, weapon_id: String) -> void:
	super._on_player_killed(victim_id, killer_id, weapon_id)
	for team in flag_carriers:
		if flag_carriers[team] == victim_id:
			var victim_node = GameManager.get_player_node(victim_id)
			var drop_pos := victim_node.global_position if victim_node else flag_positions[team]
			_drop_flag(team, drop_pos)

func _drop_flag(flag_team: int, drop_pos: Vector3) -> void:
	flag_carriers[flag_team]  = -1
	flag_positions[flag_team] = drop_pos
	_flag_at_base[flag_team]  = false
	_sync_flag_dropped.rpc(flag_team, drop_pos)

func try_pickup_flag(player_id: int, flag_team: int) -> void:
	if not multiplayer.is_server():
		return
	var info := PlayerRegistry.get_info(player_id)
	if not info or info.team_id == flag_team:
		return
	if flag_carriers.get(flag_team, -1) != -1:
		return
	if not _flag_at_base.get(flag_team, false):
		return
	flag_carriers[flag_team] = player_id
	_sync_flag_picked_up.rpc(player_id, flag_team)

func try_capture_flag(player_id: int) -> void:
	if not multiplayer.is_server():
		return
	var info := PlayerRegistry.get_info(player_id)
	if not info:
		return
	var my_team := info.team_id
	for flag_team in flag_carriers:
		if flag_carriers[flag_team] == player_id:
			if _flag_at_base.get(my_team, false):
				_capture_flag(my_team, flag_team)

func _capture_flag(capturing_team: int, flag_team: int) -> void:
	flag_carriers[flag_team]  = -1
	flag_positions[flag_team] = flag_stands[flag_team]
	_flag_at_base[flag_team]  = true
	_add_score(capturing_team, 1)
	_sync_flag_captured.rpc(capturing_team, flag_team)

func _check_win_condition() -> void:
	for i in team_count:
		if team_scores[i] >= score_limit:
			GameManager.end_match(i)
			return

@rpc("authority", "call_local", "reliable")
func _sync_flag_picked_up(player_id: int, flag_team: int) -> void:
	flag_carriers[flag_team] = player_id
	_flag_at_base[flag_team] = false
	EventBus.flag_picked_up.emit(player_id, flag_team)
	var fn = flag_nodes.get(flag_team)
	if fn and is_instance_valid(fn):
		fn.hide()

@rpc("authority", "call_local", "reliable")
func _sync_flag_dropped(flag_team: int, drop_pos: Vector3) -> void:
	flag_carriers[flag_team]  = -1
	flag_positions[flag_team] = drop_pos
	_flag_at_base[flag_team]  = false
	EventBus.flag_dropped.emit(flag_team, drop_pos)
	var fn = flag_nodes.get(flag_team)
	if fn and is_instance_valid(fn):
		fn.global_position = drop_pos
		fn.show()

@rpc("authority", "call_local", "reliable")
func _sync_flag_captured(capturing_team: int, captured_flag_team: int) -> void:
	flag_carriers[captured_flag_team]  = -1
	_flag_at_base[captured_flag_team]  = true
	flag_positions[captured_flag_team] = flag_stands.get(captured_flag_team, Vector3.ZERO)
	EventBus.flag_captured.emit(capturing_team)
	var fn = flag_nodes.get(captured_flag_team)
	if fn and is_instance_valid(fn):
		fn.global_position = flag_positions[captured_flag_team]
		fn.show()
