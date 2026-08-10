#! namespace Singletons.RefCount
extends Singletons.Base


static func _get_singleton_type() -> SingletonType:
	return SingletonType.REF_COUNT

static func _get_instance(script:Script, print_err:=true):
	var instance = _get_singleton_node_or_null(script, script._get_singleton_node_path(), false)
	if is_instance_valid(instance):
		return instance
	
	if print_err:
		print("Could not get %s instance." % script.get_singleton_name())

static func _register_node(script:Script, node):
	var instance = _get_singleton_node_or_null(script, script._get_singleton_node_path(), true, node)
	instance.instance_refs.append(node)
	return instance

static func _unregister_node(script:Script, node):
	var ins = _get_instance(script, false)
	if not is_instance_valid(ins):
		printerr("Singleton: '%s' has not been instanced yet." % script._get_singleton_name())
		return
	
	ins.instance_refs.erase(node)
	if ins.instance_refs.is_empty():
		ins._all_unregistered_callback()
		ins.queue_free()

## Instance members

var instance_refs = []

#func unregister_node(node):
	#instance_refs.erase(node)
	#if instance_refs.is_empty():
		#_all_unregistered_callback()
		#queue_free()

func _all_unregistered_callback():
	pass

func _init(node):
	pass


## Implement in extended classes

#extends Singletons.RefCount # if the class is not global class else do script path

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
#static func register_node(node:Node):
	#return _register_node(PE_STRIP_CAST_SCRIPT, node)

#static func unregister_node(node:Node):
	#_unregister_node(PE_STRIP_CAST_SCRIPT, node)
#
#static func call_on_ready(callable, print_err:bool=true):
	#_call_on_ready(PE_STRIP_CAST_SCRIPT, callable, print_err)

#func _init(node):
	#pass
#
#func _all_unregistered_callback():
	#pass

#func _get_ready_bool() -> bool:
	#return is_node_ready()
