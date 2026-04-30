extends Node

const POOL_SIZE := 16

var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _music_player: AudioStreamPlayer = null

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not stream:
		return
	var player := _sfx_pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = "SFX"
	player.play()

func play_sfx_3d(stream: AudioStream, position: Vector3, volume_db: float = 0.0) -> void:
	if not stream:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "SFX"
	add_child(player)
	player.global_position = position
	player.play()
	player.finished.connect(player.queue_free)

func play_music(stream: AudioStream, loop: bool = true) -> void:
	if not stream:
		return
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func set_sfx_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(linear))

func set_music_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(linear))
