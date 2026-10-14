#! namespace ALibRuntime.Utils class UList


static func get_next_item(list_size:int, current_idx:int=-1):
	if list_size == 0:
		return -1
	if current_idx == -1:
		return 0
	var last = list_size - 1
	var next = current_idx + 1
	if next > last:
		next = 0
	return next

static func get_previous_item(list_size:int, current_idx:int=-1):
	if list_size == 0:
		return -1
	var last = list_size - 1
	if current_idx == -1:
		return last
	var prev = current_idx - 1
	if prev < 0:
		prev = last
	return prev
