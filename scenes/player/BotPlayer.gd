class_name BotPlayer
extends Player

const THINK_INTERVAL   := 0.25
const ATTACK_RANGE     := 18.0
const WANDER_RANGE     := 12.0
const BOT_SPEED        := 3.0

const ENEMY_FIRE_INTERVAL   := 0.9    # extra delay between shots for enemy bots
const FRIENDLY_FIRE_INTERVAL := 0.4
const ENEMY_DAMAGE_MULT     := 0.42   # enemy bots deal 42% of normal weapon damage
const HIT_IMMUNITY_SECS     := 0.65   # seconds enemy bots are immune after being hit

var _target: Player = null
var _think_timer: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _nav_agent: NavigationAgent3D = null

var _bot_fire_timer: float = 0.0
var _strafe_dir: int = 1
var _strafe_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _hit_immunity_timer: float = 0.0

@onready var bot_body: MeshInstance3D = $BotBody
@onready var bot_head: MeshInstance3D = $BotHead

func _ready() -> void:
	name = str(peer_id)
	set_multiplayer_authority(1)
	player_camera.current = false
	if has_node("NavigationAgent3D"):
		_nav_agent = $NavigationAgent3D
	_wander_target = global_position + Vector3(
		randf_range(-WANDER_RANGE, WANDER_RANGE), 0,
		randf_range(-WANDER_RANGE, WANDER_RANGE))
	weapon_manager.initialize(peer_id, true)
	_apply_team_colors()
	if team_id == 1:
		# Nerf enemy bot damage after weapon manager sets up
		await get_tree().process_frame
		var wm: WeaponBase = weapon_manager.get_current_weapon()
		if wm:
			wm.damage_multiplier = ENEMY_DAMAGE_MULT

func _apply_team_colors() -> void:
	var body_col: Color
	var head_col: Color
	if team_id == 0:
		body_col = Color(0.05, 0.25, 0.75, 1)  # dark blue
		head_col = Color(0.35, 0.75, 1.0, 1)   # light blue
	else:
		body_col = Color(0.85, 0.12, 0.05, 1)  # red
		head_col = Color(1.0, 0.42, 0.0, 1)    # orange
	_tint_mesh(bot_body, body_col, 0.5)
	_tint_mesh(bot_head, head_col, 0.6)

func _tint_mesh(mesh: MeshInstance3D, color: Color, emission: float) -> void:
	if not mesh:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission
	mesh.material_override = mat

func take_damage(amount: float, attacker_id: int, weapon_id: String) -> void:
	if team_id == 1 and _hit_immunity_timer > 0:
		return  # enemy bot is briefly immune after last hit
	super.take_damage(amount, attacker_id, weapon_id)
	if team_id == 1 and is_alive:
		_hit_immunity_timer = HIT_IMMUNITY_SECS

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_think_timer -= delta
	_bot_fire_timer -= delta
	_strafe_timer -= delta
	if team_id == 1:
		_hit_immunity_timer -= delta

	if _think_timer <= 0:
		_think_timer = THINK_INTERVAL
		_find_target()
		if _strafe_timer <= 0:
			_strafe_dir = 1 if randf() > 0.5 else -1
			_strafe_timer = randf_range(0.8, 2.4)

	_handle_gravity(delta)
	_smart_move(delta)
	move_and_slide()

	if _target and is_instance_valid(_target) and _target.is_alive:
		var dist := global_position.distance_to(_target.global_position)
		if dist < ATTACK_RANGE:
			_aim_at_target()
			_try_fire()

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

func _try_fire() -> void:
	if _bot_fire_timer > 0:
		return
	var wm: WeaponBase = weapon_manager.get_current_weapon()
	if wm:
		wm.attempt_fire()
	var interval := ENEMY_FIRE_INTERVAL if team_id == 1 else FRIENDLY_FIRE_INTERVAL
	_bot_fire_timer = interval

func _smart_move(delta: float) -> void:
	# Stuck detection: if barely moving, jump and pick a new destination
	if _last_pos.distance_to(global_position) < 0.04:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
	_last_pos = global_position

	if _stuck_timer > 0.75:
		_stuck_timer = 0.0
		if is_on_floor():
			velocity.y = JUMP_VELOCITY * 0.8
		_wander_target = global_position + Vector3(
			randf_range(-WANDER_RANGE, WANDER_RANGE), 0,
			randf_range(-WANDER_RANGE, WANDER_RANGE))

	var move_dir := Vector3.ZERO

	if _target and is_instance_valid(_target) and _target.is_alive:
		var dist := global_position.distance_to(_target.global_position)
		var flat := (_target.global_position - global_position)
		flat.y = 0
		var to_target := flat.normalized()

		if dist > ATTACK_RANGE * 0.65:
			move_dir = to_target           # close in on target
		elif dist < ATTACK_RANGE * 0.25:
			move_dir = -to_target          # back up if too close

		# Lateral strafe while in attack range
		if dist < ATTACK_RANGE:
			var strafe := to_target.cross(Vector3.UP) * _strafe_dir
			move_dir = (move_dir + strafe * 0.8).normalized()
	else:
		# Wander to random destination
		var to_wander := _wander_target - global_position
		to_wander.y = 0
		if to_wander.length() < 2.0:
			_wander_target = global_position + Vector3(
				randf_range(-WANDER_RANGE, WANDER_RANGE), 0,
				randf_range(-WANDER_RANGE, WANDER_RANGE))
		else:
			move_dir = to_wander.normalized()

	# Wall avoidance — cast short ray forward, slide off wall normal
	if move_dir.length() > 0.1:
		var space := get_world_3d().direct_space_state
		var origin := global_position + Vector3.UP * 0.6
		var ray := PhysicsRayQueryParameters3D.create(origin, origin + move_dir * 1.8)
		ray.exclude = [get_rid()]
		var hit := space.intersect_ray(ray)
		if hit and not (hit.collider is Player):
			var wall_n: Vector3 = hit.normal
			wall_n.y = 0
			if wall_n.length() > 0.01:
				var slid := move_dir.slide(wall_n)
				if slid.length() > 0.1:
					move_dir = slid.normalized()
				else:
					_strafe_dir = -_strafe_dir
					move_dir = move_dir.reflect(wall_n).normalized()

	if move_dir.length() > 0.1:
		move_dir = move_dir.normalized()
		velocity.x = move_dir.x * BOT_SPEED
		velocity.z = move_dir.z * BOT_SPEED
		var look_dir := Transform3D().looking_at(move_dir, Vector3.UP)
		rotation.y = look_dir.basis.get_euler().y
	else:
		velocity.x = move_toward(velocity.x, 0, BOT_SPEED)
		velocity.z = move_toward(velocity.z, 0, BOT_SPEED)

func _aim_at_target() -> void:
	if not _target:
		return
	var aim_pos := _target.global_position + Vector3.UP * 1.3
	# Enemy bots have aim inaccuracy — add slight jitter toward player's general area
	if team_id == 1:
		aim_pos += Vector3(
			randf_range(-0.5, 0.5),
			randf_range(-0.25, 0.25),
			randf_range(-0.5, 0.5))
	var dir := (aim_pos - camera_mount.global_position).normalized()
	camera_mount.rotation.x = -asin(clamp(dir.y, -1.0, 1.0))
	rotation.y = atan2(-dir.x, -dir.z)
