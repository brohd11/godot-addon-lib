extends PopupMenu
#! namespace ALibRuntime class PopupHelper

const ButtonHelper = preload("res://addons/_lib/brohd/alib_runtime/popup_menu/button_helper.gd")
const UTexture = preload("res://addons/_lib/brohd/alib_runtime/utils/u_texture.gd") # ALibRuntime.Utils.UTexture


const ICON_DEFAULT_SIZE = Vector2(16,16)

const BACKPORTED = 100

var popup_items_dict:Dictionary = {}

var mouse_helper :MouseHelper

signal item_pressed_parsed_menu_path(menu_path)
signal item_pressed_parsed(id_text)
signal item_pressed(id, _popup)

func _parse_item_clicked(id, _popup:PopupMenu):
	item_pressed.emit(id,_popup)
	item_pressed_parsed.emit(parse_id_text(id, _popup))
	item_pressed_parsed_menu_path.emit(parse_menu_path(id, _popup))

static func parse_id_text(id, _popup:PopupMenu):
	var index = _popup.get_item_index(id)
	return _popup.get_item_text(index)

static func parse_metadata(id:int, _popup:PopupMenu):
	return get_metadata(id, _popup)

static func parse_menu_path(id:int, _popup:PopupMenu):
	var metadata = get_metadata(id, _popup)
	return metadata.get("menu_path")

static func parse_callable(id, _popup, dict, callable_key=ParamKeys.CALLABLE):
	var menu_path = parse_menu_path(id, _popup)
	var data = dict.get(menu_path, {})
	var callable = data.get(callable_key)
	if callable:
		callable.call()

static func get_metadata(id:int, _popup:PopupMenu):
	var index = _popup.get_item_index(id)
	return _popup.get_item_metadata(index)

static func set_popup_description(_popup:PopupMenu, id:int, text:String):
	var index = _popup.get_item_index(id)
	_popup.set_item_metadata(index, {"description": text})

func _init(path_dict=null, mouse_signal_node=null, base_id=-1) -> void:
	if path_dict == null:
		return
	parse_dict(path_dict, mouse_signal_node, base_id)


func parse_dict(path_dict, mouse_signal_node, base_id=-1, extra_args=[]):
	if mouse_signal_node == null:
		popup_hide.connect(_on_popup_hide.bind(self))
		mouse_helper = MouseHelper.new(self)
		mouse_signal_node = mouse_helper
	_parse_dict(path_dict, self, _parse_item_clicked, popup_items_dict, base_id, extra_args)
	connect_mouse_signals(popup_items_dict, mouse_signal_node)

# use static func to process an existing _popup
static func parse_dict_static(path_dict, _popup, callable,  mouse_signal_node=null, base_id=-1, extra_args=[]):
	var item_dict = {}
	_parse_dict(path_dict, _popup, callable ,item_dict, base_id, extra_args)
	connect_mouse_signals(item_dict, mouse_signal_node)


static func _parse_dict(path_dict, _popup:PopupMenu, callable:Callable, item_dict, base_id=-1, extra_args=[]):
	if not _popup.id_pressed.is_connected(callable):
		if extra_args.is_empty():
			_popup.id_pressed.connect(callable.bind(_popup))
		else:
			_popup.id_pressed.connect(callable.bindv(extra_args).bind(_popup))
	item_dict["ZZ_ROOT_POPUP_MENU_ZZ"] = _popup # adds _popup to dict to include in connect_signals
	var current_id = base_id
	for key in path_dict:
		var menu_path = key
		var data = path_dict.get(key, {})
		
		var params = PopupMenuPathParams.new(menu_path, _popup, callable, item_dict, data)
		_parse_popup_menu_path(params, current_id, extra_args)
		
		if base_id != -1:
			current_id += 1
		

static func connect_mouse_signals(item_dict, mouse_signal_node):
	if not mouse_signal_node:
		return
	for _popup:PopupMenu in item_dict.values():
		if not _popup.mouse_entered.is_connected(mouse_signal_node._on_mouse_entered):
			_popup.mouse_entered.connect(mouse_signal_node._on_mouse_entered)
		if not _popup.mouse_exited.is_connected(mouse_signal_node._on_mouse_exited):
			_popup.mouse_exited.connect(mouse_signal_node._on_mouse_exited)


