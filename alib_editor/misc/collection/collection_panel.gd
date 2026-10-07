extends VBoxContainer

const CollectionContainer = preload("res://addons/_lib/brohd/collections/class/collection_container.gd")

var right_click_handler:UtilR.Nodes.PopupMenus.Placer
var collection_container:CollectionContainer

var _dock_data:Dictionary

func get_dock_data():
	var data = {}
	if collection_container.current_collection_valid():
		data[Data.CURRENT_COLLECTION] = collection_container.current_collection.get_collection_name()
	data[Data.LAYOUT] = collection_container.get_layout()
	return data

func set_dock_data(data:Dictionary):
	_dock_data = data


func _ready() -> void:
	_build_nodes()
	
	var current_collection = _dock_data.get(Data.CURRENT_COLLECTION)
	if current_collection != null:
		collection_container.set_current_collection_by_name(current_collection)
	collection_container.set_layout(_dock_data.get(Data.LAYOUT, true))

func _build_nodes():
	if is_instance_valid(collection_container):
		return
	
	right_click_handler = UtilR.Nodes.PopupMenus.Placer.new()
	add_child(right_click_handler)
	
	collection_container = CollectionContainer.new()
	name = "Collection"
	#collection_container.vertical_layout
	collection_container.vertical_layout = true
	collection_container.single_row = false
	add_child(collection_container)
	collection_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_container.collection_button_pressed.connect(_on_collections_button_pressed)
	collection_container.left_clicked.connect(_on_left_clicked)
	collection_container.right_clicked.connect(_on_right_clicked)


func _on_left_clicked():
	pass

func _on_right_clicked():
	var options = UtilR.Nodes.PopupMenus.Placer.Options.new()
	options.add_option("Remove Asset(s)", collection_container.remove_item.bind(collection_container.get_selected_indexes()), ["Clear"])
	right_click_handler.display_popup(options)


func _on_collections_button_pressed():
	var options = get_collections_options(collection_container)
	right_click_handler.display_on_control(options, collection_container.collections_button)


static func get_collections_options(_collection_container:CollectionContainer):
	var options = UtilR.Nodes.PopupMenus.Placer.Options.new()
	var collections = _collection_container.get_collections()
	if not collections.is_empty():
		for collection in collections:
			var _name:String = collection.get_collection_name()
			var icons = ["Load"]
			for i in range(_name.get_slice_count("/")):
				icons.append(null)
			options.add_option("Load/" + _name, _collection_container.set_current_collection.bind(collection), icons)
	
	if not _collection_container.current_collection_valid():
		options.add_option("Save New Collection", _collection_container.save_collection, ["Save"])
	
	if _collection_container.item_list.item_count > 0:
		options.add_option("New/From Current", _collection_container.unload_current_collection.bind(true), ["New", null])
	options.add_option("New/Empty", _collection_container.unload_current_collection.bind(false), ["New", null])
	
	if not collections.is_empty():
		for collection in collections:
			var _name:String = collection.get_collection_name()
			var icons = ["Remove"]
			for i in range(_name.get_slice_count("/")):
				icons.append(null)
			options.add_option("Delete/" + _name, _collection_container.erase_collection.bind(collection), icons)
	
	return options


class Data:
	const CURRENT_COLLECTION = &"collection_panel.data.current_collection"
	const LAYOUT = &"collection_panel.data.layout"
