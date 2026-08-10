class_name SignalBusSingleton #! singleton-module
extends "res://addons/addon_lib/brohd/singleton/singleton_base.gd" #! ext Singletons.Base

const SignalBus = preload("res://addons/addon_lib/brohd/alib_runtime/signal_bus/signal_bus.gd")

const PE_STRIP_CAST_SCRIPT = preload("res://addons/addon_lib/brohd/alib_runtime/signal_bus/signal_bus_singleton.gd")

static func get_singleton_name() -> String:
	return "SignalBusSingleton"

static func get_instance() -> SignalBusSingleton:
	return _get_instance(PE_STRIP_CAST_SCRIPT)

static func instance_valid() -> bool:
	return _instance_valid(PE_STRIP_CAST_SCRIPT)

static func call_on_ready(callable, print_err:bool=true):
	_call_on_ready(PE_STRIP_CAST_SCRIPT, callable, print_err)

func _get_ready_bool() -> bool:
	return is_node_ready()


static func subscribe(bus_name:StringName, signal_name:StringName, callable:Callable):
	var bus = get_bus(bus_name)
	bus.subscribe(signal_name, callable)

static func unsubscribe(bus_name:StringName, signal_name:StringName, callable:Callable):
	var bus = get_bus(bus_name)
	bus.unsubscribe(signal_name, callable)
	if not bus.has_signals():
		get_instance()._bus_instances.erase(bus_name)

static func signal_emit(bus_name:StringName, signal_name:StringName, data:Dictionary={}):
	var bus = get_bus(bus_name)
	bus.signal_emit(signal_name, data)

static func signal_emitv(bus_name:StringName, signal_name:StringName, arg_array:Array=[]):
	var bus = get_bus(bus_name)
	bus.signal_emitv(signal_name, arg_array)


static func get_bus(bus_name:StringName):
	var ins = get_instance()
	return ins.create_or_get_bus(bus_name)

static func get_bus_names():
	var ins = get_instance()
	return ins._bus_instances.keys()


var _bus_instances:= {}

func create_or_get_bus(bus_name:StringName) -> SignalBus:
	if _bus_instances.has(bus_name):
		return _bus_instances[bus_name]
	var new_bus = SignalBus.new()
	_bus_instances[bus_name] = new_bus
	return new_bus
