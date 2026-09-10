const UString = preload("uid://bbk1yedqm7a6a") #! resolve ALibRuntime.Utils.UString.Methods

const BRACKETS = { "(": ")", "[": "]", "{": "}" }
enum Mode {
	FULL,
	STRING,
}
## Copy of text that was parsed.
var string:String
## A mask where 1 means "inside a string" and 0 means "outside".
var string_mask: PackedByteArray
## A dictionary mapping start index of each string to the strings content.
var string_map:Dictionary
## A dictionary mapping a quote's index to its matching partner's index.
var quote_map: Dictionary
## A dictionary mapping each bracket's index to the index of its matching partner.
var bracket_map: Dictionary[int, int]
## A flag to indicate if any parsing errors (like mismatched brackets) occurred.
var has_errors: bool = false
## Select full scan or only string mask
var mode:Mode
## A mask where 1 is after a comment and before newline
var comment_mask:PackedByteArray


func _init(text:String, _mode:Mode=Mode.FULL, print_err:=false) -> void:
	string = text
	mode = _mode
	_parse(text)

func _parse(text: String, print_err:=false):
	var text_length = text.length()
	string_mask.resize(text_length)
	comment_mask.resize(text_length)
	
	var bracket_values = BRACKETS.values()
	var bracket_stack = []
	var in_comment = false
	var in_string = false
	var quote_char = ""
	var string_start_index = -1
	var current_string = ""
	
	var i = -1 # for easy indexing
	while i + 1 < text_length:
		i += 1
		var _char = text[i]
		if in_comment:
			if _char == "\n":
				in_comment = false
			else:
				comment_mask[i] = 1
		elif in_string:
			string_mask[i] = 1
			if _char == "\\":
				if i + 1 < text_length:
					string_mask[i + 1] = 1
				i += 1
			elif _char == quote_char:
				in_string = false
				quote_map[string_start_index] = i
				quote_map[i] = string_start_index
				string_map[string_start_index] = current_string
				current_string = ""
				continue
			current_string += _char
		else: # not in_string
			if _char == '"' or _char == "'":
				in_string = true
				quote_char = _char
				string_start_index = i
				string_mask[i] = 1
			elif _char == "#":
				in_comment = true
				comment_mask[i] = 1
			elif mode == Mode.FULL:
				if _char in BRACKETS:
					bracket_stack.push_back(i)
				elif _char in bracket_values:# bracket closing
					if bracket_stack.is_empty():
						has_errors = true
						break
					var open_idx = bracket_stack.pop_back()
					if BRACKETS[text[open_idx]] == _char:
						bracket_map[open_idx] = i
						bracket_map[i] = open_idx
					else:
						has_errors = true
						break
	
	# after loop
	if in_string:
		if print_err:
			printerr("Unterminated string starting at index ", string_start_index)
		has_errors = true
	if not bracket_stack.is_empty():
		if print_err:
			printerr("Unclosed opening bracket at index ", bracket_stack.front())
		has_errors = true

func index_in_string_or_comment(index:int):
	if comment_mask[index] == 1:
		return true
	if string_mask[index] == 1:
		return true
	return false

func get_comment_index(from:int=0):
	return comment_mask.find(1, from)

func get_line_at_index(index:int):
	var beginning_new_line_i = UString.rfind_index_safe(string, "\n", index)
	if beginning_new_line_i == -1:
		beginning_new_line_i = 0
	var end_new_line_i = string.find("\n", index)
	if end_new_line_i == -1:
		end_new_line_i = string.length() - 1
	return string.substr(beginning_new_line_i, end_new_line_i - beginning_new_line_i)

func get_strings():
	return string_map.values()

func get_tightest_bracket_set(idx:int, bracket_type:=""):
	var all_brackets = bracket_type == ""
	var open_bracket_index = -1
	var closed_bracket_index = string.length()
	var bracket_map_keys = bracket_map.keys()
	bracket_map_keys.sort()
	
	for open in bracket_map_keys:
		if open > idx:
			break
		var _char = string[open]
		if not all_brackets and _char != bracket_type:
			continue
		var close = bracket_map.get(open)
		if not (open <= idx and close >= idx):
			continue
		
		if close - open < closed_bracket_index - open_bracket_index:
			open_bracket_index = open
			closed_bracket_index = close
	
	return open_bracket_index
	
	
