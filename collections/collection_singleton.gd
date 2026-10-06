
extends Singletons.Base

const Form = preload("res://addons/_lib/brohd/alib_runtime/dialog/form/form.gd")



 #Use 'PE_STRIP_CAST_SCRIPT' to auto strip type casts with plugin exporter, if the class is not a global name
const PE_STRIP_CAST_SCRIPT = preload("res://addons/_lib/brohd/collections/collection_singleton.gd")
static func get_singleton_name() -> String:
	return "CollectionSingleton"

static func get_instance() -> PE_STRIP_CAST_SCRIPT:
	return _get_instance(PE_STRIP_CAST_SCRIPT)

static func instance_valid() -> bool:
	return _instance_valid(PE_STRIP_CAST_SCRIPT)

static func call_on_ready(callable, print_err:bool=true):
	_call_on_ready(PE_STRIP_CAST_SCRIPT, callable, print_err)

func _get_ready_bool() -> bool:
	return is_node_ready()




const CollectionManager = preload("res://addons/_lib/brohd/collections/class/collection_manager.gd")
const CollectionBase = CollectionManager.CollectionBase

const COLLECTIONS_DIR = "user://addons/collections/"

enum CollectionType{
	STANDARD,
}

signal collections_updated

var collection_managers:={}

func _init(_node:Node=null):
	var standard_manager = CollectionManager.new()
	standard_manager.collections_dir = COLLECTIONS_DIR.path_join("standard/")
	standard_manager.collections_updated.connect(_on_manager_updated)
	collection_managers[CollectionType.STANDARD] = standard_manager
	
	_load_all_collections()

static func get_manager(collection_type:CollectionType) -> CollectionManager:
	return get_instance()._get_manager(collection_type)

func _get_manager(collection_type:CollectionType):
	var manager = collection_managers.get(collection_type) as CollectionManager
	if not is_instance_valid(manager):
		printerr("Not a valid collection manager: %s" % collection_type)
		return
	return manager

#! keys manager_name:String storage_dir:Dictionary
static func get_named_manager(manager_data:Dictionary) -> CollectionManager:
	return get_instance()._get_named_manager(manager_data)

#! keys i-get_named_manager;
func _get_named_manager(manager_data:Dictionary):
	var man_name:String = manager_data.get(&"manager_name", "un-named")
	if man_name == "un-named" or not man_name.is_valid_filename():
		printerr("Invalid collection manager name::", man_name)
	var storage_dir = manager_data.get(&"storage_dir", COLLECTIONS_DIR.path_join(man_name))
	var manager = collection_managers.get(man_name)
	if not is_instance_valid(manager):
		manager = CollectionManager.new()
		manager.collections_dir = storage_dir
		manager.collections_updated.connect(_on_manager_updated)
		manager.load_all_collections()
		collection_managers[man_name] = manager
	
	if not manager.collections_dir == storage_dir:
		printerr("Requested manager does not match existing signature:")
		printerr("Requested: %s Existing: %s" % [storage_dir, manager.collections_dir])
	
	return manager

func _update_collections():
	print("UPDATING")
	_load_all_collections()
	collections_updated.emit()

func _on_manager_updated():
	collections_updated.emit()


func _load_all_collections():
	for manager:CollectionManager in collection_managers.values():
		manager.load_all_collections()

static func new_collection_dialog(collection_type:CollectionType):
	return await get_instance()._new_collection_dialog(collection_type)

func _new_collection_dialog(collection_type:CollectionType):
	var manager = _get_manager(collection_type)
	if not manager: return
	
	var form = Form.new({
		"title": "New Collection",
		"size": Vector2(400,100) * EditorInterface.get_editor_scale(),
		"New Collection Name":{
			"type":"LineEdit",
			"placeholder":"Enter name..."
		}
	})
	var result = await form.show_dialog()
	if result is String and (result == Form.CANCEL_STRING or result == ""):
		return
	
	var new_name = result.get("New Collection Name")
	new_name = new_name.trim_prefix("/").trim_suffix("/")
	if new_name in manager.collections.keys():
		print("Collection already exists.")
		return
	
	return manager.new_collection(new_name)