static func _parse_popup_menu_path(params:PopupMenuPathParams, current_id, extra_args=[]):
	params.even_array_sizes()
	var popup_menu_path = params.popup_menu_path
	var icon_array = params.icon_array
	var icon_color_array = params.icon_color_array
	var base_popup = params.base_popup
	var signal_callable = params.signal_callable
	var tool_tip_array = params.tool_tip_array
	var radio = params.radio
	var radio_is_checked = params.radio_is_checked
	var item_dict = params.popup_items_dict
	var user_metadata = params.metadata
	
	
	var slice_count = popup_menu_path.get_slice_count("/")
	var working_menu_path = ""
	var parent_popup:PopupMenu = base_popup
	
	for i in range(slice_count):
		var icon
		if i < icon_array.size():
			icon = icon_array[i]
		var icon_color
		if i < icon_color_array.size():
			icon_color = icon_color_array[i]
		var tool_tip
		if i < tool_tip_array.size():
			tool_tip = tool_tip_array[i]
		
		var slice = popup_menu_path.get_slice("/", i)
		working_menu_path = working_menu_path.path_join(slice)
		if  i == slice_count - 1: # THIS IS THE CLICKABLE
			var sep_string = ParamKeys.get_seperator(slice)
			if sep_string != null:
				parent_popup.add_separator(sep_string)
				parent_popup.set_item_metadata(parent_popup.item_count - 1, {ParamKeys.METADATA: user_metadata})
				break
			
			_create_popup_item(parent_popup, params, slice, tool_tip, icon, icon_color, current_id)
			var popup_index = parent_popup.item_count - 1
			var metadata = {
				"menu_path": popup_menu_path,
				"description":tool_tip
			}
			if not user_metadata.is_empty():
				for key in user_metadata.keys():
					metadata[key] = user_metadata.get(key)
			
			parent_popup.set_item_metadata(popup_index, metadata)
			break
		
		var path_popup: PopupMenu
		if working_menu_path in item_dict:
			path_popup = item_dict.get(working_menu_path)
		else:
			path_popup = PopupMenu.new()
			if signal_callable != null:
				if extra_args.is_empty():
					path_popup.id_pressed.connect(signal_callable.bind(path_popup))
				else:
					path_popup.id_pressed.connect(signal_callable.bindv(extra_args).bind(path_popup))
			path_popup.submenu_popup_delay = 0
			_create_popup_item(parent_popup, params, slice, tool_tip, icon, icon_color, -1, path_popup)
			item_dict[working_menu_path] = path_popup
			
		
		parent_popup = path_popup
	
	return parent_popup

static func _create_popup_item(_popup:PopupMenu, params:PopupMenuPathParams, text, 
		tool_tip, icon, color, id, submenu_node:PopupMenu=null):
	
	if submenu_node:
		_popup.add_submenu_node_item(text, submenu_node)
		var popup_index = _popup.item_count - 1
		if icon:
			if icon is String:
				icon = _get_icon(icon)
			_popup.set_item_icon(popup_index, icon)
			if color:
				_popup.set_item_icon_modulate(popup_index, color)
		if tool_tip:
			_popup.set_item_metadata(popup_index, {"description":tool_tip})
			#_popup.set_item_tooltip(popup_index, tool_tip) # this doesn't seem to work
	else:
		if icon:
			if icon is String:
				icon = _get_icon(icon)
			icon = icon as Texture2D
			if icon.get_size() != ICON_DEFAULT_SIZE * EditorInterface.get_editor_scale():
				#print("RESIZE")
				var icon_size = 16 * EditorInterface.get_editor_scale()
				icon = UTexture.resize_texture(icon, icon_size)
			if params.radio:
				_popup.add_icon_radio_check_item(icon, text, id)
				if params.radio_is_checked:
					var popup_index = _popup.item_count - 1
					_popup.set_item_as_radio_checkable(popup_index, true)
					_popup.set_item_checked(popup_index, true)
			else:
				_popup.add_icon_item(icon, text, id)
			var popup_index = _popup.item_count - 1
			if color:
				_popup.set_item_icon_modulate(popup_index, color)
			#if tool_tip:
				#_popup.set_item_tooltip(popup_index, tool_tip)
		else:
			if params.radio:
				_popup.add_radio_check_item(text, id)
				if params.radio_is_checked:
					var popup_index = _popup.item_count - 1
					_popup.set_item_as_radio_checkable(popup_index, true)
					_popup.set_item_checked(popup_index, true)
			else:
				_popup.add_item(text, id)
		#if tool_tip:
			#var popup_index = _popup.item_count - 1
			#_popup.set_item_tooltip(popup_index, tool_tip)


