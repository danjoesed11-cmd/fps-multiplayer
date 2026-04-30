extends Node2D

const SHAPE_COUNT := 28

var _shapes: Array = []
var _time: float = 0.0
var _screen: Vector2 = Vector2(1920, 1080)

func _ready() -> void:
	_screen = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_on_resize)
	_spawn_shapes()

func _on_resize() -> void:
	_screen = get_viewport().get_visible_rect().size

func _spawn_shapes() -> void:
	_shapes.clear()
	for i in SHAPE_COUNT:
		_shapes.append({
			"pos":   Vector2(randf() * _screen.x, randf() * _screen.y),
			"vel":   Vector2(randf_range(-18, 18), randf_range(-18, 18)),
			"hue":   float(i) / SHAPE_COUNT,
			"size":  randf_range(55, 185),
			"phase": randf() * TAU,
			"type":  randi() % 4,
			"spin":  randf_range(-0.4, 0.4),
			"angle": randf() * TAU,
		})

func _process(delta: float) -> void:
	_time += delta
	for s in _shapes:
		s.pos  += (s.vel as Vector2) * delta
		s.hue   = fmod((s.hue as float) + delta * 0.04, 1.0)
		s.angle = fmod((s.angle as float) + (s.spin as float) * delta, TAU)
		var p: Vector2 = s.pos
		var sz: float  = s.size
		if p.x < -sz:         s.pos.x = _screen.x + sz
		if p.x > _screen.x + sz: s.pos.x = -sz
		if p.y < -sz:         s.pos.y = _screen.y + sz
		if p.y > _screen.y + sz: s.pos.y = -sz
	queue_redraw()

func _draw() -> void:
	# Soft gradient background
	draw_rect(Rect2(Vector2.ZERO, _screen), Color(0.06, 0.02, 0.16))

	# Radial glow spots
	_draw_radial(Vector2(_screen.x * 0.2, _screen.y * 0.25), 380,
		Color.from_hsv(fmod(0.75 + _time * 0.04, 1.0), 0.9, 0.8, 0.28))
	_draw_radial(Vector2(_screen.x * 0.8, _screen.y * 0.7), 320,
		Color.from_hsv(fmod(0.05 + _time * 0.035, 1.0), 0.95, 1.0, 0.25))
	_draw_radial(Vector2(_screen.x * 0.5, _screen.y * 0.5), 260,
		Color.from_hsv(fmod(0.55 + _time * 0.03, 1.0), 0.8, 0.9, 0.2))

	# Floating shapes
	for s in _shapes:
		var alpha: float = 0.16 + 0.09 * sin(_time * 0.9 + (s.phase as float))
		var col := Color.from_hsv(s.hue, 0.88, 1.0, alpha)
		var r: float = (s.size as float) + 14.0 * sin(_time * 0.7 + (s.phase as float))
		var angle: float = s.angle
		match s.type as int:
			0: draw_circle(s.pos, r, col)
			1: _draw_star(s.pos, r, 6, col, angle)
			2: _draw_polygon_n(s.pos, r, 6, col, angle)
			3: _draw_polygon_n(s.pos, r, 3, col, angle)

func _draw_radial(center: Vector2, radius: float, color: Color) -> void:
	var transparent := Color(color.r, color.g, color.b, 0.0)
	for i in 12:
		var t := float(i) / 12.0
		var r := radius * (1.0 - t)
		var a := color.a * (1.0 - t)
		draw_circle(center, r, Color(color.r, color.g, color.b, a * 0.25))

func _draw_star(center: Vector2, radius: float, points: int, color: Color, angle: float) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := angle + i * PI / points
		var r := radius if i % 2 == 0 else radius * 0.42
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)

func _draw_polygon_n(center: Vector2, radius: float, sides: int, color: Color, angle: float) -> void:
	var pts := PackedVector2Array()
	for i in sides:
		var a := angle + i * TAU / sides
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)
