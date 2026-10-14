#! namespace ALibRuntime.UICustom class LineSlider
extends MarginContainer

# Signals
signal value_changed(new_value: float)

static var _cache:={}

# Exports
@export var label_text: String = "":
	set(v):
		label_text = v
		_update_label()

@export var value: float = 0.0:
	set(v):
		var old_val = value
		if not allow_greater:
			v = min(v, max_value)
		if not allow_lesser:
			v = max(v, min_value)
		# Snap to step
		value = v
		if step > 0:
			value = round(value / step) * step
		
		if not _set_value_no_signal and value != old_val:
			value_changed.emit(value)
		
		_update_visuals()

@export var min_value: float = 0.0:
	set(v): 
		min_value = v
		if _slider: _slider.min_value = v
		_update_visuals()

@export var max_value: float = 100.0:
	set(v): 
		max_value = v
		if _slider: _slider.max_value = v
		_update_visuals()

@export var step: float = -1:
	set(v):
		step = v
		if _slider: _slider.step = v

@export var allow_lesser:bool:
	set(v):
		allow_lesser = v
		if _slider: _slider.allow_lesser = v

@export var allow_greater:bool:
	set(v):
		allow_greater = v
		if _slider: _slider.allow_greater = v


@export var sensitivity: float = 1 # Sensitivity for the relative mouse dragging
@export var suffix:String = ""
@export var prefix:String = ""

@export var show_slider:= true:
	set(v):
		show_slider = v
		if _slider: _slider.visible = v

# Internal Nodes
var _slider: HSlider
var prefix_color:Color
var _label_hbox:HBoxContainer
var _prefix_label:Label
var _label: Label
var _suffix_label:Label
var _line_edit: LineEdit

# State
var _is_dragging: bool = false
var _mouse_start_pos: Vector2

var _mouse_in_panel:=false
var _set_value_no_signal = false

var _last_value:float=0

func _init():
	#custom_minimum_size = Vector2(80, 24)
	#mouse_default_cursor_shape = Control.CURSOR_HSIZE
	pass

func _ready():
	_setup_nodes()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_visuals()

func set_value(new_value):
	value = new_value

func set_value_no_signal(new_value):
	_set_value_no_signal = true
	value = new_value
	_set_value_no_signal = false


func _setup_nodes():
	var vbox = VBoxContainer.new()
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_label_hbox = HBoxContainer.new()
	_label_hbox.add_theme_constant_override("separation", 0)
	vbox.add_child(_label_hbox)
	_label_hbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	
	
	#^ labels
	_prefix_label = Label.new()
	_label_hbox.add_child(_prefix_label)
	_prefix_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prefix_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var spacer = Control.new()
	_label_hbox.add_child(spacer)
	spacer.mouse_filter = Control.MOUSE_FILTER_PASS
	spacer.custom_minimum_size.x = 8
	
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_hbox.add_child(_label)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	
	_suffix_label = Label.new()
	_label_hbox.add_child(_suffix_label)
	_suffix_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_suffix_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	for label:Label in [_prefix_label, _label, _suffix_label]:
		label.add_theme_stylebox_override("normal", get_empty_sb())

	
	# 4. LineEdit (Editing)
	_line_edit = LineEdit.new()
	_line_edit.visible = false
	_line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_line_edit.add_theme_stylebox_override("normal", get_empty_sb())
	_line_edit.add_theme_stylebox_override("focus", get_empty_sb())
	_line_edit.add_theme_stylebox_override("read_only", get_empty_sb())
	
	# Logic to commit text
	
	_line_edit.focus_exited.connect(_on_line_edit_focus_exited)
	_line_edit.text_submitted.connect(_on_line_edit_text_submitted)
	_line_edit.gui_input.connect(_on_line_edit_gui_input)
	vbox.add_child(_line_edit)
	
	_cache.clear()
	_slider = HSlider.new()
	_slider_add_icon_overide()
	_slider.add_theme_stylebox_override("slider", get_line_sb())
	_slider.add_theme_icon_override("grabber_highlight", get_square(Color.WHITE, 6))
	# Important: Ignore mouse so the parent Control handles the "Click vs Drag" logic
	#_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Sync properties
	_slider.min_value = min_value
	_slider.max_value = max_value
	var _range = max_value - min_value
	if step == -1:
		step = max(_range / 100, 0.1)
	
	#sensitivity = _range / 10
	_slider.step = step
	_slider.value = value
	_slider.allow_greater = allow_greater
	_slider.allow_lesser = allow_lesser
	vbox.add_child(_slider)
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	#_slider.value_changed.connect(_on_slider_value_changed)
	_slider.drag_ended.connect(_on_slider_drag_ended)
	
	if not show_slider:
		_slider.hide()
	
	
	#_label_hbox.add_child(_line_edit)
	#_label_hbox.move_child(_line_edit, 2)

