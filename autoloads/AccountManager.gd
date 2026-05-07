extends Node

signal account_changed

const STORAGE_KEY := "fnz_accounts_v1"
const SESSION_KEY := "fnz_session_v1"

var _current_user: String = ""
var _accounts: Dictionary = {}

func _ready() -> void:
	_load_accounts()
	var session := _local_get(SESSION_KEY)
	if session != "" and _accounts.has(session):
		_current_user = session
		SettingsManager.set_setting("display_name", _current_user)
	EventBus.match_over.connect(_on_match_over)

func is_logged_in() -> bool:
	return _current_user != ""

func get_username() -> String:
	return _current_user

func get_stats() -> Dictionary:
	if not is_logged_in():
		return {"kills": 0, "deaths": 0, "wins": 0, "matches": 0}
	return _accounts[_current_user].get("stats", {"kills": 0, "deaths": 0, "wins": 0, "matches": 0})

func get_friends() -> Array:
	if not is_logged_in():
		return []
	return _accounts[_current_user].get("friends", [])

func signup(username: String, password: String) -> String:
	username = username.strip_edges().to_lower()
	if username.length() < 3:
		return "Username must be at least 3 characters"
	if not _is_valid_username(username):
		return "Only letters, numbers, and underscores"
	if _accounts.has(username):
		return "Username already taken"
	if password.length() < 4:
		return "Password must be at least 4 characters"
	_accounts[username] = {
		"pw": _hash(password),
		"friends": [],
		"stats": {"kills": 0, "deaths": 0, "wins": 0, "matches": 0}
	}
	_save_accounts()
	return _do_login(username)

func login(username: String, password: String) -> String:
	username = username.strip_edges().to_lower()
	if not _accounts.has(username):
		return "Account not found"
	if _accounts[username]["pw"] != _hash(password):
		return "Wrong password"
	return _do_login(username)

func logout() -> void:
	_current_user = ""
	_local_set(SESSION_KEY, "")
	account_changed.emit()

func add_friend(target: String) -> String:
	if not is_logged_in():
		return "Not logged in"
	target = target.strip_edges().to_lower()
	if target == _current_user:
		return "That's you!"
	if not _accounts.has(target):
		return "User \"%s\" not found on this device" % target
	var friends: Array = _accounts[_current_user]["friends"]
	if target in friends:
		return "Already friends"
	friends.append(target)
	_save_accounts()
	return ""

func remove_friend(target: String) -> void:
	if not is_logged_in():
		return
	var friends: Array = _accounts[_current_user]["friends"]
	friends.erase(target)
	_save_accounts()

func _on_match_over(winner_team: int) -> void:
	if not is_logged_in():
		return
	var my_id := multiplayer.get_unique_id()
	var info := PlayerRegistry.get_info(my_id)
	if not info:
		return
	var stats: Dictionary = _accounts[_current_user]["stats"]
	stats["matches"] = stats.get("matches", 0) + 1
	if info.team_id == winner_team:
		stats["wins"] = stats.get("wins", 0) + 1
	_save_accounts()

func _do_login(username: String) -> String:
	_current_user = username
	_local_set(SESSION_KEY, username)
	SettingsManager.set_setting("display_name", username)
	account_changed.emit()
	return ""

func _is_valid_username(u: String) -> bool:
	for c in u:
		if not (c.is_valid_identifier() or c == "_" or c.to_int() > 0 or c == "0"):
			if not ("abcdefghijklmnopqrstuvwxyz0123456789_".contains(c)):
				return false
	return true

func _hash(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()

func _load_accounts() -> void:
	var raw := _local_get(STORAGE_KEY)
	if raw.is_empty():
		return
	var json := JSON.new()
	if json.parse(raw) == OK:
		var data = json.get_data()
		if data is Dictionary:
			_accounts = data

func _save_accounts() -> void:
	_local_set(STORAGE_KEY, JSON.stringify(_accounts))

func _local_get(key: String) -> String:
	if OS.has_feature("web"):
		var b64 = JavaScriptBridge.eval("localStorage.getItem('%s') || ''" % key, true)
		var b64_str := str(b64) if b64 != null else ""
		if b64_str.is_empty():
			return ""
		var bytes := Marshalls.base64_to_raw(b64_str)
		return bytes.get_string_from_utf8()
	else:
		var cfg := ConfigFile.new()
		if cfg.load("user://local_store.cfg") == OK:
			return str(cfg.get_value("store", key, ""))
		return ""

func _local_set(key: String, value: String) -> void:
	if OS.has_feature("web"):
		var b64 := Marshalls.raw_to_base64(value.to_utf8_buffer())
		JavaScriptBridge.eval("localStorage.setItem('%s', '%s')" % [key, b64], true)
	else:
		var cfg := ConfigFile.new()
		cfg.load("user://local_store.cfg")
		cfg.set_value("store", key, value)
		cfg.save("user://local_store.cfg")
