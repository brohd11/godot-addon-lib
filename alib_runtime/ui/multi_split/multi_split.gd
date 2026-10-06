extends Control

const Dragger = preload("res://addons/_lib/brohd/alib_runtime/ui/column/dragger.gd")

static func get_v_split(scrollable:=false):
	var instance = new()
	instance.vertical = true
	if scrollable:
		instance.scroll_container = ScrollContainer.new()
		instance.scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		instance.scroll_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		instance.add_child(instance.scroll_container)
		instance.box_container = VBoxContainer.new()
		instance.scroll_container.add_child(instance.box_container)
		instance.box_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		instance.box_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		
	else:
		instance.box_container = VBoxContainer.new()
		instance.box_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		instance.add_child(instance.box_container)
	
	
	
	return instance


static func get_h_split():
	
	
	pass

static func _set_separation(control:Container):
	
	pass

var vertical = false
var scroll_container:ScrollContainer
var box_container:BoxContainer
var start_split_size:float=200
var min_split_size:float=200

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func new_item(control:Control):
	box_container.add_child(control)
	if vertical:
		#control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		control.custom_minimum_size.y = min_split_size
	var dragger = Dragger.new()
	dragger.target_control = control
	dragger.vertical = vertical
	dragger.min_size = min_split_size
	
	box_container.add_child(dragger)
	
	pass
