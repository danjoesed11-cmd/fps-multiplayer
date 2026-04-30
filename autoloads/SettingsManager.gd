extends Node

const SETTINGS_PATH := "user://settings.cfg"

var _config := ConfigFile.new()
var _defaults: Dictionary = {
	"display_name": "Player",
	"mouse_sensitivity": 0.002,
	"fov": 90.0,
	"graphics_preset": "medium",
	"sfx_volume": 0.8,
	"music_volume": 0.5,
	"fullscreen": false,
	"vsync": true,
}

func _ready() -> void:
	_config.load(SETTINGS_PATH)

func get_setting(key: String, default = null) -> Variant:
	if default == null:
		default = _defaults.get(key)
	return _config.get_value("settings", key, default)

func set_setting(key: String, value: Variant) -> void:
	_config.set_value("settings", key, value)
	_config.save(SETTINGS_PATH)
	_apply_setting(key, value)

func get_cosmetics() -> Dictionary:
	return {
		"body": get_setting("cosmetic_body", "body_default"),
		"head": get_setting("cosmetic_head", "head_default"),
		"gloves": get_setting("cosmetic_gloves", "gloves_default"),
		"boots": get_setting("cosmetic_boots", "boots_default"),
		"kill_fx": get_setting("cosmetic_kill_fx", "fx_default"),
	}

func get_sensitivity() -> float:
	return get_setting("mouse_sensitivity", 0.002)

func get_fov() -> float:
	return get_setting("fov", 90.0)

func _apply_setting(key: String, value: Variant) -> void:
	match key:
		"sfx_volume":
			AudioManager.set_sfx_volume(value)
		"music_volume":
			AudioManager.set_music_volume(value)
		"fullscreen":
			if value:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
			)
