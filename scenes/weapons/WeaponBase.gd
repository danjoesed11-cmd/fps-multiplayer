class_name WeaponBase
extends Node3D

@export var weapon_data: WeaponData

var current_ammo: int = 30
var reserve_ammo: int = 90
var is_reloading: bool = false
var upgrade_level: int = 0
var _fire_cooldown: float = 0.0
var _owner_id: int = 0
var _is_local: bool = false

var _damage: float = 25.0
var _fire_rate: float = 0.12
var _range: float = 150.0
var _spread: float = 0.03

@onready var muzzle_point: Marker3D = $MuzzlePoint
@onready var muzzle_flash: GPUParticles3D = $MuzzleFlash
@onready var reload_timer: Timer = $ReloadTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

signal fired()
signal reloaded()
signal ammo_changed(current: int, reserve: int)

func _ready() -> void:
	if weapon_data:
		apply_upgrade(upgrade_level)
	if reload_timer:
		reload_timer.timeout.connect(_finish_reload)

func setup(owner_id: int, is_local: bool) -> void:
	_owner_id = owner_id
	_is_local = is_local
	if weapon_data:
		apply_upgrade(upgrade_level)

func _process(delta: float) -> void:
	if _fire_cooldown > 0:
		_fire_cooldown -= delta

func attempt_fire() -> void:
	if not _is_local:
		return
	if _fire_cooldown > 0 or is_reloading or current_ammo <= 0:
		if current_ammo <= 0 and not is_reloading:
			reload()
		return

	_fire_cooldown = _get_stat("fire_rate")
	current_ammo -= 1
	ammo_changed.emit(current_ammo, reserve_ammo)
	EventBus.ammo_changed.emit(_owner_id, current_ammo, reserve_ammo)

	_execute_fire()
	rpc_play_fire_fx.rpc()
	fired.emit()

func _execute_fire() -> void:
	if not weapon_data:
		return
	var cam := _get_player_camera()
	if not cam:
		return

	if weapon_data.is_hitscan:
		_hitscan_fire(cam)
	else:
		_projectile_fire(cam)

func _hitscan_fire(cam: Camera3D) -> void:
	var spread := _get_stat("spread")
	var direction := -cam.global_transform.basis.z
	direction += Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))
	direction = direction.normalized()

	var from := muzzle_point.global_position if muzzle_point else cam.global_position
	var to := from + direction * _get_stat("range")

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_parent().get_parent()]
	var result := space.intersect_ray(query)

	if result and multiplayer.is_server():
		var collider := result.collider
		# Walk up to find a Player node
		var node := collider
		while node and not node is Player:
			node = node.get_parent()
		if node is Player:
			var victim := node as Player
			var base_damage := _get_stat("damage")
			var hit_pos: Vector3 = result.position
			# Headshot check via group
			var is_headshot := collider.is_in_group("head_hitbox")
			var final_damage := base_damage * (weapon_data.headshot_multiplier if is_headshot else 1.0)
			victim.take_damage(final_damage, _owner_id, weapon_data.weapon_id if weapon_data else "unknown")

func _projectile_fire(_cam: Camera3D) -> void:
	pass

func reload() -> void:
	if is_reloading or reserve_ammo <= 0:
		return
	if current_ammo == _get_stat("magazine") as int:
		return
	is_reloading = true
	if animation_player and animation_player.has_animation("reload"):
		animation_player.play("reload")
	if reload_timer:
		reload_timer.start(1.8)

func _finish_reload() -> void:
	var mag := _get_stat("magazine") as int
	var needed := mag - current_ammo
	var take := mini(needed, reserve_ammo)
	current_ammo += take
	reserve_ammo -= take
	is_reloading = false
	ammo_changed.emit(current_ammo, reserve_ammo)
	EventBus.ammo_changed.emit(_owner_id, current_ammo, reserve_ammo)
	reloaded.emit()

func apply_upgrade(level: int) -> void:
	upgrade_level = level
	if not weapon_data:
		return
	var stats := weapon_data.get_tier(level)
	_damage = stats["damage"]
	_fire_rate = stats["fire_rate"]
	_range = stats["range"]
	_spread = stats["spread"]
	current_ammo = stats["magazine"] as int
	reserve_ammo = stats["reserve"] as int

func reset_ammo() -> void:
	if weapon_data:
		var stats := weapon_data.get_tier(upgrade_level)
		current_ammo = stats["magazine"] as int
		reserve_ammo = stats["reserve"] as int
	ammo_changed.emit(current_ammo, reserve_ammo)

func equip() -> void:
	show()
	if animation_player and animation_player.has_animation("equip"):
		animation_player.play("equip")
	EventBus.ammo_changed.emit(_owner_id, current_ammo, reserve_ammo)

func unequip() -> void:
	if animation_player and animation_player.has_animation("unequip"):
		animation_player.play("unequip")
	else:
		hide()

func _get_stat(key: String) -> float:
	match key:
		"damage": return _damage
		"fire_rate": return _fire_rate
		"range": return _range
		"spread": return _spread
		"magazine": return weapon_data.get_tier(upgrade_level)["magazine"] if weapon_data else 30
	return 0.0

func _get_player_camera() -> Camera3D:
	var p := get_parent()
	while p:
		if p is Camera3D:
			return p as Camera3D
		if p.has_method("get"):
			var cam = p.get("player_camera")
			if cam is Camera3D:
				return cam
		p = p.get_parent()
	return get_viewport().get_camera_3d()

@rpc("any_peer", "call_local", "unreliable")
func rpc_play_fire_fx() -> void:
	if muzzle_flash:
		muzzle_flash.restart()
	if animation_player and animation_player.has_animation("fire"):
		animation_player.play("fire")
