extends RefCounted

#! namespace ALibEditor.Nodes class MainScreen

static func get_main_screen():
	return EditorInterface.get_editor_main_screen()

static func get_title_bar():
	return EditorNodeRef.get_registered(EditorNodeRef.Nodes.TITLE_BAR)
	
static func get_button_container():
	return EditorNodeRef.get_registered(EditorNodeRef.Nodes.TITLE_BUTTONS)

static func get_button_theme():
	var button_container = EditorNodeRef.get_registered(EditorNodeRef.Nodes.TITLE_BUTTONS)
	var button = button_container.get_child(0)
	return button.theme_type_variation
