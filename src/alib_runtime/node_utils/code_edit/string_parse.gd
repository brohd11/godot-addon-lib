
var code_edit:CodeEdit

func _init(_code_edit:CodeEdit) -> void:
	code_edit = _code_edit


func get_line_data(line:int) -> Dictionary:
	var line_text = code_edit.get_line(line)
	var com_idx = line_text.find("#")
	if com_idx == -1:
		return {"code": line_text, "comment": ""}
	while com_idx != -1:
		if code_edit.is_in_string(line, com_idx) != -1:
			com_idx = line_text.find("#", com_idx + 1)
		else:
			break
	
	var code = line_text.substr(0, com_idx)
	var comment = line_text.substr(com_idx)
	return {"code": code, "comment": comment}



#^ these are from code edit parser
func get_line(line:int, strip_comment:=false, strip_left:=false):
	var line_text = code_edit.get_line(line)
	if not strip_comment:
		return line_text.strip_edges(strip_left, true)
	else:
		var com_idx = line_text.find("#")
		while com_idx != -1:
			if code_edit.is_in_string(line, com_idx) != -1:
				com_idx = line_text.find("#", com_idx + 1)
			else:
				break
		return line_text.substr(0, com_idx).strip_edges(strip_left, true)

func get_extended_line(line_index:int):
	var full_line = ""
	var in_extension:= false
	var start_i = line_index - 1
	while start_i >= 0:
		var line = get_line(start_i, true)
		if not line.ends_with("\\"):
			break
		start_i -= 1
	start_i += 1 # offsets back to last line no extension
	
	while start_i < code_edit.get_line_count() - 1:
		var line = get_line(start_i, true)
		in_extension = line.ends_with("\\")
		full_line += " " + line.trim_suffix("\\") + " "
		start_i += 1
		if not in_extension:
			break
		
	return full_line
