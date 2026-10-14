#! namespace ALibRuntime.Utils class UTexture

static func resize_texture(texture:Texture2D, new_size_x:int, new_size_y:int=-1):
	var img = texture.get_image()
	if new_size_y == -1:
		new_size_y = new_size_x
	img.resize(new_size_x, new_size_y)
	var img_tex = ImageTexture.create_from_image(img)
	return img_tex

static func get_modulated_icon(texture:Texture2D, color:=Color(1,1,1)) -> Texture2D:
	var img = texture.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8) # Convert to RGBA8 to ensure can modify pixels
	
	for y in img.get_height():
		for x in img.get_width():
			var pixel_color = img.get_pixel(x, y)
			if pixel_color.a > 0: # Check if pixel has any visibility
				img.set_pixel(x, y, Color(color.r, color.b, color.g, pixel_color.a)) # Set RGB to White, KEEP the original Alpha
	
	return ImageTexture.create_from_image(img)

static func create_rect_texture(color:Color=Color.WHITE, size_x:int=1, size_y:int=1):
	var img = Image.create_empty(size_x, size_y, false, Image.FORMAT_BPTC_RGBA)
	img.decompress()
	for x in range(size_x):
		for y in range(size_y):
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
