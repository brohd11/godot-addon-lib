#! namespace ALibEditor.Singleton class EditorIcons
extends Singletons.Base

const UTexture = preload("uid://ddu76iygjkxih") #! resolve ALibRuntime.Utils.UTexture

## Implement in extended classes

 #Use 'PE_STRIP_CAST_SCRIPT' to auto strip type casts with plugin exporter, if the class is not a global name
const PE_STRIP_CAST_SCRIPT = preload("res://addons/addon_lib/brohd/alib_editor/misc/icons/editor_icons.gd")
static func get_singleton_name() -> String:
	return "EditorIconsSingleton"

static func get_instance() -> PE_STRIP_CAST_SCRIPT:
	return _get_instance(PE_STRIP_CAST_SCRIPT)

static func instance_valid() -> bool:
	return _instance_valid(PE_STRIP_CAST_SCRIPT)

static func call_on_ready(callable, print_err:bool=true):
	_call_on_ready(PE_STRIP_CAST_SCRIPT, callable, print_err)

func _get_ready_bool() -> bool:
	return is_node_ready()

static func get_icon_white(icon_name:String, brightness:=0.8, overwite:=false):
	return get_instance()._get_icon(icon_name, Color.WHITE, brightness, overwite)

static func get_icon(icon_name:String, color=null, brightness:=0.8, overwite:=false):
	return get_instance()._get_icon(icon_name, color, brightness, overwite)

static func get_visibility_icon(visible:bool):
	if visible:
		return get_instance()._get_icon_simple("GuiVisibilityVisible")
	return get_instance()._get_icon_simple("GuiVisibilityHidden")

static func get_class_icon(object:Object):
	return get_instance()._get_class_icon(object)


static func clear_cache():
	get_instance()._cache.clear()

var _cache:= {}

var editor_theme:Theme
var icon_list:PackedStringArray

func _ready() -> void:
	editor_theme = EditorInterface.get_editor_theme()
	icon_list = editor_theme.get_icon_list("EditorIcons")

func _get_icon_simple(icon_name:String):
	return editor_theme.get_icon(icon_name, "EditorIcons")

func _get_icon(icon_name:String, color=null, brightness:=0.8, overwrite:=false):
	if not icon_list.has(icon_name):
		printerr("No icon: %s in EditorIcons." % icon_name)
		return
	var icon_dict = _cache.get_or_add(icon_name, {})
	var color_dict = icon_dict.get_or_add(color, {})
	if not overwrite:
		if color_dict.has(brightness):
			return color_dict[brightness]
	
	var icon = editor_theme.get_icon(icon_name, "EditorIcons")
	if color == null:
		return icon
	color *= brightness
	var texture = UTexture.get_modulated_icon(icon, color)
	color_dict[brightness] = texture
	return texture

func _get_class_icon(node:Object):
	var node_class:String = node.get_class()
	var icon:Texture2D = editor_theme.get_icon(node_class, &"EditorIcons")
	if icon:
		return icon
	else:
		return editor_theme.get_icon("MissingNode",  &"EditorIcons")
