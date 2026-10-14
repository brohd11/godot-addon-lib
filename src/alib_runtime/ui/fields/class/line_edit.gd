extends HBoxContainer

const UResource = preload("uid://72uu8yngsoht") # u_resource.gd

var line_edit:=LineEdit.new()

func get_text():
	return line_edit.text

func _init(label:="", placeholder:="", icon=null):
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var _label = Label.new()
	_label.text = label
	add_child(_label)
	
	#add_spacer(false)
	
	add_child(line_edit)
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.placeholder_text = placeholder
	if icon is String:
		icon = UResource.load_or_get_icon(icon)
	line_edit.right_icon = icon
