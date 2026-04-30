class_name Arena01
extends MapBase

# Palette — vivid neon colours used throughout the map
const C_FLOOR    := Color(0.10, 0.08, 0.28)   # deep indigo floor
const C_TRIM     := Color(0.90, 0.20, 0.90)   # magenta trim strips
const C_BASE0    := Color(0.10, 0.55, 1.00)   # blue team base
const C_BASE1    := Color(1.00, 0.42, 0.10)   # orange team base
const C_CENTRAL  := Color(0.15, 0.85, 0.65)   # teal central platform
const C_BRIDGE   := Color(0.95, 0.90, 0.20)   # yellow bridges
const C_PILLAR_A := Color(0.95, 0.25, 0.45)   # pink pillars
const C_PILLAR_B := Color(0.25, 0.95, 0.55)   # green pillars
const C_WALL     := Color(0.20, 0.15, 0.50)   # dark purple boundary walls
const C_SIDE_PLT := Color(0.85, 0.35, 0.90)   # purple side platforms
const C_RAMP     := Color(0.40, 0.40, 0.90)   # periwinkle ramps
const C_COVER_A  := Color(0.95, 0.70, 0.10)   # gold cover boxes
const C_COVER_B  := Color(0.10, 0.75, 0.90)   # cyan cover boxes
const C_GRID     := Color(0.14, 0.12, 0.38)   # subtle grid accent tiles

func _ready() -> void:
	map_id       = "arena01"
	display_name = "Neon Nexus"
	supported_modes = ["tdm", "ctf", "zone_wars", "wipeout"]
	_build_map()

