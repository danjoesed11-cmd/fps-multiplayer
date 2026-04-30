class_name Shop
extends CanvasLayer

@onready var coin_label: Label = %CoinLabel
@onready var weapon_grid: GridContainer = %WeaponGrid
@onready var upgrade_panel: VBoxContainer = %UpgradePanel
@onready var feedback_label: Label = %FeedbackLabel
@onready var close_button: Button = %CloseButton

const SHOP_ITEM_SCENE := "res://scenes/economy/ShopItem.tscn"

var _my_id: int = 0
var _catalog: Dictionary = {}

func _ready() -> void:
	_my_id = multiplayer.get_unique_id()
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.purchase_confirmed.connect(_on_purchase_confirmed)
	EventBus.purchase_denied.connect(_on_purchase_denied)
	close_button.pressed.connect(_on_close)
	_load_catalog()
	_populate_weapons()
	_refresh_coins()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _load_catalog() -> void:
	var file := FileAccess.open("res://data/shop_catalog.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_catalog = json.get_data()

func _populate_weapons() -> void:
	for child in weapon_grid.get_children():
		child.queue_free()
	for item_id in _catalog:
		var data: Dictionary = _catalog[item_id]
		if data.get("is_upgrade", false):
			continue
		var item := _create_item(item_id, data)
		weapon_grid.add_child(item)

func _create_item(item_id: String, data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var name_lbl := Label.new()
	name_lbl.text = data.get("name", item_id)
	vbox.add_child(name_lbl)
	var cost_lbl := Label.new()
	cost_lbl.text = "$%d" % data.get("cost", 0)
	vbox.add_child(cost_lbl)
	var btn := Button.new()
	btn.text = "Buy"
	btn.pressed.connect(_on_buy_pressed.bind(item_id, data.get("cost", 0)))
	vbox.add_child(btn)
	return panel

func _populate_upgrades() -> void:
	for child in upgrade_panel.get_children():
		child.queue_free()
	var player := GameManager.get_player_node(_my_id)
	if not player:
		return
	var owned := player.weapon_manager.get_owned_weapon_ids()
	for weapon_id in owned:
		var lbl := Label.new()
		lbl.text = "Upgrades for %s:" % weapon_id
		upgrade_panel.add_child(lbl)
		for lvl in [1, 2, 3]:
			var upgrade_id := "%s:%d" % [weapon_id, lvl]
			var cost_key := "%s_upgrade_%d" % [weapon_id, lvl]
			var data: Dictionary = _catalog.get(cost_key, {})
			if data.is_empty():
				continue
			var btn := Button.new()
			btn.text = "Level %d — $%d" % [lvl, data.get("cost", 0)]
			btn.pressed.connect(_on_buy_pressed.bind(upgrade_id, data.get("cost", 0)))
			upgrade_panel.add_child(btn)

func _refresh_coins() -> void:
	var coins := EconomyManager.get_coins(_my_id)
	coin_label.text = "$%d" % coins

func _on_buy_pressed(item_id: String, cost: int) -> void:
	EconomyManager.request_purchase.rpc_id(1, item_id)

func _on_coins_changed(peer_id: int, new_total: int) -> void:
	if peer_id != _my_id:
		return
	coin_label.text = "$%d" % new_total

func _on_purchase_confirmed(_peer_id: int, item_id: String) -> void:
	feedback_label.text = "Purchased: %s" % item_id
	_refresh_coins()
	_populate_upgrades()

func _on_purchase_denied(_peer_id: int, reason: String) -> void:
	feedback_label.text = "Cannot buy: %s" % reason

func _on_close() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	EventBus.shop_close_requested.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_shop") or event.is_action_pressed("pause"):
		_on_close()