static func _on_popup_hide(_popup): # if no mouse signal node, free _popup
	_popup.queue_free()

class ParamKeys:
	const ICON = &"ICON"
	const ICON_COLOR = &"ICON_COLOR"
	const TOOL_TIP = &"TOOL_TIP"
	const CALLABLE = &"CALLABLE"
	const METADATA = &"METADATA"
	const RADIO = &"RADIO"
	const RADIO_IS_CHECKED = &"RADIO_IS_CHECKED"
	const ID = &"ID"
	const PRIORITY = "PRIORITY"
	const DEFAULT_PRIORITY = 1000
	
	const SEPARATOR_STRING = "#sep"
	const _SEP_DELIM = "-&|-"
	
	static func add_separator(dict:Dictionary, label:="", path:="", priority:int=DEFAULT_PRIORITY):
		var string = SEPARATOR_STRING + _SEP_DELIM + label
		if path != "":
			string = path.path_join(string)
		var count = 0
		while dict.has(string):
			string = SEPARATOR_STRING + str(count) + _SEP_DELIM + label
			count += 1
		dict[string] = {METADATA: {PRIORITY: priority}}
		return string
	
	static func get_seperator(text:String):
		if text.begins_with(SEPARATOR_STRING):
			if text.find(_SEP_DELIM) > -1:
				return text.get_slice(_SEP_DELIM, 1)
			return ""
	
	static func create_entry_from_item(dict:Dictionary, _popup:PopupMenu, idx:int):
		if not idx < _popup.item_count:
			return
		var data = {}
		
		var id = _popup.get_item_id(idx)
		data[ID] = id
		
		if _popup.is_item_radio_checkable(idx):
			data[RADIO] = true
			if _popup.is_item_checked(idx):
				data[RADIO_IS_CHECKED] = true
		
		var meta = _popup.get_item_metadata(idx)
		if meta == null:
			meta = {}
		data[METADATA] = meta
		
		var _name = _popup.get_item_text(idx)
		var icons = [_popup.get_item_icon(idx)]
		var icon_colors = [_popup.get_item_icon_modulate(idx)]
		
		var menu_path = ""
		var parent = _popup
		while parent is PopupMenu:
			for i in range(parent.item_count):
				var submenu = parent.get_item_submenu_node(i)
				if not is_instance_valid(submenu):
					continue
				if submenu.is_ancestor_of(_popup) or submenu == _popup:
					menu_path = parent.get_item_text(i).path_join(menu_path)
					icons.push_front(parent.get_item_icon(i))
					icon_colors.push_front(parent.get_item_icon_modulate(i))
					break
				continue
			parent = parent.get_parent()
		
		if _popup.is_item_separator(idx):
			menu_path = add_separator({}, _name, menu_path)
		else:
			menu_path = menu_path.path_join(_name)
		
		data[ICON] = icons
		data[ICON_COLOR] = icon_colors
		
		dict[menu_path] = data
		return menu_path

class PopupMenuPathParams:
	var popup_menu_path:String
	var base_popup:PopupMenu
	var signal_callable#:Callable
	var popup_items_dict:Dictionary
	
	var icon_array:Array = []
	var icon_color_array:Array = []
	var tool_tip_array:Array = []
	var metadata:Dictionary = {}
	var radio:= false
	var radio_is_checked:=false
	
	func _init(_popup_menu_path, _base_popup, _callable, _popup_items_dict, popup_data=null) -> void:
		popup_menu_path = clean_menu_path(_popup_menu_path)
		base_popup = _base_popup
		signal_callable = _callable
		popup_items_dict = _popup_items_dict
		
		if popup_data == null:
			return
		for key in popup_data.keys():
			var value = popup_data.get(key)
			if key == ParamKeys.ICON:
				icon_array = value
			elif key == ParamKeys.ICON_COLOR:
				icon_color_array = value
			elif key == ParamKeys.TOOL_TIP:
				tool_tip_array = value
			elif key == ParamKeys.RADIO:
				radio = value
			elif key == ParamKeys.RADIO_IS_CHECKED:
				radio_is_checked = value
			elif key == ParamKeys.METADATA:
				if value is not Dictionary:
					print("Metadata must be dictionary for popup: %s" % _popup_menu_path)
					continue
				metadata.merge(value)
			else:
				metadata[key] = value
	
	
	static func clean_menu_path(path):
		if path.ends_with("/"):
			path = path.erase(path.length()-1)
		if path.begins_with("/"):
			path = path.erase(0)
		return path
	
	func even_array_sizes():
		var slice_count = popup_menu_path.get_slice_count("/")
		var arrays = [
			icon_array,
			icon_color_array,
			tool_tip_array,
		]
		for array in arrays:
			var items_missing = slice_count - array.size()
			for i in range(items_missing):
				array.push_front(null)


