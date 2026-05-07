class_name Player
extends CharacterBody3D

const SPEED := 6.0
const SPRINT_SPEED := 9.0
const CROUCH_SPEED := 3.0
const JUMP_VELOCITY := 14.0
const GRAVITY := -20.0
const RESPAWN_INVINCIBLE_TIME := 2.0

@export var peer_id: int = 1

var health: float = 100.0
var max_health: float = 100.0
var team_id: int = -1
var is_alive: bool = true
var _invincible_timer: float = 0.0

@onready var camera_mount: Node3D = $CameraMount
@onready var player_camera: Camera3D = $CameraMount/PlayerCamera
@onready var weapon_holder: Node3D = $CameraMount/PlayerCamera/WeaponHolder
@onready var weapon_manager: Node = $WeaponManager
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var player_body: Node3D = $PlayerBody
var network_sync: MultiplayerSynchronizer = null

var _camera_pitch: float = 0.0
var _is_crouching: bool = false
var _is_sprinting: bool = false

func _ready() -> void:
	network_sync = get_node_or_null("NetworkSynchronizer")
	set_multiplayer_authority(peer_id)

	var info := PlayerRegistry.get_info(peer_id)
	if info:
		team_id = info.team_id

	_populate_player_body()

	if is_multiplayer_authority():
		player_camera.current = true
		_capture_mouse()
		_apply_camera_mode(SettingsManager.get_setting("camera_mode", "fps"))
		SettingsManager.setting_changed.connect(_on_setting_changed)
	else:
		player_camera.current = false
		player_body.show()

	weapon_manager.initialize(peer_id, is_multiplayer_authority())

func _populate_player_body() -> void:
	for child in player_body.get_children():
		child.queue_free()

	var body_color := Color(0.05, 0.25, 0.75) if team_id == 0 else Color(0.85, 0.12, 0.05)

	var torso := MeshInstance3D.new()
	torso.name = "BodyMesh"
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.32
	torso_mesh.height = 1.55
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 0.78, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = body_color
	bmat.emission_enabled = true
	bmat.emission = body_color
	bmat.emission_energy_multiplier = 0.5
	torso.material_override = bmat
	player_body.add_child(torso)

	var head := MeshInstance3D.new()
	head.name = "HeadMesh"
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.52, 0.52, 0.52)
	head.mesh = head_mesh
	head.position = Vector3(0, 1.72, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.9, 0.75, 0.6)
	head.material_override = hmat
	player_body.add_child(head)

	player_body.hide()

func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "camera_mode":
		_apply_camera_mode(value)
	elif key == "mouse_sensitivity":
		pass
	elif key == "fov":
		player_camera.fov = float(value)

func _apply_camera_mode(mode: String) -> void:
	match mode:
		"fps":
			player_camera.position = Vector3.ZERO
			player_camera.rotation_degrees = Vector3.ZERO
			weapon_holder.show()
			player_body.hide()
		"tps":
			player_camera.position = Vector3(0, 0.8, 3.2)
			player_camera.rotation_degrees = Vector3(-20, 0, 0)
			weapon_holder.hide()
			player_body.show()
		"far":
			player_camera.position = Vector3(0, 1.5, 6.5)
			player_camera.rotation_degrees = Vector3(-15, 0, 0)
			weapon_holder.hide()
			player_body.show()

func _physics_process(delta: float) -> void:
	if _invincible_timer > 0:
		_invincible_timer -= delta

	if not is_multiplayer_authority() or not is_alive:
		return

	_handle_gravity(delta)
	_handle_movement()
	_handle_jump()
	move_and_slide()

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func _handle_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	_is_sprinting = Input.is_action_pressed("sprint") and input_dir.y < 0
	_is_crouching = Input.is_action_pressed("crouch")

	var speed: float
	if _is_crouching:
		speed = CROUCH_SPEED
	elif _is_sprinting:
		speed = SPRINT_SPEED
	else:
		speed = SPEED

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event.is_action_pressed("pause"):
		return

	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			_capture_mouse()
			return

	if not is_alive:
		return

	# V key cycles FPS → TPS → Far → FPS
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		var modes := ["fps", "tps", "far"]
		var cur: String = SettingsManager.get_setting("camera_mode", "fps")
		var idx := modes.find(cur)
		var next: String = modes[(idx + 1) % modes.size()]
		SettingsManager.set_setting("camera_mode", next)
		_apply_camera_mode(next)  # direct call in case signal chain is slow

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sens := SettingsManager.get_sensitivity()
		rotate_y(-event.relative.x * sens)
		_camera_pitch = clamp(_camera_pitch - event.relative.y * sens, -1.4, 1.4)
		camera_mount.rotation.x = _camera_pitch

func take_damage(amount: float, attacker_id: int, weapon_id: String) -> void:
	if not multiplayer.is_server() and multiplayer.get_unique_id() != 1:
		return
	if not is_alive or _invincible_timer > 0:
		return

	health = maxf(health - amount, 0.0)
	_sync_health.rpc(health)
	EventBus.player_damaged.emit(peer_id, attacker_id, amount)

	if health <= 0:
		_die(attacker_id, weapon_id)

func _die(killer_id: int, weapon_id: String) -> void:
	is_alive = false
	_sync_death.rpc(killer_id, weapon_id)

	var killer_name := PlayerRegistry.get_display_name(killer_id)
	var victim_name := PlayerRegistry.get_display_name(peer_id)
	EventBus.player_killed.emit(peer_id, killer_id, weapon_id)
	EventBus.kill_feed_entry.emit(killer_name, victim_name, weapon_id)

	var info := PlayerRegistry.get_info(killer_id)
	if info:
		info.kills += 1
	var victim_info := PlayerRegistry.get_info(peer_id)
	if victim_info:
		victim_info.deaths += 1

	await get_tree().create_timer(3.0).timeout
	if multiplayer.is_server():
		var mode := GameManager.current_mode_node
		var blocked: bool = mode != null and mode.has_method("prevents_respawn") and mode.prevents_respawn()
		if not blocked:
			GameManager.respawn_player(peer_id)

