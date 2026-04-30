extends WeaponBase

const ROCKET_SCENE := "res://scenes/weapons/projectiles/Rocket.tscn"
const BLAST_RADIUS := 6.0
const BLAST_DAMAGE_FALLOFF := true

func _execute_fire() -> void:
	var cam := _get_player_camera()
	if not cam:
		return
	if not ResourceLoader.exists(ROCKET_SCENE):
		return
	var rocket := load(ROCKET_SCENE).instantiate()
	get_tree().root.add_child(rocket)
	if muzzle_point:
		rocket.global_position = muzzle_point.global_position
	else:
		rocket.global_position = cam.global_position
	rocket.direction = -cam.global_transform.basis.z
	rocket.owner_id = _owner_id
	rocket.blast_radius = BLAST_RADIUS
	if weapon_data:
		rocket.damage = _get_stat("damage")
