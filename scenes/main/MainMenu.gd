class_name MainMenu
extends Control

const CHARACTER_CATALOG_PATH := "res://data/character_catalog.json"

var _name_input: LineEdit
var _ip_input: LineEdit
var _port_input: LineEdit
var _status_label: Label
var _char_catalog: Dictionary = {}
var _skin_feedback: Label
var _root_hbox: HBoxContainer = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_load_catalog()
	_add_waffle_button()
	call_deferred("_build_ui")

func _add_waffle_button() -> void:
	var btn := Button.new()
	btn.text = "Did you eat toaster waffles today?"
	btn.flat = true
	btn.set_anchor_and_offset(SIDE_LEFT,   1.0, -360)
	btn.set_anchor_and_offset(SIDE_RIGHT,  1.0,  -8)
	btn.set_anchor_and_offset(SIDE_TOP,    0.0,   8)
	btn.set_anchor_and_offset(SIDE_BOTTOM, 0.0,  34)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0, 0.5))
	btn.add_theme_color_override("font_hover_color", Color(0.8, 1.0, 1.0, 1.0))
	btn.z_index = 10
	btn.pressed.connect(_open_waffle)
	add_child(btn)

func _load_catalog() -> void:
	var file := FileAccess.open(CHARACTER_CATALOG_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_char_catalog = json.get_data()

# ── UI construction ───────────────────────────────────────────

func _build_ui() -> void:
	_root_hbox = HBoxContainer.new()
	_root_hbox.add_theme_constant_override("separation", 0)
	_root_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root_hbox)

	_build_left_panel(_root_hbox)
	_build_right_panel(_root_hbox)

func _panel_bg(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.content_margin_left   = 36
	sb.content_margin_right  = 36
	sb.content_margin_top    = 32
	sb.content_margin_bottom = 32
	return sb

func _build_left_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.45
	panel.add_theme_stylebox_override("panel", _panel_bg(Color(0.04, 0.01, 0.14, 0.94)))
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "FLASHPOINT NEON ZONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.15, 1))
	title.add_theme_color_override("font_shadow_color", Color(1, 0.4, 0.0, 1))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("shadow_outline_size", 4)
	vbox.add_child(title)

	var tag := Label.new()
	tag.text = "Zap. Capture. Dominate."
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	vbox.add_child(tag)

	vbox.add_child(_sep())

	# Name input
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Your name..."
	_name_input.text = SettingsManager.get_setting("display_name", "Player")
	_name_input.custom_minimum_size = Vector2(0, 44)
	_style_input(_name_input)
	vbox.add_child(_name_input)

	vbox.add_child(_build_account_bar())
	vbox.add_child(_divider("PLAY vs AI"))

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	vbox.add_child(row1)
	var tdm_btn := _mode_btn("Team Deathmatch", Color(1.0, 0.40, 0.0))
	tdm_btn.pressed.connect(func(): _start_ai("tdm"))
	row1.add_child(tdm_btn)
	var wipe_btn := _mode_btn("Elimination", Color(0.65, 0.15, 0.80))
	wipe_btn.pressed.connect(func(): _start_ai("wipeout"))
	row1.add_child(wipe_btn)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	vbox.add_child(row2)
	var zone_btn := _mode_btn("Zone Wars", Color(0.1, 0.6, 0.9))
	zone_btn.pressed.connect(func(): _start_ai("zone_wars"))
	row2.add_child(zone_btn)
	var koth_btn := _mode_btn("King of the Hill", Color(0.9, 0.7, 0.05))
	koth_btn.pressed.connect(func(): _start_ai("koth"))
	row2.add_child(koth_btn)

	var dom_btn := _mode_btn("Domination", Color(0.15, 0.75, 0.45))
	dom_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dom_btn.pressed.connect(func(): _start_ai("domination"))
	vbox.add_child(dom_btn)

	vbox.add_child(_divider("LAN MULTIPLAYER"))

	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 8)
	vbox.add_child(ip_row)
	_ip_input = LineEdit.new()
	_ip_input.placeholder_text = "Host IP (e.g. 192.168.1.5)"
	_ip_input.text = SettingsManager.get_setting("last_ip", "")
	_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_input.custom_minimum_size = Vector2(0, 40)
	_style_input(_ip_input)
	ip_row.add_child(_ip_input)
	_port_input = LineEdit.new()
	_port_input.text = str(NetworkManager.PORT)
	_port_input.custom_minimum_size = Vector2(68, 40)
	_style_input(_port_input)
	ip_row.add_child(_port_input)

	var join_btn := _mode_btn("JOIN LAN GAME", Color(0.15, 0.50, 1.0))
	join_btn.pressed.connect(_on_join)
	vbox.add_child(join_btn)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	# Spacer to push settings/quit to bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	vbox.add_child(_sep())

	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 8)
	vbox.add_child(bot_row)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_btn.flat = true
	settings_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	settings_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.9))
	settings_btn.pressed.connect(func(): UIManager.push_screen("res://scenes/main/SettingsScreen.tscn"))
	bot_row.add_child(settings_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn.flat = true
	quit_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 0.55))
	quit_btn.add_theme_color_override("font_hover_color", Color(1, 0.5, 0.5, 0.9))
	quit_btn.pressed.connect(get_tree().quit)
	bot_row.add_child(quit_btn)

