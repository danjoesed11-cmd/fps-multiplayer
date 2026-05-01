class_name Player
extends CharacterBody3D

const SPEED := 6.0
const SPRINT_SPEED := 9.0
const CROUCH_SPEED := 3.0
const JUMP_VELOCITY := 9.0
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
@onready var network_sync: MultiplayerSynchronizer = $NetworkSynchronizer

var _camera_pitch: float = 0.0
var _is_crouching: bool = false
var _is_sprinting: bool = false

func _ready() -> void:
	set_multiplayer_authority(peer_id)
	if is_multiplayer_authority():
		player_camera.current = true
		_capture_mouse()
	else:
		player_camera.current = false

	var info := PlayerRegistry.get_info(peer_id)
	if info:
		team_id = info.team_id

	weapon_manager.initialize(peer_id, is_multiplayer_authority())

func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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

	# Escape releases / re-captures the mouse
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			_capture_mouse()
		return

	# Any click re-captures the mouse when it was released
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			_capture_mouse()
			return   # don't fire on the recapture click

	if not is_alive:
		return

	# Mouse look — only when captured
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sens := SettingsManager.get_sensitivity()
		rotate_y(-event.relative.x * sens)
		_camera_pitch = clamp(_camera_pitch - event.relative.y * sens, -1.4, 1.4)
		camera_mount.rotation.x = _camera_pitch

func take_damage(amount: float, attacker_id: int, weapon_id: String) -> void:
	if not multiplayer.is_server():
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
	if is_multiplayer_authority():
		_on_local_death()

func _on_local_death() -> void:
	pass

@rpc("authority", "call_local", "reliable")
func _force_respawn(spawn_pos: Vector3) -> void:
	is_alive = true
	health = max_health
	global_position = spawn_pos
	_invincible_timer = RESPAWN_INVINCIBLE_TIME
	if is_multiplayer_authority():
		weapon_manager.reset_weapons()
