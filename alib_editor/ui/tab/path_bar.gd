extends TabBar

const UVersion = preload("uid://dn156lc18d1vt") #! resolve UtilR.UVersion

enum DisplayMode {
	FILE_SYSTEM,
	OUTLINE,
}

static var _style_boxes = {}

var display_mode:DisplayMode = DisplayMode.FILE_SYSTEM

func _ready() -> void:
	_set_style_boxes()
	clip_tabs = false

func _draw() -> void:
	if display_mode == DisplayMode.OUTLINE:
		var icon = EditorInterface.get_editor_theme().get_icon(&"PageNext", &"EditorIcons")
		for i in range(get_tab_offset(), tab_count - 1):
			var tab_rect = get_tab_rect(i)
			#print(tab_rect)
			#draw_rect(tab_rect, Color.WHITE, false)
			tab_rect.position.x += (tab_rect.size.x - icon.get_width())
			tab_rect.position.y += (tab_rect.size.y / 2) - (icon.get_height() / 2)
			draw_texture(icon, tab_rect.position)

func _set_style_boxes():
	var version = UVersion.get_minor_version()
	var sbs = ["tab_selected", "tab_unselected", "tab_hovered", "tab_focus", "tab_disabled"]
	for _name in sbs:
		var sb
		if version < 6:
			sb = _get_style_box_44(_name)
		else: #elif version <= 7:
			sb = _get_style_box_46(_name)
		add_theme_stylebox_override(_name, sb)
	

func _get_style_box_44(_name:String):
	if _style_boxes == null:
		_style_boxes = {}
	var style_box_dict = _style_boxes.get_or_add(display_mode, {})
	if style_box_dict.has(_name):
		return style_box_dict[_name]
	var sb = get_theme_stylebox(_name).duplicate() as StyleBoxFlat
	sb.border_width_right = 2
	sb.border_color = Color.TRANSPARENT
	if _name == "tab_selected":
		sb.border_width_top = 0
		sb.bg_color = sb.bg_color.darkened(0.5)
	
	if display_mode == DisplayMode.FILE_SYSTEM:
		sb.border_width_right = 2
	elif display_mode == DisplayMode.OUTLINE:
		sb.border_width_right = 4
	
	
	style_box_dict[_name] = sb
	return sb

func _get_style_box_46(_name:String):
	if _style_boxes == null:
		_style_boxes = {}
	var style_box_dict = _style_boxes.get_or_add(display_mode, {})
	if style_box_dict.has(_name):
		return style_box_dict[_name]
	var editor_scale = EditorInterface.get_editor_scale()
	var sb = get_theme_stylebox(_name).duplicate() as StyleBoxFlat
	sb.set_content_margin_all(7)
	#sb.content_margin_right += 3
	#sb.border_width_right = 3
	sb.border_color = Color.TRANSPARENT
	sb.set_corner_radius_all(0)
	if _name == "tab_selected":
		sb.border_width_top = 0
		sb.bg_color = sb.bg_color.darkened(0.2)
	
	if display_mode == DisplayMode.FILE_SYSTEM:
		sb.content_margin_right += (3 * editor_scale)
		sb.border_width_right = (3 * editor_scale)
	elif display_mode == DisplayMode.OUTLINE:
		sb.content_margin_right += (12 * editor_scale)
		sb.border_width_right = (12 * editor_scale)
	
		
	style_box_dict[_name] = sb
	return sb
