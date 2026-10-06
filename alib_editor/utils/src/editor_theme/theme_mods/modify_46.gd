@tool
extends "res://addons/_lib/brohd/alib_editor/utils/src/editor_theme/theme_mods/base/modify_base.gd"

const FILE_NAME = "custom_theme_46"
const SAVE_TO_RES = false

# Usage: run this and it will save a new theme with these changes made to it.
# may need to me be reset if the theme doesn't update right away.
func _run() -> void:
	generate_theme(FILE_NAME, _modify_theme, SAVE_TO_RES)


static func _modify_theme() -> Theme:
	var new_theme = Theme.new()
	var thm = EditorInterface.get_editor_theme()
	var editor_scale = EditorInterface.get_editor_scale()
	
	var panel = &"panel"
	
	var margin_theme_type_variations = {
		&"NoBorderBottomPanel": 0,
		&"NoBorderHorizontalBottom": -2,
		&"NoBorderAnimation": 0
	}
	for marg_theme in margin_theme_type_variations.keys():
		var val = margin_theme_type_variations[marg_theme]
		new_theme.set_constant(&"margin_left", marg_theme, val)
		new_theme.set_constant(&"margin_right", marg_theme, val)
		new_theme.set_constant(&"margin_bottom", marg_theme, val)
	
	var item_sb = thm.get_stylebox(panel, &"ItemList").duplicate() as StyleBoxFlat
	var base_color = thm.get_color(&"base_color", &"Editor")
	var darkened_base = base_color.darkened(0.2)
	item_sb.bg_color = darkened_base
	new_theme.set_stylebox(panel, &"Tree", item_sb)
	new_theme.set_stylebox(panel, &"ItemList", item_sb)
	new_theme.set_stylebox(panel, &"EditorInspector", item_sb)
	
	
	var tab_sb = [&"tab_selected", &"tab_unselected", &"tab_hovered", &"tab_focus", &"tab_disabled"]
	for type in [&"TabBar", &"TabContainer"]:
		for _name in tab_sb:
			var sb = thm.get_stylebox(_name, type).duplicate()
			sb.set_content_margin_all(8 * editor_scale)
			new_theme.set_stylebox(_name, type, sb)
	
	return new_theme
