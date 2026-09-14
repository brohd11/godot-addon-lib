#! namespace ALibEditor.UIHelpers class Margin

const UVersion = preload("uid://b4f7kxqukmbj2") #! resolve ALibRuntime.Utils.UVersion

static func new_plugin_margin_container():
	var margin_container = MarginContainer.new()
	var main_marg = 0
	var minor_version = UVersion.get_minor_version()
	if minor_version >= 6:
		var scale = EditorInterface.get_editor_scale()
		
		main_marg = -2 * scale
	margin_container.add_theme_constant_override("margin_top", main_marg)
	margin_container.add_theme_constant_override("margin_left", main_marg)
	margin_container.add_theme_constant_override("margin_right", main_marg)
	margin_container.add_theme_constant_override("margin_bottom", main_marg)
	return margin_container
