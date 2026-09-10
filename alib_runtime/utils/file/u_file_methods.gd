
const IGNORE_FILES = [".gitignore", ".gitattributes", ".gitmodules", ".git"]

const _UID = "uid" + "://"
const _UID_INVALID = _UID + "<invalid>"

static func get_file_access(path:String, flag:=FileAccess.ModeFlags.READ, print_err:=false):
	var file_access = FileAccess.open(path, flag)
	if not file_access and print_err:
		printerr("Could not open FileAccess: %s" % path)
	return file_access

static func store_data_bin(data:Variant, path:String, allow_obj:bool=false) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f = FileAccess.open(path, FileAccess.WRITE)
	return f.store_var(data, allow_obj)

static func get_data_bin(path:String, allow_obj:bool=false) -> Variant:
	if FileAccess.file_exists(path):
		var f = FileAccess.open(path, FileAccess.READ)
		return f.get_var(allow_obj)
	return null

static func temp_file_arr_comp(a, b):
	var a_missing = []
	var b_missing = []
	for f in a:
		if not f in b:
			b_missing.append(f)
	for f in b:
		if not f in a:
			a_missing.append(f)
	
	if not (a_missing.is_empty() and b_missing.is_empty()):
		print("FILE MISMATCH:", a_missing)
		print(b_missing)

static func scan_for_files(dir:String,file_types:Array, include_dirs=false, ignore_dirs:Array=[], show_ignore=false) -> PackedStringArray:
	return _scan_for_files(dir, file_types, include_dirs, ignore_dirs, show_ignore)


static func _scan_for_files(dir:String,file_types:Array, include_dirs=false, ignore_dirs:Array=[], show_ignore=false) -> PackedStringArray:
	var file_array:PackedStringArray = []
	var files:PackedStringArray = []
	if not show_ignore and FileAccess.file_exists(dir.path_join(".gdignore")):
		return file_array
	
	var dir_access:DirAccess = DirAccess.open(dir)
	if not dir_access:
		return file_array
	dir_access.include_hidden = true
	
	if dir_access.dir_exists_absolute(dir):
		files = dir_access.get_files()
	
	#if ".gdignore" in files:
		#if not show_ignore:
			#return file_array
	
	if include_dirs:
		file_array.append(dir)
	
	var dirs:Array = []
	if dir_access.dir_exists_absolute(dir):
		
		dirs = dir_access.get_directories_at(dir)
		dirs.sort_custom(_case_insensitive_compare)
	
	for d:String in dirs:
		var dir_path:String = dir.path_join(d)
		if dir_path in ignore_dirs:
			continue
		var recur_files:Array = _scan_for_files(dir_path,file_types,include_dirs,ignore_dirs,show_ignore)
		file_array.append_array(recur_files)
	
	var ignore_files:Array = IGNORE_FILES
	if show_ignore:
		ignore_files = []
	
	for f:String in files:
		if file_types == []:
			if f in ignore_files:
				continue
			
			var file_path:String = dir.path_join(f)
			file_array.append(file_path)
			continue
		if f.to_lower().get_extension() in file_types:
			var file_path:String = dir.path_join(f)
			file_array.append(file_path)
	
	return file_array


static func scan_for_dirs(dir:String,seperate_stacks:bool=false, include_hidden:=true):
	var folders = [] # seperate stacks to get all directories in a hierachy as a seperate array
	var dir_stacks = [] # then can reverse each array and iterate bottom up for deletion
	if not DirAccess.dir_exists_absolute(dir):
		return dir_stacks
	var dir_access = DirAccess.open(dir)
	dir_access.include_hidden = include_hidden
	folders = dir_access.get_directories()
	for f in folders:
		var dir_array = []
		var current_dir = dir.path_join(f)
		dir_array.append(current_dir)
		var next_dir_path = dir.path_join(f) # should separate stacks be passed? not sure
		var recur_dirs = scan_for_dirs(next_dir_path, false, include_hidden)
		dir_array.append_array(recur_dirs)
		if seperate_stacks:
			dir_stacks.append(dir_array)
		else:
			dir_stacks.append_array(dir_array)
	
	return dir_stacks

static func recursive_delete_in_dir(directory:String, include_hidden:=true) -> bool:
	if not DirAccess.dir_exists_absolute(directory):
		return false
	
	var dir_arrays = scan_for_dirs(directory, true, include_hidden)
	for array in dir_arrays:
		array.reverse()
		for dir in array:
			var dir_access = DirAccess.open(dir)
			dir_access.include_hidden = include_hidden
			var files = dir_access.get_files()
			for f in files:
				var file_path = dir.path_join(f)
				DirAccess.remove_absolute(file_path)
			DirAccess.remove_absolute(dir)
	
	var dir_access = DirAccess.open(directory)
	dir_access.include_hidden = include_hidden
	var files = dir_access.get_files()
	for file in files:
		var path = directory.path_join(file)
		DirAccess.remove_absolute(path)
	
	return true


