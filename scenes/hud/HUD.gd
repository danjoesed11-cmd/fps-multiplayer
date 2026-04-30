class_name HUD
extends CanvasLayer

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var ammo_current: Label = %AmmoCurrent
@onready var ammo_reserve: Label = %AmmoReserve
@onready var coin_label: Label = %CoinLabel
@onready var match_timer_label: Label = %MatchTimer
@onready var team0_score: Label = %Team0Score
@onready var team1_score: Label = %Team1Score
@onready var kill_feed_root: VBoxContainer = %KillFeed
@onready var crosshair: Control = %Crosshair
@onready var scoreboard: Control = %Scoreboard
@onready var hit_indicator: Control = %HitIndicator
@onready var low_health_overlay: Control = %LowHealthOverlay

const KILL_FEED_ENTRY_SCENE := "res://scenes/hud/KillFeedEntry.tscn"
const MAX_KILL_FEED := 5
const KILL_FEED_DURATION := 4.0

var _hit_flash_timer: float = 0.0
var _my_id: int = 0

func _ready() -> void:
	_my_id = multiplayer.get_unique_id()
	EventBus.ammo_changed.connect(_on_ammo_changed)
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.match_state_changed.connect(_on_match_state_changed)
	scoreboard.hide()
	hit_indicator.hide()
	low_health_overlay.modulate.a = 0.0

	# Connect to local player health
	await get_tree().process_frame
	_find_local_player()

func _find_local_player() -> void:
	var player := GameManager.get_player_node(_my_id)
	if player:
		_on_ammo_changed(_my_id, 30, 90)
		_on_coins_changed(_my_id, 0)

func _process(delta: float) -> void:
	if _hit_flash_timer > 0:
		_hit_flash_timer -= delta
		hit_indicator.modulate.a = _hit_flash_timer / 0.3
		if _hit_flash_timer <= 0:
			hit_indicator.hide()

	var player := GameManager.get_player_node(_my_id)
	if player:
		var hp_ratio: float = player.health / player.max_health
		health_bar.value = hp_ratio * 100.0
		health_label.text = str(int(player.health))
		low_health_overlay.modulate.a = max(0.0, 0.4 - hp_ratio * 0.8)

	if Input.is_action_just_pressed("scoreboard"):
		scoreboard.show()
	elif Input.is_action_just_released("scoreboard"):
		scoreboard.hide()

func add_kill_feed_entry(killer: String, victim: String, weapon_id: String) -> void:
	if not ResourceLoader.exists(KILL_FEED_ENTRY_SCENE):
		_add_simple_kill_feed(killer, victim)
		return
	var entry: Node = load(KILL_FEED_ENTRY_SCENE).instantiate()
	kill_feed_root.add_child(entry)
	if entry.has_method("setup"):
		entry.setup(killer, victim, weapon_id)
	while kill_feed_root.get_child_count() > MAX_KILL_FEED:
		kill_feed_root.get_child(0).queue_free()
	var tween := create_tween()
	tween.tween_interval(KILL_FEED_DURATION)
	tween.tween_callback(func(): if is_instance_valid(entry): entry.queue_free())

func _add_simple_kill_feed(killer: String, victim: String) -> void:
	var lbl := Label.new()
	lbl.text = "%s zapped %s" % [killer, victim]
	kill_feed_root.add_child(lbl)
	while kill_feed_root.get_child_count() > MAX_KILL_FEED:
		kill_feed_root.get_child(0).queue_free()
	var tween := create_tween()
	tween.tween_interval(KILL_FEED_DURATION)
	tween.tween_callback(func(): if is_instance_valid(lbl): lbl.queue_free())

func _on_ammo_changed(peer_id: int, current: int, reserve: int) -> void:
	if peer_id != _my_id:
		return
	ammo_current.text = str(current)
	ammo_reserve.text = str(reserve)

func _on_coins_changed(peer_id: int, total: int) -> void:
	if peer_id != _my_id:
		return
	coin_label.text = "$%d" % total

func _on_player_damaged(victim_id: int, _attacker_id: int, _amount: float) -> void:
	if victim_id != _my_id:
		return
	_hit_flash_timer = 0.3
	hit_indicator.show()

func _on_score_changed(_team_id: int, _score: int) -> void:
	if GameManager.current_mode_node:
		var scores: Array = GameManager.current_mode_node.team_scores
		if scores.size() >= 2:
			team0_score.text = str(scores[0])
			team1_score.text = str(scores[1])

func _on_match_state_changed(state: int) -> void:
	pass
