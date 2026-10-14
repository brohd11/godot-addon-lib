extends RefCounted
#! namespace ALibRuntime class TreeHelperBase
const UTree = preload("uid://byxrrav3r3afw") # u_tree.gd

var tree_node:Tree = null
var item_dict:= {}
var data_dict:= {}
var parent_item = null

#var selected_items:= []
#var selected_item_paths:= []

var filtered_item_paths:= []

var updating:= false
var multi_selected_flag:= false

var show_item_preview := true

var folder_icon
var folder_color

signal multi_item_selected
signal mouse_double_clicked
signal mouse_left_clicked
signal mouse_middle_clicked
signal mouse_right_clicked


func _init(_tree_node:Tree, _parent_item=null, _item_dict=null, _data_dict=null, print_err:=true):
	tree_node = _tree_node
	if _parent_item != null:
		parent_item = _parent_item
	if _item_dict != null:
		item_dict = _item_dict
	if _data_dict != null:
		data_dict = _data_dict
	else:
		tree_node.item_collapsed.connect(_on_item_collapsed)
	
	if print_err:
		if not tree_node.allow_rmb_select:
			print("TreeHelper - Tree.allow_rmb_select not set to true.")
		if not tree_node.select_mode == Tree.SELECT_MULTI:
			print("TreeHelper - Tree.select_mode not set to Tree.SELECT_MULTI.")
		if not tree_node.allow_reselect:
			print("TreeHelper - Tree.allow_reselect not set to true.")
	
	connect_mouse_signals()
	_set_folder_icon_img()

func get_tree_item(path:String):
	if item_dict.has(path):
		return item_dict.get(path)
	if path.ends_with("/"):
		var check = path.trim_suffix("/")
		if item_dict.has(check):
			return item_dict.get(check)

func select_paths(paths:Array, deselect_current:=true):
	if deselect_current:
		tree_node.deselect_all()
	
	for path in paths:
		var item = item_dict.get(path) as TreeItem
		if item:
			item.select(0)

func get_selected_paths():
	return _get_selected(false)


func get_selected_tree_items(): # possibly use get_selected and get_next_selected to get items instead of caching
	return _get_selected()
	#return selected_items

func _get_selected(items:=true):
	var _selected_items = []
	var _selected_paths = []
	var sel = tree_node.get_selected()
	if is_instance_valid(sel):
		var first_path = get_path_from_item(sel)
		if first_path:
			_selected_items.append(sel)
			_selected_paths.append(first_path)
		sel = tree_node.get_next_selected(null) # this selects the first selected in tree to iterate over all
		while is_instance_valid(sel):
			var sel_path = get_path_from_item(sel)
			if sel_path and not sel_path in _selected_paths:
				_selected_items.append(sel)
				_selected_paths.append(sel_path)
			sel = tree_node.get_next_selected(sel)
	
	#print(_selected_items, _selected_paths)
	if items:
		return _selected_items
	else:
		return _selected_paths

func get_filtered_paths():
	return filtered_item_paths



func connect_mouse_signals():
	tree_node.multi_selected.connect(_on_multi_selected)
	tree_node.item_mouse_selected.connect(_on_item_mouse_selected)
	tree_node.item_activated.connect(_on_item_activated)

func clear_items_keep_paths():
	item_dict.clear()
	#selected_items.clear()
	tree_node.clear()

func clear_items():
	item_dict.clear()
	#selected_items.clear()
	#selected_item_paths.clear()
	tree_node.clear()

func clear_selection():
	tree_node.deselect_all()
	#selected_items.clear()
	#selected_item_paths.clear()

func new_file_path(file_path, root_dir="", file_data=null):
	var local_path:String = file_path.get_slice(root_dir,1)
	if root_dir == "":
		local_path = file_path
	if local_path.begins_with("/"):
		local_path = local_path.trim_prefix("/")
	if local_path.ends_with("/"):
		local_path = local_path.trim_suffix("/")
	
	var is_folder = file_path.ends_with("/")
	var folder_slice_count = local_path.get_slice_count("/")
	
	var working_path = root_dir
	var last_item:TreeItem = parent_item
	for i in range(folder_slice_count):
		var current_slice = local_path.get_slice("/",i)
		working_path = working_path.path_join(current_slice)
		var path_key = working_path
		if i < folder_slice_count - 1 or is_folder:
			path_key += "/"
		var slice_item
		if item_dict.has(path_key):
			slice_item = item_dict.get(path_key)
		else:
			slice_item = tree_node.create_item(last_item)
			slice_item.set_text(0,current_slice)
			
			var item_metadata = {Keys.METADATA_PATH: path_key}
			slice_item.set_metadata(0, item_metadata)
			_set_folder_icon(path_key, slice_item)
			if data_dict != null: # not sure how to implement without a ton of args
				var collapsed = true
				var data = data_dict.get(path_key)
				if data:
					collapsed = data.get(Keys.METADATA_COLLAPSED, true)
				slice_item.collapsed = collapsed
				data_dict[path_key] = {Keys.METADATA_COLLAPSED: collapsed}
			
			item_dict[path_key] = slice_item
			# meta data
		
		last_item = slice_item
	
	if file_data and not is_folder:
		_set_item_icon(last_item, file_data)
	
	return last_item