# --- Visual Updates ---

func _update_label():
	if not is_instance_valid(_label): return
	var txt = ""
	if label_text != "":
		txt = label_text + ": "
	var val_str = String.num(value, 3 if step < 1 else 0)
	_label.text = txt + val_str
	
	_prefix_label.visible = prefix != ""
	_prefix_label.text = prefix
	if prefix_color:
		_prefix_label.add_theme_color_override("font_color", prefix_color)
	_suffix_label.visible = suffix != ""
	_suffix_label.text = suffix
	_suffix_label.add_theme_color_override("font_color", Color.WEB_GRAY)

func _on_mouse_entered():
	_mouse_in_panel = true
	_update_visuals()

func _on_mouse_exited():
	_mouse_in_panel = false
	_update_visuals()

func _update_visuals():
	_update_label()
	if show_slider:
		if is_instance_valid(_slider):
			_slider.set_value_no_signal(value)
			_slider_add_icon_overide()

func _on_slider_drag_ended(val_changed:bool):
	if val_changed:
		value = _slider.value

# --- Input Handling (Replicates EditorSpinSlider) ---

func _gui_input(event: InputEvent):
	if _line_edit.visible: return 
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = false
				_mouse_start_pos = event.global_position
				accept_event() # Grab focus
			else:
				# Mouse Up
				if not _is_dragging:
					_enable_edit_mode()
				_is_dragging = false
				#value_changed.emit(value)

	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var dist = event.global_position.distance_to(_mouse_start_pos)
			if dist > 2.0: # Drag threshold
				_is_dragging = true
			
			if _is_dragging:
				_handle_slide(event.relative.x)

func _handle_slide(relative_x: float):
	var range_len = max_value - min_value
	if range_len <= 0: return

	# Dynamic speed modifiers
	var speed_mult = 1.0
	if Input.is_key_pressed(KEY_SHIFT): speed_mult = 10.0
	if Input.is_key_pressed(KEY_CTRL): speed_mult = 0.1
	
	# Slide logic: pixel movement * sensitivity
	var proportional_delta = relative_x / size.x
	var delta = proportional_delta * speed_mult * range_len
	delta = snapped(delta, step)
	
	#var delta = relative_x * sensitivity * speed_mult * (range_len / 100.0)
	
	# Fallback for small ranges so it doesn't get stuck
	#if range_len < 1: delta = relative_x * sensitivity * speed_mult
	
	#set_value_no_signal(value + delta)
	value += delta

# --- Edit Mode Logic ---

func _enable_edit_mode():
	_line_edit.text = str(value)
	_line_edit.select_all()
	_line_edit.show()
	_line_edit.grab_focus()
	
	# Requirements: Slider and Label must disappear
	#_label.hide()
	_label_hbox.hide()
	_slider.hide()
	
	_last_value = value

func _disable_edit_mode():
	_line_edit.hide()
	_label_hbox.show()
	if show_slider:
		_slider.show()

func _on_line_edit_gui_input(event:InputEvent):
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			_cancel_edit()

func _on_line_edit_text_submitted(new_text: String):
	_commit_edit(new_text)

func _on_line_edit_focus_exited():
	_commit_edit(_line_edit.text)

func _commit_edit(text_val: String):
	if text_val.is_valid_float():
		self.value = float(text_val)
	_disable_edit_mode()

func _cancel_edit():
	_line_edit.text = str(_last_value)
	_disable_edit_mode()

func _slider_add_icon_overide():
	if _is_dragging:
		_slider.add_theme_icon_override("grabber", get_square(Color.WHITE))
	else:
		var color = Color.WHITE * 0.8 if _mouse_in_panel else Color.WHITE * 0.6
		_slider.add_theme_icon_override("grabber", get_square(color))
	


static func get_square(color:Color, _size:int=4):
	var size_cache = _cache.get_or_add(_size, {})
	if size_cache.has(color):
		return size_cache[color]
	var img = Image.create_empty(_size,_size, false, Image.FORMAT_BPTC_RGBA)
	img.decompress()
	for x in range(_size):
		for y in range(_size):
			img.set_pixel(x, y, color)
	var tex = ImageTexture.create_from_image(img)
	size_cache[color] = tex
	return tex

static func get_line_sb():
	var cached = _cache.get("line_sb")
	if cached != null:
		return cached
	var line_sb = StyleBoxLine.new()
	line_sb.thickness = 2
	_cache["line_sb"] = line_sb
	return line_sb

static func get_empty_sb():
	var cached = _cache.get("empty_sb")
	if cached != null:
		return cached
	_cache["empty_sb"] = StyleBoxEmpty.new()
	return _cache["empty_sb"]
