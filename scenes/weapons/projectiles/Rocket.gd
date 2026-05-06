extends Area3D

var direction: Vector3 = Vector3.FORWARD
var owner_id: int = 0
var damage: float = 80.0
var blast_radius: float = 6.0
const SPEED := 35.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta

func _on_body_entered(_body: Node) -> void:
	_explode()

func _explode() -> void:
	var pos := global_position
	_spawn_explosion_fx(pos)

	var space := get_world_3d().direct_space_state
	var sphere := PhysicsShapeQueryParameters3D.new()
	sphere.shape = SphereShape3D.new()
	(sphere.shape as SphereShape3D).radius = blast_radius
	sphere.transform.origin = pos
	var hits := space.intersect_shape(sphere)
	for hit in hits:
		var node: Node = hit.collider
		while node and not node is Player:
			node = node.get_parent()
		if node is Player:
			var dist := pos.distance_to((node as Player).global_position)
			var falloff := clampf(1.0 - dist / blast_radius, 0.1, 1.0)
			(node as Player).take_damage(damage * falloff, owner_id, "rocket_launcher")
	queue_free()

func _spawn_explosion_fx(pos: Vector3) -> void:
	var fx := Node3D.new()
	get_tree().root.add_child(fx)
	fx.global_position = pos

	# Central fireball
	var fireball := MeshInstance3D.new()
	fireball.mesh = SphereMesh.new()
	(fireball.mesh as SphereMesh).radius = blast_radius * 0.55
	(fireball.mesh as SphereMesh).height = blast_radius * 1.1
	(fireball.mesh as SphereMesh).radial_segments = 16
	(fireball.mesh as SphereMesh).rings = 8
	var fb_mat := StandardMaterial3D.new()
	fb_mat.albedo_color = Color(1.0, 0.55, 0.1, 0.9)
	fb_mat.emission_enabled = true
	fb_mat.emission = Color(1.0, 0.3, 0.0)
	fb_mat.emission_energy_multiplier = 12.0
	fb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fb_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fireball.material_override = fb_mat
	fx.add_child(fireball)

	# Shockwave ring expanding outward
	var ring := MeshInstance3D.new()
	ring.mesh = CylinderMesh.new()
	(ring.mesh as CylinderMesh).top_radius = 0.4
	(ring.mesh as CylinderMesh).bottom_radius = 0.4
	(ring.mesh as CylinderMesh).height = 0.5
	(ring.mesh as CylinderMesh).radial_segments = 32
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.75, 0.2, 0.9)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.55, 0.1)
	ring_mat.emission_energy_multiplier = 8.0
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = ring_mat
	fx.add_child(ring)

	# Animate: fireball expands and fades, ring expands faster
	var tw := fx.create_tween()
	tw.tween_property(fireball, "scale", Vector3(2.2, 2.2, 2.2), 0.4).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fb_mat, "albedo_color:a", 0.0, 0.5)
	tw.parallel().tween_property(ring, "scale", Vector3(blast_radius * 0.45, 0.12, blast_radius * 0.45), 0.4).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(fx.queue_free)

	# Flying debris chunks
	for i in 8:
		var chunk := MeshInstance3D.new()
		chunk.mesh = BoxMesh.new()
		(chunk.mesh as BoxMesh).size = Vector3(
			randf_range(0.08, 0.28), randf_range(0.08, 0.28), randf_range(0.08, 0.28))
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color(0.7, 0.35, 0.1, 1.0)
		cm.emission_enabled = true
		cm.emission = Color(1.0, 0.45, 0.1)
		cm.emission_energy_multiplier = 5.0
		cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		chunk.material_override = cm
		get_tree().root.add_child(chunk)
		chunk.global_position = pos + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.5), randf_range(-0.5, 0.5))
		var angle := i * TAU / 8.0 + randf_range(-0.4, 0.4)
		var dist  := blast_radius * randf_range(0.5, 1.1)
		var end   := pos + Vector3(cos(angle) * dist, randf_range(1.0, 4.5), sin(angle) * dist)
		var ctw   := chunk.create_tween()
		ctw.tween_property(chunk, "global_position", end, 0.65).set_ease(Tween.EASE_OUT)
		ctw.parallel().tween_property(cm, "albedo_color:a", 0.0, 0.75)
		ctw.tween_callback(chunk.queue_free)
