#! namespace ALibEditor.Singleton class ScriptListManager
extends Singletons.Base

const _STABLE_TARGET := 8
const _TIMEOUT_MS := 5000

const TEXT_FILE_TYPES = ["gd", "json", "cfg", "txt", "ini", "md"]

var text_file_types:= []

const PE_STRIP_CAST_SCRIPT = preload("res://addons/addon_lib/brohd/alib_editor/misc/script_list/script_list_manager.gd")
static func get_singleton_name() -> String:
	return "ScriptListManager"

static func get_instance() -> PE_STRIP_CAST_SCRIPT:
	return _get_instance(PE_STRIP_CAST_SCRIPT)

static func instance_valid() -> bool:
	return _instance_valid(PE_STRIP_CAST_SCRIPT)

static func call_on_ready(callable, print_err:bool=true):
	_call_on_ready(PE_STRIP_CAST_SCRIPT, callable, print_err)

func _get_ready_bool() -> bool:
	return _initialized

var _initialized:=false

var editor_script_tab_container:TabContainer

var script_list:ItemList
var filter_line_edit:LineEdit
var item_cache:= {}

var current_script_editor:Node

var script_editor_map:= {}

var _last_script_signature:Array
var _update_debounce:bool = false
var _update_timer:Timer

var tool_color:Color

signal cache_updated

func _ready() -> void:
	EditorNodeRef.call_on_ready(_on_enr_ready)
	tool_color = EditorInterface.get_editor_theme().get_color(&"accent_color", &"Editor")
	tool_color.s = min(tool_color.s * 1.5, 1.0)
	
	EditorInterface.get_editor_settings().settings_changed.connect(_on_editor_settings_changed)
	_get_text_file_types()
	

func _on_enr_ready():
	var side_bar = EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.SCRIPT_EDITOR_SIDEBAR_V_SPLIT)
	filter_line_edit = side_bar.get_child(0).get_child(0)
	script_list = side_bar.get_child(0).get_child(1)

	editor_script_tab_container = EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.SCRIPT_EDITOR_TAB_CONTAINER)

	# item_list must be populated to be populated
	await _await_script_list_settled()
	
	current_script_editor = editor_script_tab_container.get_current_tab_control()
	update_cache(true)
	
	_update_timer = Timer.new()
	add_child(_update_timer)
	_update_timer.wait_time = 1.0
	_update_timer.timeout.connect(_on_update_timer_timeout)
	_update_timer.start()
	
	_initialized = true
	_connect_signals_def.call_deferred()

# check if item_list is populated, check at least x frames before returning
func _await_script_list_settled():
	
	var expected := _get_expected_open_count()
	var stable_frames := 0
	var last_count := -1
	var start_ms := Time.get_ticks_msec()
	while true:
		var count := script_list.item_count
		if count == last_count:
			stable_frames += 1
		else:
			stable_frames = 0
			last_count = count

		var is_ready := (count > 0 or expected == 0) and stable_frames >= _STABLE_TARGET
		if is_ready or Time.get_ticks_msec() - start_ms >= _TIMEOUT_MS:
			return
		await get_tree().process_frame

# Count of scripts/help the editor is about to restore, read from its saved layout.
func _get_expected_open_count() -> int:
	var path = EditorInterface.get_editor_paths().get_project_settings_dir().path_join("editor_layout.cfg")
	var cfg = ConfigFile.new()
	if cfg.load(path) != OK:
		return 0
	var open_scripts = cfg.get_value("ScriptEditor", "open_scripts", [])
	var open_help = cfg.get_value("ScriptEditor", "open_help", [])
	return open_scripts.size() + open_help.size()

func _connect_signals_def():
	editor_script_tab_container.tab_changed.connect(_on_editor_tab_changed)
	editor_script_tab_container.child_order_changed.connect(_on_editor_tab_child_order_changed)
	ScriptEditorRef.subscribe(ScriptEditorRef.Event.VALIDATE_SCRIPT, _on_script_editor_validate, 1)
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed, 1)


