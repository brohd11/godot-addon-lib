extends "res://addons/_lib/brohd/alib_runtime/controller/viewport_raycast/component/base/intercept_base.gd"

const EditorRaycast3D = preload("res://addons/_lib/brohd/alib_editor/misc/editor_raycast/editor_raycast_3D.gd")

func _get_viewport_manager():
	return EditorRaycast3D.get_instance()

func _get_current_tool():
	return _get_viewport_manager().current_tool
