class_name BotPlayer
extends Player

const THINK_INTERVAL        := 0.10
const ATTACK_RANGE          := 45.0
const WANDER_RANGE          := 16.0
const BOT_SPEED             := 5.5

const ENEMY_FIRE_INTERVAL   := 0.35
const FRIENDLY_FIRE_INTERVAL := 0.20
const ENEMY_DAMAGE_MULT     := 0.70
const HIT_IMMUNITY_SECS     := 0.08

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
var _jump_timer: float = 0.0

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
		await get_tree().process_frame
		var wm: WeaponBase = weapon_manager.get_current_weapon()
		if wm:
			wm.damage_multiplier = ENEMY_DAMAGE_MULT

func _apply_team_colors() -> void:
	var body_col: Color
	var head_col: Color
	if team_id == 0:
		body_col = Color(0.05, 0.25, 0.75, 1)
		head_col = Color(0.35, 0.75, 1.0, 1)
	else:
		body_col = Color(0.85, 0.12, 0.05, 1)
		head_col = Color(1.0, 0.42, 0.0, 1)
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
		return
	super.take_damage(amount, attacker_id, weapon_id)
	if team_id == 1 and is_alive:
		_hit_immunity_timer = HIT_IMMUNITY_SECS

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_think_timer      -= delta
	_bot_fire_timer   -= delta
	_strafe_timer     -= delta
	_jump_timer       -= delta
	if team_id == 1:
		_hit_immunity_timer -= delta

	if _think_timer <= 0:
		_think_timer = THINK_INTERVAL
		_find_target()
		if _strafe_timer <= 0:
			_strafe_dir = 1 if randf() > 0.5 else -1
			_strafe_timer = randf_range(0.5, 1.6)

	_handle_gravity(delta)
	_smart_move(delta)
	move_and_slide()

	if _target and is_instance_valid(_target) and _target.is_alive:
		var dist := global_position.distance_to(_target.global_position)
		if dist < ATTACK_RANGE:
			_aim_at_target()
			_try_fire()
			# Random jump to become harder to hit
			if _jump_timer <= 0 and is_on_floor():
				_jump_timer = randf_range(1.8, 3.5)
				if randf() < 0.35:
					velocity.y = JUMP_VELOCITY

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
	if _last_pos.distance_to(global_position) < 0.04:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
	_last_pos = global_position

	if _stuck_timer > 0.6:
		_stuck_timer = 0.0
		if is_on_floor():
			velocity.y = JUMP_VELOCITY * 0.9
		_wander_target = global_position + Vector3(
			randf_range(-WANDER_RANGE, WANDER_RANGE), 0,
			randf_range(-WANDER_RANGE, WANDER_RANGE))

	var move_dir := Vector3.ZERO

	if _target and is_instance_valid(_target) and _target.is_alive:
		var dist := global_position.distance_to(_target.global_position)
		var flat := (_target.global_position - global_position)
		flat.y = 0
		var to_target := flat.normalized()

		var low_hp := health < max_health * 0.25

		if low_hp and dist < ATTACK_RANGE * 0.5:
			move_dir = -to_target   # retreat when badly hurt
		elif dist > ATTACK_RANGE * 0.55:
			move_dir = to_target    # close in
		elif dist < ATTACK_RANGE * 0.18:
			move_dir = -to_target   # back off if too close

		if dist < ATTACK_RANGE:
			var strafe := to_target.cross(Vector3.UP) * _strafe_dir
			move_dir = (move_dir + strafe * 1.1).normalized()
	else:
		var obj_pos := _get_objective_position()
		if obj_pos != Vector3.ZERO:
			var to_obj := obj_pos - global_position
			to_obj.y = 0
			if to_obj.length() > 2.5:
				move_dir = to_obj.normalized()
			else:
				move_dir = Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
		else:
			var to_wander := _wander_target - global_position
			to_wander.y = 0
			if to_wander.length() < 2.0:
				_wander_target = global_position + Vector3(
					randf_range(-WANDER_RANGE, WANDER_RANGE), 0,
					randf_range(-WANDER_RANGE, WANDER_RANGE))
			else:
				move_dir = to_wander.normalized()

	# Wall avoidance
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

func _get_objective_position() -> Vector3:
	var mode := GameManager.current_mode_node
	if not mode:
		return Vector3.ZERO
	var zp = mode.get("zone_pos")
	if zp is Vector3:
		return zp
	return Vector3.ZERO

func _aim_at_target() -> void:
	if not _target:
		return
	var aim_pos := _target.global_position + Vector3.UP * 1.3
	# Lead moving targets based on distance
	if _target is CharacterBody3D:
		var vel: Vector3 = (_target as CharacterBody3D).velocity
		var dist := global_position.distance_to(_target.global_position)
		aim_pos += vel * (dist / 100.0)
	# Enemy bots have slight inaccuracy; friendly bots are spot-on
	if team_id == 1:
		aim_pos += Vector3(
			randf_range(-0.12, 0.12),
			randf_range(-0.08, 0.08),
			randf_range(-0.12, 0.12))
	var dir := (aim_pos - camera_mount.global_position).normalized()
	camera_mount.rotation.x = -asin(clamp(dir.y, -1.0, 1.0))
	rotation.y = atan2(-dir.x, -dir.z)
