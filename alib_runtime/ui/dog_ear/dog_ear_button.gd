extends Control

const ClickState = preload("res://addons/_lib/brohd/gui_click_handler/click_state.gd")

enum Position {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
}

signal left_clicked
signal right_clicked

var draw_color = Color.WHITE
var _button_position:Position
var _triangle_size = 16 # Size in pixels

var _mouse_in_control:=false

func _init(button_position:Position=Position.TOP_LEFT, triangle_size:float = -1) -> void:
	_button_position = button_position
	if triangle_size > 0:
		_triangle_size = triangle_size
	

func _ready():
	var preset = PRESET_TOP_LEFT
	if _button_position == Position.TOP_RIGHT:
		preset = PRESET_TOP_RIGHT
	
	custom_minimum_size = Vector2(_triangle_size, _triangle_size)
	set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_KEEP_SIZE)
	
	set_draw_color(Color.WHITE)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	

func _on_mouse_entered():
	set_mouse_in_control(true)

func _on_mouse_exited():
	set_mouse_in_control(false)

func set_mouse_in_control(in_control:bool):
	_mouse_in_control = in_control
	queue_redraw()

func set_draw_color(color:Color):
	draw_color = color
	draw_color.a = 0.3
	queue_redraw()

func _draw():
	if not _mouse_in_control:
		return
	
	var points
	if _button_position == Position.TOP_LEFT:
		points = PackedVector2Array([
			Vector2(0, 0),
			Vector2(0, _triangle_size),
			Vector2(_triangle_size, 0)
		])
	elif _button_position == Position.TOP_RIGHT:
		points = PackedVector2Array([
			Vector2(size.x, 0),
			Vector2(size.x, _triangle_size),
			Vector2(size.x - _triangle_size, 0)
		])
	draw_colored_polygon(points, draw_color) # Semi-transparent

# THE MAGIC SAUCE
func _has_point(point) -> bool:
	# This logic defines the clickable area.
	# If this returns false, the mouse event passes through to the control below.
	
	# Logic for a Top-Right Triangle:
	# 1. Check if inside bounding box
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	# 2. Check "Triangular" condition
	var x = point.x 
	var y = point.y
	if _button_position == Position.TOP_LEFT:
		return (x + y) <= _triangle_size
	elif _button_position == Position.TOP_RIGHT:
		return x > (size.x - _triangle_size) + y
	elif _button_position == Position.BOTTOM_LEFT:
		return x <= y
	elif _button_position == Position.BOTTOM_RIGHT:
		return x + y >= _triangle_size
	return false

func _gui_input(event):
	mouse_filter = Control.MOUSE_FILTER_PASS
	var click_state = ClickState.get_click_state(event) as ClickState.State
	if click_state == ClickState.State.LMB_RELEASED:
		if _mouse_in_control:
			left_clicked.emit()
	elif click_state == ClickState.State.RMB_RELEASED:
		right_clicked.emit()