func server_respawn(spawn_position: Vector3) -> void:
	if not multiplayer.is_server():
		return
	health = max_health
	is_alive = true
	_force_respawn.rpc(spawn_position)
	EventBus.player_respawned.emit(peer_id)

@rpc("authority", "call_local", "unreliable_ordered")
func _sync_health(new_health: float) -> void:
	health = new_health

@rpc("authority", "call_local", "reliable")
func _sync_death(killer_id: int, weapon_id: String) -> void:
	is_alive = false
	_spawn_death_fx(global_position)
	hide()
	player_body.hide()
	if is_multiplayer_authority():
		_on_local_death()

func _on_local_death() -> void:
	pass

func _spawn_death_fx(pos: Vector3) -> void:
	var root := get_tree().root
	var fx := Node3D.new()
	root.add_child(fx)
	fx.global_position = pos + Vector3.UP * 0.8

	var flash := MeshInstance3D.new()
	flash.mesh = SphereMesh.new()
	(flash.mesh as SphereMesh).radius = 0.5
	(flash.mesh as SphereMesh).height = 1.0
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1, 1, 0.6, 0.9)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1, 1, 0.4, 1)
	flash_mat.emission_energy_multiplier = 8.0
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = flash_mat
	fx.add_child(flash)

	var star_colors: Array[Color] = [Color(1, 0.2, 0.8), Color(0.2, 1.0, 0.4), Color(1, 0.9, 0.1), Color(0.3, 0.8, 1.0)]
	for i in 8:
		var star := MeshInstance3D.new()
		root.add_child(star)
		star.global_position = pos + Vector3.UP * 0.8
		var sm := SphereMesh.new()
		sm.radius = randf_range(0.12, 0.25)
		sm.height = sm.radius * 2
		star.mesh = sm
		var sc: Color = star_colors[i % star_colors.size()]
		var smat := StandardMaterial3D.new()
		smat.albedo_color = sc
		smat.emission_enabled = true
		smat.emission = sc
		smat.emission_energy_multiplier = 6.0
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		star.material_override = smat
		var angle := i * TAU / 8.0
		var dist := randf_range(1.2, 2.2)
		var end_pos := pos + Vector3.UP * randf_range(0.5, 2.0) + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var tw := star.create_tween()
		tw.tween_property(star, "global_position", end_pos, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(smat, "albedo_color:a", 0.0, 0.5)
		tw.tween_callback(star.queue_free)

	for i in 3:
		var bone := MeshInstance3D.new()
		root.add_child(bone)
		bone.global_position = pos + Vector3.UP * (0.6 + i * 0.5)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.06, randf_range(0.6, 1.0))
		bone.mesh = bm
		bone.rotation.y = randf() * TAU
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(1, 1, 1, 1)
		bmat.emission_enabled = true
		bmat.emission = Color(0.8, 0.8, 1.0, 1)
		bmat.emission_energy_multiplier = 3.0
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bone.material_override = bmat
		var tw2 := bone.create_tween()
		tw2.tween_property(bone, "global_position:y", bone.global_position.y + randf_range(1.0, 2.5), 0.6).set_ease(Tween.EASE_OUT)
		tw2.parallel().tween_property(bone, "scale", Vector3(1.5, 1.5, 1.5), 0.3)
		tw2.parallel().tween_property(bmat, "albedo_color:a", 0.0, 0.7)
		tw2.tween_callback(bone.queue_free)

	for i in 6:
		var arc := MeshInstance3D.new()
		root.add_child(arc)
		arc.global_position = pos + Vector3.UP * randf_range(0.3, 1.5)
		var am := BoxMesh.new()
		am.size = Vector3(0.03, 0.03, randf_range(0.8, 1.8))
		arc.mesh = am
		arc.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.3, 0.3))
		var amat := StandardMaterial3D.new()
		amat.albedo_color = Color(0.5, 0.8, 1.0, 1)
		amat.emission_enabled = true
		amat.emission = Color(0.4, 0.7, 1.0, 1)
		amat.emission_energy_multiplier = 12.0
		amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		arc.material_override = amat
		var tw3 := arc.create_tween()
		tw3.tween_property(arc, "scale", Vector3(2.0, 2.0, 2.0), 0.2)
		tw3.parallel().tween_property(amat, "albedo_color:a", 0.0, 0.35)
		tw3.tween_callback(arc.queue_free)

	var ftw := flash.create_tween()
	ftw.tween_property(flash, "scale", Vector3(3, 3, 3), 0.25).set_ease(Tween.EASE_OUT)
	ftw.parallel().tween_property(flash_mat, "albedo_color:a", 0.0, 0.3)
	ftw.tween_callback(fx.queue_free)

@rpc("authority", "call_local", "reliable")
func _force_respawn(spawn_pos: Vector3) -> void:
	is_alive = true
	health = max_health
	global_position = spawn_pos
	show()
	if is_multiplayer_authority():
		var mode_str: String = SettingsManager.get_setting("camera_mode", "fps")
		if mode_str != "fps":
			player_body.show()
	else:
		player_body.show()
	_invincible_timer = RESPAWN_INVINCIBLE_TIME
	if is_multiplayer_authority():
		weapon_manager.reset_weapons()
