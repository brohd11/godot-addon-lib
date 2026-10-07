@tool
extends PanelContainer

const CollectionSingleton = preload("res://addons/_lib/brohd/collections/collection_singleton.gd")

var viewport:Viewport
var get_preview_callable

var right_click_handler: UtilR.Nodes.PopupMenus.Placer

var current_collection:CollectionSingleton.CollectionManager.CollectionBase
var collection_manager:= CollectionSingleton.get_manager(CollectionSingleton.CollectionType.STANDARD)

var vertical_layout:= false
var single_row:= true

var split_container
var button_container:BoxContainer
var item_list:ItemList
#^ buttons

var collections_button:Button
var layout_button:Button


#^ icons
var collections_icon:Texture2D
var layout_icon:Texture2D
var default_icon:Texture2D
var ui_scale:float = 1

var _item_list_sel_flag:=false

signal collection_button_pressed
signal left_clicked
signal right_clicked

func _ready() -> void:
	_build_nodes()

func set_layout(vertical:bool):
	vertical_layout = vertical
	split_container.vertical = vertical_layout
	button_container.vertical  = not vertical_layout
	_set_button_text(collections_button, collections_button.tooltip_text)
	_set_button_text(layout_button, layout_button.tooltip_text)

func get_layout():
	return vertical_layout

func _on_vp_resized():
	if not is_instance_valid(viewport): return
	var new_size = Vector2(viewport.get_parent().size.x * 0.6, 64)
	custom_minimum_size = new_size

func resize_item_list():
	_resize_item_list.call_deferred()

func _resize_item_list():
	if item_list.item_count == 0:
		return
	item_list.custom_minimum_size.y = item_list.get_item_rect(0, false).size.y + (4 * ui_scale)


func _on_item_clicked(idx, _pos, mouse_button):
	if mouse_button == 1:
		#_on_left_click.call_deferred()
		pass
	elif mouse_button == 2:
		if not idx in item_list.get_selected_items():
			item_list.select(idx)
		right_clicked.emit()


func _on_item_multi_select(_idx:int, _selected:bool):
	if _item_list_sel_flag:
		return
	_item_list_sel_flag = true
	await get_tree().process_frame
	left_clicked.emit()
	_item_list_sel_flag = false


func _sort_items(ascending:=true): #^ this no longer works, but it would make sense to move to collection
	#var items = _get_current_item_data()
	#item_list.clear()
	item_list.sort_items_by_text()
	if not ascending:
		var items = get_current_item_paths()
		items.reverse()
		item_list.clear()
		for path in items:
			_add_item(path)
		
		resize_item_list()
		_save_current_collection()


func get_current_item_data():
	var data = {}
	for i in range(item_list.item_count):
		data[i] = item_list.get_item_metadata(i)
	return data

func get_current_item_paths():
	return get_current_item_data().values()

func get_selected_paths():
	var paths = []
	for i in item_list.get_selected_items():
		paths.append(item_list.get_item_metadata(i))
	return paths

func get_selected_indexes():
	return item_list.get_selected_items()


func _on_tool_belt_get_drag_data(at_position: Vector2):
	var idx = item_list.get_item_at_position(at_position)
	if idx == -1:
		return
	var path = item_list.get_item_metadata(idx)
	return {"type":"item_list", "files":[path], "from":item_list, "from_item":idx}

func _on_tool_belt_can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not (data.get("type", "") == "files" or data.get("type", "") == "item_list"):
		return false
	var valid = false
	var current_paths = get_current_item_paths()
	var files = data.get("files")
	var from = data.get("from")
	if from == item_list:
		if files.size() != 1:
			return false
		var to_item = item_list.get_item_at_position(at_position, true)
		if to_item == -1:
			return false
		if item_list.get_item_metadata(to_item) == files[0]:
			return false
		return true
	
	for f in files:
		if not f in current_paths:
			valid = true
			break
	return valid

