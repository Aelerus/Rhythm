class_name AudioManager
extends RefCounted

var _music_player: AudioStreamPlayer
var _music_vol: float = 0.85
var _master_vol: float = 0.6
var _tween: Tween = null

func _init(music_player: AudioStreamPlayer) -> void:
	_music_player = music_player
	_music_player.volume_db = linear_to_db(_music_vol)

func play_music(stream: AudioStreamWAV, offset_sec: float = 0.0, vol: float = -1.0) -> void:
	stop_music()
	if _tween:
		_tween.kill()
		_tween = null
	_music_player.stream = stream
	if vol >= 0.0:
		_music_vol = vol
	_music_player.volume_db = linear_to_db(_music_vol)
	_music_player.play(offset_sec)

func fade_out_music(duration: float = 0.6) -> void:
	if not _music_player.playing:
		return
	if _tween:
		_tween.kill()
	_tween = _music_player.create_tween()
	_tween.tween_property(_music_player, "volume_db", -80.0, duration)
	_tween.tween_callback(stop_music)

func stop_music() -> void:
	_music_player.stop()
	_music_player.volume_db = linear_to_db(_music_vol)

func get_music_position() -> float:
	if not _music_player.playing:
		return 0.0
	return _music_player.get_playback_position() + AudioServer.get_time_since_last_mix()

func set_music_volume(v: float) -> void:
	_music_vol = v
	_music_player.volume_db = linear_to_db(v)

func set_master_volume(v: float) -> void:
	_master_vol = v
	AudioServer.set_bus_volume_db(0, linear_to_db(v))
