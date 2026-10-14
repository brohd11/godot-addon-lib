

static func get_audio_duration(path: String) -> float:
	var ext = path.get_extension().to_lower()
	
	# STRATEGY 1: WAV Math (No Load)
	# WAVs are uncompressed. We can calculate duration = DataBytes / BytesPerSecond
	if ext == "wav":
		return _get_wav_duration(path)
		
	# STRATEGY 2: Load (Safe for streams)
	# MP3 and OGG are imported as Streams by default. 
	# Loading them is lightweight (KB of memory) compared to WAV Samples.
	if ext == "mp3" or ext == "ogg":
		if ResourceLoader.exists(path):
			var stream = load(path) as AudioStream
			if stream:
				return stream.get_length()
				
	return 0.0

# --- WAV PARSER ---
static func _get_wav_duration(path: String) -> float:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return 0.0
	
	# 1. RIFF Header
	var riff = f.get_buffer(4).get_string_from_ascii()
	if riff != "RIFF": return 0.0
	
	f.seek(8) # Skip File Size
	var wave = f.get_buffer(4).get_string_from_ascii()
	if wave != "WAVE": return 0.0
	
	# 2. Iterate Chunks to find 'fmt ' and 'data'
	# Standard WAV: [RIFF][WAVE][fmt ][...][data][...]
	var byte_rate = 0
	var data_size = 0
	
	while f.get_position() < f.get_length():
		var chunk_id = f.get_buffer(4).get_string_from_ascii()
		var chunk_size = f.get_32() # Little Endian
		
		if chunk_id == "fmt ":
			# Parse Format Chunk
			var _audio_format = f.get_16()
			var _num_channels = f.get_16()
			var _sample_rate = f.get_32()
			byte_rate = f.get_32() # Bytes per second
			var _block_align = f.get_16()
			var _bits_per_sample = f.get_16()
			
			# If chunk size is > 16, skip extra params
			if chunk_size > 16:
				f.seek(f.get_position() + (chunk_size - 16))
				
		elif chunk_id == "data":
			# We found the audio data!
			data_size = chunk_size
			# We don't need to read the data, just the size
			break
			
		else:
			f.seek(f.get_position() + chunk_size) # Unknown chunk (Metadata, cues, LIST, etc), skip it
			
	if byte_rate > 0 and data_size > 0:
		return float(data_size) / float(byte_rate)
		
	return 0.0


static func format_duration(seconds: float) -> String:
	if seconds == 0: return "?"
	var m = int(seconds / 60)
	var s = int(seconds) % 60
	
	if seconds < 1.0:
		return "%.3fs" % seconds
		
	return "%02d:%02d" % [m, s]
