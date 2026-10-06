#! namespace ALibRuntime.NodeUtils.NUCodeEdit

const _UString = preload("res://addons/_lib/brohd/alib_runtime/utils/u_string.gd")

const Selection = preload("res://addons/_lib/brohd/alib_runtime/node_utils/code_edit/selection.gd")
const StringParse = preload("res://addons/_lib/brohd/alib_runtime/node_utils/code_edit/string_parse.gd")


static func parse_identifier_at_position(text:String, start_pos:int, string_map:_UString.StringMap=null):
	if string_map == null:
		string_map = _UString.get_string_map(text, _UString.StringMap.Mode.STRING)
	
	var current_pos = start_pos
	var name_start_pos = start_pos + 1
	var last_char = ""
	while current_pos >= 0:
		if string_map.string_mask[current_pos] == 1:
			current_pos -= 1
			continue
		
		var _char = text[current_pos]
		if _char == ")" or _char == "]" or _char == "}":
			current_pos = string_map.bracket_map.get(current_pos, current_pos)
		
		if not _char.is_valid_ascii_identifier() and _char != ".":
			var valid = false
			if _char == ")" and last_char == ".":
				valid = true
			if _char in _UString.NUMBERS:
				valid = true
			
			if not valid:
				break
		
		last_char = _char
		name_start_pos = current_pos
		current_pos -= 1
	
	return text.substr(name_start_pos, start_pos - name_start_pos + 1)
