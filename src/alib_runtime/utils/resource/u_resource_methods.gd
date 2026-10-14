
const UFile = preload("uid://bl33psa06nv1e") #! resolve ALibRuntime.Utils.UFile.Methods

static func save_resource_to_path(res:Resource,path:String, name_overide:String="") -> void:
	if name_overide == "":
		res.resource_name = path.get_file().get_basename()
	else:
		res.resource_name = name_overide
	ResourceSaver.save(res, path)
	res.take_over_path(path)


static func load_or_get_icon(name_or_path:String):
	if FileAccess.file_exists(name_or_path):
		return load(name_or_path)
	var editor_interface = Engine.get_singleton(&"EditorInterface")
	if is_instance_valid(editor_interface):
		var theme = editor_interface.get_editor_theme()
		if theme.has_icon(name_or_path, &"EditorIcons"):
			return theme.get_icon(name_or_path, &"EditorIcons")
	printerr("Could not find icon: %s" % name_or_path)


static func instance_scene_or_script(path:String):
	if not FileAccess.file_exists(path):
		print("Could not instance, file doesn't exist: %s" % path)
		return
	var res = load(path)
	if res is PackedScene:
		var ins = res.instantiate()
		return ins
	elif res is Script:
		var ins = res.new()
		return ins
	else:
		print("Could not instance file: %s, file is: %s" % [path, type_string(typeof(res))])

static func get_object_file_path(obj:Object) -> String:
	if obj is Node:
		if obj.scene_file_path != "":
			return obj.scene_file_path
	if obj is Resource:
		return obj.resource_path
	else:
		var script = obj.get_script()
		if script:
			return script.resource_path
	return ""



static func get_resource_script_class(path:String):
	if path.get_extension() == "tres":
		return _get_resource_script_class_file_access(path)
	var res = load(path) as Resource
	var script = res.get_script() as GDScript
	if script == null:
		return ""
	return script.get_global_name()

static func _get_resource_script_class_file_access(file_path: String) -> String:
	var result:String = ""
	var f:FileAccess = UFile.get_file_access(file_path)
	if f:
		var header:String = f.get_line()
		if "script_class=" in header:
			var start_index:int = header.find("script_class=") + 14 # Length of 'script_class="'
			var end_index:int = header.find('"', start_index)
			if end_index != -1:
				result = header.substr(start_index, end_index - start_index)
	return result

static func ensure_fresh_load(resource:Resource, cache_hint:=ResourceLoader.CACHE_MODE_IGNORE_DEEP) -> Resource:
	if not UFile.path_in_res(resource.resource_path):
		return ResourceLoader.load(resource.resource_path, "", cache_hint)
	return resource
