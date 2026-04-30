extends Node

var _hud: CanvasLayer = null
var _screen_stack: Array[CanvasLayer] = []

func _ready() -> void:
	EventBus.kill_feed_entry.connect(_on_kill_feed_entry)
	EventBus.shop_open_requested.connect(_on_shop_open_requested)
	EventBus.shop_close_requested.connect(_on_shop_close_requested)

func show_hud() -> void:
	if _hud:
		_hud.queue_free()
	var hud_scene := load("res://scenes/hud/HUD.tscn") as PackedScene
	_hud = hud_scene.instantiate() as CanvasLayer
	get_tree().root.add_child(_hud)
	EventBus.hud_show_requested.emit()

func hide_hud() -> void:
	if _hud:
		_hud.queue_free()
		_hud = null
	EventBus.hud_hide_requested.emit()

func get_hud() -> CanvasLayer:
	return _hud

func push_screen(scene_path: String) -> CanvasLayer:
	var scene := load(scene_path) as PackedScene
	if not scene:
		push_error("UIManager: scene not found: %s" % scene_path)
		return null
	var screen := scene.instantiate() as CanvasLayer
	get_tree().root.add_child(screen)
	_screen_stack.push_back(screen)
	return screen

func pop_screen() -> void:
	if _screen_stack.is_empty():
		return
	var screen: CanvasLayer = _screen_stack.pop_back()
	if is_instance_valid(screen):
		screen.queue_free()

func pop_all_screens() -> void:
	for screen in _screen_stack:
		if is_instance_valid(screen):
			screen.queue_free()
	_screen_stack.clear()

func show_post_match(winner_team: int) -> void:
	var screen := push_screen("res://scenes/main/PostMatch.tscn")
	if screen and screen.has_method("set_winner"):
		screen.set_winner(winner_team)

func show_kill_feed_entry(killer: String, victim: String, weapon_id: String) -> void:
	if _hud and _hud.has_method("add_kill_feed_entry"):
		_hud.add_kill_feed_entry(killer, victim, weapon_id)

func _on_kill_feed_entry(killer_name: String, victim_name: String, weapon_id: String) -> void:
	show_kill_feed_entry(killer_name, victim_name, weapon_id)

func _on_shop_open_requested() -> void:
	for screen in _screen_stack:
		if screen.name == "Shop":
			return
	push_screen("res://scenes/economy/Shop.tscn")

func _on_shop_close_requested() -> void:
	for i in range(_screen_stack.size() - 1, -1, -1):
		if _screen_stack[i].name == "Shop":
			_screen_stack[i].queue_free()
			_screen_stack.remove_at(i)
			return
