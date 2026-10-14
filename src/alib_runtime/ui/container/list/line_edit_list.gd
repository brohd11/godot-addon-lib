#! namespace ALibRuntime.UICustom class LineEditList
extends PanelContainer

const NUMarginContainer = preload("uid://t8ajrsqdbrva") # nu_margin.gd
const UNode = preload("uid://dsywt12xnn7oh") # u_node.gd

var _title_background:PanelContainer
var title_hbox:HBoxContainer
var _title_label:Label
var _add_entry_button:Button
var _main_vbox:VBoxContainer
var entries_target:VBoxContainer

var _new_entry_default_text = ""

var show_folder_button:=false
var _flat_buttons:=false

var entry_folder_icon
var entry_clear_icon

signal folder_button_pressed(entry_line:EntryLine)


func _init() -> void:
	_set_icons()
	_build_list()

func _set_icons():
	entry_clear_icon = Util.get_editor_icon("Clear")
	entry_folder_icon = Util.get_editor_icon("Folder")

func _build_list():
	var main_marg = MarginContainer.new()
	NUMarginContainer.set_margins(main_marg, 4)
	add_child(main_marg)
	main_marg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_main_vbox = VBoxContainer.new()
	main_marg.add_child(_main_vbox)
	_main_vbox.add_theme_constant_override("seperation", 2)
	_main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	set_minimum_size()
	
	_title_background = PanelContainer.new()
	_title_background.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_main_vbox.add_child(_title_background)
	_title_background.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	title_hbox = HBoxContainer.new()
	_title_background.add_child(title_hbox)
	title_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_create_title_bar()
	
	var scroll_container = ScrollContainer.new()
	_main_vbox.add_child(scroll_container)
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	entries_target = VBoxContainer.new()
	scroll_container.add_child(entries_target)
	entries_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_target.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _create_title_bar():
	title_hbox.add_spacer(false)
	_title_label = Label.new()
	title_hbox.add_child(_title_label)
	title_hbox.add_spacer(false)
	_add_entry_button = Button.new()
	_add_entry_button.pressed.connect(new_entry)
	set_add_entry_icon(Util.get_editor_icon("Add"))
	
	_add_entry_button.hide()
	title_hbox.add_child(_add_entry_button)
	
	title_hbox.hide()

func set_add_entry_icon(icon):
	Util.set_button_icon(_add_entry_button, icon, "Add")

func set_title_background(stylebox:StyleBox):
	_title_background.add_theme_stylebox_override("panel", stylebox)

func set_background(stylebox:StyleBox):
	add_theme_stylebox_override("panel", stylebox)

func set_title(new_title:String):
	title_hbox.show()
	_title_label.text = new_title

func show_add_entry_button():
	title_hbox.show()
	_add_entry_button.show()

func set_minimum_size(new_minimum_size:=Vector2(400, 200)):
	_main_vbox.custom_minimum_size = new_minimum_size

func set_new_entry_default_text(text):
	_new_entry_default_text = text

func set_button_flat():
	_flat_buttons = true
	var buttons = UNode.get_all_nodes_of_type(self, Button)
	for b:Button in buttons:
		Util.set_button_flat(b)

func new_entry(text=_new_entry_default_text):
	var _new_entry = EntryLine.new(text)
	_new_entry.set_clear_icon(entry_clear_icon)
	_new_entry.set_folder_icon(entry_folder_icon)
	if _flat_buttons:
		_new_entry.set_button_flat()
	
	if show_folder_button:
		_new_entry.show_folder_button()
		_new_entry.folder_button.pressed.connect(func():folder_button_pressed.emit(_new_entry))
	entries_target.add_child(_new_entry)
	return _new_entry

func clear():
	for entry:EntryLine in entries_target.get_children():
		entry.queue_free()

func set_entries(entries:PackedStringArray):
	clear()
	for entry in entries:
		new_entry(entry)

func get_entries(include_empty:=false, include_duplicates:=false):
	var entries = []
	for entry:EntryLine in entries_target.get_children():
		var text = entry.get_text()
		if include_empty or text != "":
			if include_duplicates or not text in entries:
				entries.append(text)
	return entries



class EntryLine extends HBoxContainer:
	var _entry_line:LineEdit
	var folder_button:Button
	var _clear_button:Button
	
	func _init(text, use_spacers:=false) -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		_entry_line = LineEdit.new()
		add_child(_entry_line)
		folder_button = Button.new()
		add_child(folder_button)
		_clear_button = Button.new()
		add_child(_clear_button)
		
		if use_spacers:
			add_spacer(true)
			add_spacer(false)
		
		folder_button.focus_mode = Control.FOCUS_NONE
		folder_button.hide()
		
		set_folder_icon(null)
		set_clear_icon(null)
		
		_clear_button.focus_mode = Control.FOCUS_NONE
		_clear_button.pressed.connect(queue_free)
		_entry_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_entry_line.text = text
	
	func show_folder_button():
		folder_button.show()
	
	func disable():
		_entry_line.editable = false
		folder_button.disabled = true
		_clear_button.disabled = true
	
	func set_clear_icon(icon):
		Util.set_button_icon(_clear_button, icon, "Clear")
	
	func set_folder_icon(icon):
		Util.set_button_icon(folder_button, icon, "File")
	
	func set_button_flat():
		Util.set_button_flat(_clear_button)
		Util.set_button_flat(folder_button)
	
	func get_text():
		return _entry_line.text

	func set_text(new_text:String):
		_entry_line.text = new_text


class Util:
	static func get_editor_icon(icon_name:String):
		var editor_interface = Engine.get_singleton("EditorInterface")
		if is_instance_valid(editor_interface):
			return editor_interface.get_editor_theme().get_icon(icon_name, "EditorIcons")
	
	static func set_button_icon(button:Button, icon, fallback_text, show_text:=false):
		if icon == null:
			button.text = fallback_text
		else:
			button.icon = icon
			if show_text:
				button.text = fallback_text
			else:
				button.text = ""
	
	static func set_button_flat(button:Button):
		button.flat = true
		button.theme_type_variation = &"FlatButton"
