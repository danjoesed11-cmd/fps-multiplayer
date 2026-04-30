extends WeaponBase

func _ready() -> void:
	super._ready()

func _execute_fire() -> void:
	if weapon_data:
		weapon_data.headshot_multiplier = 3.0
	super._execute_fire()
