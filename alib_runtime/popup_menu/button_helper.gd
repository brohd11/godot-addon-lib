
const PopupHelper = preload("res://addons/_lib/brohd/alib_runtime/popup_menu/popup_menu_path_helper.gd")
const ParamKeys = PopupHelper.ParamKeys

static func parse_dict_static(item_dict:Dictionary, icon_only:bool=false, target_control:Control=null):
	var buttons = []
	for path:String in item_dict:
		var data = item_dict.get(path)
		
		var icons = data.get(ParamKeys.ICON, [])
		var icons_colors = data.get(ParamKeys.ICON_COLOR, [])
		var callable = data.get(ParamKeys.CALLABLE)
		
		var button = Button.new()
		button.focus_mode = Control.FOCUS_NONE
		
		if not icon_only:
			var button_name = path.get_file()
			button.text = button_name
		
		if icons.size() > 0:
			var icon = icons[icons.size() - 1]
			button.icon = icon
			if icons_colors.size() > 0:
				var icon_color = icons_colors[icons_colors.size() - 1]
				button.add_theme_color_override("icon_disabled_color", icon_color)
				button.add_theme_color_override("icon_hover_color", icon_color)
				button.add_theme_color_override("icon_hover_pressed_color", icon_color)
				button.add_theme_color_override("icon_pressed_color", icon_color)
				button.add_theme_color_override("icon_focus_color", icon_color)
				button.add_theme_color_override("icon_normal_color", icon_color)
		
		if callable != null:
			button.pressed.connect(callable)
		
		buttons.append(button)
	
	if target_control:
		for b in buttons:
			target_control.add_child(b)
	
	return buttons
