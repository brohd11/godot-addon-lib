#! namespace ALibRuntime.UICustom class FoldContainer
extends PanelContainer

const NUMarginContainer = preload("uid://t8ajrsqdbrva") # nu_margin.gd

var main_vbox = VBoxContainer.new()
var _title_button:= Button.new()
var _sub_vbox = VBoxContainer.new()
var _content_margin:= MarginContainer.new()
var content_vbox:= VBoxContainer.new()

var margin:=4

func _ready() -> void:
	var ed_int = Engine.get_singleton("EditorInterface")
	
	gui_input.connect(_on_gui_input)
	add_child(main_vbox)
	focus_mode = Control.FOCUS_CLICK
	
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if is_instance_valid(ed_int):
		add_theme_stylebox_override("panel", ed_int.get_editor_theme().get_stylebox("panel", "ItemList"))
	
	_title_button.pressed.connect(_on_title_button_pressed)
	main_vbox.add_child(_title_button)
	main_vbox.add_child(_sub_vbox)
	main_vbox.add_theme_constant_override("separation", 0)
	_sub_vbox.add_theme_constant_override("separation", 0)
	_sub_vbox.add_child(_content_margin)
	_content_margin.add_child(content_vbox)
	set_content_margin(margin)
	
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL


func set_content_margin(new_val:int):
	NUMarginContainer.set_margins(_content_margin, new_val)

func _on_title_button_pressed():
	_sub_vbox.visible = not _sub_vbox.visible

func set_title(new_title:String):
	_title_button.text = new_title
	


func get_title():
	return _title_button.text

func set_icon(icon):
	if icon == null:
		return
	_title_button.icon = icon
	_title_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func add_content(content:Control):
	content_vbox.add_child(content)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _on_gui_input(event:InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			grab_focus(true)

func set_folded(state:bool):
	_sub_vbox.visible = not state

func is_folded():
	return not _sub_vbox.visible
