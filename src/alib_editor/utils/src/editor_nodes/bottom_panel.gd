extends RefCounted
#! namespace ALibEditor.Nodes class BottomPanel

static func get_bottom_panel() -> Control:
	return EditorNodeRef.get_registered(EditorNodeRef.Nodes.BOTTOM_PANEL)

static func get_button_top_hbox():
	var buttons = EditorNodeRef.get_registered(EditorNodeRef.Nodes.BOTTOM_PANEL_BUTTONS)
	return buttons.get_parent().get_parent()

static func get_button_hbox():
	return EditorNodeRef.get_registered(EditorNodeRef.Nodes.BOTTOM_PANEL_BUTTONS)


static func get_panel(_class_name):
	var bottom_panel = get_bottom_panel()
	for p in bottom_panel.get_children():
		if p.get_class() == _class_name:
			return p
	push_error("Could not find %s" % _class_name)

static func show_first_panel():
	var hbox = get_button_hbox()
	for c in hbox.get_children():
		
		if not c is Button:
			continue
		if c.visible:
			c.toggled.emit(true)
			break

static func show_panel(button_name:String):
	var hbox = get_button_hbox()
	for c in hbox.get_children():
		if not c is Button:
			continue
		if c.text == button_name:
			c.toggled.emit(true)
			break

static func get_editor_log():
	return EditorNodeRef.get_registered(EditorNodeRef.Nodes.EDITOR_LOG)

static func get_filter_line_edit():
	return EditorNodeRef.get_registered(EditorNodeRef.Nodes.EDITOR_LOG_FILTER)
