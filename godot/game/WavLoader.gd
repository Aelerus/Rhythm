class_name WavLoader
extends RefCounted

# Loads a standard PCM WAV file from an absolute filesystem path.
# Returns an AudioStreamWAV or null on failure.
static func load_file(path: String) -> AudioStreamWAV:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("WavLoader: cannot open " + path)
		return null

	# RIFF header
	var riff_id := file.get_buffer(4).get_string_from_ascii()
	if riff_id != "RIFF":
		push_warning("WavLoader: not a RIFF file: " + path)
		file.close()
		return null
	file.get_32()  # chunk size
	var wave_id := file.get_buffer(4).get_string_from_ascii()
	if wave_id != "WAVE":
		push_warning("WavLoader: not a WAVE file: " + path)
		file.close()
		return null

	var num_channels := 2
	var sample_rate := 44100
	var bits_per_sample := 16
	var audio_data := PackedByteArray()

	while not file.eof_reached():
		var chunk_id_buf := file.get_buffer(4)
		if chunk_id_buf.size() < 4:
			break
		var chunk_id := chunk_id_buf.get_string_from_ascii()
		var chunk_size: int = file.get_32()

		if chunk_id == "fmt ":
			file.get_16()                    # audio format (1 = PCM), read to advance pointer
			num_channels   = file.get_16()
			sample_rate    = file.get_32()
			file.get_32()                    # byte rate
			file.get_16()                    # block align
			bits_per_sample = file.get_16()
			if chunk_size > 16:
				file.get_buffer(chunk_size - 16)
		elif chunk_id == "data":
			audio_data = file.get_buffer(chunk_size)
			break
		else:
			# Skip unknown chunks (LIST, cue, etc.)
			if chunk_size > 0:
				file.get_buffer(chunk_size)

	file.close()

	if audio_data.is_empty():
		push_warning("WavLoader: no data chunk in " + path)
		return null

	var stream := AudioStreamWAV.new()
	stream.mix_rate    = sample_rate
	stream.stereo      = num_channels == 2
	stream.format      = 1 if bits_per_sample == 16 else 0
	stream.data        = audio_data
	return stream
