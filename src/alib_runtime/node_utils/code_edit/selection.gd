
const StringMap = preload("uid://mhebqdb72dqn") # string_map.gd

var begin_line:int
var end_line:int
var begin_col:int
var end_col:int

var selected_text:String
var string_map

var max_line_data_size:= 500
var _line_data = {}

var script_editor:CodeEdit
func _init(_script_editor:CodeEdit, _max_line_data_size=500):
	script_editor = _script_editor
	max_line_data_size = _max_line_data_size
	begin_line = script_editor.get_selection_from_line()
	end_line = script_editor.get_selection_to_line()
	begin_col = script_editor.get_selection_from_column()
	end_col = script_editor.get_selection_to_column()
	
	selected_text = script_editor.get_selected_text()

func get_line_data():
	if _line_data.is_empty():
		_line_data = get_selected_line_data(script_editor, max_line_data_size)
	return _line_data

func get_strings():
	if not is_instance_valid(string_map):
		string_map = StringMap.new(selected_text, StringMap.Mode.STRING)
	return string_map.get_strings()


static func get_selected_line_data(_script_editor:CodeEdit, max_lines:=500):
	var data = {}
	if _script_editor.has_selection():
		var sel_start = _script_editor.get_selection_from_line()
		var sel_end = _script_editor.get_selection_to_line()
		if sel_end - sel_start > max_lines:
			return {}
		for i in range(sel_start, sel_end + 1):
			data[i] = _script_editor.get_line(i)
	else:
		var current_line  = _script_editor.get_caret_line()
		data[current_line] = _script_editor.get_line(current_line)
	
	return data
