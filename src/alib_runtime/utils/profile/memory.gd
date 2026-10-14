#! namespace ALibRuntime.Utils.UProfile class Memory

var _mem_start:int
var _mem_total:int

var _message:String

func _init(msg:String="") -> void:
	_message = msg
	_mem_start = OS.get_static_memory_usage()

func stop(msg:String=""):
	_mem_total = OS.get_static_memory_usage() - _mem_start
	_print_mem(msg)


func _print_mem(msg:String=""):
	var message = msg
	if message.is_empty():
		message = _message
	if message.is_empty():
		message = "Memory Difference"
	
	print(message + ": ", String.humanize_size(_mem_total))
