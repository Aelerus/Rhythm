extends Node2D

var _input_mgr:  InputManager
var _audio:      AudioManager
var _beat_clock: BeatClock

var _stages:      Array      = []
var _worlds:      Array      = []
var _pattern_lib: Dictionary = {}
var _rhythm_root: String     = ""  # absolute path to Rhythm/ folder

var _screen = null  # current active screen (RefCounted with update/draw)

func _ready() -> void:
	# Resolve Rhythm/ root: res:// points to godot/, parent is Rhythm/
	var res_abs := ProjectSettings.globalize_path("res://")
	_rhythm_root = res_abs.rstrip("/").rstrip("\\").get_base_dir()

	_input_mgr  = InputManager.new()
	_audio      = AudioManager.new($MusicPlayer)
	_beat_clock = BeatClock.new()

	_load_stages()
	_load_pattern_library()
	_goto_boss_select()

# ─── Data loading ─────────────────────────────────────────────────────────────

func _load_stages() -> void:
	var path := _rhythm_root.path_join("data/stages.json")
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Main: cannot open stages.json at " + path)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and parsed.has("stages"):
		_stages = parsed["stages"]
		_worlds = parsed.get("worlds", [])
	else:
		push_error("Main: unexpected stages.json format")

func _load_pattern_library() -> void:
	# Load pattern file list from stages.json
	var path := _rhythm_root.path_join("data/stages.json")
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary and parsed.has("patternFiles")):
		return

	for rel_path in parsed["patternFiles"]:
		var full := _rhythm_root.path_join(rel_path)
		var pf := FileAccess.open(full, FileAccess.READ)
		if pf == null:
			push_warning("Main: missing pattern file: " + full)
			continue
		var data = JSON.parse_string(pf.get_as_text())
		pf.close()
		if data is Dictionary:
			var pid: String = data.get("id", rel_path.get_file().get_basename())
			_pattern_lib[pid] = data

# ─── Screen transitions ────────────────────────────────────────────────────────

func _goto_boss_select() -> void:
	_audio.stop_music()
	_beat_clock.stop()
	_screen = BossSelect.new(_stages, _worlds, Callable(self, "_on_boss_picked"))
	queue_redraw()

func _on_boss_picked(stage: Dictionary) -> void:
	_start_fight(stage)

func _start_fight(stage: Dictionary) -> void:
	# Load boss JSON — path stored as "data/bosses/boss_01.json" relative to Rhythm/
	var boss_rel: String = stage.get("boss", stage.get("bossFile", ""))
	if boss_rel == "":
		push_error("Main: stage has no boss file path: " + str(stage))
		return
	var boss_path := _rhythm_root.path_join(boss_rel)
	var bf := FileAccess.open(boss_path, FileAccess.READ)
	if bf == null:
		push_error("Main: cannot open boss file " + boss_path)
		return
	var boss_data = JSON.parse_string(bf.get_as_text())
	bf.close()
	if not boss_data is Dictionary:
		push_error("Main: invalid boss JSON at " + boss_path)
		return

	# Merge stage-level keys (name, color, bpm) into boss_data where not already set
	for k in stage.keys():
		if not boss_data.has(k):
			boss_data[k] = stage[k]

	var music_buf = _load_music_for_boss(boss_data)

	_beat_clock = BeatClock.new()

	var fight_screen := FightGame.new(
		boss_data, _pattern_lib,
		_audio, _beat_clock, music_buf,
		Callable(self, "_on_victory"),
		Callable(self, "_on_defeat"),
		Callable(self, "_on_restart").bind(stage),
		Callable(self, "_goto_boss_select")
	)
	_screen = fight_screen
	fight_screen.enter()
	queue_redraw()

func _load_music_for_boss(boss_data: Dictionary):
	# Check for per-phase music first
	var phases: Array = boss_data.get("phases", [])
	if phases.size() > 0:
		var buffers := {}
		for i in range(phases.size()):
			var ph = phases[i]
			var mfile: String = ph.get("music", "")
			if mfile != "":
				var full_path := _rhythm_root.path_join(mfile)
				var stream := WavLoader.load_file(full_path)
				if stream != null:
					buffers[i] = stream
		if buffers.size() > 0:
			return buffers

	# Single music file (path relative to Rhythm/)
	var mfile: String = boss_data.get("music", "")
	if mfile != "":
		var full_path := _rhythm_root.path_join(mfile)
		return WavLoader.load_file(full_path)

	return null

func _on_victory(summary: Dictionary) -> void:
	_audio.stop_music()
	_beat_clock.stop()
	_screen = VictoryScreen.new(summary, Callable(self, "_goto_boss_select"))
	queue_redraw()

func _on_defeat(info: Dictionary) -> void:
	_audio.stop_music()
	_beat_clock.stop()
	var stage_ref := _find_stage_by_name(info.get("bossName", ""))
	_screen = GameOver.new(
		info,
		Callable(self, "_on_retry").bind(stage_ref),
		Callable(self, "_goto_boss_select")
	)
	queue_redraw()

func _on_retry(stage: Dictionary) -> void:
	if stage.size() > 0:
		_start_fight(stage)
	else:
		_goto_boss_select()

func _on_restart(stage: Dictionary) -> void:
	_start_fight(stage)

func _find_stage_by_name(boss_name: String) -> Dictionary:
	for s in _stages:
		if s.get("name", "") == boss_name:
			return s
	return {}

# ─── Godot loop ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _screen == null:
		return
	_input_mgr.tick(delta)
	_screen.update(delta, _input_mgr)
	_input_mgr.end_frame()
	queue_redraw()

func _draw() -> void:
	if _screen == null:
		return
	_screen.draw(self)

func _input(event: InputEvent) -> void:
	_input_mgr.handle_event(event)
