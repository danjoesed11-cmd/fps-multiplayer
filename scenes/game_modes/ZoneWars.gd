class_name ZoneWars
extends GameModeBase

class ZoneState:
	var zone_id: int = 0
	var controlling_team: int = -1
	var capture_progress: float = 0.0
	var capturing_team: int = -1
	var players_in_zone: Dictionary = {}

const CAPTURE_RATE := 0.15
const SCORE_INTERVAL := 1.0
const SCORE_PER_ZONE := 1

var zones: Array[ZoneState] = []
var _score_timer: float = 0.0

func _ready() -> void:
	mode_id = "zone_wars"
	score_limit = 200
	match_duration = 900.0
	super._ready()

func _setup_objectives() -> void:
	if not _map:
		return
	var obj_root := _map.get_node_or_null("ObjectivePoints")
	if not obj_root:
		return
	var zone_id := 0
	for child in obj_root.get_children():
		if child.is_in_group("capture_zone") and child is Area3D:
			var zone := ZoneState.new()
			zone.zone_id = zone_id
			zones.append(zone)
			child.set_meta("zone_id", zone_id)
			child.body_entered.connect(_on_body_entered_zone.bind(zone_id))
			child.body_exited.connect(_on_body_exited_zone.bind(zone_id))
			zone_id += 1

func _on_body_entered_zone(body: Node, zone_id: int) -> void:
	if not body is Player:
		return
	var p := body as Player
	if zone_id < zones.size():
		zones[zone_id].players_in_zone[p.peer_id] = p.team_id

func _on_body_exited_zone(body: Node, zone_id: int) -> void:
	if not body is Player:
		return
	var p := body as Player
	if zone_id < zones.size():
		zones[zone_id].players_in_zone.erase(p.peer_id)

func _process(delta: float) -> void:
	super._process(delta)
	if match_state != MatchState.ACTIVE:
		return
	_update_zone_capture(delta)
	_score_timer += delta
	if _score_timer >= SCORE_INTERVAL:
		_score_timer = 0.0
		_tick_zone_scores()

func _update_zone_capture(delta: float) -> void:
	for zone in zones:
		var team_counts: Dictionary = {}
		for pid in zone.players_in_zone:
			var t: int = zone.players_in_zone[pid]
			team_counts[t] = team_counts.get(t, 0) + 1

		var dominant_team := -1
		var dominant_count := 0
		var contested := false
		for t in team_counts:
			if team_counts[t] > dominant_count:
				dominant_count = team_counts[t]
				dominant_team = t
				contested = false
			elif team_counts[t] == dominant_count:
				contested = true

		if contested or dominant_team == -1:
			continue

		if zone.controlling_team == dominant_team:
			continue

		if zone.capturing_team != dominant_team:
			zone.capturing_team = dominant_team
			zone.capture_progress = 0.0

		zone.capture_progress += CAPTURE_RATE * delta * dominant_count
		EventBus.zone_progress_changed.emit(zone.zone_id, dominant_team, zone.capture_progress)

		if zone.capture_progress >= 1.0:
			zone.controlling_team = dominant_team
			zone.capturing_team = -1
			zone.capture_progress = 0.0
			EventBus.zone_captured.emit(zone.zone_id, dominant_team)
			EconomyManager.server_add_coins(dominant_team, coins_per_objective)
			_sync_zone_captured.rpc(zone.zone_id, dominant_team)

func _tick_zone_scores() -> void:
	var zone_counts: Array = []
	zone_counts.resize(team_count)
	zone_counts.fill(0)
	for zone in zones:
		if zone.controlling_team >= 0 and zone.controlling_team < team_count:
			zone_counts[zone.controlling_team] += 1
	for t in team_count:
		if zone_counts[t] > 0:
			_add_score(t, zone_counts[t] * SCORE_PER_ZONE)

func _check_win_condition() -> void:
	for i in team_count:
		if team_scores[i] >= score_limit:
			GameManager.end_match(i)
			return

@rpc("authority", "call_local", "reliable")
func _sync_zone_captured(zone_id: int, team_id: int) -> void:
	EventBus.zone_captured.emit(zone_id, team_id)
