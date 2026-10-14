extends EditorScript


static func generate_theme(file_name:String, mod_callable:Callable, save_to_res:bool=false):
	var paths = EditorInterface.get_editor_paths()
	var save_path = _get_editor_settings_dir().path_join(file_name + ".res")
	if save_to_res:
		save_path = "res://%s.tres" % file_name
	
	var new_theme = mod_callable.call()
	if not new_theme is Theme:
		printerr("Modify callable must return 'Theme'")
		return
	
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	ResourceSaver.save(new_theme, save_path)
	
	if not save_to_res:
		_set_theme(save_path)


static func _get_editor_settings_dir():
	var paths = EditorInterface.get_editor_paths()
	return paths.get_config_dir().path_join("saved_editor_themes")

static func _set_theme(path:String):
	var settings = EditorInterface.get_editor_settings()
	settings.set_setting("interface/theme/custom_theme", path)
	print("Custom theme set.")
