#! namespace BasicData class Bool

static func all(bool_array:Array[bool]) -> bool:
	for v:bool in bool_array:
		if not v:
			return false
	return true

static func any(bool_array:Array[bool]) -> bool:
	for v:bool in bool_array:
		if v:
			return true
	return false

static func count(bool_array:Array[bool]) -> int:
	var i:int = 0
	for v:bool in bool_array:
		if v:
			i += 1
	return i
