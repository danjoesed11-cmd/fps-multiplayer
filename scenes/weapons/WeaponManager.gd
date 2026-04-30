class_name WeaponManager
extends Node

const WEAPON_CATALOG_PATH := "res://data/weapon_catalog.json"
const MAX_SLOTS := 3

var _slots: Array = [null, null, null]
var _current_slot: int = 0
var _owner_id: int = 0
var _is_local: bool = false
var _weapon_holder: Node3D = null
var _owned_weapon_ids: Array[String] = []
var _catalog: Dictionary = {}

func initialize(owner_id: int, is_local: bool) -> void:
	_owner_id = owner_id
	_is_local = is_local
	_load_catalog()

	# Find weapon holder in the tree
	var player := get_parent()
	var cam_mount := player.get_node_or_null("CameraMount")
	if cam_mount:
		var cam := cam_mount.get_node_or_null("PlayerCamera")
		if cam:
			_weapon_holder = cam.get_node_or_null("WeaponHolder")

	if _is_local:
		_equip_starter_weapons()
		EventBus.purchase_confirmed.connect(_on_purchase_confirmed)

func _load_catalog() -> void:
	var file := FileAccess.open(WEAPON_CATALOG_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_catalog = json.get_data()

func _equip_starter_weapons() -> void:
	for weapon_id in _catalog:
		var data: Dictionary = _catalog[weapon_id]
		if data.get("is_starter", false):
			_give_weapon(weapon_id, 0)
	_switch_to_slot(0)

func _give_weapon(weapon_id: String, slot: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	var existing = _slots[slot]
	if existing and is_instance_valid(existing):
		existing.queue_free()

	var data: Dictionary = _catalog.get(weapon_id, {})
	var scene_path: String = data.get("scene_path", "")
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("WeaponManager: scene not found for %s" % weapon_id)
		return

	var scene := load(scene_path) as PackedScene
	var weapon := scene.instantiate() as WeaponBase
	weapon.setup(_owner_id, _is_local)

	if _weapon_holder:
		_weapon_holder.add_child(weapon)
	else:
		add_child(weapon)

	_slots[slot] = weapon
	if weapon_id not in _owned_weapon_ids:
		_owned_weapon_ids.append(weapon_id)
	weapon.hide()

func _switch_to_slot(slot: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	var current_weapon = _slots[_current_slot]
	if current_weapon and is_instance_valid(current_weapon):
		current_weapon.unequip()
		await get_tree().create_timer(0.15).timeout

	_current_slot = slot
	var next_weapon = _slots[slot]
	if next_weapon and is_instance_valid(next_weapon):
		next_weapon.equip()
		var weapon_id := _get_weapon_id(next_weapon)
		EventBus.weapon_switched.emit(_owner_id, weapon_id)

func _process(_delta: float) -> void:
	if not _is_local:
		return
	if Input.is_action_just_pressed("weapon_slot_1"):
		_switch_to_slot(0)
	elif Input.is_action_just_pressed("weapon_slot_2"):
		_switch_to_slot(1)
	elif Input.is_action_just_pressed("weapon_slot_3"):
		_switch_to_slot(2)
	elif Input.is_action_pressed("fire"):
		var w := get_current_weapon()
		if w:
			w.attempt_fire()
	elif Input.is_action_just_pressed("reload"):
		var w := get_current_weapon()
		if w:
			w.reload()

func get_current_weapon() -> WeaponBase:
	var w = _slots[_current_slot]
	if w and is_instance_valid(w):
		return w
	return null

func reset_weapons() -> void:
	for i in MAX_SLOTS:
		var w = _slots[i]
		if w and is_instance_valid(w):
			w.reset_ammo()

func _on_purchase_confirmed(peer_id: int, item_id: String) -> void:
	if peer_id != _owner_id:
		return
	if ":" in item_id:
		var parts := item_id.split(":")
		var weapon_id := parts[0]
		var level := int(parts[1])
		for i in MAX_SLOTS:
			var w = _slots[i]
			if w and is_instance_valid(w):
				if _get_weapon_id(w) == weapon_id:
					w.apply_upgrade(level)
					EventBus.weapon_upgraded.emit(peer_id, weapon_id, level)
					return
	else:
		var data: Dictionary = _catalog.get(item_id, {})
		var slot: int = data.get("slot", _find_empty_slot())
		_give_weapon(item_id, slot)
		_switch_to_slot(slot)

func _find_empty_slot() -> int:
	for i in MAX_SLOTS:
		if _slots[i] == null:
			return i
	return MAX_SLOTS - 1

func _get_weapon_id(weapon: WeaponBase) -> String:
	if weapon.weapon_data:
		return weapon.weapon_data.weapon_id
	return ""

func get_owned_weapon_ids() -> Array[String]:
	return _owned_weapon_ids
