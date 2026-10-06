@tool
extends "res://addons/_lib/brohd/alib_runtime/dialog/general/general_dialog.gd"

const Fields = preload("res://addons/_lib/brohd/alib_runtime/ui/fields/fields.gd")
enum FieldType {
	BOOL,
	LINE_EDIT,
	OPTION
}

var _form_build_data = {}
var constructed_data = {}

func _init(form_build_data:Dictionary, _root_node=null) -> void:
	_set_root_node(_root_node)
	_form_build_data = form_build_data
	
	_title = _form_build_data.get(Keys.TITLE, _title)
	default_size = _form_build_data.get(Keys.SIZE, default_size)


func add_bool(_name, icon=null, default:=false, target:TargetSection=TargetSection.BODY):
	_form_build_data[_name] = {
		Keys.TYPE: "bool",
		Keys.ICON: icon,
		Keys.DEFAULT: default,
		Keys.TARGET: target
	}


func show_dialog():
	_build_dialog()
	_build_fields()
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	Engine.get_main_loop().root.add_child(dialog)
	
	var first_field = constructed_data.values()[0]
	if first_field is Fields.LineEditField:
		first_field.line_edit.grab_focus()
	return await handled


func _build_fields():
	for _name in _form_build_data.keys():
		var data = _form_build_data.get(_name)
		if data is not Dictionary:
			continue
		_add_field(_name, data)


func _on_confirmed():
	self.handled.emit(get_data())
	dialog.queue_free()
	
func _on_canceled():
	self.handled.emit(CANCEL_STRING)
	dialog.queue_free()


func get_data():
	var data = {}
	for _name in constructed_data.keys():
		var control = constructed_data[_name]
		var build_data = _form_build_data.get(_name)
		if not build_data:
			continue
		var type = build_data.get(Keys.TYPE)
		var val
		if type == null:
			val = control
		elif type == "bool":
			val = control.button_pressed
		elif type == "LineEdit":
			val = control.get_text()
		data[_name] = val
	
	return data


func add_custom_field(_name, control:Control, target_section:TargetSection=TargetSection.BODY):
	_build_dialog() # ensure this has been setup
	constructed_data[_name] = control
	match target_section:
		TargetSection.HEADER: dialog.header.add_child(control)
		TargetSection.BODY: dialog.body.add_child(control)
		TargetSection.FOOTER: dialog.footer.add_child(control)
	
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _add_field(_name, data):
	var type = data.get(Keys.TYPE)
	var icon = data.get(Keys.ICON)
	var control
	if type == "bool":
		control = Fields.get_bool(_name, icon)
	elif type == "LineEdit":
		var placeholder = data.get("placeholder", "")
		control = Fields.get_line_edit(_name, placeholder, icon)
	
	var target = data.get(Keys.TARGET, TargetSection.BODY)
	match target:
		TargetSection.HEADER: dialog.header.add_child(control)
		TargetSection.BODY: dialog.body.add_child(control)
		TargetSection.FOOTER: dialog.footer.add_child(control)
	
	constructed_data[_name] = control
	return control

static func was_cancelled(result:Variant):
	return result is String and result == CANCEL_STRING

# builders
static func construct_and_display(form_data:Dictionary, _root_node=null):
	var form = new(form_data, _root_node)
	return await form.show_dialog()

class Data:
	#! keys title:String size:Vector2
	static func new_data(params:={}) -> Dictionary:
		return params
	
	#! keys placeholder:String target_section:TargetSection
	static func line_edit(params:={}):
		params["type"] = "LineEdit"
		return params
	
	#! keys default:bool icon target_section:TargetSection
	static func bool(params:={}):
		params["type"] = "bool"
		return params

class Keys:
	const TITLE = &"title"
	const SIZE = &"size"
	const NAME = &"name"
	const ICON = &"icon"
	const TYPE = &"type"
	const DEFAULT = &"default"
	const TARGET = &"target"