class MouseHelper:
	var timer:Timer
	var selected_node
	var _mouse_in_panel:= true
	var _mouse_in_panel_time = 1
	
	signal timer_elapsed
	
	func _init(sel_node, callable=null) -> void:
		selected_node = sel_node
		
		timer = Timer.new()
		timer.wait_time = _mouse_in_panel_time
		selected_node.add_child(timer)
		
		if selected_node is PopupMenu:
			selected_node.popup_hide.connect(stop_timer)
			if callable == null:
				if BACKPORTED >= 4:
					timer_elapsed.connect(hide_popup)
			else:
				timer_elapsed.connect(callable)
		else:
			if not callable:
				print("No callable set for Popup Mouse Helper.")
			timer_elapsed.connect(callable)
		connect_node(selected_node)
	
	func connect_node(node):
		if not node.mouse_entered.is_connected(_on_mouse_entered):
			node.mouse_entered.connect(_on_mouse_entered)
		if not node.mouse_exited.is_connected(_on_mouse_exited):
			node.mouse_exited.connect(_on_mouse_exited)
	
	func _on_mouse_exited():
		_mouse_in_panel = false
		timer.start()
		await timer.timeout
		if _mouse_in_panel:
			return
		timer_elapsed.emit()
	
	func _on_mouse_entered():
		_mouse_in_panel = true
		if not timer.is_stopped():
			stop_timer()
	
	func stop_timer():
		timer.stop()
		timer.timeout.emit()
		timer.wait_time = _mouse_in_panel_time
	
	func hide_popup():
		selected_node.hide()
	
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			if is_instance_valid(timer):
				timer.queue_free()

static func create_popup_items_dict(_popup:PopupMenu):
	var dict = {}
	_create_popup_items_dict(_popup, dict)
	return dict

static func _create_popup_items_dict(_popup:PopupMenu, dict:Dictionary, path=""):
	for i in range(_popup.item_count):
		var submenu = _popup.get_item_submenu_node(i)
		if not is_instance_valid(submenu):
			continue
		var text = _popup.get_item_text(i)
		var popup_path = text
		if path != "":
			popup_path = path.path_join(text)
		dict[popup_path] = submenu
		_create_popup_items_dict(submenu, dict, popup_path)


static func add_single_item(_popup:PopupMenu, popup_path:String, popup_data:Dictionary, popup_items_dict:Dictionary):
	var path_count = popup_path.count("/")
	var callable = popup_data.get(ParamKeys.CALLABLE)
	var id = popup_data.get(ParamKeys.ID, -1)
	
	var popup_params = PopupMenuPathParams.new(popup_path, _popup, callable, popup_items_dict, popup_data)
	return _parse_popup_menu_path(popup_params, id)

static func set_popup_position(_popup:PopupMenu, offset:=Vector2i.ZERO):
	offset = offset * EditorInterface.get_editor_scale()
	_popup.position = DisplayServer.mouse_get_position() - offset

static func _get_icon(icon_name:String, theme_type:String="EditorIcons"):
	return EditorInterface.get_editor_theme().get_icon(icon_name, theme_type)

### EXAMPLE
#func _menu_pressed(btn_id:int, _popup:PopupMenu):   # example func for static parse
	#var layout_name = _popup.get_item_text(btn_id)  # _popup will be bound to the signal
	#_add_browser_window(layout_name)

#var items_dict = {        # example for parse dict.  Note path seperated by '/'.
	#"Dock|Undock" : {     # add icons in array if desired, else it will default to none.
		#ParamKeys.ICON: [Icons.make_floating],
		#option_keys.callable_key: on_dock_undock_button_pressed,
		#},
	#"Window/Toggle Split" : {
		#ParamKeys.ICON: [Icons.window, Icons.split_container],
		#ParamKeys.ICON_COLOR: [null, Color(5,5,5)],
		#option_keys.callable_key: on_toggle_split_button_pressed,
		#
		#},
	#"Window/Layouts" : {
		#ParamKeys.ICON: [Icons.window, Icons.panels_3_alt],
		#ParamKeys.TOOL_TIP: [null, "Open Layouts"]
		#option_keys.callable_key: on_layout_button_pressed,
		#}
	#}

	
