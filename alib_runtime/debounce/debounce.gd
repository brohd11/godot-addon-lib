class_name Debounce
extends "res://addons/addon_lib/brohd/singleton/singleton_base.gd" #! ext Singletons.Base

const PE_STRIP_CAST_SCRIPT = preload("res://addons/addon_lib/brohd/alib_runtime/debounce/debounce.gd")
static func get_singleton_name() -> String:
	return "Debounce"

static func get_instance() -> PE_STRIP_CAST_SCRIPT:
	return _get_instance(PE_STRIP_CAST_SCRIPT)

static func instance_valid() -> bool:
	return _instance_valid(PE_STRIP_CAST_SCRIPT)

static func call_on_ready(callable, print_err:bool=true):
	_call_on_ready(PE_STRIP_CAST_SCRIPT, callable, print_err)

func _get_ready_bool() -> bool:
	return is_node_ready()

enum DebounceType{
	FRAME,
	TIMER,
	DEFER,
}

var _current_debounces:= {}
var debounce_timer:Timer

func _ready() -> void:
	debounce_timer = Timer.new()
	add_child(debounce_timer)

static func debouncing(key:Variant):
	return get_instance()._current_debounces.has(key)

static func start_debounce(key:Variant, type:DebounceType=DebounceType.FRAME, time:=1) -> bool:
	var ins = get_instance()
	if ins._current_debounces.has(key):
		return false
	
	if type == DebounceType.DEFER:
		ins._current_debounces[key] = true
		ins._on_defer.call_deferred(key)
	elif type == DebounceType.FRAME:
		ins._current_debounces[key] = true
		ins._on_frame(key)
	elif type == DebounceType.TIMER:
		var timer = ins.get_timer()
		timer.wait_time = time
		if not timer.timeout.is_connected(ins._on_timer_timeout):
			timer.timeout.connect(ins._on_timer_timeout.bind(key))
		timer.start(time)
		ins._current_debounces[key] = timer
	
	return true


func _on_frame(key:Variant):
	await get_tree().process_frame
	_current_debounces.erase(key)

func _on_defer(key:Variant):
	_current_debounces.erase(key)

func _on_timer_timeout(key:Variant):
	var timer = _current_debounces[key]
	if timer != debounce_timer:
		timer.queue_free()
	_current_debounces.erase(key)

func get_timer() -> Timer:
	if debounce_timer.is_stopped():
		return debounce_timer
	var timer:= Timer.new()
	add_child(timer)
	return timer
