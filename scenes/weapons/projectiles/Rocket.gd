class_name Rocket
extends Area3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 30.0
var damage: float = 120.0
var blast_radius: float = 6.0
var owner_id: int = 0
var _lifetime: float = 5.0

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_lifetime -= delta
	if _lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	_explode()

func _explode() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	query.shape = sphere
	query.transform = global_transform
	var results := space.intersect_shape(query)
	for result in results:
		var node := result.collider
		while node and not node is Player:
			node = node.get_parent()
		if node is Player:
			var p := node as Player
			var dist := global_position.distance_to(p.global_position)
			var falloff := 1.0 - clampf(dist / blast_radius, 0.0, 1.0)
			p.take_damage(damage * falloff, owner_id, "rocket_launcher")
	queue_free()