func _on_editor_settings_changed():
	_get_text_file_types()

func _on_update_timer_timeout(): # quick check for differences
	if _update_debounce:
		return # if updating, abort
	var arr = _get_list_signature()
	if arr != _last_script_signature:
		update_cache()
	_last_script_signature = arr

func _get_list_signature() -> Array:
	var sig = []
	for i in range(script_list.item_count): # meta + text to catch reorders, renames
		var meta = script_list.get_item_metadata(i)
		var text = script_list.get_item_text(i) 
		sig.append(str(meta) + "_" + text)
	return sig

func _on_editor_tab_child_order_changed():
	update_cache()

func _on_editor_tab_changed(_arg):
	current_script_editor = editor_script_tab_container.get_current_tab_control()
	update_cache()

func _on_script_editor_validate():
	update_cache()

func _on_filesystem_changed():
	_update_debounce = false
	text_file_types = get_text_file_types() # should really be editor settings changed
	update_cache()


func update_cache(clear_filter:=false):
	if _update_debounce:
		return
	
	_update_debounce = true
	await _update_cache(clear_filter)
	_update_debounce = false

func _update_cache(clear_filter:=false):
	var current_text = filter_line_edit.text
	if current_text != "":
		if not clear_filter:
			return
		filter_line_edit.clear() # option is to return or clear. This should probably just be cleared so it is always accurate, say script editor opened when filtering
	
	script_editor_map = {}
	item_cache.clear()
	#item_cache = get_all_script_data()
	var script_tab_child_count:= editor_script_tab_container.get_child_count()
	for i in range(script_list.item_count):
		var data = get_item_data(i)
		var script_idx = data.get(Keys.SCRIPT_IDX)
		item_cache[script_idx] = data
		if script_idx < script_tab_child_count:
			var script_editor = editor_script_tab_container.get_child(script_idx)
			script_editor_map[script_editor] = data.get(Keys.TOOLTIP)
			if script_editor.get_class().ends_with("TextEditor"):
				script_editor_map[script_editor.get_base_editor()] = data.get(Keys.TOOLTIP)
	
	#if current_text != "":
		#filter_line_edit.text = current_text
		#filter_line_edit.text_changed.emit(current_text)
	
	cache_updated.emit()
	await get_tree().process_frame
	_update_timer.start()

# need to redo
func get_cached_item_data(tooltip:String):
	for script_idx in item_cache.keys():
		var data = item_cache[script_idx]
		if data.get(Keys.TOOLTIP) == tooltip:
			return data

func get_current_script_editor():
	return current_script_editor

func get_current_script_editor_index():
	return current_script_editor.get_index()

func get_current_item():
	# script list can be subject to lag, index maps to the script list items. Should be valid
	if is_instance_valid(current_script_editor):
		return get_current_script_editor_index()
	var sel = -1
	var items = script_list.get_selected_items()
	if not items.is_empty():
		sel = items[0]
	return sel


func get_item_by_tooltip(tooltip:String):
	var data = get_cached_item_data(tooltip)
	if data == null:
		return -1
	return data.get(Keys.ITEM_IDX, -1)


func get_current_item_data():
	var sel = get_current_item()
	if sel > -1:
		return get_item_data(sel)
	return {}

func get_item_data(idx:int):
	var text = script_list.get_item_text(idx)
	var tooltip = script_list.get_item_tooltip(idx)
	var icon = script_list.get_item_icon(idx)
	var icon_mod = script_list.get_item_icon_modulate(idx)
	var fg_color = script_list.get_item_custom_fg_color(idx)
	var script_idx = script_list.get_item_metadata(idx)
	return {
		Keys.ITEM_IDX: idx,
		#Keys.IDX: idx,
		Keys.NAME:text,
		Keys.TOOLTIP:tooltip,
		Keys.ICON: icon,
		Keys.ICON_MOD: icon_mod,
		Keys.FG_COLOR: fg_color,
		Keys.SCRIPT_IDX: script_idx,
		}


