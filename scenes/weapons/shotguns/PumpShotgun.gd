extends WeaponBase

const PELLET_COUNT := 8

func _execute_fire() -> void:
	if not weapon_data:
		return
	var cam := _get_player_camera()
	if not cam:
		return
	for i in PELLET_COUNT:
		_hitscan_fire(cam)
