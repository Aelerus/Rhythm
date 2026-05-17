class_name BeatClock
extends RefCounted

var bpm: float = 120.0
var beat_interval: float = 0.5
var running: bool = false
var last_beat_index: int = -1
var _start_usec: int = 0
var _listeners: Array = []

func set_bpm(new_bpm: float) -> void:
	bpm = new_bpm
	beat_interval = 60.0 / bpm

func start() -> void:
	# Offset by audio output latency so beats align with what is heard
	_start_usec = Time.get_ticks_usec() - int(AudioServer.get_output_latency() * 1_000_000)
	last_beat_index = -1
	running = true

func stop() -> void:
	running = false

func get_current_time() -> float:
	return float(Time.get_ticks_usec() - _start_usec) / 1_000_000.0

func get_beat_position() -> float:
	if not running:
		return 0.0
	return get_current_time() / beat_interval

func get_song_time() -> float:
	if not running:
		return 0.0
	return get_current_time()

func beat_time(beat_index: int) -> float:
	return float(beat_index) * beat_interval

func on(fn: Callable) -> Callable:
	_listeners.append(fn)
	return func(): _listeners.erase(fn)

func tick() -> void:
	if not running:
		return
	var pos := get_beat_position()
	var current_beat := int(pos)
	while last_beat_index < current_beat:
		last_beat_index += 1
		var idx := last_beat_index
		for fn in _listeners:
			fn.call(idx)