func _build_right_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.55
	panel.add_theme_stylebox_override("panel", _panel_bg(Color(0.03, 0.00, 0.10, 0.96)))
	parent.add_child(panel)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var title := Label.new()
	title.text = "CUSTOMIZE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0, 1))
	outer.add_child(title)

	var pts: int = SettingsManager.get_setting("cosmetic_points", 0)
	var pts_lbl := Label.new()
	pts_lbl.text = "%d pts  (earn 500+ pts per match win)" % pts
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pts_lbl.add_theme_font_size_override("font_size", 12)
	pts_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 0.85))
	outer.add_child(pts_lbl)

	_skin_feedback = Label.new()
	_skin_feedback.text = ""
	_skin_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skin_feedback.add_theme_font_size_override("font_size", 12)
	outer.add_child(_skin_feedback)

	outer.add_child(_sep())

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	for slot_info in [["body", "Body Skin"], ["head", "Headgear"], ["kill_fx", "Kill Effect"]]:
		var slot: String = slot_info[0]
		var slot_label: String = slot_info[1]

		var section_lbl := Label.new()
		section_lbl.text = slot_label.to_upper()
		section_lbl.add_theme_font_size_override("font_size", 11)
		section_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0, 0.8))
		vbox.add_child(section_lbl)

		var equipped: String = SettingsManager.get_setting("cosmetic_%s" % slot, "")
		var items_for_slot: Array = []
		for item_id in _char_catalog:
			var d: Dictionary = _char_catalog[item_id]
			if d.get("slot", "") == slot:
				items_for_slot.append({"id": item_id, "data": d})

		if items_for_slot.is_empty():
			var none_lbl := Label.new()
			none_lbl.text = "No items available"
			none_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
			none_lbl.add_theme_font_size_override("font_size", 11)
			vbox.add_child(none_lbl)
		else:
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			vbox.add_child(grid)
			for item_info in items_for_slot:
				var item_id: String = item_info["id"]
				var data: Dictionary = item_info["data"]
				var cost: int = data.get("cost", 0)
				var pts_val: int = SettingsManager.get_setting("cosmetic_points", 0)
				var is_equipped := (item_id == equipped)
				var can_afford := (cost == 0 or pts_val >= cost)
				grid.add_child(_skin_card(slot, item_id, data, is_equipped, can_afford, pts_lbl))

		var sep2 := HSeparator.new()
		sep2.modulate.a = 0.2
		vbox.add_child(sep2)

