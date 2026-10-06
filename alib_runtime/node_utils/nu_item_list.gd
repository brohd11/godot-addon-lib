#! namespace ALibRuntime.NodeUtils.NUItemList

const AltColor = preload("res://addons/_lib/brohd/alib_runtime/node_utils/item_list/alternate_color.gd")


static func replace_panel_stylebox_margin(item_list:ItemList, margin:int=0, only_right:=true):
	var sb = item_list.get_theme_stylebox(&"panel").duplicate()
	if only_right:
		sb.content_margin_right = margin
	else:
		sb.set_content_margin_all(margin)
	item_list.add_theme_stylebox_override(&"panel", sb)

## manually calc item text overflow, for use with a right aligned icon
## assumes standard tree, column 0
static func item_text_overflows(item_list:ItemList, idx:int, custom_icon:Texture2D) -> bool:
	var font = item_list.get_theme_font(&"font")
	var font_size = item_list.get_theme_font_size(&"font_size")
	
	var text: String = item_list.get_item_text(idx)
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	#var available_width: float = item_list.size.x
	var available_width = item_list.get_item_rect(idx).size.x
	
	available_width -= item_list.get_theme_constant(&"icon_margin")
	# *3 to account for the margin for the custom icon + separation
	available_width -= item_list.get_theme_constant(&"h_separation") * 2
	available_width -= custom_icon.get_width()
	
	
	# 5. Check if the Text Width + Icon Width clashes with the Column Width
	var icon_width = 0
	var icon = item_list.get_item_icon(idx)
	if icon:
		icon_width = item_list.get_item_icon(idx).get_width()
	
	# We leave a small margin (e.g., 10 pixels) for spacing
	var is_clashing = (text_width + icon_width) > available_width
	
	return is_clashing


static func get_selected_meta(item_list:ItemList):
	var metas = []
	for i in item_list.get_selected_items():
		var m = item_list.get_item_metadata(i)
		if m != null:
			metas.append(m)
	return metas