static func _case_insensitive_compare(a: String, b: String) -> int:
	var a_lower = a.to_lower()
	var b_lower = b.to_lower()
	if a_lower < b_lower:
		return true
	else:
		return false

static func sort_file_paths_dirs_first(a: String, b: String) -> int:
	var a_is_dir = a.get_extension() == ""
	var b_is_dir = b.get_extension() == ""
	
	if a_is_dir and not b_is_dir:
		return true  # a comes before b
	elif not a_is_dir and b_is_dir:
		return false  # b comes before a
	else:
		return a < b  # Sort alphabetically if both are files or both are directories


static func write_to_json(data:Variant,path:String,access=FileAccess.WRITE) -> bool:
	if not DirAccess.dir_exists_absolute(path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var data_string = JSON.stringify(data,"\t")
	var json_file = FileAccess.open(path, access)
	return json_file.store_string(data_string)


static func read_from_json(path:String,access=FileAccess.READ) -> Dictionary:
	var json_read = JSON.new()
	var json_load = FileAccess.open(path, access)
	if json_load == null:
		print("Couldn't load JSON: ", path)
		return {}
	var json_string = json_load.get_as_text()
	var err = json_read.parse(json_string)
	if err != OK:
		print("Couldn't load JSON, error: ", err)
		return {}
	
	return json_read.data


static func hash_string(text:String):
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	var hash = ctx.finish()
	var hash_encode = hash.hex_encode()
	return hash_encode

static func create_dir(file_path:String):
	if not DirAccess.dir_exists_absolute(file_path):
		DirAccess.make_dir_recursive_absolute(file_path)

static func copy_file(from:String, to:String, overwrite:bool=false) -> Error:
	if not overwrite:
		if FileAccess.file_exists(to):
			return ERR_ALREADY_EXISTS
	var base_dir:String = to.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	var err = DirAccess.copy_absolute(from, to)
	return err

static func uid_to_path(uid:String):
	if not uid.begins_with(_UID):
		return uid
	var id = ResourceUID.text_to_id(uid)
	if ResourceUID.has_id(id):
		return ResourceUID.get_id_path(id)
	return ""

static func path_to_uid(path:String):
	if path.begins_with(_UID):
		return path
	var uid = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path))
	if uid == _UID_INVALID:
		uid = path
	return uid


static func uid_invalid(uid:String):
	return uid == _UID_INVALID

static func file_exists(path_or_uid:String, current_script:Script=null, print_err:=false):
	if not path_or_uid.is_absolute_path():
		if is_instance_valid(current_script):
			var dir = current_script.resource_path.get_base_dir()
			path_or_uid = dir.path_join(path_or_uid)
		else:
			if print_err:
				printerr("Not absolute path provided in file exists.")
			return false
	if path_or_uid.begins_with(_UID):
		path_or_uid = uid_to_path(path_or_uid)
		if path_or_uid == "":
			if print_err:
				printerr("Invalid UID: %s" % path_or_uid)
			return false
	return FileAccess.file_exists(path_or_uid)

static func load_config_file(path:String):
	var config = ConfigFile.new()
	var err = config.load(path)
	if err != OK:
		print(err)
		return
	return config

static func replace_text_in_file(file_path, replace, with):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var lines = []
		while not file.eof_reached():
			var line = file.get_line()
			lines.append(line)
		file.close()
		file = FileAccess.open(file_path, FileAccess.WRITE)  # Open for writing
		if file:
			for line in lines:
				if line.find(replace) > -1:
					line = line.replace(replace, with)
				file.store_line(line)
				
			file.close() 


static func get_relative_path(from_path: String, to_path: String) -> String:
	var from_dir = from_path.get_base_dir()
	var from_parts: PackedStringArray = from_dir.trim_prefix("/").split("/")
	var to_parts: PackedStringArray = to_path.trim_prefix("/").split("/")
	# If a path was just "/", the split results in ["'"], so we clear it.
	if from_parts.size() == 1 and from_parts[0] == "":
		from_parts = []
	if to_parts.size() == 1 and to_parts[0] == "":
		to_parts = []
	# 3. Find the length of the common root path.
	# We iterate while the components of both paths match.
	var common_path_len = 0
	while (common_path_len < from_parts.size() and
		common_path_len < to_parts.size() and
		from_parts[common_path_len] == to_parts[common_path_len]):
		common_path_len += 1
	
	var relative_parts: Array = []
	var num_dirs_up = from_parts.size() - common_path_len
	for i in range(num_dirs_up):
		relative_parts.append("..")
	
	var remaining_to_parts = to_parts.slice(common_path_len, to_parts.size())
	relative_parts.append_array(remaining_to_parts)
	
	if relative_parts.is_empty():
		return "."
	else:
		var final_string = ""
		final_string = "/".join(relative_parts)
		return final_string

