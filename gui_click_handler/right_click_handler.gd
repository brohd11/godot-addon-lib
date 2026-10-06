#! namespace ClickHandlers class RightClickHandler
@tool
extends Node

#! import_p PopupHelper,

const UWindow = preload("uid://d1yl3cuumcudy") #! resolve UtilR.Nodes.UWindow
const PopupHelper = preload("res://addons/_lib/brohd/alib_runtime/popup_menu/popup_menu_path_helper.gd")
const MouseHelper = PopupHelper.MouseHelper
const Options = preload("uid://c61qxuau2v0pb") #! resolve ALibRuntime.Popups.Options
const Params = PopupHelper.ParamKeys

var popup:PopupMenu
var mouse_helper:MouseHelper

var hide_popup_with_timer:bool = true

var _custom_id_pressed_callable:Callable

var _click_debounce_timer:float = 0
var _click_debounce_time: float = 0.3

signal popup_hidden

func _ready() -> void:
	if is_part_of_edited_scene():
		return
	_new_popup()

func display_on_control(options:Options, control:Control, offset:=Vector2.ZERO):
	var pos = get_centered_control_position(control)
	if offset != Vector2.ZERO:
		pos += Vector2i(offset)
	return display_popup(options, true, pos)

func display_popup(options, center_popup:=false, position_overide=null):
	if options is Options:
		options = options.get_options()
	if options.is_empty():
		return
	
	if is_instance_valid(popup):
		popup.queue_free()
	_new_popup()
	
	PopupHelper.parse_dict_static(options, popup, _popup_id_pressed, mouse_helper)
	popup.reset_size()
	
	var popup_position = DisplayServer.mouse_get_position()
	if center_popup:
		var offset = _get_popup_offset()
		offset.x = 0
		popup_position -= offset
	else:
		popup_position -= _get_popup_offset()
	
	if position_overide != null:
		if position_overide is Vector2i:
			popup_position = position_overide
		elif position_overide is Vector2:
			popup_position = Vector2i(position_overide)
		else:
			print("Unsupported position overide: ", position_overide)
	
	if center_popup:
		var size_offset = popup.size.x / 2
		popup_position.x -= size_offset
	
	_move_popup(popup_position)
	return popup


func _move_popup(popup_position:Vector2i):
	_set_popup_parent()
	popup.position = popup_position
	popup.popup()

func _new_popup():
	#popup = PopupHelper.new()
	popup = PopupMenu.new()
	popup.wrap_controls = true
	popup.submenu_popup_delay = 0
	#_set_popup_parent()
	mouse_helper = MouseHelper.new(popup, _on_mouse_helper_timeout)
	
	popup.popup_hide.connect(_on_popup_hide)
	
	_return_popup()


func set_custom_id_pressed_callable(callable):
	_custom_id_pressed_callable = callable

func _popup_id_pressed(id:int, _popup:PopupMenu):
	if _custom_id_pressed_callable.is_valid():
		_custom_id_pressed_callable.call(id, _popup)
		return
	
	var metadata = PopupHelper.parse_metadata(id, _popup)
	var callable = metadata.get(Params.CALLABLE)
	if callable is Callable:
		callable.call()


func _on_mouse_helper_timeout():
	if hide_popup_with_timer:
		_hide_popup()

func _on_popup_hide():
	_hide_popup()

func _hide_popup():
	popup_hidden.emit()
	popup.hide()
	_return_popup()





func _get_popup_offset():
	var item_count = popup.item_count
	var size_y = popup.size.y
	var size_per_item = size_y / item_count
	return Vector2i(15, size_per_item * 0.5)

func _set_popup_parent():
	var target_parent = get_window().get_child(0)
	if popup.get_parent() == null:
		target_parent.add_child(popup)
	elif popup.get_window() != get_window():
		popup.reparent(target_parent)



func _return_popup():
	if is_instance_valid(popup.get_parent()):
		popup.reparent(self)
		#popup.get_parent().remove_child(popup)
	else:
		add_child(popup)

#func _remove_popup_from_tree():
	#if is_instance_valid(popup.get_parent()):
		#popup.get_parent().remove_child(popup)

func _process(delta: float) -> void:
	if _click_debounce_timer != 0:
		_click_debounce_timer -= delta
		_click_debounce_timer = clampf(_click_debounce_timer,0,1)


func get_double_click():
	if _click_debounce_timer == 0:
		_click_debounce_timer = _click_debounce_time
		return false
	return true

static func get_centered_control_position(control:Control):
	var button_pos = control.global_position + Vector2(control.size.x / 2 , 0)
	return get_window_offset_position(control, button_pos)

static func get_window_offset_position(control:Control, position:Vector2i):
	var window_pos = UWindow.get_window_global_position(control.get_window(), false)
	return window_pos + position
