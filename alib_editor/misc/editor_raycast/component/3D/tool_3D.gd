extends "res://addons/_lib/brohd/alib_runtime/controller/viewport_raycast/component/base/tool_base.gd"

const EditorRaycast3D = ALibEditor.Singleton.EditorRaycast3D

func _init() -> void:
	_register_self()


func _register_self():
	var path = get_script().resource_path
	EditorRaycast3D.register_tool(path, self)

func _unregister_self():
	var path = get_script().resource_path
	EditorRaycast3D.unregister_tool(path)

func clean_up():
	_unregister_self()
	_clean_up()

func _clean_up():
	pass

func _get_viewport_manager():
	return EditorRaycast3D.get_instance()

## Returns dictionary with "position" and "normal" or null if not valid raycast
func _get_last_raycast_result():
	return EditorRaycast3D.get_last_raycast_result()

## Returns Transform3D or null if not valid raycast
func _get_raycast_transform(apply_randomize:=false):
	return EditorRaycast3D.get_transformed_raycast_result(apply_randomize)

func _visual_instance_raycast(cursor_node=null, ignore_nodes:=[]):
	return EditorRaycast3D.visual_instance_raycast(cursor_node, ignore_nodes)

func get_current_viewport():
	return EditorRaycast3D.get_current_viewport()

func set_as_current_tool():
	EditorRaycast3D.set_current_tool(self)

func enable(state:bool):
	EditorRaycast3D.set_enabled(state)

func draw_cursor():
	pass

func remove_cursor():
	pass
