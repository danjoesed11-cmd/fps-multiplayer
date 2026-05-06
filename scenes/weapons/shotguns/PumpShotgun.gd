extends WeaponBase

const PELLET_COUNT := 8

func _execute_fire() -> void:
	if not weapon_data:
		return
	var cam := _get_player_camera()
	if not cam:
		return
	_fire_fx_handled = true
	var muzzle_pos := muzzle_point.global_position if muzzle_point else global_position
	for i in PELLET_COUNT:
		_hitscan_fire(cam)
		rpc_play_fire_fx.rpc(_last_hit_pos, PAINTBALL_COLORS[i % PAINTBALL_COLORS.size()])
