#! namespace ALibRuntime.UICustom class PathBar

extends ScrollContainer

var _hbox:HBoxContainer
var _sections:Array[Button]= []
var _selected:int =-1

signal section_pressed(idx:int)
signal section_right_clicked(idx:int)

var show_arrows:bool =false
var select_on_right_click:bool =false

# theme items
var arrow_icon:Texture2D
var normal_styleboxes:Dictionary[StringName, StyleBox]
var selected_styleboxes:Dictionary[StringName, StyleBox]
var selected_stylebox:StyleBoxFlat
#

func _ready() -> void:
	_set_theme_items()
	
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	
	_hbox = HBoxContainer.new()
	add_child(_hbox)
	_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	#_hbox.add_theme_constant_override("separation", 0)

func get_selected() -> int:
	return _selected

func select_section(index:int, scroll:=true) -> void:
	var sel_section:Button = _get_section(index)
	if not is_instance_valid(sel_section):
		return
	_selected = index
	
	for sec:Button in _sections:
		if sec == sel_section:
			_set_style_boxes(sec, selected_styleboxes)
		else:
			_set_style_boxes(sec, normal_styleboxes)
	
	if scroll:
		await get_tree().process_frame # ensure tabs are drawn, then show
		if is_instance_valid(sel_section):
			ensure_control_visible(sel_section)
	

func get_section_count() -> int:
	return _sections.size()

func add_section(text:String, icon:Texture2D=null) -> void:
	if _hbox.get_child_count() > 0 and show_arrows:
		var texture_rect:TextureRect = TextureRect.new()
		_hbox.add_child(texture_rect)
		texture_rect.texture = arrow_icon
		texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var next_idx:int = _sections.size()
	var button:Button = Button.new()
	_hbox.add_child(button)
	button.text = text
	button.icon = icon
	button.pressed.connect(_on_section_pressed.bind(next_idx))
	button.gui_input.connect(_on_section_gui_input.bind(next_idx))
	
	_sections.append(button)

func set_icon(index:int, icon:Texture2D) -> void:
	var section:Button = _get_section(index)
	if not is_instance_valid(section):
		return
	section.icon = icon

func remove_section(index:int) -> void:
	var previous_arrow:TextureRect
	var section:Button = _sections[index]
	var node_index:int = section.get_index()
	if node_index > 0:
		previous_arrow = _hbox.get_child(node_index - 1)
	
	if previous_arrow is TextureRect:
		_hbox.remove_child(previous_arrow)
		previous_arrow.queue_free()
	
	_hbox.remove_child(section)
	section.queue_free()


func set_section_metadata(index:int, meta:Variant) -> void:
	var section:Button = _get_section(index)
	if not is_instance_valid(section):
		return
	section.set_meta(&"metadata", meta)

func get_section_metadata(index:int) -> Variant:
	var section:Button = _get_section(index)
	if not is_instance_valid(section):
		return
	return section.get_meta(&"metadata", null)

func _get_section(index:int) -> Button:
	if not _sections.size() > index:
		printerr("Could not get section in path bar, index out of range.")
		return
	return _sections[index]

func clear() -> void:
	for c:Node in _hbox.get_children():
		_hbox.remove_child(c)
		c.queue_free()
	_sections.clear()


func _on_section_pressed(idx:int) -> void:
	section_pressed.emit(idx)

func _on_section_gui_input(event:InputEvent, idx:int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MASK_RIGHT and event.pressed:
			if select_on_right_click:
				select_section(idx)
				section_pressed.emit(idx)
			section_right_clicked.emit(idx)


func _set_style_boxes(section:Button, style_box_dict:Dictionary[StringName, StyleBox]) -> void:
	for style_name:StringName in style_box_dict.keys():
		section.add_theme_stylebox_override(style_name, style_box_dict[style_name])

func _set_theme_items() -> void:
	var ed_int:Object = Engine.get_singleton("EditorInterface")
	if not is_instance_valid(ed_int):
		return
	var ed_theme:Theme = ed_int.get_editor_theme()
	if not is_instance_valid(arrow_icon):
		arrow_icon = ed_theme.get_icon(&"PageNext", &"EditorIcons")
	
	for style_name:String in ed_theme.get_stylebox_list(&"Button"):
		if selected_styleboxes.has(style_name):
			continue
		var sb:StyleBoxFlat
		if style_name == &"hover": # makes the hover more subtle on the selected section
			selected_styleboxes[style_name] = selected_styleboxes[&"normal"]
			continue
			#sb = ed_theme.get_stylebox(&"normal", &"Button").duplicate() as StyleBoxFlat
		else:
			sb = ed_theme.get_stylebox(style_name, &"Button").duplicate() as StyleBoxFlat
		#sb.bg_color = sb.bg_color.lightened(0.05)
		#sb.bg_color = sb.bg_color.darkened(0.1)
		sb.set_border_width_all(0)
		
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		selected_styleboxes[style_name] = sb
	
	for style_name:String in ed_theme.get_stylebox_list(&"Button"):
		if normal_styleboxes.has(style_name):
			continue
		var sb:StyleBoxFlat = ed_theme.get_stylebox(style_name, &"Button").duplicate() as StyleBoxFlat
		if style_name == &"normal":
			#sb.draw_center = false
			#sb.bg_color = sb.bg_color.darkened(0.7)
			sb.bg_color = ed_theme.get_color(&"dark_color_1", &"Editor")
		sb.set_border_width_all(0)
		
		
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		
		normal_styleboxes[style_name] = sb
	
