extends WeaponBase

const SCOPE_FOV := 20.0

var _scoped: bool = false
var _base_fov: float = 90.0
var _scope_overlay: CanvasLayer = null

func _ready() -> void:
	super._ready()
	if weapon_data:
		weapon_data.headshot_multiplier = 3.0

func _process(delta: float) -> void:
	super._process(delta)
	if not _is_local or not visible:
		if _scoped:
			_exit_scope()
		return
	var aiming := (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_4)) \
		and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if aiming and not _scoped:
		_enter_scope()
	elif not aiming and _scoped:
		_exit_scope()

func unequip() -> void:
	_exit_scope()
	super.unequip()

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		if _scope_overlay and is_instance_valid(_scope_overlay):
			_scope_overlay.queue_free()
			_scope_overlay = null

func _enter_scope() -> void:
	_scoped = true
	var cam := _get_player_camera()
	if cam:
		_base_fov = cam.fov
		cam.fov = SCOPE_FOV
	_build_scope_overlay()

func _exit_scope() -> void:
	if not _scoped:
		return
	_scoped = false
	var cam := _get_player_camera()
	if cam and is_instance_valid(cam):
		cam.fov = _base_fov
	if _scope_overlay and is_instance_valid(_scope_overlay):
		_scope_overlay.queue_free()
	_scope_overlay = null

func _build_scope_overlay() -> void:
	if _scope_overlay and is_instance_valid(_scope_overlay):
		_scope_overlay.queue_free()
	_scope_overlay = CanvasLayer.new()
	_scope_overlay.layer = 5
	get_tree().root.add_child(_scope_overlay)

	var vp := get_viewport().get_visible_rect()
	var cx := vp.size.x * 0.5
	var cy := vp.size.y * 0.5
	var r := minf(vp.size.x, vp.size.y) * 0.4

	# 4 dark border panels leaving a square scope window in the centre
	for data: Array in [
		[Vector2.ZERO,            Vector2(vp.size.x, cy - r)],
		[Vector2(0, cy + r),      Vector2(vp.size.x, cy - r)],
		[Vector2(0, cy - r),      Vector2(cx - r, r * 2.0)],
		[Vector2(cx + r, cy - r), Vector2(cx - r, r * 2.0)],
	]:
		var panel := ColorRect.new()
		panel.color = Color(0.02, 0.04, 0.02, 1.0)
		panel.position = data[0]
		panel.size    = data[1]
		_scope_overlay.add_child(panel)

	# Crosshair — four segments with a gap at the centre
	var line_len := r * 0.28
	var thick    := 2.0
	var gap      := r * 0.06
	for seg: Array in [
		[Vector2(cx - gap - line_len, cy - thick * 0.5), Vector2(line_len, thick)],
		[Vector2(cx + gap,            cy - thick * 0.5), Vector2(line_len, thick)],
		[Vector2(cx - thick * 0.5,   cy - gap - line_len), Vector2(thick, line_len)],
		[Vector2(cx - thick * 0.5,   cy + gap),            Vector2(thick, line_len)],
	]:
		var line := ColorRect.new()
		line.color    = Color(0.05, 0.85, 0.15, 0.95)
		line.position = seg[0]
		line.size     = seg[1]
		_scope_overlay.add_child(line)

	# Thin scope-ring outline (two horizontal + two vertical short ticks at edge)
	var tick_len := r * 0.06
	for tick: Array in [
		[Vector2(cx - r - tick_len, cy - thick * 0.5), Vector2(tick_len, thick)],
		[Vector2(cx + r,            cy - thick * 0.5), Vector2(tick_len, thick)],
		[Vector2(cx - thick * 0.5, cy - r - tick_len), Vector2(thick, tick_len)],
		[Vector2(cx - thick * 0.5, cy + r),            Vector2(thick, tick_len)],
	]:
		var t := ColorRect.new()
		t.color    = Color(0.05, 0.85, 0.15, 0.6)
		t.position = tick[0]
		t.size     = tick[1]
		_scope_overlay.add_child(t)
