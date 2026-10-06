
const UWindow = preload("uid://d1yl3cuumcudy") #! resolve UtilR.Nodes.UWindow
const PopupHelper = preload("uid://bb13ihrvdkjdj") # popup_menu_path_helper.gd

enum SelectMode {
	NONE,
	ALL,
	BASENAME
}

signal line_submitted(text:String)

var mouse_helper: PopupHelper.MouseHelper

var popup:Popup
var line_edit:LineEdit
var selected_node

static func on_control(control:Control, auto_hide:=true):
	var rect = Rect2(Vector2.ZERO, control.size)
	rect.position += UWindow.get_control_absolute_position(control)
	var new = new(control, rect, auto_hide)
	return new

func _init(sel_node, rect:Rect2=Rect2(), auto_hide:=true) -> void:
	selected_node = sel_node
	if rect == Rect2():
		var line_pos = Vector2(DisplayServer.mouse_get_position())
		var local_offset = Vector2(-50, -10)
		line_pos = line_pos + local_offset
		rect = Rect2(line_pos, Vector2(200, 25))
	
	popup = Popup.new()
	if auto_hide:
		mouse_helper = PopupHelper.MouseHelper.new(popup, _on_timer_elapsed)
	
	line_edit = LineEdit.new()
	line_edit.custom_minimum_size = rect.size
	line_edit.mouse_filter = Control.MOUSE_FILTER_PASS
	
	sel_node.add_child(popup)
	popup.position = rect.position
	popup.add_child(line_edit)
	line_edit.grab_focus()
	
	popup.reset_size()
	popup.popup()
	popup.popup_hide.connect(_popup_hide)
	
	line_edit.text_submitted.connect(_on_text_submitted)

func set_text(new_text:String, select:=SelectMode.NONE):
	line_edit.text = new_text
	if select == SelectMode.ALL:
		line_edit.select_all()
	elif select == SelectMode.BASENAME:
		var base_name = new_text.get_basename()
		line_edit.select(0, base_name.length())

func _popup_hide():
	_submit_text("")

func _on_text_submitted(new_text):
	_submit_text(new_text)

func _on_timer_elapsed():
	_submit_text.call_deferred("")

func _submit_text(new_text):
	line_submitted.emit(new_text)
	popup.queue_free()

static func make_margin_container(_margin_size:int):
	var _margin = MarginContainer.new()
	var margin_size = _margin_size
	for margin_or in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_margin.add_theme_constant_override(margin_or, margin_size)
	_margin.mouse_filter = Control.MOUSE_FILTER_STOP
	
	return _margin
