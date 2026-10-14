#! namespace ALibRuntime.Utils.UProfile class TimeFunction

var _one_shot := true
var iterations:int = 10

enum TimeScale{
	MSEC,
	USEC
}
var _message = ""
var _time_scale: TimeScale = TimeScale.MSEC
var _unit:String = "msec"
var _start_time:int = 0
var _end_time:int = 0
var _accumulated_time:int = 0
var _current_time_count:int = 0

var callable:Callable

func _init(msg="", _ts:TimeScale=TimeScale.USEC, one_shot:=true, _callable=null) -> void:
	_message = msg
	_one_shot = one_shot
	_time_scale = _ts
	
	if _callable:
		if _callable is Callable:
			callable = _callable
			if one_shot:
				run_callable()
		else:
			print("Must pass callable.")
		return
	
	if _one_shot:
		start()

func start():
	if _time_scale == TimeScale.MSEC:
		_start_time = Time.get_ticks_msec()
	else:
		_unit = "usec"
		_start_time = Time.get_ticks_usec()

func stop(msg:="", lap:=false):
	if _time_scale == TimeScale.MSEC:
		_end_time = Time.get_ticks_msec()
	else:
		_end_time = Time.get_ticks_usec()
	_print(msg)
	if lap:
		if _time_scale == TimeScale.MSEC:
			_start_time = Time.get_ticks_msec()
		else:
			_start_time = Time.get_ticks_usec()

func _print(msg_overide:=""):
	if _one_shot:
		var print_string = "Function complete in: "
		if msg_overide != "":
			print_string = "%s: " % msg_overide
		elif _message != "":
			print_string = "%s: " % _message
		if callable:
			var callable_name = callable.get_method() as String
			print_string = "Function: '%s' complete in: " % callable_name
		print(print_string, _end_time - _start_time, _unit)
	else:
		_accumulated_time += _end_time - _start_time
		_current_time_count += 1
		if _current_time_count >= iterations:
			var print_string = "Average speed in "
			if msg_overide != "":
				print_string = "%s: " % msg_overide
			elif _message != "":
				print_string = "%s: " % _message
			if callable:
				var callable_name = callable.get_method() as String
				print_string = "Function: '%s' average speed in: " % callable_name
			var result:int = _accumulated_time / iterations
			print(print_string, iterations, " iterations: ", result , _unit)
			_accumulated_time = 0
			_current_time_count = 0


func run_callable():
	if not callable:
		return
	_one_shot = true
	start()
	await callable.call()
	stop()

static func time_func(_callable:Callable, message:="", unit:TimeScale=TimeScale.USEC):
	var t = new(message, unit)
	var res = _callable.call()
	t.stop()
	return res