func _on_tool_belt_drop_data(at_position: Vector2, data: Variant) -> void:
	var from = data.get("from")
	var item_at_pos = item_list.get_item_at_position(at_position, true)
	if from == item_list:
		var from_item = data.get("from_item")
		_move_item(from_item, item_at_pos)
	else:
		var current_paths = get_current_item_paths()
		var files = data.get("files", [])
		var move_items = item_at_pos != -1
		for path in files:
			if not path in current_paths:
				_add_item(path)
				if move_items:
					print("MOVING %s -> %s" % [item_list.item_count - 1, item_at_pos])
					_move_item(item_list.item_count - 1, item_at_pos, false)
					item_at_pos += 1
		resize_item_list()
		_save_current_collection()


func _add_item(asset_path="", icon=null):
	_add_file_to_collection(asset_path)
	item_list.add_icon_item(icon, true)
	var idx = item_list.item_count - 1
	if icon == null:
		_queue_preview(asset_path, idx)
		icon = default_icon
	item_list.set_item_text(idx, asset_path.get_file().get_basename())
	item_list.set_item_metadata(idx, asset_path)

func _move_item(from_idx, to_idx, save:=true):
	item_list.move_item(from_idx, to_idx)
	if current_collection == null:
		return
	current_collection.move_file(from_idx, to_idx)
	if save:
		_save_current_collection()

func remove_item(idxes:Array):
	idxes.reverse()
	for i in idxes:
		_remove_file_from_collection(item_list.get_item_metadata(i))
		item_list.remove_item(i)
	_save_current_collection()


#^ collection

func get_collections():
	return collection_manager.get_collections()





func _add_file_to_collection(file_path):
	if current_collection == null: return
	current_collection.new_file(file_path)

func _remove_file_from_collection(file_path):
	if current_collection == null: return
	current_collection.remove_file(file_path)

func _on_collections_button_pressed():
	collection_button_pressed.emit()

func _on_collections_updated():
	_load_current_collection()

func current_collection_valid():
	return collection_manager.collection_valid(current_collection)

func get_current_collection_name():
	if current_collection_valid():
		return current_collection.get_collection_name()

func set_current_collection_by_name(_name:String):
	current_collection = collection_manager.get_collection(_name)
	if current_collection == null:
		print("Could not get collection: %s" % _name)
	
	set_current_collection(current_collection)

func set_current_collection(collection):
	current_collection = collection
	if is_instance_valid(collection):
		_set_button_text(collections_button, current_collection.get_collection_name())
	_load_current_collection()

func _load_current_collection():
	if not current_collection_valid():
		_set_button_text(collections_button, _COLLECTIONS)
		current_collection = null
		return
	
	_refresh_current_collection()
	item_list.clear()
	for path in current_collection.get_file_paths():
		_add_item(path)
	
	resize_item_list()

func unload_current_collection(keep_items:bool=false):
	set_current_collection(null)
	if not keep_items:
		item_list.clear()


func _refresh_current_collection():
	current_collection = collection_manager.refresh_collection(current_collection)

func save_collection():
	if current_collection_valid():
		_save_current_collection()
	else:
		_save_new_collection()

func _save_current_collection():
	if current_collection_valid():
		collection_manager.save_collection(current_collection)
		_refresh_current_collection()

func _save_new_collection():
	var new_collection = await CollectionSingleton.new_collection_dialog(CollectionSingleton.CollectionType.STANDARD)
	if new_collection == null: return
	for path in get_current_item_paths():
		new_collection.new_file(path)
	
	collection_manager.save_collection(new_collection)
	set_current_collection(new_collection)

func erase_collection(collection):
	collection_manager.erase_collection(collection)


