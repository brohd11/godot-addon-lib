#! namespace ALibRuntime.Utils.UProfile class TimeBudget

var _time_budget:int = 5000

var _start_time:int = 0
var _total_acc_time:int = 0

var _cycle_start_time:int = 0
var _accumulated_time:int = 0

func _init() -> void:
	_start_time = Time.get_ticks_usec()

## Set time budget in msec, default is 5msec
func set_time_budget(msec:float):
	# convert to usec for granularity
	_time_budget = int(msec * 1000)


func get_total_time(as_msec:=true) -> float:
	var time:int = Time.get_ticks_usec() - _start_time
	if as_msec:
		return float(time * 0.001)
	return float(time)

func get_working_time(as_msec:=true) -> float:
	if as_msec:
		return float(_total_acc_time * 0.001)
	return float(_total_acc_time)


func start_cycle() -> void:
	_cycle_start_time = Time.get_ticks_usec()

## returns true if over budget
func end_cycle() -> bool:
	var cycle_time = Time.get_ticks_usec() - _cycle_start_time
	_accumulated_time += cycle_time
	_total_acc_time += cycle_time
	if _accumulated_time >= _time_budget:
		_accumulated_time = 0
		return true
	
	return false
