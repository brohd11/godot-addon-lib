#! namespace Singletons.Base
extends Node

const PLUGIN_EXPORTED = false

const UFile = preload("uid://bl33psa06nv1e") #! resolve ALibRuntime.Utils.UFile.Methods

enum SingletonType {
	STANDARD,
	REF_COUNT
}

static var _singleton_node_parents:Dictionary = {}

static func get_singleton_name() -> String:
	return "SingletonBase"

static func _get_singleton_node_path() -> String: # <t> will check if node is of type using Node.get_class()
	return "EditorNode<t>/EditorSingletons"

static func _get_singleton_type() -> SingletonType:
	return SingletonType.STANDARD

static func _instance_valid(script:Script) -> bool:
	var root = Engine.get_main_loop().root
	var instance = _get_singleton_node_or_null(script, script._get_singleton_node_path(), false)
	if is_instance_valid(instance):
		return true
	return false

static func _get_instance(script:Script):
	var root = Engine.get_main_loop().root
	return _get_singleton_node_or_null(script, script._get_singleton_node_path())


static func _get_singleton_node_or_null(script:Script, node_path:String, create:=true, registered_node=null):
	var root = Engine.get_main_loop().root
	var current_node:Node = root
	
	if _singleton_node_parents.has(node_path):
		current_node = _singleton_node_parents.get(node_path)
	else:
		var all_parts = node_path.split("/", false)
		var path_parts = []
		for part in all_parts:
			if part != "":
				path_parts.append(part)
		
		for part:String in path_parts:
			var child_node
			if part.ends_with("<t>"):
				part = part.trim_suffix("<t>")
				for c in current_node.get_children():
					if c.get_class() == part:
						child_node = c
						break
			else:
				child_node = current_node.get_node_or_null(part)
			
			if not is_instance_valid(child_node):
				if not create:
					return null
				child_node = Node.new()
				child_node.name = part
				current_node.add_child(child_node)
			
			current_node = child_node
		
		_singleton_node_parents[node_path] = current_node
	
	
	var singleton_name = script.get_singleton_name()
	var singleton = current_node.get_node_or_null(singleton_name)
	if not is_instance_valid(singleton):
		if not create:
			return null
		if PLUGIN_EXPORTED:
			script = _get_latest_version(script)
		if registered_node == null:
			singleton = script.new()
		else:
			singleton = script.new(registered_node)
		current_node.add_child(singleton)
		singleton.name = singleton_name
	
	return singleton


#static func call_on_ready(callable):
	#pass

static func _call_on_ready(script:Script, callable:Callable, print_err:bool=true):
	var singleton_name:String = script.get_singleton_name()
	var instance
	var singleton_type = script._get_singleton_type()
	if singleton_type == SingletonType.REF_COUNT:
		var root = Engine.get_main_loop().root
		var count = 0
		while not is_instance_valid(instance):
			instance = script._get_instance(script, false)
			count += 1
			await root.get_tree().process_frame
			if count == 512:
				if print_err:
					printerr("Timed out getting ref count singleton: %s, make sure singleton has been registered." % singleton_name)
				return
	elif singleton_type == SingletonType.STANDARD:
		instance = script._get_instance(script)
	
	if instance.has_method("_get_ready_bool"):
		while not instance._get_ready_bool():
			await instance.get_tree().process_frame
	else:
		while not instance.is_node_ready():
			await instance.get_tree().process_frame
	
	callable.call()

static func _get_latest_version(script:Script, dir_to_check:String="res://addons"):
	var singleton_name = script.get_singleton_name()
	var global_classes = ProjectSettings.get_global_class_list()
	for dict in global_classes:
		var _class = dict.get("class")
		if _class != singleton_name:
			continue
		var path = dict.get("path")
		var global_script = load(path)
		if not global_script.has_method("get_singleton_name"):
			continue # check that script actually is a singleton, in case of name collision
		return global_script
	
	if not DirAccess.dir_exists_absolute(dir_to_check):
		return script
	var directories = DirAccess.get_directories_at(dir_to_check)
	
	var candidates = []
	for dir in directories:
		var module_file_path = dir_to_check.path_join(dir).path_join(".export_data")
		if not FileAccess.file_exists(module_file_path):
			continue
		var module_data = UFile.read_from_json(module_file_path)
		var modules = module_data.get("singleton_modules", [])
		for single_module_data in modules:
			var _name = single_module_data.get("name", "")
			if not _name == singleton_name:
				continue
			candidates.append(single_module_data)
			break
	
	if candidates.is_empty():
		return script
	
	var highest_version = candidates[0]
	for i in range(1, candidates.size()):
		if _is_version_greater(candidates[i].version, highest_version.version):
			highest_version = candidates[i]
	
	var new_script = load(highest_version.path)
	return new_script

static func _is_version_greater(v1_str: String, v2_str: String) -> bool:
	var v1 = v1_str.split(".")
	var v2 = v2_str.split(".")
	for i in range(3):
		var n1 = int(v1[i]) if i < v1.size() else 0
		var n2 = int(v2[i]) if i < v2.size() else 0
		if n1 > n2: return true
		if n1 < n2: return false
	return false


func _get_ready_bool() -> bool:
	return is_node_ready()

func _init(node:Node=null):
	
	pass


## Implement in extended classes

#extends Singletons.Base # if class_name, use absolute path
#extends "res://addons/addon_lib/brohd/singleton/singleton_base.gd"

# Use 'PE_STRIP_CAST_SCRIPT' to auto strip type casts with plugin exporter, if the class is not a global name
#const PE_STRIP_CAST_SCRIPT = preload("this_file")
#static func get_singleton_name() -> String:
	#return "MySingleton"
#
#static func get_instance() -> PE_STRIP_CAST_SCRIPT:
	#return _get_instance(PE_STRIP_CAST_SCRIPT)
#
#static func instance_valid() -> bool:
	#return _instance_valid(PE_STRIP_CAST_SCRIPT)
#
#static func call_on_ready(callable, print_err:bool=true):
	#_call_on_ready(PE_STRIP_CAST_SCRIPT, callable, print_err)

#func _get_ready_bool() -> bool:
	#return is_node_ready()