func _build_nodes():
	if is_instance_valid(right_click_handler):
		return
	right_click_handler = UtilR.Nodes.PopupMenus.Placer.new()
	add_child(right_click_handler)
	_get_editor_values()
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(_event):accept_event())
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 64)
	_set_style_box()
	
	
	split_container = BoxContainer.new()
	add_child(split_container)
	split_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_container.vertical = vertical_layout
	
	button_container = BoxContainer.new()
	split_container.add_child(button_container)
	button_container.vertical = not vertical_layout
	button_container.size_flags_horizontal = Control.SIZE_FILL
	button_container.size_flags_vertical = Control.SIZE_FILL
	
	collections_button = _new_button("", collections_icon, _on_collections_button_pressed)
	button_container.add_child(collections_button)
	_set_button_text(collections_button, _COLLECTIONS)
	
	layout_button = _new_button("", layout_icon, _on_layout_button_pressed)
	button_container.add_child(layout_button)
	_set_button_text(layout_button, _LAYOUT)
	
	
	item_list = ItemList.new()
	split_container.add_child(item_list)
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.select_mode = ItemList.SELECT_MULTI
	item_list.max_columns = 0
	item_list.icon_mode = ItemList.ICON_MODE_TOP
	item_list.multi_selected.connect(_on_item_multi_select)
	item_list.item_clicked.connect(_on_item_clicked)
	item_list.max_text_lines = 2
	item_list.fixed_column_width = 64
	
	#item_list.allow_reselect = true
	#item_list.allow_rmb_select = true
	
	item_list.custom_minimum_size.y = 64
	
	if single_row:
		item_list.wraparound_items = false
	item_list.set_drag_forwarding(_on_tool_belt_get_drag_data, _on_tool_belt_can_drop_data, _on_tool_belt_drop_data)
	
	collection_manager.collections_updated.connect(_on_collections_updated)
	
	_on_vp_resized()
	if is_instance_valid(viewport):
		viewport.size_changed.connect(_on_vp_resized)

#^ misc buttons

func _on_layout_button_pressed():
	set_layout(not vertical_layout)




#^ utils

func _set_button_text(button:Button, text:String):
	button.tooltip_text = text
	if vertical_layout:
		button.text = text
	else:
		button.text = ""

func _set_style_box():
	var sb = StyleBoxFlat.new()
	var ed_interface = Engine.get_singleton("EditorInterface")
	if is_instance_valid(ed_interface):
		sb.bg_color = ed_interface.get_editor_theme().get_color("base_color", "Editor")
	sb.set_content_margin_all(int(4 * ui_scale))
	add_theme_stylebox_override("panel", sb)

func _get_editor_values():
	var ed_interface = Engine.get_singleton("EditorInterface")
	if not is_instance_valid(ed_interface):
		return
	
	if not is_instance_valid(collections_icon):
		collections_icon = ed_interface.get_editor_theme().get_icon("ResourcePreloader", "EditorIcons")
	if not is_instance_valid(layout_icon):
		layout_icon = ed_interface.get_editor_theme().get_icon("Panels3Alt", "EditorIcons")
	if not is_instance_valid(default_icon):
		default_icon = ed_interface.get_editor_theme().get_icon("Object", "EditorIcons")
	
	if is_equal_approx(ui_scale, 1):
		ui_scale = ed_interface.get_editor_scale()


func _queue_preview(asset_path:String, item_index:int):
	var ed_interface = Engine.get_singleton("EditorInterface")
	if not is_instance_valid(ed_interface):
		return
	ed_interface.get_resource_previewer().queue_resource_preview(asset_path, self, &"_preview_generated", item_index)

func _preview_generated(path, preview, _thumbnail, item:int):
	if preview == null:
		if not path.ends_with(".tscn"):
			return
		if not get_preview_callable is Callable:
			return
		preview = get_preview_callable.call(path)
		if preview == null:
			return
	
	item_list.set_item_icon(item, preview)

func _new_button(text:="", icon=null, callable=null):
	var button = Button.new()
	button.theme_type_variation = &"FlatButton"
	button.flat = true
	button.text = text
	if icon != null:
		button.icon = icon
	if callable != null:
		button.pressed.connect(callable)
	return button

const _COLLECTIONS = "Collections"
const _LAYOUT = "Layout"
