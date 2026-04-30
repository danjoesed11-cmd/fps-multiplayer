class_name PlayerBody
extends Node3D

@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var head_mesh: MeshInstance3D = $HeadMesh

var _skin_cache: Dictionary = {}

func apply_cosmetics(cosmetics: Dictionary) -> void:
	_apply_slot("body", cosmetics.get("body", "body_default"))
	_apply_slot("head", cosmetics.get("head", "head_default"))

func _apply_slot(slot: String, item_id: String) -> void:
	var path := "res://resources/characters/%s.tres" % item_id
	if not ResourceLoader.exists(path):
		return
	var data: Resource = _skin_cache.get(item_id)
	if not data:
		data = load(path)
		_skin_cache[item_id] = data
	match slot:
		"body":
			if data.get("mesh_override") and body_mesh:
				body_mesh.mesh = data.mesh_override
			if data.get("material_override") and body_mesh:
				body_mesh.set_surface_override_material(0, data.material_override)
		"head":
			if data.get("mesh_override") and head_mesh:
				head_mesh.mesh = data.mesh_override
