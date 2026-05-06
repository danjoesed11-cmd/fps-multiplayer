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
var _fire_fx_handled: bool = false

var _damage: float = 25.0
var _fire_rate: float = 0.12
var _range: float = 150.0
var _spread: float = 0.03
var _last_hit_pos: Vector3 = Vector3.ZERO
var damage_multiplier: float = 1.0  # set on bot weapons to nerf damage

const PAINTBALL_COLORS: Array[Color] = [
	Color(1.0, 0.1, 0.8, 1),
	Color(0.1, 1.0, 0.9, 1),
	Color(0.6, 0.0, 1.0, 1),
	Color(1.0, 0.8, 0.0, 1),
	Color(0.0, 1.0, 0.3, 1),
	Color(1.0, 0.4, 0.0, 1),
]

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

	var muzzle_pos := muzzle_point.global_position if muzzle_point else global_position
	_last_hit_pos = muzzle_pos + (-global_transform.basis.z * _get_stat("range"))
	_fire_fx_handled = false
	_execute_fire()

	if not _fire_fx_handled:
		var paint_color := PAINTBALL_COLORS[randi() % PAINTBALL_COLORS.size()]
		rpc_play_fire_fx.rpc(_last_hit_pos, paint_color)
	fired.emit()

func _execute_fire() -> void:
	var cam := _get_player_camera()
	if not cam:
		return
	var is_hitscan := weapon_data.is_hitscan if weapon_data else true
	if is_hitscan:
		_hitscan_fire(cam)
	else:
		_projectile_fire(cam)

func _get_player_body_rid() -> RID:
	var p := get_parent()
	while p:
		if p is CharacterBody3D:
			return (p as CharacterBody3D).get_rid()
		p = p.get_parent()
	return RID()

func _hitscan_fire(cam: Camera3D) -> void:
	var spread := _get_stat("spread")
	var direction := -cam.global_transform.basis.z
	direction += Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))
	direction = direction.normalized()

	var from := muzzle_point.global_position if muzzle_point else cam.global_position
	var to := from + direction * _get_stat("range")
	_last_hit_pos = to

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var body_rid := _get_player_body_rid()
	if body_rid.is_valid():
		query.exclude = [body_rid]

	var result := space.intersect_ray(query)
	if result:
		_last_hit_pos = result.position
		var is_authority := multiplayer.is_server() or multiplayer.get_unique_id() == 1
		if is_authority:
			var node: Node = result.collider as Node
			while node and not node is Player:
				node = node.get_parent()
			if node is Player:
				var victim := node as Player
				var is_headshot: bool = (result.collider as Node).is_in_group("head_hitbox")
				var headshot_mult := weapon_data.headshot_multiplier if (weapon_data and is_headshot) else 1.0
				victim.take_damage(_get_stat("damage") * headshot_mult * damage_multiplier, _owner_id,
					weapon_data.weapon_id if weapon_data else "unknown")

func _projectile_fire(_cam: Camera3D) -> void:
	pass

func reload() -> void:
	if is_reloading or current_ammo == _get_stat("magazine") as int:
		return
	if reserve_ammo <= 0:
		if _owner_id < 0:
			reserve_ammo = _get_stat("magazine") as int * 10
		else:
			return
	is_reloading = true
	if animation_player and animation_player.has_animation("reload"):
		animation_player.play("reload")
	if reload_timer:
		reload_timer.start(1.8)

func _finish_reload() -> void:
	var mag := _get_stat("magazine") as int
	if _owner_id < 0:
		current_ammo = mag
		reserve_ammo = mag * 10
	else:
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
func rpc_play_fire_fx(hit_pos: Vector3, paint_color: Color) -> void:
	if muzzle_flash:
		muzzle_flash.restart()
	if animation_player and animation_player.has_animation("fire"):
		animation_player.play("fire")
	var muzzle_pos := muzzle_point.global_position if muzzle_point else global_position
	_spawn_tracer(muzzle_pos, hit_pos, paint_color)

func _spawn_tracer(from: Vector3, to: Vector3, color: Color) -> void:
	var tracer := Node3D.new()
	get_tree().root.add_child(tracer)
	tracer.global_position = from

	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 10.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	tracer.add_child(mesh_inst)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 5.0
	light.omni_range = 4.0
	tracer.add_child(light)

	var travel_time := maxf(from.distance_to(to) / 50.0, 0.1)
	var tw := tracer.create_tween()
	tw.tween_property(tracer, "global_position", to, travel_time)
	tw.tween_callback(func():
		_spawn_splat(to, color)
		tracer.queue_free()
	)

func _spawn_splat(pos: Vector3, color: Color) -> void:
	for i in 6:
		var dot := MeshInstance3D.new()
		get_tree().root.add_child(dot)
		dot.global_position = pos
		var sphere := SphereMesh.new()
		sphere.radius = randf_range(0.08, 0.18)
		dot.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 6.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dot.material_override = mat

		var end_pos := pos + Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.3), randf_range(-0.6, 0.6))
		var tw := dot.create_tween()
		tw.tween_property(dot, "global_position", end_pos, 0.3)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
		tw.tween_callback(dot.queue_free)