func _skin_card(slot: String, item_id: String, data: Dictionary, is_equipped: bool, can_afford: bool, pts_lbl: Label) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.45, 0.85, 0.25) if is_equipped else Color(0.08, 0.08, 0.18, 0.85)
	sb.border_width_left   = 2; sb.border_width_right  = 2
	sb.border_width_top    = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.3, 0.9, 1.0, 0.8) if is_equipped else Color(1, 1, 1, 0.1)
	sb.corner_radius_top_left     = 8; sb.corner_radius_top_right    = 8
	sb.corner_radius_bottom_left  = 8; sb.corner_radius_bottom_right = 8
	sb.content_margin_left  = 10; sb.content_margin_right  = 10
	sb.content_margin_top   = 8;  sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = data.get("name", item_id)
	name_lbl.add_theme_font_size_override("font_size", 12)
	var col := Color(0.3, 1.0, 0.5, 1) if is_equipped else Color(1, 1, 1, 0.9)
	name_lbl.add_theme_color_override("font_color", col)
	if is_equipped:
		name_lbl.text += "  [EQUIPPED]"
	vb.add_child(name_lbl)

	var cost: int = data.get("cost", 0)
	var cost_lbl := Label.new()
	cost_lbl.text = "FREE" if cost == 0 else "%d pts" % cost
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1) if cost == 0 else Color(1, 0.9, 0.2, 0.85))
	vb.add_child(cost_lbl)

	if not is_equipped:
		var btn := Button.new()
		btn.text = "Equip" if can_afford else "Need %d pts" % cost
		btn.disabled = not can_afford
		btn.custom_minimum_size = Vector2(0, 26)
		btn.add_theme_font_size_override("font_size", 11)
		_style_equip_btn(btn, can_afford)
		btn.pressed.connect(_on_equip.bind(slot, item_id, cost, pts_lbl))
		vb.add_child(btn)

	return card

func _on_equip(slot: String, item_id: String, cost: int, pts_lbl: Label) -> void:
	var pts: int = SettingsManager.get_setting("cosmetic_points", 0)
	if cost > 0 and pts < cost:
		_skin_feedback.text = "Not enough points"
		_skin_feedback.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
		return
	if cost > 0:
		SettingsManager.set_setting("cosmetic_points", pts - cost)
	SettingsManager.set_setting("cosmetic_%s" % slot, item_id)
	_skin_feedback.text = "Equipped!"
	_skin_feedback.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	pts_lbl.text = "%d pts  (earn 500+ pts per match win)" % SettingsManager.get_setting("cosmetic_points", 0)
	if _root_hbox and is_instance_valid(_root_hbox):
		_root_hbox.queue_free()
		_root_hbox = null
	_build_ui()

# ── Helpers ───────────────────────────────────────────────────

func _mode_btn(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 48)
	btn.add_theme_font_size_override("font_size", 14)
	for state in [["normal", color], ["hover", color.lightened(0.15)], ["pressed", color.darkened(0.1)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = state[1]
		sb.corner_radius_top_left    = 12; sb.corner_radius_top_right   = 12
		sb.corner_radius_bottom_left = 12; sb.corner_radius_bottom_right= 12
		btn.add_theme_stylebox_override(state[0], sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	return btn

func _style_equip_btn(btn: Button, active: bool) -> void:
	var col := Color(0.2, 0.65, 0.35) if active else Color(0.2, 0.2, 0.2)
	for state in [["normal", col], ["hover", col.lightened(0.1)], ["pressed", col.darkened(0.1)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = state[1]
		sb.corner_radius_top_left    = 6; sb.corner_radius_top_right    = 6
		sb.corner_radius_bottom_left = 6; sb.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override(state[0], sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))

func _style_input(input: LineEdit) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.08)
	sb.border_width_left   = 2; sb.border_width_top    = 2
	sb.border_width_right  = 2; sb.border_width_bottom = 2
	sb.border_color = Color(1, 1, 1, 0.22)
	sb.corner_radius_top_left    = 10; sb.corner_radius_top_right    = 10
	sb.corner_radius_bottom_left = 10; sb.corner_radius_bottom_right = 10
	sb.content_margin_left  = 14; sb.content_margin_top    = 10
	sb.content_margin_right = 14; sb.content_margin_bottom = 10
	input.add_theme_stylebox_override("normal", sb)
	input.add_theme_stylebox_override("focus", sb)
	input.add_theme_color_override("font_color", Color(1, 1, 1))
	input.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.35))
	input.add_theme_font_size_override("font_size", 14)

func _sep() -> HSeparator:
	var sep := HSeparator.new()
	sep.modulate.a = 0.25
	return sep

func _divider(text: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var l1 := HSeparator.new()
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l1.modulate.a = 0.2
	hbox.add_child(l1)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.0, 0.7))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)
	var l2 := HSeparator.new()
	l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l2.modulate.a = 0.2
	hbox.add_child(l2)
	return hbox

