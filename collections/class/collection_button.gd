extends Button

const CollectionSingleton = preload("res://addons/_lib/brohd/collections/collection_singleton.gd")

var _right_click_handler := ClickHandlers.RightClickHandler.new()
var current_collection:CollectionSingleton.CollectionManager.CollectionBase

var collection_manager:= CollectionSingleton.get_manager(CollectionSingleton.CollectionType.STANDARD)

func _ready() -> void:
	collection_manager.collections_updated.connect(_on_collections_updated)
	pressed.connect(_on_collections_pressed)

func _on_collections_updated():
	_load_current_collection()

func _set_current_collection(collection):
	current_collection = collection
	if is_instance_valid(collection):
		text = current_collection.get_collection_name()
	_load_current_collection()

func _load_current_collection():
	if not collection_manager.collection_valid(current_collection):
		text = "Collections"
		current_collection = null
		return
	
	_refresh_current_collection()
	
	#for path in current_collection.get_file_paths():
		#_add_tool_belt_item(path)


func _add_file_to_collection(file_path):
	if current_collection == null: return
	current_collection.new_file(file_path)

func _remove_file_from_collection(file_path):
	if current_collection == null: return
	current_collection.remove_file(file_path)


func _on_collections_pressed():
	var options = ClickHandlers.RightClickHandler.Options.new()
	var collections = collection_manager.collections
	if not collections.is_empty():
		for collection in collections.values():
			options.add_option(collection.get_collection_name(), _set_current_collection.bind(collection))
	
	if is_instance_valid(current_collection) and current_collection.get_collection_size() > 0:
	#if item_list.item_count > 0:
		options.add_option("New Collection/From Current", _new_collection.bind(true), ["Add", null])
	options.add_option("New Collection/Empty", _new_collection.bind(false), ["Add", null])
	
	if not collections.is_empty():
		for collection in collections.values():
			var _name:String = collection.get_collection_name()
			var icons = ["Remove"]
			for i in range(_name.get_slice_count("/")):
				icons.append(null)
			options.add_option("Delete/" + _name, _erase_collection.bind(collection), icons)

	_right_click_handler.display_on_control(options, self)

func _new_collection(use_current:bool=false):
	var new_collection = await CollectionSingleton.new_collection_dialog(CollectionSingleton.CollectionType.STANDARD)
	if new_collection == null: return
	#if not collection_manager.collection_valid(current_collection):
	if use_current:
		for path in current_collection.get_file_paths():
		#for path in _get_current_item_paths():
			new_collection.new_file(path)
	
	collection_manager.save_collection(new_collection)
	_set_current_collection(new_collection)

func _erase_collection(collection):
	collection_manager.erase_collection(collection)

func _refresh_current_collection():
	current_collection = collection_manager.refresh_collection(current_collection)

func _save_current_collection():
	if collection_manager.collection_valid(current_collection):
		collection_manager.save_collection(current_collection)
		_refresh_current_collection()
