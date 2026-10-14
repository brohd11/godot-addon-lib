extends Control

enum Corner {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
}

var _corner:Corner
var corner_size = 40 # Size in pixels

func _init(corner:Corner=0) -> void:
	_corner = corner
	pass

func _ready():
	var preset = PRESET_TOP_LEFT
	if _corner == Corner.TOP_RIGHT:
		preset = PRESET_TOP_RIGHT
	
	set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_KEEP_SIZE)
	
	# Ensure this control is on top of the sub-panel content
	# Set custom minimum size to 0 so it doesn't push layouts around
	custom_minimum_size = Vector2(corner_size, corner_size)

func _draw():
	var points
	if _corner == Corner.TOP_LEFT:
		points = PackedVector2Array([
			Vector2(0, 0),
			Vector2(0, corner_size),
			Vector2(corner_size, 0)
		])
	elif _corner == Corner.TOP_RIGHT:
		points = PackedVector2Array([
			Vector2(size.x, 0), # Top Right
			Vector2(size.x, corner_size), # Bottom Right of the corner area
			Vector2(size.x - corner_size, 0) # Top Left of the corner area
		])
	draw_colored_polygon(points, Color(1, 1, 1, 0.5)) # Semi-transparent

# THE MAGIC SAUCE
func _has_point(point):
	# This logic defines the clickable area.
	# If this returns false, the mouse event passes through to the control below.
	
	# Logic for a Top-Right Triangle:
	# 1. Check if inside bounding box
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	# 2. Check "Triangular" condition
	var x = point.x 
	var y = point.y
	if _corner == Corner.TOP_LEFT:
		return (x + y) <= corner_size
	elif _corner == Corner.TOP_RIGHT:
		return x > (size.x - corner_size) + y
	elif _corner == Corner.BOTTOM_LEFT:
		return x <= y
	elif _corner == Corner.BOTTOM_RIGHT:
		return x + y >= corner_size
	return false

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			print("Open Context Menu")
		elif event.button_index == MOUSE_BUTTON_LEFT:
			print("Start Dragging")
