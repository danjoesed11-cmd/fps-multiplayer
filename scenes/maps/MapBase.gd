class_name MapBase
extends Node3D

@export var map_id: String = ""
@export var supported_modes: Array[String] = []
@export var display_name: String = ""

func get_spawn_points(team_id: int) -> Array:
	var node := get_node_or_null("SpawnPoints_Team%d" % team_id)
	if node:
		return node.get_children()
	var fallback := get_node_or_null("SpawnPoints_Team0")
	if fallback:
		return fallback.get_children()
	return []

func get_objective_markers() -> Array:
	var obj_root := get_node_or_null("ObjectivePoints")
	if obj_root:
		return obj_root.get_children()
	return []

func get_buy_zones() -> Array:
	var bz_root := get_node_or_null("BuyZones")
	if bz_root:
		return bz_root.get_children()
	return []

func get_map_bounds() -> AABB:
	return AABB(Vector3(-50, 0, -50), Vector3(100, 30, 100))