# ── Account / social UI ──────────────────────────────────────

func _build_account_bar() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	if not is_instance_valid(AccountManager) or AccountManager == null:
		var lbl := Label.new()
		lbl.text = "Playing as guest"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		row.add_child(lbl)
		return row

	if AccountManager.is_logged_in():
		var name_lbl := Label.new()
		name_lbl.text = "Signed in as  %s" % AccountManager.get_username()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55, 0.9))
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_lbl)

		var friends_btn := _small_btn("Friends", Color(0.1, 0.5, 0.25))
		friends_btn.pressed.connect(_open_friends)
		row.add_child(friends_btn)

		var acct_btn := _small_btn("Account", Color(0.15, 0.3, 0.7))
		acct_btn.pressed.connect(_open_account)
		row.add_child(acct_btn)
	else:
		var lbl := Label.new()
		lbl.text = "Playing as guest"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lbl)

		var signin_btn := _small_btn("Sign In / Register", Color(0.35, 0.2, 0.65))
		signin_btn.pressed.connect(_open_account)
		row.add_child(signin_btn)

	return row


func _open_account() -> void:
	var panel := load("res://scenes/main/AccountPanel.gd").new()
	panel.closed.connect(func(): _rebuild())
	get_tree().root.add_child(panel)

func _open_friends() -> void:
	if not AccountManager.is_logged_in():
		_open_account()
		return
	var panel := load("res://scenes/main/FriendsPanel.gd").new()
	get_tree().root.add_child(panel)

func _open_waffle() -> void:
	var page := load("res://scenes/main/WafflePage.gd").new()
	get_tree().root.add_child(page)

func _rebuild() -> void:
	if _root_hbox and is_instance_valid(_root_hbox):
		_root_hbox.queue_free()
		_root_hbox = null
	call_deferred("_build_ui")

func _small_btn(text: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_size_override("font_size", 11)
	for state in [["normal", col], ["hover", col.lightened(0.12)], ["pressed", col.darkened(0.1)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = state[1]
		sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
		sb.content_margin_left = 10; sb.content_margin_right = 10
		btn.add_theme_stylebox_override(state[0], sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	return btn

# ── Game start ────────────────────────────────────────────────

func _start_ai(mode_id: String) -> void:
	_save_settings()
	var offline := OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = offline
	PlayerRegistry.request_register(_get_display_name(), SettingsManager.get_cosmetics())
	GameManager.start_match_offline(mode_id, "arena01")

func _on_join() -> void:
	var ip := _ip_input.text.strip_edges()
	if ip.is_empty():
		_show_status("Enter the host's local IP address", Color(1, 0.7, 0.3))
		return
	_save_settings()
	var port := _get_port()
	_show_status("Connecting to %s:%d..." % [ip, port], Color(0.4, 0.9, 1.0))
	NetworkManager.join_server(ip, port)
	NetworkManager.joined_server.connect(_on_connected, CONNECT_ONE_SHOT)
	NetworkManager.connection_failed.connect(_on_failed, CONNECT_ONE_SHOT)

func _on_connected(_id: int) -> void:
	PlayerRegistry.request_register.rpc_id(1, _get_display_name(), SettingsManager.get_cosmetics())
	GameManager.transition_to_lobby()

func _on_failed() -> void:
	_show_status("Connection failed", Color(1, 0.4, 0.3))

func _show_status(msg: String, color: Color) -> void:
	if _status_label:
		_status_label.text = msg
		_status_label.modulate = color

func _get_display_name() -> String:
	if _name_input:
		var n := _name_input.text.strip_edges()
		return n if not n.is_empty() else "Player"
	return "Player"

func _get_port() -> int:
	if _port_input and _port_input.text.is_valid_int():
		return int(_port_input.text)
	return NetworkManager.PORT

func _save_settings() -> void:
	if _name_input:
		var n := _name_input.text.strip_edges()
		if not n.is_empty():
			SettingsManager.set_setting("display_name", n)
	if _ip_input:
		SettingsManager.set_setting("last_ip", _ip_input.text.strip_edges())

