#! namespace ALibEditor.UIHelpers class SetNodeContainer
extends HBoxContainer

const _NOT_VALID_PATH = &"Not valid scene path."

const PluginButton = preload("uid://cwiqk1fttu0sy").PluginButton #! resolve ALibEditor.UIHelpers.Buttons.PluginButton

var _button:Button
var _label:=Label.new()

var _default_text:= ""
var _current_set_node
var _current_node_path:NodePath

var icon=null
var node_type:="Node"
var set_current_node_icon:= false

signal node_set(node)

func get_set_node():
	return _current_set_node

func reset():
	_set_node(null)

func scene_has_current_node_path():
	if not is_instance_valid(_current_set_node):
		return false
	var root = EditorInterface.get_edited_scene_root()
	return root.has_node(_current_node_path) and root.is_ancestor_of(_current_set_node)


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_default_text = "Set Node(%s)" % node_type
	
	_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_button = PluginButton.new("", _on_button_pressed).get_button()
	_button.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_button)
	if icon == null:
		icon = _get_node_icon(node_type)
	_button.icon = icon
	
	add_child(_label)
	_label.text = _default_text

func _on_button_pressed():
	var ed_sel = EditorInterface.get_selection().get_selected_nodes()
	if ed_sel.size() != 1:
		print("Must select 1 node.")
		return
	_set_node_with_signal(ed_sel[0])

func set_node(node:Node):
	_set_node(node)

func _set_node_with_signal(node:Node):
	_set_node(node)
	node_set.emit(node)

func _set_node(node:Node):
	
	if _valid_node(node):
		_current_set_node = node
		_label.text = node.name
		var scene_path = _get_scene_path(node)
		if StringName(scene_path) == _NOT_VALID_PATH:
			_current_node_path = ""
			_label.tooltip_text = ""
		else:
			_current_node_path = scene_path
			_label.tooltip_text = "(scene root)".path_join(scene_path)
		
		if set_current_node_icon:
			_button.icon = _get_node_icon(_current_set_node.get_class())
	else:
		_label.text = _default_text #"Node not valid, " + _default_text
		_label.tooltip_text = ""
		_button.icon = icon
		_current_set_node = null
		_current_node_path = ""

func _get_scene_path(node:Node):
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root.is_ancestor_of(node):
		return _NOT_VALID_PATH
	return scene_root.get_path_to(node)


func _get_node_icon(node_class:String):
	if EditorInterface.get_editor_theme().has_icon(node_class, "EditorIcons"):
		return EditorInterface.get_editor_theme().get_icon(node_class, "EditorIcons")
	else:
		return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var node = _get_single_node(data)
	if not is_instance_valid(node):
		return false
	return ClassDB.is_parent_class(node.get_class(), node_type)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_set_node_with_signal(_get_single_node(data))

func _get_drag_data(_at_position: Vector2) -> Variant:
	#var data = {}
	return # data

func _valid_node(node):
	if not is_instance_valid(node): return false
	return ClassDB.is_parent_class(node.get_class(), node_type)


func _get_nodes_from_data(data):
	var nodes = []
	if data.get("type", "") == "nodes":
		var node_paths = data.get("nodes")
		for node_path in node_paths:
			var node = get_tree().root.get_node_or_null(node_path)
			if node == null:
				continue
			nodes.append(node)
	return nodes

func _get_single_node(data):
	if data.get("type", "") == "nodes":
		var node_paths = data.get("nodes")
		if node_paths.size() == 1:
			return get_tree().root.get_node_or_null(node_paths[0])
