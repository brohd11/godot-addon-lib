@tool
extends "res://addons/addon_lib/brohd/alib_runtime/dialog/base/handler_base.gd"

const NUMarginContainer = preload("uid://t8ajrsqdbrva") #! resolve ALibRuntime.NodeUtils.NUMarginContainer

const SUCCESS_STRING = &"SUCCESS_STRING"

enum TargetSection{
	ROOT,
	HEADER,
	BODY,
	FOOTER,
}

var _title:String=""
var default_size = Vector2(600, 400)

func _init(_root_node=null) -> void:
	_set_root_node(_root_node)

func set_title(title:String):
	_title = title
	if is_instance_valid(dialog):
		dialog.title = _title


func show_dialog():
	_build_dialog()
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	root_node.add_child(dialog)
	return await handled

func _build_dialog():
	if is_instance_valid(dialog):
		return
	
	dialog = DialogStructure.new()
	
	dialog.title = _title
	dialog.size = default_size
	
	#dialog.reset_size.call_deferred()
	
	#root_node.add_child(dialog)
	
	#dialog.popup()
	
	dialog.close_requested.connect(_on_canceled)
	dialog.cancel_button.pressed.connect(_on_canceled)
	dialog.confirm_button.pressed.connect(_on_confirmed)
	dialog.always_on_top = true





func _on_confirmed():
	#self.handled.emit(get_data())
	handled.emit(SUCCESS_STRING)
	dialog.queue_free()
	
func _on_canceled():
	handled.emit(CANCEL_STRING)
	dialog.queue_free()


func add_content(node:Node, target_section:TargetSection=TargetSection.BODY):
	_build_dialog() # ensure this has been setup
	match target_section:
		TargetSection.ROOT: dialog.add_child(node)
		TargetSection.HEADER: dialog.header.add_child(node)
		TargetSection.BODY: dialog.body.add_child(node)
		TargetSection.FOOTER: dialog.footer.add_child(node)
	
	if node is Control:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL


class DialogStructure extends Window:
	
	var header:= VBoxContainer.new()
	var body:= VBoxContainer.new()
	var footer:= VBoxContainer.new()
	
	var cancel_button:= Button.new()
	var confirm_button:= Button.new()
	
	func _init() -> void:
		var back_bg = Panel.new()
		add_child(back_bg)
		back_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var scale = 1
		
		var marg = MarginContainer.new()
		back_bg.add_child(marg)
		marg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		
		var bg = PanelContainer.new()
		marg.add_child(bg)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if Engine.has_singleton(&"EditorInterface"):
			var editor_interface = Engine.get_singleton("EditorInterface")
			scale = editor_interface.get_editor_scale()
			var bg_sb = bg.get_theme_stylebox("panel").duplicate()
			bg_sb.set_corner_radius_all(0)
			bg_sb.set_content_margin_all(12 * scale)
			bg_sb.bg_color = editor_interface.get_editor_theme().get_color("base_color", "Editor")
			bg.add_theme_stylebox_override("panel", bg_sb)
		
		NUMarginContainer.set_margins(marg, 4 * scale, false)
		
		var main_vbox := VBoxContainer.new()
		bg.add_child(main_vbox)
		main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		main_vbox.add_child(header)
		main_vbox.add_child(body)
		main_vbox.add_child(footer)
		
		var button_hbox = HBoxContainer.new()
		button_hbox.add_spacer(false)
		button_hbox.add_child(cancel_button)
		cancel_button.text = "Cancel"
		cancel_button.custom_minimum_size = Vector2(75, 0)
		button_hbox.add_spacer(false)
		button_hbox.add_child(confirm_button)
		confirm_button.text = "Confirm"
		confirm_button.custom_minimum_size = Vector2(75, 0)
		button_hbox.add_spacer(false)
		
		footer.add_child(button_hbox)
	
	
	func add_to_header(control:Control):
		header.add_child(control)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	func add_to_body(control:Control):
		body.add_child(control)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	func add_to_footer(control:Control):
		footer.add_child(control)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
