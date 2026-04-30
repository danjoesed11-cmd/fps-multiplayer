class_name WeaponData
extends Resource

@export var weapon_id: String = ""
@export var display_name: String = ""
@export var scene_path: String = ""
@export var icon_path: String = ""
@export var purchase_cost: int = 0
@export var is_hitscan: bool = true
@export var headshot_multiplier: float = 2.0
@export var is_starter: bool = false

@export var damage_per_tier: Array[float] = [25.0, 30.0, 38.0]
@export var fire_rate_per_tier: Array[float] = [0.12, 0.10, 0.08]
@export var magazine_per_tier: Array[int] = [30, 35, 40]
@export var reserve_per_tier: Array[int] = [90, 105, 120]
@export var range_per_tier: Array[float] = [150.0, 175.0, 200.0]
@export var spread_per_tier: Array[float] = [0.03, 0.02, 0.01]
@export var upgrade_cost_per_tier: Array[int] = [0, 400, 900]

func get_tier(level: int) -> Dictionary:
	var l := clampi(level, 0, damage_per_tier.size() - 1)
	return {
		"damage": damage_per_tier[l],
		"fire_rate": fire_rate_per_tier[l],
		"magazine": magazine_per_tier[l],
		"reserve": reserve_per_tier[l],
		"range": range_per_tier[l],
		"spread": spread_per_tier[l],
	}

func get_upgrade_cost(next_level: int) -> int:
	if next_level <= 0 or next_level >= upgrade_cost_per_tier.size():
		return -1
	return upgrade_cost_per_tier[next_level]

func max_tier() -> int:
	return damage_per_tier.size() - 1
