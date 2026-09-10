const UFile = preload("uid://bl33psa06nv1e") #! resolve ALibRuntime.Utils.UFile.Methods


static func check_root(file_path:String, valid_types:Array) -> bool:
	var root = get_root_type(file_path, true)
	return root in valid_types
	

## Recursive param will search instantiated scene in case of inherited scene.
static func get_root_type(file_path:String, recursive:=false):
	var root_line = get_root_line(file_path)
	if root_line:
		if root_line.find("instance=") > -1:
			var id = get_id_from_line(root_line)
			
			var resource_line = get_resource_line(file_path, id)
			if not resource_line:
				printerr("Could not find resource: %s in %s" % [id, file_path])
				return ""
			var inh_path = get_path_from_line(resource_line)
			if not recursive:
				return inh_path
			else:
				return get_root_type(inh_path, recursive)
		else:
			return get_type_from_line(root_line)
	return ""

static func get_root_line(file_path:String):
	var file = UFile.get_file_access(file_path)
	if file:
		while not file.eof_reached():
			var line = file.get_line()
			if not line.find("[node name=") > -1:
				continue
			return line
	return ""

static func get_resource_line(file_path:String, resource_id:String):
	var file = UFile.get_file_access(file_path)
	if file:
		var id_string = ' id="%s"' % resource_id
		while not file.eof_reached():
			var line = file.get_line()
			if not line.find(id_string) > -1:
				continue
			return line
	return ""

static func get_id_from_line(line:String):
	if line.find(' id="') > -1:
		return _get_slice_from_line(line, ' id="')
	elif line.find('Resource("') > -1:
		return _get_slice_from_line(line, 'Resource("')
	return ""

static func get_path_from_line(line:String):
	return _get_slice_from_line(line, 'path="')

static func get_type_from_line(line:String):
	return _get_slice_from_line(line, 'type="')

static func get_name_from_line(line:String):
	return _get_slice_from_line(line, 'name="')

static func _get_slice_from_line(line:String, slice_string:String, second_slice:='"'):
	if line.find(slice_string):
		return line.get_slice(slice_string, 1).get_slice(second_slice, 0)
	return ""


static func get_root_script_path(file_path:String):
	var file = UFile.get_file_access(file_path)
	if not file:
		return ""
	var scripts = {}
	
	var in_node = false
	while not file.eof_reached():
		var line = file.get_line()
		if line.begins_with("[ext_resource"):
			var type = get_type_from_line(line)
			if type != "Script":
				continue
			var id = get_id_from_line(line)
			var path = get_path_from_line(line)
			scripts[id] = path
			continue
		if not line.begins_with("[node name="):
			if not in_node:
				continue
		elif in_node:
			return ""
		else:
			in_node = true
		if not line.begins_with("script = "):
			continue
		
		var script_id = get_id_from_line(line)
		return scripts.get(script_id, "")
