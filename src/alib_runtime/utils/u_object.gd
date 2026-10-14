#! namespace ALibRuntime.Utils class UObject

const PLUGIN_EXPORTED = false
const PRINT_ERR = not PLUGIN_EXPORTED

static func disconnect_signals_of_name(object:Object, signal_name:String) -> Array[Dictionary]:
	var signal_list:Array[Dictionary] = object.get_signal_connection_list(signal_name)
	for data:Dictionary in signal_list:
		var callable:Callable = data.get("callable")
		object.text_changed.disconnect(callable)
	return signal_list

static func connect_signals_from_list(object:Object, signal_list:Array[Dictionary]) -> void:
	for data:Dictionary in signal_list:
		var callable:Callable = data.get("callable")
		var flags:int = data.get("flags")
		if not object.text_changed.is_connected(callable):
			object.text_changed.connect(callable, flags)
		elif PRINT_ERR:
			printerr("SIGNAL ALREADY CONNECTED::",callable.get_object(), "::", callable.get_method())
