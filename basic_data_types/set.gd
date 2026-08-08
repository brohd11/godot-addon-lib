#! namespace BasicData class Set

static func add(s:Dictionary, to_add:Variant) -> void:
	s[to_add] = true

static func remove(s:Dictionary, to_remove:Variant) -> void:
	s.erase(to_remove)

static func members(s:Dictionary) -> Array:
	return s.keys()


class Instance:
	var _data:Dictionary = {}
	
	func add(to_add:Variant) -> void:
		_data[to_add] = true

	func remove(to_remove:Variant) -> void:
		_data.erase(to_remove)
	
	func has(v:Variant):
		return _data.has(v)

	func members() -> Array:
		return _data.keys()
