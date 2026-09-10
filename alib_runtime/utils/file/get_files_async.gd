
const SELF = preload("uid://ctsugodrtg3rc") # get_files_async.gd
const UFile = preload("uid://bl33psa06nv1e") #! resolve ALibRuntime.Utils.UFile.Methods

var _found_files:= PackedStringArray()

var _search_dir:String = ""
var _progress_callback:Callable
var _include_dirs:=false
var _file_types:=[]
var _show_hidden:=false

var _abort_operation:=false

signal search_complete

static func open(search_dir:String, progress_callback:Callable) -> SELF:
	if not DirAccess.dir_exists_absolute(search_dir):
		printerr("Could not open dir: ", search_dir)
		return
	var ins = new()
	ins._search_dir = search_dir
	ins._progress_callback = progress_callback
	return ins

func set_settings(include_dirs:=false, file_types:Array=[], show_hidden:=false):
	_include_dirs = include_dirs
	_file_types = file_types
	_show_hidden = show_hidden

func get_cached_files():
	return _found_files

func was_cancelled():
	return _abort_operation



func get_files(dirs_per_frame:=200) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(_search_dir):
		printerr("Could not open dir: ", _search_dir)
		return PackedStringArray()
	_found_files.clear()
	var filter = not _file_types.is_empty()
	var root = Engine.get_main_loop().root
	var rest_counter = 0
	var queue = [_search_dir]
	while not queue.is_empty() and not _abort_operation:
		var current_dir = queue.pop_front()
		var dir_content = UFile.get_dir_contents(current_dir, true, _show_hidden)
		var files = dir_content.get("files", [])
		if not filter:
			_found_files.append_array(files)
		else:
			for path in files:
				if path.get_extension() in _file_types:
					_found_files.append(path)
		
		var dirs = dir_content.get("dirs", [])
		if _include_dirs:
			_found_files.append_array(dirs)
		queue.append_array(dirs)
		
		rest_counter += 1
		if rest_counter >= dirs_per_frame:
			rest_counter = 0
			_progress_callback.call()
			await root.get_tree().process_frame
	
	search_complete.emit()
	if _abort_operation:
		return PackedStringArray()
	return _found_files

func cancel():
	_abort_operation = true
