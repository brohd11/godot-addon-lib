@tool
extends Resource

const UFile = preload("uid://bl33psa06nv1e") #! resolve ALibRuntime.Utils.UFile.Methods

@export var _collection_name:String="untitled"
@export var _collection_data:= {}


func set_collection_name(new_name:String):
	_collection_name = new_name

func get_collection_name():
	return _collection_name

func set_data(data:Dictionary):
	_collection_data = data

func get_data():
	return _collection_data

#! keys metadata:Dictionary path:String uid:String index:int
func get_file_data(uid_or_path:String) -> Dictionary:
	var uid = UFile.path_to_uid(uid_or_path)
	return _collection_data.get(uid, {})

func clear():
	_collection_data.clear()

func get_collection_size():
	return _collection_data.size()

func new_file(file_path:String, metadata:Dictionary={}):
	var file_data = _get_file_data(file_path)
	var path = file_data.get(Keys.PATH)
	var uid = file_data.get(Keys.UID)
	
	var collection_uids = get_uids()
	if uid in collection_uids: return false
	
	var new_file_data = {
		Keys.PATH: path,
		Keys.UID: uid,
		Keys.INDEX: _collection_data.size(),
		Keys.METADATA: metadata,
	}
	
	_collection_data[uid] = new_file_data
	return true

func remove_file(file_path:String):
	var file_data = _get_file_data(file_path)
	var uid = file_data.get(Keys.UID)
	if not _collection_data.has(uid):
		print("File not in collection: %s" % file_data.get(Keys.PATH))
		return
	_collection_data.erase(uid)
	_reindex()

func move_file(current_idx, new_idx):
	for data in _collection_data.values():
		var index = data.get(Keys.INDEX)
		if index == current_idx:
			data[Keys.INDEX] = new_idx
		elif index == new_idx:
			data[Keys.INDEX] = current_idx


func get_file_paths(sorted:=true):
	var paths = []
	var collection_uids = get_uids(sorted)
	for uid in collection_uids:
		paths.append(_get_path(uid))
	return paths

func get_uids(sorted:=false):
	var collection_uids = _collection_data.keys()
	if sorted:
		collection_uids.sort_custom(_sort_indexes)
	return collection_uids

func _get_path(key:String):
	var data = _collection_data.get(key)
	if data:
		return data.get(Keys.PATH)
	else:
		print("Not in collection: %s" % key)

func _get_index(key:String):
	var data = _collection_data.get(key)
	if data:
		return data.get(Keys.INDEX)
	else:
		print("Not in collection: %s" % key)

func _sort_indexes(a:String, b:String):
	var a_idx = _collection_data[a].get(Keys.INDEX)
	var b_idx = _collection_data[b].get(Keys.INDEX)
	return a_idx < b_idx

func _get_file_data(file_path:String):
	var path = file_path
	var uid = file_path
	if path.begins_with("uid/"):
		path = UFile.uid_to_path(file_path)
	else:
		uid = UFile.path_to_uid(file_path)
		if UFile.uid_invalid(uid):
			uid = file_path
	return {Keys.PATH: path, Keys.UID: uid}

func _reindex():
	var sorted_uids = get_uids(true)
	for i in range(sorted_uids.size()):
		_collection_data[sorted_uids[i]]["index"] = i

class Keys:
	const PATH = &"path"
	const UID = &"uid"
	const INDEX = &"index"
	const METADATA = &"metadata"
