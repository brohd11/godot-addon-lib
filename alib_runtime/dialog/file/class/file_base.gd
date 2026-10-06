extends "res://addons/_lib/brohd/alib_runtime/dialog/base/handler_base.gd"

var file_mode:FileDialog.FileMode

func _init(_root_node=null, current_path="") -> void:
	_set_root_node(_root_node)
	_set_file_mode()
	_create_dialog(current_path)

func _set_file_mode():
	file_mode = FileDialog.FILE_MODE_OPEN_FILE

func _create_dialog(current_path):
	
	dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	if current_path != "":
		dialog.current_path = ProjectSettings.globalize_path(current_path)
	dialog.file_mode = file_mode
	
	if dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		dialog.file_selected.connect(_on_file_selected)
	if dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILES:
		dialog.file_selected.connect(_on_file_selected)
		dialog.files_selected.connect(_on_files_selected)
	elif dialog.file_mode == FileDialog.FILE_MODE_OPEN_DIR:
		dialog.dir_selected.connect(_on_dir_selected)
	elif dialog.file_mode == FileDialog.FILE_MODE_OPEN_ANY:
		dialog.dir_selected.connect(_on_dir_selected)
		dialog.file_selected.connect(_on_file_selected)
	elif dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		dialog.file_selected.connect(_on_file_selected)
	
	dialog.canceled.connect(_on_canceled)
	
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	dialog.size = Vector2i(1000,800)
	
	root_node.add_child(dialog)
	dialog.show()
	
	var cancel_button = dialog.get_cancel_button()
	cancel_button.focus_mode = Control.FOCUS_NONE
	var ok_button = dialog.get_ok_button()
	ok_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ok_button.focus_mode = Control.FOCUS_NONE


func _on_file_selected(file:String):
	_on_confirmed(file)

func _on_files_selected(files:PackedStringArray):
	_on_confirmed(files)

func _on_dir_selected(dir:String):
	_on_confirmed(dir)


func _on_confirmed(path):
	self.handled.emit(path)
	dialog.queue_free()
	
func _on_canceled():
	self.handled.emit(CANCEL_STRING)
	dialog.queue_free()
