extends RefCounted
#! namespace ALibEditor.Utils class UEditorTheme

const BACKPORTED = 100

const ThemeColor = preload("res://addons/_lib/brohd/alib_editor/utils/src/editor_theme/theme_color.gd")
const ThemeSetter = preload("res://addons/_lib/brohd/alib_editor/utils/src/editor_theme/theme_setter.gd")

static func get_icon(icon_name:String, theme_type:String=&"EditorIcons"):
	var icon = EditorInterface.get_editor_theme().get_icon(icon_name, theme_type)
	return icon

static func get_icon_name(icon, theme_type:String=&"EditorIcons"):
	if BACKPORTED < 2:
		var path = new().get_script().resource_path
		printerr("Cannot get icon list in backported plugin version 4.%s. Calling file: %s" % [BACKPORTED, path])
		return ""
	var icon_list = EditorInterface.get_editor_theme().get_icon_list(theme_type)
	for icon_name in icon_list:
		if icon == get_icon(icon_name, theme_type):
			return icon_name

static func set_menu_button_to_editor_theme(menu_button:MenuButton):
	menu_button.flat = false
	var b = Button.new()
	menu_button.add_child(b)
	var overides = ["normal", "pressed"]
	for o in overides:
		menu_button.add_theme_stylebox_override(o, b.get_theme_stylebox(o))
	b.queue_free()

static func button_set_main_screen_theme_var(button:Button):
	button.theme_type_variation = &"MainScreenButton"

static func get_size_of_control_type(type):
	var ins = type.new()
	EditorInterface.get_base_control().add_child(ins)
	var new_size = ins.size
	ins.hide()
	ins.queue_free()
	return new_size

static func get_current_theme_style():
	return EditorInterface.get_editor_settings().get_setting("interface/theme/style")

static func get_custom_theme_path():
	return EditorInterface.get_editor_settings().get_setting("interface/theme/custom_theme")
