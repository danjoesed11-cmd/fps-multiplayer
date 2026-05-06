class_name Shop
extends CanvasLayer

@onready var coin_label: Label = %CoinLabel
@onready var weapon_grid: GridContainer = %WeaponGrid
@onready var upgrade_panel: VBoxContainer = %UpgradePanel
@onready var skin_panel: VBoxContainer = %SkinPanel
@onready var feedback_label: Label = %FeedbackLabel
@onready var close_button: Button = %CloseButton
@onready var tab_container: TabContainer = %TabContainer

const WEAPON_CATALOG_PATH := "res://data/weapon_catalog.json"
const SHOP_CATALOG_PATH := "res://data/shop_catalog.json"
const CHARACTER_CATALOG_PATH := "res://data/character_catalog.json"

var _my_id: int = 0
var _shop_catalog: Dictionary = {}
var _weapon_catalog: Dictionary = {}
var _char_catalog: Dictionary = {}

func _ready() -> void:
	_my_id = multiplayer.get_unique_id()
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.purchase_confirmed.connect(_on_purchase_confirmed)
	EventBus.purchase_denied.connect(_on_purchase_denied)
	close_button.pressed.connect(_on_close)
	tab_container.tab_changed.connect(_on_tab_changed)
	_load_catalogs()
	_populate_weapons()
	_populate_upgrades()
	_populate_skins()
	_refresh_coins()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _load_catalogs() -> void:
	var file := FileAccess.open(SHOP_CATALOG_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_shop_catalog = json.get_data()
	file = FileAccess.open(WEAPON_CATALOG_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_weapon_catalog = json.get_data()
	file = FileAccess.open(CHARACTER_CATALOG_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_char_catalog = json.get_data()

func _populate_weapons() -> void:
	for child in weapon_grid.get_children():
		child.queue_free()
	for item_id in _shop_catalog:
		var data: Dictionary = _shop_catalog[item_id]
		if data.get("is_upgrade", false):
			continue
		var weapon_info: Dictionary = _weapon_catalog.get(item_id, {})
		var card := _make_weapon_card(item_id, data, weapon_info)
		weapon_grid.add_child(card)

func _make_weapon_card(item_id: String, shop_data: Dictionary, weapon_data: Dictionary) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.18, 1)
	sb.border_width_left = 3
	sb.border_color = Color(0.3, 0.6, 1.0, 1)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(160, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = shop_data.get("name", item_id)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = weapon_data.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# Quick stats from tier 0
	var dmg_arr: Array = weapon_data.get("damage", [])
	var rng_arr: Array = weapon_data.get("range", [])
	if dmg_arr.size() > 0:
		var stats_lbl := Label.new()
		stats_lbl.text = "DMG %d  RNG %dm" % [int(dmg_arr[0]), int(rng_arr[0]) if rng_arr.size() > 0 else 0]
		stats_lbl.add_theme_font_size_override("font_size", 11)
		stats_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1))
		vbox.add_child(stats_lbl)

	var sep := HSeparator.new()
	sep.modulate.a = 0.3
	vbox.add_child(sep)

	var row := HBoxContainer.new()
	vbox.add_child(row)

	var cost_lbl := Label.new()
	cost_lbl.text = "$%d" % shop_data.get("cost", 0)
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_lbl.add_theme_font_size_override("font_size", 16)
	cost_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.1, 1))
	row.add_child(cost_lbl)

	var btn := Button.new()
	btn.text = "BUY"
	btn.custom_minimum_size = Vector2(50, 28)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_buy_pressed.bind(item_id, shop_data.get("cost", 0)))
	_style_buy_button(btn)
	row.add_child(btn)

	return card

func _style_buy_button(btn: Button) -> void:
	for state in [["normal", Color(0.15, 0.6, 0.25)], ["hover", Color(0.2, 0.8, 0.35)], ["pressed", Color(0.1, 0.4, 0.2)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = state[1]
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_right = 6
		sb.corner_radius_bottom_left = 6
		btn.add_theme_stylebox_override(state[0], sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))

func _populate_upgrades() -> void:
	for child in upgrade_panel.get_children():
		child.queue_free()

	var player := GameManager.get_player_node(_my_id)
	if not player:
		var no_player_lbl := Label.new()
		no_player_lbl.text = "No player found"
		upgrade_panel.add_child(no_player_lbl)
		return

	var owned: Array = player.weapon_manager.get_owned_weapon_ids()
	if owned.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No weapons to upgrade yet"
		empty_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		upgrade_panel.add_child(empty_lbl)
		return

	for weapon_id in owned:
		var header := Label.new()
		header.text = _weapon_catalog.get(weapon_id, {}).get("name", weapon_id).to_upper()
		header.add_theme_font_size_override("font_size", 14)
		header.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1))
		upgrade_panel.add_child(header)

		for lvl in [1, 2]:
			var upgrade_key := "%s_upgrade_%d" % [weapon_id, lvl]
			var data: Dictionary = _shop_catalog.get(upgrade_key, {})
			if data.is_empty():
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			upgrade_panel.add_child(row)

			var lbl := Label.new()
			lbl.text = "Level %d" % (lvl + 1)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.add_theme_font_size_override("font_size", 13)
			row.add_child(lbl)

			var cost_lbl := Label.new()
			cost_lbl.text = "$%d" % data.get("cost", 0)
			cost_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.1, 1))
			row.add_child(cost_lbl)

			var btn := Button.new()
			btn.text = "Upgrade"
			var upgrade_id := "%s:%d" % [weapon_id, lvl]
			btn.pressed.connect(_on_buy_pressed.bind(upgrade_id, data.get("cost", 0)))
			_style_buy_button(btn)
			row.add_child(btn)

		var sep := HSeparator.new()
		sep.modulate.a = 0.3
		upgrade_panel.add_child(sep)