func is_item_tool(idx:int):
	return is_data_tool(get_item_data(idx))

func is_data_tool(data:Dictionary):
	return data.get(Keys.ICON_MOD) != Color.WHITE


func close_script_by_idx(idx:int):
	script_list.item_clicked.emit(idx, Vector2(), MOUSE_BUTTON_MIDDLE)

func right_click_by_idx(idx:int, position:Vector2):
	script_list.item_clicked.emit(idx, position, MOUSE_BUTTON_RIGHT)

func activate_item_by_idx(idx:int):
	script_list.item_selected.emit(idx)


func close_script_by_tooltip(tooltip:String):
	var idx = get_item_by_tooltip(tooltip)
	if idx == -1:
		printerr("COULD NOT GET SCRIPT::CLOSE::", tooltip)
		return
	script_list.item_clicked.emit(idx, Vector2(), MOUSE_BUTTON_MIDDLE)

func right_click_by_tooltip(tooltip:String, position:Vector2):
	var idx = get_item_by_tooltip(tooltip)
	if idx == -1:
		printerr("COULD NOT GET SCRIPT::RIGHT CLICK::", tooltip)
		return
	script_list.item_clicked.emit(idx, position, MOUSE_BUTTON_RIGHT)

func activate_item_by_tooltip(tooltip:String):
	var idx = get_item_by_tooltip(tooltip)
	if idx == -1:
		printerr("COULD NOT GET SCRIPT::ACTIVATE::", tooltip)
		return
	
	script_list.item_selected.emit(idx)

func get_all_script_data():
	var all_data = {}
	for i in range(script_list.item_count):
		var data = get_item_data(i)
		all_data[data.get(Keys.SCRIPT_IDX)] = data
	return all_data

func get_all_script_data_tooltip_key():
	var all_data = {}
	for i in range(script_list.item_count):
		var data = get_item_data(i)
		all_data[data.get(Keys.TOOLTIP)] = data
	return all_data

func get_script_index(file_path:String):
	var ext = file_path.get_extension()
	if not ext in get_text_file_types(): return -1
	var script_list_data = get_cached_item_data(file_path)
	if script_list_data == null: return -1
	return script_list_data.get(Keys.SCRIPT_IDX, -1)

## Pass FileSystemSingleton instance. This allows ScriptTabs to be used without including the singleton.
func get_script_index_or_open(file_path:String, filesystem_singleton=null):
	var ext = file_path.get_extension()
	var index = get_script_index(file_path)
	if index > -1:
		return index
	if filesystem_singleton != null:
		if filesystem_singleton.instance_valid():
			filesystem_singleton.activate_path(file_path)
	elif ext == "gd":
		EditorInterface.edit_resource(load(file_path))
	else:
		printerr("ScriptListManager - Can't open file, no resource loader:", file_path)
	return -1


func clear_script_list_filter():
	if is_instance_valid(filter_line_edit) and not filter_line_edit.text.is_empty():
		filter_line_edit.clear()

func script_list_filtering():
	return filter_line_edit.text != ""


static func get_text_file_types(include_script:bool=true):
	var arr = get_instance()._get_text_file_types().duplicate()
	if include_script:
		arr.append("gd")
		#arr.append("cs")
	return arr

func _get_text_file_types():
	if not text_file_types.is_empty():
		return text_file_types
	var types:String = EditorInterface.get_editor_settings().get_setting("docks/filesystem/textfile_extensions")
	text_file_types = types.split(",", false)
	for i in text_file_types.size():
		text_file_types[i] = text_file_types[i].strip_edges()
	return text_file_types

class Keys:
	const ITEM_IDX = &"item_idx"
	const NAME = &"name"
	const TOOLTIP = &"tooltip"
	const ICON = &"icon"
	const ICON_MOD = &"icon_mod"
	#const IDX = &"idx"
	const SCRIPT_IDX = &"script_idx"
	const FG_COLOR = &"fg_color"