func _build_map() -> void:
	# ── Floor ──────────────────────────────────────────────────
	_add_platform(Vector3(0, -0.5, 0), Vector3(90, 1, 90), C_FLOOR)

	# Coloured accent strips criss-crossing the floor
	for i in range(-4, 5):
		_add_platform(Vector3(i * 9.0, 0.01, 0), Vector3(0.4, 0.02, 90), C_TRIM)
		_add_platform(Vector3(0, 0.01, i * 9.0), Vector3(90, 0.02, 0.4), C_TRIM)

	# ── Boundary walls ─────────────────────────────────────────
	_add_platform(Vector3(0,  5, -45.5), Vector3(91, 10, 1), C_WALL)
	_add_platform(Vector3(0,  5,  45.5), Vector3(91, 10, 1), C_WALL)
	_add_platform(Vector3(-45.5, 5, 0), Vector3(1, 10, 91), C_WALL)
	_add_platform(Vector3( 45.5, 5, 0), Vector3(1, 10, 91), C_WALL)

	# ── Team bases (raised, team-coloured) ─────────────────────
	# Blue base — northwest
	_add_platform(Vector3(-28, 1.5, -28), Vector3(22, 3, 22), C_BASE0)
	_add_platform(Vector3(-28, 3.1, -28), Vector3(22, 0.2, 22), Color(0.5, 0.8, 1.0)) # top accent
	# Orange base — southeast
	_add_platform(Vector3( 28, 1.5,  28), Vector3(22, 3, 22), C_BASE1)
	_add_platform(Vector3( 28, 3.1,  28), Vector3(22, 0.2, 22), Color(1.0, 0.65, 0.3)) # top accent

	# Ramps from floor up to each base
	_add_ramp(Vector3(-17, 1.5, -20), Vector3(5, 3, 10), C_RAMP, 0.0)
	_add_ramp(Vector3(-20, 1.5, -17), Vector3(10, 3, 5), C_RAMP, 0.0)
	_add_ramp(Vector3( 17, 1.5,  20), Vector3(5, 3, 10), C_RAMP, 0.0)
	_add_ramp(Vector3( 20, 1.5,  17), Vector3(10, 3, 5), C_RAMP, 0.0)

	# ── Central elevated platform ───────────────────────────────
	_add_platform(Vector3(0, 3, 0), Vector3(18, 6, 18), C_CENTRAL)
	_add_platform(Vector3(0, 6.1, 0), Vector3(18, 0.2, 18), Color(0.3, 1.0, 0.8)) # top surface

	# Steps up to centre from all 4 sides
	for rot in [0.0, PI * 0.5, PI, PI * 1.5]:
		_add_tilted_ramp(Vector3(0, 3, 12), Vector3(8, 6, 6), C_RAMP, rot)

	# ── Yellow bridges (floor → central) ───────────────────────
	_add_platform(Vector3(0, 2.9, 24), Vector3(6, 0.5, 12), C_BRIDGE)
	_add_platform(Vector3(0, 2.9, -24), Vector3(6, 0.5, 12), C_BRIDGE)
	_add_platform(Vector3(24, 2.9, 0), Vector3(12, 0.5, 6), C_BRIDGE)
	_add_platform(Vector3(-24, 2.9, 0), Vector3(12, 0.5, 6), C_BRIDGE)

	# Bridge guard rails
	for z_off in [3.5, -3.5]:
		_add_platform(Vector3(0,  4.3, 24 + z_off * 0.0), Vector3(6, 1.5, 0.3), C_BRIDGE)
	_add_platform(Vector3( 2.8, 4.3, 24), Vector3(0.3, 1.5, 12), C_BRIDGE)
	_add_platform(Vector3(-2.8, 4.3, 24), Vector3(0.3, 1.5, 12), C_BRIDGE)
	_add_platform(Vector3( 2.8, 4.3, -24), Vector3(0.3, 1.5, 12), C_BRIDGE)
	_add_platform(Vector3(-2.8, 4.3, -24), Vector3(0.3, 1.5, 12), C_BRIDGE)
	_add_platform(Vector3(24,  4.3,  2.8), Vector3(12, 1.5, 0.3), C_BRIDGE)
	_add_platform(Vector3(24,  4.3, -2.8), Vector3(12, 1.5, 0.3), C_BRIDGE)
	_add_platform(Vector3(-24, 4.3,  2.8), Vector3(12, 1.5, 0.3), C_BRIDGE)
	_add_platform(Vector3(-24, 4.3, -2.8), Vector3(12, 1.5, 0.3), C_BRIDGE)

	# ── Side platforms (east / west, purple) ───────────────────
	_add_platform(Vector3( 35, 1.5,  0), Vector3(12, 3, 20), C_SIDE_PLT)
	_add_platform(Vector3(-35, 1.5,  0), Vector3(12, 3, 20), C_SIDE_PLT)
	# Access ramps
	_add_ramp(Vector3( 29, 1.5, 0), Vector3(6, 3, 8), C_RAMP, 0.0)
	_add_ramp(Vector3(-29, 1.5, 0), Vector3(6, 3, 8), C_RAMP, 0.0)

	# ── Colourful pillars (scattered) ──────────────────────────
	var pillar_spots := [
		Vector3(-12,  0, -12), Vector3( 12,  0,  12),
		Vector3(-12,  0,  12), Vector3( 12,  0, -12),
		Vector3( -6,  0, -22), Vector3(  6,  0,  22),
		Vector3(-22,  0,   6), Vector3( 22,  0,  -6),
	]
	for i in pillar_spots.size():
		var col := C_PILLAR_A if i % 2 == 0 else C_PILLAR_B
		_add_pillar(pillar_spots[i] + Vector3(0, 3, 0), 6.0, 1.0, col)

	# ── Low cover boxes (scattered mid-field) ──────────────────
	var covers := [
		[Vector3(-8, 0.6, 0),   Vector3(5, 1.2, 2)],
		[Vector3( 8, 0.6, 0),   Vector3(5, 1.2, 2)],
		[Vector3( 0, 0.6, -10), Vector3(2, 1.2, 5)],
		[Vector3( 0, 0.6,  10), Vector3(2, 1.2, 5)],
		[Vector3(-18, 0.6, 8),  Vector3(4, 1.2, 2)],
		[Vector3( 18, 0.6,-8),  Vector3(4, 1.2, 2)],
		[Vector3(-5, 0.6, 20),  Vector3(3, 1.2, 3)],
		[Vector3( 5, 0.6,-20),  Vector3(3, 1.2, 3)],
	]
	for i in covers.size():
		var col := C_COVER_A if i % 2 == 0 else C_COVER_B
		_add_platform(covers[i][0], covers[i][1] as Vector3, col)

	# ── Floating decoration cubes above the central platform ───
	var deco := [
		[Vector3(-6, 8.5, -6), Color(1.0, 0.3, 0.6)],
		[Vector3( 6, 8.5,  6), Color(0.3, 1.0, 0.5)],
		[Vector3( 6, 8.5, -6), Color(0.3, 0.5, 1.0)],
		[Vector3(-6, 8.5,  6), Color(1.0, 0.85, 0.2)],
	]
	for d in deco:
		_add_platform(d[0] as Vector3, Vector3(2.5, 2.5, 2.5), d[1] as Color)

# ── Builders ───────────────────────────────────────────────────

func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.55
	mat.metallic     = 0.15
	return mat

func _add_platform(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos

	var mesh_i := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh_i.mesh = bm
	mesh_i.material_override = _make_material(color)
	body.add_child(mesh_i)

	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)

	add_child(body)
	return body

func _add_ramp(pos: Vector3, size: Vector3, color: Color, _rot_y: float) -> StaticBody3D:
	# Wedge ramp using a tilted box
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.x = -0.45   # ~26° incline

	var mesh_i := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh_i.mesh = bm
	mesh_i.material_override = _make_material(color)
	body.add_child(mesh_i)

	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)

	add_child(body)
	return body

func _add_tilted_ramp(pos: Vector3, size: Vector3, color: Color, rot_y: float) -> StaticBody3D:
	var body := _add_ramp(pos, size, color, 0.0)
	body.rotation.y = rot_y
	body.position = Vector3(
		sin(rot_y) * pos.z + cos(rot_y) * pos.x,
		pos.y,
		cos(rot_y) * pos.z - sin(rot_y) * pos.x
	)
	return body

func _add_pillar(pos: Vector3, height: float, radius: float, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos

	var mesh_i := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.height        = height
	cm.top_radius    = radius
	cm.bottom_radius = radius
	mesh_i.mesh = cm
	mesh_i.material_override = _make_material(color)
	body.add_child(mesh_i)

	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.height = height
	cs.radius = radius
	col.shape = cs
	body.add_child(col)

	add_child(body)
	return body
