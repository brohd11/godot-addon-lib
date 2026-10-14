@tool
#! namespace ALibRuntime.UICustom class SplitWrapper
extends Container

@export var vertical: bool = false:
	set(v):
		vertical = v
		if _is_native_supported and is_instance_valid(_native_split):
			_native_split.vertical = vertical

var _is_native_supported: bool = false
var _native_split: SplitContainer = null
var _managed_controls: Array[Control] = []

func _init():
	var v_info = Engine.get_version_info()
	_is_native_supported = (v_info.major == 4 and v_info.minor >= 6) or v_info.major > 4
	
	if _is_native_supported:
		_native_split = SplitContainer.new()
		_native_split.vertical = vertical
		_native_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_native_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(_native_split)

func _notification(what):
	if what == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			if c is Control:
				fit_child_in_rect(c, Rect2(Vector2.ZERO, size))

func add_split(control: Control) -> void:
	if _is_native_supported:
		_native_split.add_child(control)
		return
		
	if _managed_controls.is_empty():
		add_child(control)
	else:
		var last_control = _managed_controls.back()
		var parent = last_control.get_parent()
		var sibling_index = last_control.get_index()
		
		parent.remove_child(last_control)
		
		var new_split = SplitContainer.new()
		new_split.vertical = vertical
		new_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		parent.add_child(new_split)
		if parent is SplitContainer:
			parent.move_child(new_split, sibling_index)
			
		new_split.add_child(last_control)
		new_split.add_child(control)
		
	_managed_controls.append(control)
	
	if not control.tree_exiting.is_connected(_on_control_exiting): # Connect tree_exiting to handle queue_free() automatically
		control.tree_exiting.connect(_on_control_exiting.bind(control))

func remove_split(control: Control) -> void:
	if _is_native_supported:
		if control.get_parent() == _native_split:
			_native_split.remove_child(control)
		return

	if not control in _managed_controls:
		return

	_managed_controls.erase(control)
	
	if control.tree_exiting.is_connected(_on_control_exiting):
		control.tree_exiting.disconnect(_on_control_exiting.bind(control))

	var parent = control.get_parent()
	parent.remove_child(control)

	if parent != self and parent is SplitContainer:
		_heal_split_tree(parent)


func _on_control_exiting(control: Control) -> void:
	if _is_native_supported:
		return
	
	if is_queued_for_deletion(): # wrapper is being freed, do nothing
		return
	
	if not control.is_queued_for_deletion(): # the control isn't queued for deletion, it's just being moved/removed
		return # only want to heal the tree if called queue_free()

	_managed_controls.erase(control)
	var parent = control.get_parent()
	
	if parent == self:
		return
		
	if parent is SplitContainer:
		_heal_split_tree.call_deferred(parent)


func _heal_split_tree(split_to_remove: SplitContainer) -> void:
	if not is_instance_valid(split_to_remove):
		return
		
	var grandparent = split_to_remove.get_parent()
	if not is_instance_valid(grandparent):
		return
		
	var split_index = split_to_remove.get_index()
	
	var surviving_child: Control = null
	for c in split_to_remove.get_children():
		# The dead control is either already gone, or caught by this check
		if not c.is_queued_for_deletion():
			surviving_child = c
			break
			
	if surviving_child:
		split_to_remove.remove_child(surviving_child)
		grandparent.add_child(surviving_child)
		
		if grandparent is SplitContainer:
			grandparent.move_child(surviving_child, split_index)
			
	split_to_remove.queue_free()