func _populate_skins() -> void:
	for child in skin_panel.get_children():
		child.queue_free()

	var pts: int = SettingsManager.get_setting("cosmetic_points", 0)
	var pts_lbl := Label.new()
	pts_lbl.text = "⭐ %d pts  (earn 500 pts per match win)" % pts
	pts_lbl.add_theme_font_size_override("font_size", 14)
	pts_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 1))
	skin_panel.add_child(pts_lbl)

	var sep := HSeparator.new()
	sep.modulate.a = 0.3
	skin_panel.add_child(sep)

	var slots := ["body", "head", "kill_fx"]
	var slot_labels := {"body": "Body Skin", "head": "Headgear", "kill_fx": "Kill Effect"}

	for slot in slots:
		var section := Label.new()
		section.text = slot_labels.get(slot, slot).to_upper()
		section.add_theme_font_size_override("font_size", 11)
		section.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0, 1))
		skin_panel.add_child(section)

		var equipped: String = SettingsManager.get_setting("cosmetic_%s" % slot, "")
		for item_id in _char_catalog:
			var data: Dictionary = _char_catalog[item_id]
			if data.get("slot", "") != slot:
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			skin_panel.add_child(row)

			var name_lbl := Label.new()
			name_lbl.text = data.get("name", item_id)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.add_theme_font_size_override("font_size", 13)
			if item_id == equipped:
				name_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1))
				name_lbl.text += "  ✓"
			row.add_child(name_lbl)

			var cost: int = data.get("cost", 0)
			if cost == 0:
				var free_lbl := Label.new()
				free_lbl.text = "FREE"
				free_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
				free_lbl.add_theme_font_size_override("font_size", 12)
				row.add_child(free_lbl)
			else:
				var cost_lbl := Label.new()
				cost_lbl.text = "%d pts" % cost
				cost_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 1))
				cost_lbl.add_theme_font_size_override("font_size", 12)
				row.add_child(cost_lbl)

			var btn := Button.new()
			btn.text = "Equip" if (cost == 0 or pts >= cost) else "Need pts"
			btn.custom_minimum_size = Vector2(70, 28)
			btn.disabled = (cost > 0 and pts < cost)
			_style_buy_button(btn)
			btn.pressed.connect(_on_skin_equip.bind(slot, item_id, cost))
			row.add_child(btn)

		var sep2 := HSeparator.new()
		sep2.modulate.a = 0.2
		skin_panel.add_child(sep2)

func _on_skin_equip(slot: String, item_id: String, cost: int) -> void:
	var pts: int = SettingsManager.get_setting("cosmetic_points", 0)
	if cost > 0 and pts < cost:
		feedback_label.text = "Not enough points (need %d, have %d)" % [cost, pts]
		feedback_label.modulate = Color(1.0, 0.4, 0.3, 1)
		return
	if cost > 0:
		SettingsManager.set_setting("cosmetic_points", pts - cost)
	SettingsManager.set_setting("cosmetic_%s" % slot, item_id)
	feedback_label.text = "Equipped %s!" % item_id.replace("_", " ")
	feedback_label.modulate = Color(0.3, 1.0, 0.4, 1)
	_populate_skins()

func _on_tab_changed(tab: int) -> void:
	if tab == 1:
		_populate_upgrades()
	elif tab == 2:
		_populate_skins()

func _refresh_coins() -> void:
	var coins := EconomyManager.get_coins(_my_id)
	coin_label.text = "$%d" % coins

func _on_buy_pressed(item_id: String, _cost: int) -> void:
	EconomyManager.request_purchase.rpc_id(1, item_id)

func _on_coins_changed(peer_id: int, new_total: int) -> void:
	if peer_id != _my_id:
		return
	coin_label.text = "$%d" % new_total

func _on_purchase_confirmed(_peer_id: int, item_id: String) -> void:
	feedback_label.text = "Purchased: %s" % item_id
	feedback_label.modulate = Color(0.3, 1.0, 0.4, 1)
	_refresh_coins()
	_populate_upgrades()

func _on_purchase_denied(_peer_id: int, reason: String) -> void:
	var msg := "Not enough coins" if reason == "insufficient_funds" else "Cannot buy: %s" % reason
	feedback_label.text = msg
	feedback_label.modulate = Color(1.0, 0.4, 0.3, 1)

func _on_close() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	EventBus.shop_close_requested.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_just_pressed("open_shop") or event.is_action_just_pressed("ui_cancel"):
		_on_close()
