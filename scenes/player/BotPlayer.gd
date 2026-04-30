class_name BotPlayer
extends Player

const THINK_INTERVAL := 0.3
const ATTACK_RANGE := 25.0
const WANDER_RANGE := 15.0

var team_id: int = 1
var _target: Player = null
var _think_timer: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _nav_agent: NavigationAgent3D = null

func _ready() -> void:
	# Bots are always authoritative on the server
	set_multiplayer_authority(1)
	player_camera.current = false
	if has_node("NavigationAgent3D"):
		_nav_agent = $NavigationAgent3D
	_wander_target = global_position + Vector3(randf_range(-WANDER_RANGE, WANDER_RANGE), 0, randf_range(-WANDER_RANGE, WANDER_RANGE))
	weapon_manager.initialize(peer_id, true)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	_think_timer -= delta
	if _think_timer <= 0:
		_think_timer = THINK_INTERVAL
		_find_target()

	_handle_gravity(delta)
	_move_towards_goal(delta)
	move_and_slide()

	if _target and is_instance_valid(_target) and _target.is_alive:
		var dist := global_position.distance_to(_target.global_position)
		if dist < ATTACK_RANGE:
			_aim_at_target()
			var wm := weapon_manager.get_current_weapon()
			if wm:
				wm.attempt_fire()

func _find_target() -> void:
	var best_dist := INF
	_target = null
	for node in GameManager.get_all_player_nodes():
		if not node is Player:
			continue
		var p := node as Player
		if p == self or p.team_id == team_id or not p.is_alive:
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			_target = p

func _move_towards_goal(delta: float) -> void:
	var goal: Vector3
	if _target and is_instance_valid(_target) and _target.is_alive:
		goal = _target.global_position
	else:
		goal = _wander_target
		if global_position.distance_to(goal) < 2.0:
			_wander_target = global_position + Vector3(randf_range(-WANDER_RANGE, WANDER_RANGE), 0, randf_range(-WANDER_RANGE, WANDER_RANGE))

	var direction := (goal - global_position).normalized()
	direction.y = 0
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	if direction.length() > 0.1:
		var look_dir := Transform3D().looking_at(direction, Vector3.UP)
		rotation.y = look_dir.basis.get_euler().y

func _aim_at_target() -> void:
	if not _target:
		return
	var dir := (_target.global_position + Vector3.UP * 1.6 - camera_mount.global_position).normalized()
	camera_mount.rotation.x = -asin(dir.y)
	rotation.y = atan2(-dir.x, -dir.z)