func update_tree_items(filtering, filter_callable, root_dir="res://"):
	if not filtering:
		filtered_item_paths.clear()
		for path in item_dict.keys():
			var runtime_data = data_dict.get(path)
			if not runtime_data:
				continue
			var item = item_dict.get(path) as TreeItem
			if not is_instance_valid(item):
				continue
			item.visible = true
			item.collapsed = runtime_data.get(Keys.METADATA_COLLAPSED)
		
		return false
	updating = true
	
	
	var vis_files = _get_visible_filter_files(filter_callable)
	for path:String in vis_files:
		var is_dir = path.ends_with("/")
		var path_tail = path.get_slice(root_dir,1)
		var work_path = root_dir
		var slice_count = path_tail.get_slice_count("/")
		for i in range(slice_count):
			var slice = path_tail.get_slice("/", i)
			work_path = work_path.path_join(slice)
			var check_path = work_path
			if i != slice_count - 1:
				if not check_path.ends_with("/"):
					check_path = check_path + "/"
			var item = item_dict.get(check_path)
			if not item:
				continue
			
			item.visible = true
	
	var root_item = tree_node.get_root()
	if not is_instance_valid(root_item):
		return true
	root_item.visible = true
	root_item.set_collapsed_recursive(false)
	updating = false
	return true

func _get_visible_filter_files(filter_callable:Callable):
	var vis_files = []
	for path:String in item_dict.keys():
		var item = item_dict.get(path) as TreeItem
		if not item:
			continue
		if path.get_extension() == "":
			if DirAccess.dir_exists_absolute(path):
				item.visible = false
				continue
		if not filter_callable.call(path):
			item.visible = false
			
			continue
		vis_files.append(path)
	
	filtered_item_paths = vis_files
	return vis_files

func _on_item_collapsed(item: TreeItem) -> void:
	if updating:
		return
	var metadata = item.get_metadata(0)
	if not metadata:
		return
	var item_path = metadata.get(Keys.METADATA_PATH)
	data_dict[item_path] = {Keys.METADATA_COLLAPSED: item.collapsed}


func uncollapse_items(items=null, item_collapse_callable=null):
	if items == null:
		items = get_selected_tree_items()
	if item_collapse_callable != null:
		UTree.uncollapse_items(items, item_collapse_callable)
	else:
		UTree.uncollapse_items(items, _on_item_collapsed)

func show_tree_item(item:TreeItem):
	if not is_instance_valid(item):
		return
	tree_node.set_selected(item,0)
	
	var item_parent:TreeItem = item.get_parent()
	while item_parent:
		item_parent.collapsed = false
		item_parent = item_parent.get_parent()
	
	tree_node.scroll_to_item(item, true)
	tree_node.set_selected(item,0)
	
	tree_node.queue_redraw()


func _on_item_activated():
	#var selected_item = tree_node.get_selected()
	#var data = selected_item.get_metadata(0)
	#if data == null:
		#return
	_mouse_double_clicked()

func _on_item_mouse_selected(_mouse_position: Vector2, mouse_button_index: int) -> void:
	if "HelperInst" in tree_node: #^ will be deleted
		tree_node.HelperInst.ABInstSignals.file_tree_selected.emit(self)
	
	#var _selected_items = get_selected_tree_items()
	#if _selected_items.is_empty():
		#return
	
	if mouse_button_index == 1:
		await tree_node.get_tree().process_frame
		_mouse_left_clicked()
	if mouse_button_index != 2:
		return
	
	#var selected_item = _selected_items[0]
	#var data = selected_item.get_metadata(0)
	#if not data:
		#return
	#_mouse_right_clicked(data)
	
	_mouse_right_clicked({})



func _on_multi_selected(_item: TreeItem, _column: int, _selected: bool) -> void:
	if multi_selected_flag:
		return
	else:
		multi_selected_flag = true
		await tree_node.get_tree().process_frame
		multi_selected_flag = false
	
	#var _selected_items = get_selected_tree_items()
	#if not _selected_items.size() > 0:
		#return
	#var selected_item = _selected_items[0]
	#var meta = selected_item.get_metadata(0)
	#if meta == null:
		#return
	
	multi_item_selected.emit()
	



#overide

func _set_folder_icon_img():
	#folder_icon = EditorInterface.get_base_control().get_theme_icon("Folder", &"EditorIcons")
	#folder_color = EditorInterface.get_base_control().get_theme_color("folder_icon_color", "FileDialog")
	#ab_lib.ABTree.get_folder_icon_and_color()
	pass

func _set_folder_icon(_file_path, slice_item):
	slice_item.set_icon(0, folder_icon)
	slice_item.set_icon_modulate(0, folder_color)


func _set_item_icon(_last_item, _file_data):
	pass

func _mouse_left_clicked():
	mouse_left_clicked.emit()

func _mouse_right_clicked(_data):
	mouse_right_clicked.emit()

func _mouse_double_clicked():
	mouse_double_clicked.emit()

static func create_item_meta(file_path:String):
	return {Keys.METADATA_PATH: file_path}

static func get_path_from_item(item:TreeItem):
	var meta = item.get_metadata(0)
	if meta is Dictionary:
		return meta.get(Keys.METADATA_PATH)
	elif meta is String:
		return meta

class Keys:
	const METADATA_PATH = &"item_path"
	const METADATA_COLLAPSED = &"collapsed"
