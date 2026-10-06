#! namespace ALibEditor.Nodes class FileSystem

const PopupID = preload("res://addons/_lib/brohd/alib_editor/utils/src/editor_nodes/filesystem/popup_id.gd")
const NUTree = preload("uid://coqq638olix8k") #! resolve ALibRuntime.NodeUtils.NUTree

static func get_tree():
	return EditorNodeRef.get_registered(EditorNodeRef.Nodes.FILESYSTEM_TREE)

static func get_tree_line_edit():
	var tree = EditorNodeRef.get_registered(EditorNodeRef.Nodes.FILESYSTEM_TREE)
	return NUTree.get_line_edit(tree)

static func populate_popup(calling_node:Node):
	var popup = EditorNodeRef.get_registered(EditorNodeRef.Nodes.FILESYSTEM_POPUP)
	if calling_node.get_window() != popup.get_window():
		popup.reparent(calling_node.get_window().get_child(0))
	var tree = EditorNodeRef.get_registered(EditorNodeRef.Nodes.FILESYSTEM_TREE)
	
	tree.item_mouse_selected.emit(Vector2.ZERO, 2)
	popup.hide()
	popup.reparent(EditorInterface.get_file_system_dock())

static func populate_bottom_popup(calling_node:Control):
	var popup = EditorNodeRef.get_registered(EditorNodeRef.Nodes.FILESYSTEM_BOTTOM_POPUP)
	if calling_node.get_window() != popup.get_window():
		popup.reparent(calling_node.get_window().get_child(0))
	var tree = EditorNodeRef.get_registered(EditorNodeRef.Nodes.FILESYSTEM_TREE)
	
	tree.item_mouse_selected.emit(Vector2.ZERO, 2)
	popup.hide()
	popup.reparent(EditorInterface.get_file_system_dock())

static func get_popup():
	return EditorNodeRef.get_registered(EditorNodeRef.Nodes.FILESYSTEM_POPUP)

static func get_create_popup():
	return EditorNodeRef.get_registered(EditorNodeRef.Nodes.FILESYSTEM_CREATE_POPUP)


static func scan_fs_dock(file_system_item_dict, file_data_dict, preview_object=null): #^ this could move to filesystem singleton?
	file_system_item_dict.clear()
	file_data_dict.clear()
	
	var fs_tree: Tree = get_tree()
	if not fs_tree:
		printerr("FileSystemDock Tree not found.")
		return
	var root: TreeItem = fs_tree.get_root()
	if not root:
		printerr("FileSystemDock Tree has no root item.")
		return
	
	_recursive_scan_tree_item(root, file_system_item_dict, file_data_dict, preview_object)


static func _recursive_scan_tree_item(item: TreeItem, file_system_item_dict, file_data_dict, preview_object=null):
	if item == null:
		return
	var file_path = item.get_metadata(0)
	if file_path != null:
		if not file_path == "res://":
		#if file_path.ends_with("/") and not file_path == "res://":
			file_path = file_path.trim_suffix("/")
		file_system_item_dict[file_path] = item
		
		var icon = item.get_icon(0)
		var file_type = EditorInterface.get_resource_filesystem().get_file_type(file_path)
		if file_type == "":
			file_type = "Folder"
		
		var file_data = {
			"item_path": file_path,
			"File Icon": icon,
			"File Type": file_type,
			"File Custom Icon": false,
		}
		if preview_object != null:
			EditorInterface.get_resource_previewer().queue_resource_preview(file_path, preview_object, "_receive_previews", file_data)
		file_data_dict[file_path] = file_data
		
	
	var child: TreeItem = item.get_first_child()
	while child != null:
		_recursive_scan_tree_item(child, file_system_item_dict, file_data_dict, preview_object)
		child = child.get_next() # Move to the next sibling
