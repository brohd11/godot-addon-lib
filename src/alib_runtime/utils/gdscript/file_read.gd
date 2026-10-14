
const UFile = preload("uid://bl33psa06nv1e") #! resolve ALibRuntime.Utils.UFile.Methods
const UString = preload("uid://bbk1yedqm7a6a") #! resolve ALibRuntime.Utils.UString.Methods

static func get_class_name(path:String):
	var file = UFile.get_file_access(path)
	if file:
		var check = check_file_for(file, "class_name ")
		if check:
			var _class = check.get_slice("class_name ", 1)
			_class = _class.get_slice(" ", 0).strip_edges()
			return _class
	return ""

static func get_extends(path:String):
	var file = UFile.get_file_access(path)
	if file:
		var check = check_file_for(file, "extends ")
		if check:
			var _extends = check.get_slice("extends ", 1)
			_extends = _extends.strip_edges().trim_suffix(":").strip_edges()
			return _extends
	return ""

static func get_is_tool(path:String):
	var file = UFile.get_file_access(path)
	if file:
		var check = check_file_for(file, "@tool")
		if check:
			return true
	return false


static func check_file_for(file:FileAccess, string:String, lines:=5, return_code:=true):
	for i in range(lines):
		var line = file.get_line()
		var code = UString.strip_comment(line)
		if code.contains(string):
			if return_code:
				return code
			else:
				return line
	return ""
