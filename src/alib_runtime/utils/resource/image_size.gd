

# Returns Vector2i(width, height) or Vector2i(-1, -1) if failed
static func get_image_size(path: String) -> Vector2i:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return Vector2i(-1, -1)

	var ext = path.get_extension().to_lower()
	
	if ext == "png":
		return _get_png_size(file)
	elif ext == "jpg" or ext == "jpeg":
		return _get_jpg_size(file)
	elif ext == "webp":
		return _get_webp_size(file)
	elif ext == "svg":
		return _get_svg_size(file) # SVG is text, usually fast enough
	elif ext == "dds":
		return _get_dds_size(file)
	return Vector2i(-1, -1)

# --- PNG PARSER ---
# PNG stores size in bytes 16-24 (Big Endian)
static func _get_png_size(file: FileAccess) -> Vector2i:
	# Seek past the 8-byte signature + 4-byte chunk length + 4-byte chunk type (IHDR)
	file.seek(16)
	var w = _read_be_32(file) # Width
	var h = _read_be_32(file) # Height
	return Vector2i(w, h)

# --- WEBP PARSER ---
# WEBP is a RIFF format. It's Little Endian.
static func _get_webp_size(file: FileAccess) -> Vector2i:
	file.seek(12) # Skip RIFF header
	var chunk_header = file.get_buffer(4).get_string_from_ascii()
	
	if chunk_header == "VP8 ":
		# Simple VP8: Check frame header
		file.seek(26)
		var w = file.get_16()
		var h = file.get_16()
		return Vector2i(w & 0x3fff, h & 0x3fff)
		
	elif chunk_header == "VP8L":
		# Lossless VP8L: Size is at byte 21 (14 bits each)
		file.seek(21)
		var b0 = file.get_8()
		var b1 = file.get_8()
		var b2 = file.get_8()
		var b3 = file.get_8()
		
		# Bit shifting magic for VP8L
		var w = 1 + (((b1 & 0x3F) << 8) | b0)
		var h = 1 + (((b3 & 0x0F) << 10) | (b2 << 2) | ((b1 & 0xC0) >> 6))
		return Vector2i(w, h)
		
	elif chunk_header == "VP8X":
		# Extended: Width/Height at byte 24 (24 bits each)
		file.seek(24)
		var w = _read_le_24(file) + 1
		var h = _read_le_24(file) + 1
		return Vector2i(w, h)
		
	return Vector2i(-1, -1)

# --- JPG PARSER ---
# JPG is variable length. We must scan for the Start Of Frame (SOF) marker.
static func _get_jpg_size(file: FileAccess) -> Vector2i:
	file.seek(2) # Skip initial SOI marker (FF D8)
	
	while file.get_position() < file.get_length():
		var b = file.get_8()
		if b == 0xFF: # Marker start
			var marker = file.get_8()
			
			# SOF0 (Baseline), SOF1 (Extended), SOF2 (Progressive)
			# Markers range from 0xC0 to 0xC3 (excluding 0xC4 which is Huffman)
			if (marker >= 0xC0 and marker <= 0xC3):
				file.seek(file.get_position() + 3) # Skip length(2) + precision(1)
				var h = _read_be_16(file)
				var w = _read_be_16(file)
				return Vector2i(w, h)
			
			# Start of Scan (SOS) - Image data starts here, we failed to find header
			if marker == 0xDA: 
				return Vector2i(-1, -1)
				
			# Skip other variable length markers
			# Read length (2 bytes, Big Endian) including the length bytes themselves
			var length = _read_be_16(file)
			file.seek(file.get_position() + length - 2)
			
	return Vector2i(-1, -1)

# --- SVG PARSER ---
# Parses XML text for width="..." and height="..."
static func _get_svg_size(file: FileAccess) -> Vector2i:
	# Read first 512 bytes (usually enough for header)
	var text = file.get_buffer(512).get_string_from_ascii()
	var w_match = _regex_find('width="([0-9.]+)"', text)
	var h_match = _regex_find('height="([0-9.]+)"', text)
	if w_match and h_match:
		return Vector2i(int(w_match), int(h_match))
	return Vector2i(-1, -1)

static func _get_dds_size(file: FileAccess) -> Vector2i:
	# 1. Check Magic Number "DDS "
	# In Little Endian hex: 0x20534444
	var magic = file.get_32()
	if magic != 0x20534444:
		return Vector2i(-1, -1)
	
	# 2. Skip dwSize (4 bytes) and dwFlags (4 bytes)
	# The header struct starts immediately after the magic number.
	# Height is at offset 12 from start of file.
	file.seek(12)
	
	# 3. Read Dimensions
	# DDS Header spec specifically lists Height BEFORE Width
	var h = file.get_32() # Standard get_32 is Little Endian
	var w = file.get_32()
	
	return Vector2i(w, h)



# --- HELPERS ---

static func _read_be_32(file: FileAccess) -> int:
	var b = file.get_buffer(4)
	# (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
	return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]

static func _read_be_16(file: FileAccess) -> int:
	var b = file.get_buffer(2)
	return (b[0] << 8) | b[1]

static func _read_le_24(file: FileAccess) -> int:
	var b = file.get_buffer(3)
	return b[0] | (b[1] << 8) | (b[2] << 16)

static func _regex_find(pattern: String, text: String):
	var regex = RegEx.new()
	regex.compile(pattern)
	var result = regex.search(text)
	if result:
		return result.get_string(1)
	return null
