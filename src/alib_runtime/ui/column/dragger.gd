extends Control

const ClickState = preload("uid://c8l2o7cw3fklh") #! resolve UtilR.Inputs.ClickState

var dragging: bool = false
var target_control: Control
var mouse_in_dragger:= false

var vertical:=false
var min_size:float=200

var grabber_icon:Texture2D

signal drag_ended

func _ready():
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	if vertical:
		mouse_default_cursor_shape = Control.CURSOR_VSPLIT
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		mouse_default_cursor_shape = Control.CURSOR_HSPLIT
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	
	mouse_entered.connect(func(): mouse_in_dragger = true; queue_redraw())
	mouse_exited.connect(func(): mouse_in_dragger = false; queue_redraw())
	
	if vertical:
		custom_minimum_size.y = 4
	else:
		custom_minimum_size.x = 4
	
	
	var ed_interface = Engine.get_singleton(&"EditorInterface")
	if ed_interface:
		if vertical:
			grabber_icon = ed_interface.get_editor_theme().get_icon("v_grabber", "SplitContainer")
			custom_minimum_size.y *= ed_interface.get_editor_scale()
		else:
			grabber_icon = ed_interface.get_editor_theme().get_icon("h_grabber", "SplitContainer")
			custom_minimum_size.x *= ed_interface.get_editor_scale()


func _draw():
	if mouse_in_dragger or dragging:
		if grabber_icon:
			var pos = size / 2
			draw_texture(grabber_icon, pos)

func _gui_input(event):
	var click_state = ClickState.get_click_state(event) as ClickState.State
	if event is InputEventMouseButton:
		if click_state == ClickState.State.RMB_PRESSED:
			target_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
			target_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			target_control.custom_minimum_size = Vector2()
			dragging = false
			return
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging:
				target_control.custom_minimum_size = target_control.size
			else:
				drag_ended.emit()
				queue_redraw()
	
	if dragging and event is InputEventMouseMotion:
		if target_control:
			if vertical:
				target_control.size_flags_vertical = Control.SIZE_FILL
				var new_height = target_control.custom_minimum_size.y + event.relative.y
				new_height = max(min_size, new_height)
				print(new_height)
				target_control.custom_minimum_size.y = new_height
			else:
				var new_width = target_control.custom_minimum_size.x + event.relative.x
				new_width = max(min_size, new_width)
				target_control.custom_minimum_size.x = new_width
