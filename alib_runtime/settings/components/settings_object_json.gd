extends "res://addons/addon_lib/brohd/alib_runtime/settings/components/settings_object_base.gd"

const UFile = preload("uid://bl33psa06nv1e") #! resolve ALibRuntime.Utils.UFile.Methods

func _ensure_file_exists():
	if not FileAccess.file_exists(_file_path):
		DirAccess.make_dir_recursive_absolute(_file_path.get_base_dir())
		UFile.write_to_json({}, _file_path)

func _populate_dict():
	_settings = UFile.read_from_json(_file_path)

func _save_to_file():
	UFile.write_to_json(_settings, _file_path)
