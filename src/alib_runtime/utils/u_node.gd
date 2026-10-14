extends RefCounted
#! namespace ALibRuntime.Utils class UNode

const BACKPORTED = 100

static func recursive_set_owner(node:Node, current_root:Node, new_root:Node) -> void:
	if node.owner == current_root:
		node.owner = new_root
	
	if node.get_child_count() > 0:
		var children = node.get_children()
		for c in children:
			recursive_set_owner(c, current_root, new_root)

## Includes the root node.
static func recursive_get_nodes(node: Node) -> Array:
	var children_array = []
	children_array.append(node) # Add the current node to the array
	
	if node.get_child_count() > 0:
		var children = node.get_children()
		for c in children:
			children_array.append_array(recursive_get_nodes(c))
	
	return children_array


static func find_first_node_of_type(node: Node,type:Variant):
	if is_instance_of(node, type):
		return node 
	
	for child in node.get_children():
		var next_node = find_first_node_of_type(child, type)
		if next_node:
			return next_node
	
	return null  # No node of type found in this branch

static func get_all_nodes_of_type(node:Node, type:Variant):
	var nodes_of_type = []
	if is_instance_of(node, type):
		nodes_of_type.append(node)
	
	for child in node.get_children():
		nodes_of_type.append_array(get_all_nodes_of_type(child, type))
	return nodes_of_type
	


static func connect_signal(callable:Callable, _signal:Signal):
	if not _signal.is_connected(callable):
		_signal.connect(callable)

static func disconnect_signal(callable:Callable, _signal:Signal):
	if _signal.is_connected(callable):
		_signal.disconnect(callable)

static func get_signal_callable(object:Object, signal_name:StringName, callable_name:StringName):
	for data in object.get_signal_connection_list(signal_name):
		var callable = data.get("callable") as Callable
		if callable and callable.get_method() == callable_name:
			return callable

static func make_scene_local(node:Node):
	if node.scene_file_path == "":
		return
	var editor_interface = Engine.get_singleton("EditorInterface")
	if not is_instance_valid(editor_interface):
		return
	var edited_scene_root = editor_interface.get_edited_scene_root()
	node.scene_file_path = ""
	recursive_set_owner(node, node, edited_scene_root)


static func has_static_method_compat(method:String, script:Object) -> bool:
	if BACKPORTED >= 4:
		return method in script
	
	var base_script = script
	while base_script != null:
		var method_list = base_script.get_script_method_list()
		for data in method_list:
			var name = data.get("name")
			if name == method:
				return true
		base_script = base_script.get_base_script()
	
	var class_list = ClassDB.get_class_list()
	var script_type = script.get_instance_base_type()
	if script_type in class_list:
		var methods = ClassDB.class_get_method_list(script_type)
		for m in methods:
			var name = m.get("name")
			if name == method:
				return true
	
	return false