static func path_from_relative(path:String, current_file_path:String) -> String:
	if path.is_absolute_path():
		return path
	var current_dir = current_file_path.get_base_dir()
	var full_path = current_dir.path_join(path)
	var simplified = full_path.simplify_path()
	if not simplified.is_absolute_path():
		printerr("UFile - path_to_relative: Could not simplify path: %s -> %s" % [path, current_file_path])
	return simplified

static func get_plugin_exported_path(path_or_name:String, new_file:=false, print_err:=true) -> String:
	print("File doesn't exists, attempted to find %s. THIS METHOD IS DEPRECATED YOU SHOULD NOT SEE THIS" % path_or_name)
	return ""
	#var script_dir = _get_script_dir()
	#var file_name = path_or_name.get_file()
	#var script_rel_path = script_dir.path_join(file_name)
	#var new_path = ""
	#if new_file:
		#return script_rel_path
	#else:
		#if FileAccess.file_exists(path_or_name):
			#new_path = path_or_name
		#else:
			#if FileAccess.file_exists(script_rel_path):
				#new_path = script_rel_path
			#else:
				#if print_err:
					#print("File doesn't exists, attempted to find %s %s" % [path_or_name, script_rel_path])
	#
	#return new_path

static func relative_file_exists(path_or_name:String) -> bool: # DEPRECATED
	return plugin_exported_file_exists(path_or_name)

static func plugin_exported_file_exists(path_or_name:String) -> bool:
	var dir = _get_script_dir()
	var rel_path = dir.path_join(path_or_name.get_file())
	return FileAccess.file_exists(rel_path)


static func _get_script_dir() -> String:
	var script = new()
	return script.get_script().resource_path.get_base_dir()

static func get_dir_contents(dir_path:String, construct_path:=false, show_hidden:=false, printerr:=false):
	var dir_access = DirAccess.open(dir_path)
	if dir_access:
		dir_access.include_hidden = show_hidden
		var files = dir_access.get_files()
		var dirs = dir_access.get_directories()
		if not construct_path:
			return {"files":files, "dirs":dirs}
		var file_paths = []
		var dir_paths = []
		for f in files:
			var path = dir_path.path_join(f)
			file_paths.append(path)
		for d in dirs:
			var path = dir_path.path_join(d) + "/"
			dir_paths.append(path)
		return {"files":file_paths, "dirs":dir_paths}
	elif printerr:
		printerr("Could not open dir - error %s: %s" % [DirAccess.get_open_error(), dir_path])
	return {"files":[], "dirs":[]}


static func is_file_in_directory(file_path: String, dir_path: String) -> bool:
	var absolute_file_path = ProjectSettings.globalize_path(file_path)
	var absolute_dir_path = ProjectSettings.globalize_path(dir_path)
	# 2. Ensure the directory path ends with a separator.
	#    This is crucial to prevent false positives where directory names are prefixes
	#    of other directory names (e.g., "folder" and "folder_plus").
	if not absolute_dir_path.ends_with("/"):
		absolute_dir_path += "/"
	# 3. A path cannot be a child of itself.
	if absolute_file_path == absolute_dir_path:
		return false
	# 4. The file path must begin with the fully resolved directory path.
	return absolute_file_path.begins_with(absolute_dir_path)

static func is_dir_in_or_equal_to_dir(file_path: String, dir_path: String) -> bool:
	var absolute_file_path = ProjectSettings.globalize_path(file_path)
	var absolute_dir_path = ProjectSettings.globalize_path(dir_path)
	if not absolute_file_path.ends_with("/"):
		absolute_file_path += "/"
	if not absolute_dir_path.ends_with("/"):
		absolute_dir_path += "/"
	#if absolute_file_path == absolute_dir_path:
		#return true
	return absolute_file_path.begins_with(absolute_dir_path)

static func ensure_dir_slash(path):
	if not path.ends_with("/"):
		path += "/"
	return path

static func get_dir(path:String):
	var original_path = path
	if path.ends_with("://"):
		return path
	path = path.trim_suffix("/")
	path = path.get_base_dir()
	return ensure_dir_slash(path)

static func path_is_root(path:String):
	if path.ends_with("://"):
		return true
	if path == "/":
		return true
	return false

static func path_in_res(path:String):
	return ProjectSettings.localize_path(path).begins_with("res://")

static func get_file_size(path: String, format:=true) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return "Unknown"
	
	var bytes = file.get_length()
	if not format:
		return bytes
	bytes = float(bytes)
	
	if bytes < 1024:
		return "%.0f B" % bytes
	elif bytes < 1024 * 1024:
		return "%.2f KiB" % (bytes / 1024)
	elif bytes < 1024 * 1024 * 1024:
		return "%.2f MiB" % (bytes / (1024 * 1024))
	else:
		return "%.2f GiB" % (bytes / (1024 * 1024 * 1024))
