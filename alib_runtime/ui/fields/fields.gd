
const UResource = preload("uid://72uu8yngsoht") # u_resource.gd

const LineEditField = preload("res://addons/_lib/brohd/alib_runtime/ui/fields/class/line_edit.gd")

static func get_bool(name="", icon=null):
	#var hbox = HBoxContainer.new()
	var check_box = CheckBox.new()
	#hbox.add_child(check_box)
	check_box.text = name
	#check_box.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if icon is String:
		icon = UResource.load_or_get_icon(icon)
	check_box.icon = icon
	check_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return check_box

static func get_line_edit(label="", placeholder="", icon=null):
	return LineEditField.new(label, placeholder, icon)
