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

func _on_body_entered(body: Node) -> void:
	_explode()

func _explode() -> void:
	var pos := global_position
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
