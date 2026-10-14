
const _HL_COLOR_VAL = 0.45
const _HL_COLOR = Color(_HL_COLOR_VAL,_HL_COLOR_VAL,_HL_COLOR_VAL,0.05)

static func draw_lines(item_list: ItemList, color = null):
	if color == null:
		color = _HL_COLOR # Ensure this constant is accessible or pass it in
	
	var scroll_y = item_list.get_v_scroll_bar().value
	var list_width = item_list.size.x
	var list_height = item_list.size.y
	var row_height = 0.0
	
	if item_list.item_count > 0:
		row_height = item_list.get_item_rect(0).size.y
	else:
		# Fallback if empty: Font height + standard padding (roughly 24px usually)
		var font = item_list.get_theme_font("font")
		var font_size = item_list.get_theme_font_size("font_size")
		row_height = font.get_height(font_size) + 4 # +4 for approximate padding
	
	# default draw of item list in modern theme
	if row_height <= 0:
		row_height = 22

	# 2. Calculate Start Position
	# We calculate the index of the first row currently visible at the top
	var first_visible_row_index = floor(scroll_y / row_height)
	
	var sb = item_list.get_theme_stylebox("panel") as StyleBoxFlat
	var margin = sb.content_margin_top
	# Calculate the exact Y pixel position where this row starts relative to the top of the control
	# (This will usually be 0 or a negative number if the row is partially scrolled off)
	var current_y = (first_visible_row_index * row_height) + margin - scroll_y
	var current_row_index = int(first_visible_row_index)
	
	while current_y < list_height:
		if current_row_index % 2 == 0: # == start on 0, != start on 1
			var rect = Rect2(0, current_y, list_width, row_height)
			item_list.draw_rect(rect, color)
		
		current_y += row_height
		current_row_index += 1
