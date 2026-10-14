
const _HL_COLOR_VAL = 0.45
const _HL_COLOR = Color(_HL_COLOR_VAL,_HL_COLOR_VAL,_HL_COLOR_VAL,0.05)


static func draw_lines(tree:Tree, color = null):
	if color == null:
		color = _HL_COLOR # Ensure this constant is accessible or pass it in
	tree.get_scroll()
	var scroll_y = tree.get_scroll().y
	var list_width = tree.size.x
	var list_height = tree.size.y
	var row_height = 0.0
	
	var item = tree.get_root()
	if is_instance_valid(item):
		if tree.hide_root:
			item = item.get_next_visible() # move off the root, is invisible
		if is_instance_valid(item):
			row_height = tree.get_item_area_rect(item).size.y
	
	if row_height <= 0:
		var font = tree.get_theme_font("font")
		var font_size = tree.get_theme_font_size("font_size")
		row_height = font.get_height(font_size) + 4 # +4 for approximate padding
	
	# default draw of item list in modern theme
	if row_height <= 0:
		row_height = 22

	# 2. Calculate Start Position
	# We calculate the index of the first row currently visible at the top
	var first_visible_row_index = floor(scroll_y / row_height)
	
	var sb = tree.get_theme_stylebox("panel")
	var margin = sb.content_margin_top
	# Calculate the exact Y pixel position where this row starts relative to the top of the control
	# (This will usually be 0 or a negative number if the row is partially scrolled off)
	var current_y = (first_visible_row_index * row_height) + margin - scroll_y
	var current_row_index = int(first_visible_row_index)
	
	while current_y < list_height:
		if current_row_index % 2 == 0: # == start on 0, != start on 1
			var rect = Rect2(0, current_y, list_width, row_height)
			tree.draw_rect(rect, color)

		current_y += row_height
		current_row_index += 1
