#! namespace ALibEditor.Singleton class EditorRaycast3D
extends Singletons.Base

const Intercept3D = preload("res://addons/_lib/brohd/alib_editor/misc/editor_raycast/component/3D/intercept_3D.gd")
const ToolBase = preload("res://addons/_lib/brohd/alib_runtime/controller/viewport_raycast/component/base/tool_base.gd")
const Raycast = preload("res://addons/_lib/brohd/alib_editor/misc/editor_raycast/component/3D/raycast_3D.gd")

const PE_STRIP_CAST_SCRIPT = preload("res://addons/_lib/brohd/alib_editor/misc/editor_raycast/editor_raycast_3D.gd")
static func get_singleton_name() -> String:
	return "EditorRaycast3D"

static func get_instance() -> PE_STRIP_CAST_SCRIPT:
	return _get_instance(PE_STRIP_CAST_SCRIPT)

static func instance_valid() -> bool:
	return _instance_valid(PE_STRIP_CAST_SCRIPT)

static func call_on_ready(callable, print_err:bool=true):
	_call_on_ready(PE_STRIP_CAST_SCRIPT, callable, print_err)

func _get_ready_bool() -> bool:
	return is_node_ready()


static func register_tool(path:String, instance:RefCounted):
	var ins = get_instance()
	if ins.registered_tools.has(path):
		print("Tool already registered, overwriting: %s" % path)
	ins.registered_tools[path] = instance

static func unregister_tool(path:String):
	var ins = get_instance()
	if not ins.registered_tools.has(path):
		print("Tool not registered: %s" % path)
		return
	ins.registered_tools.erase(path)

static func set_current_tool(tool):
	var ins = get_instance()
	ins.current_tool = tool

static func set_enabled(state:bool):
	get_instance()._set_enabled(state)

static func get_current_viewport():
	return get_instance()._current_viewport

static func get_last_raycast_refreshed():
	var ins = get_instance()
	ins.refresh_last_raycast()
	return ins.last_raycast_result

static func get_last_raycast_result():
	return get_instance().last_raycast_result

static func get_transformed_raycast_result(apply_randomize:=false):
	var ins = get_instance()
	if ins.last_raycast_result != null:
		return ins.raycast.get_final_transform(ins.last_raycast_result, apply_randomize)
	

static func set_terrain_3D(node:Node):
	if not node.get_class() == "Terrain3D":
		return
	var ins = get_instance()
	ins.terrain_3D = node
	ins.raycast.terrain_3D = node

static func set_raycast_settings(new_settings:Dictionary):
	get_instance()._set_raycast_settings(new_settings)


static func visual_instance_raycast(cursor_node=null, ignore_nodes:=[], viewport=null):
	var ins = get_instance()
	if viewport == null:
		viewport = ins._current_viewport
	return ins.raycast.get_visual_instances(viewport, cursor_node, ignore_nodes)


var raycast:Raycast
var _raycast_settings:Dictionary

var terrain_3D:Node

var _intercepts = {}
var _current_viewport

var last_raycast_result
var last_raycast_transform

var current_tool:ToolBase
var registered_tools:= {}

var _enabled:=false


func _init(_node:Node=null):
	raycast = Raycast.new()
	pass

func _ready() -> void:
	_connect_viewports()

func _exit_tree() -> void:
	_disconnect_viewports()


func _connect_viewports():
	for i in range(4):
		var viewport = EditorInterface.get_editor_viewport_3d(i)
		var viewport_control = get_viewport_control(i)
		
		var intercept = Intercept3D.new()
		_intercepts[viewport] = intercept
		intercept.handled_event.connect(_on_intercept_handled_event.bind(viewport))
		intercept.gui_input.connect(_on_intercept_unhandled_input.bind(viewport))
		viewport_control.add_child(intercept)
		viewport_control.move_child(intercept, 0)
		
		viewport_control.mouse_entered.connect(_on_mouse_entered_viewport.bind(viewport))
		viewport_control.mouse_exited.connect(_on_mouse_exited_viewport)


func _disconnect_viewports():
	for i in range(4):
		var viewport_control = get_viewport_control(i)
		for c in viewport_control.get_children():
			if c is Intercept3D:
				c.queue_free()


func _set_enabled(state:bool):
	_enabled = state
	for intercept:Intercept3D in _intercepts.values():
		intercept.set_enabled(state)

func _set_raycast_settings(new_settings:Dictionary):
	_raycast_settings = new_settings
	raycast.settings = _raycast_settings
	raycast.on_settings_changed()


func _on_mouse_entered_viewport(viewport:Viewport):
	_current_viewport = viewport

func _on_mouse_exited_viewport():
	_current_viewport = null
	last_raycast_result = null
	last_raycast_transform = null
	if is_instance_valid(current_tool):
		current_tool.remove_cursor()


func _on_intercept_unhandled_input(event:InputEvent, viewport:Viewport):
	if not is_instance_valid(current_tool):
		last_raycast_result = null
		last_raycast_transform = null
		return
	if event is not InputEventMouseMotion:
		return
	#var raycast_result = raycast.get_raycast_collision(viewport)
	#raycast_result["viewport"] = viewport
	last_raycast_result = _get_raycast(viewport)
	current_tool.draw_cursor()


func _on_intercept_handled_event(event_type:Intercept3D.EventType, event:InputEvent, viewport:Viewport):
	if not is_instance_valid(current_tool):
		return
	if event_type == Intercept3D.EventType.NONE or event_type == Intercept3D.EventType.DISCARD:
		return
	current_tool.intercept_handled_event(event_type, event, viewport)
	#print("EVENT SINGLETON: ", Intercept3D.EventType.keys()[event_type])


func refresh_last_raycast():
	if last_raycast_result == null:
		return
	var viewport = last_raycast_result.get(Keys.VIEWPORT)
	if is_instance_valid(viewport):
		last_raycast_result = _get_raycast(viewport)


func _get_raycast(viewport):
	var raycast_result = raycast.get_raycast_collision(viewport)
	if raycast_result != null:
		raycast_result[Keys.VIEWPORT] = viewport
	return raycast_result

## idx is the desired Editor 3D viewport.
static func get_viewport_control(idx:int):
	var viewport = EditorInterface.get_editor_viewport_3d(idx)
	return viewport.get_parent().get_parent().get_child(1)

class Keys:
	const VIEWPORT = &"viewport"
