#! namespace ALibRuntime.Utils class USort

static func sort_priority_dict(key_priority_dict:Dictionary) -> Dictionary:
	var keys = key_priority_dict.keys()
	# basic sort of priorities with ref to key
	keys.sort_custom(func(a, b):
		var pri_a = key_priority_dict[a]
		var pri_b = key_priority_dict[b]
		if pri_a != pri_b:
			return pri_a < pri_b
		else:
			return false) # if they are the same, just keep order
		
	
	var result_dict: Dictionary = {}
	for i in range(keys.size()):
		var current_key = keys[i]
		result_dict[current_key] = i
	
	return result_dict

static func sort_dict_with_priority_key(dict:Dictionary, priority_key) -> Dictionary:
	var keys = dict.keys()
	# basic sort of priorities with ref to key
	keys.sort_custom(func(a, b):
		var pri_a = dict[a].get(priority_key, 1000)
		var pri_b = dict[b].get(priority_key, 1000)
		if pri_a != pri_b:
			return pri_a < pri_b
		else:
			return false) # if they are the same, just keep order
	
	var result_dict: Dictionary = {}
	for i in range(keys.size()):
		var current_key = keys[i]
		result_dict[current_key] = dict[current_key]
	
	return result_dict
