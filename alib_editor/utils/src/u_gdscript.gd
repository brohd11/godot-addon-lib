#! namespace ALibEditor.Utils class UGDScript

const UString = preload("uid://bbk1yedqm7a6a") #! resolve ALibRuntime.Utils.UString.Methods
const UStringToken = preload("uid://ckamjm80ocd1x") #! resolve ALibRuntime.Utils.UString.Token
const UClassDetail = preload("uid://dpmubecadgfk8") #! resolve ALibRuntime.Utils.UGDScript.UClassDetail


const VarInsertType = preload("res://addons/addon_lib/brohd/alib_editor/utils/src/gdscript/var_insert_type.gd")

enum ContextType {
	
}


static func resolve_global_script(line:String, tokens=null, path_insert:='preload("%s")'):
	if tokens == null:
		tokens = UStringToken.tokenize_string(line, false)
	var replace = false
	for tok in tokens.tokens:
		var front = UString.get_member_access_front(tok)
		if UClassDetail.get_global_class_path(front) == "":
			continue
		var value_string = _get_resolved_access_path(tok)
		if value_string == "":
			continue
		var has_suffix = value_string.find(".gd.") > -1
		var new_string = path_insert
		var replace_arr = [value_string]
		if has_suffix:
			new_string += ".%s"
			var script_path = value_string.get_slice(".gd.", 0) + ".gd"
			var script_suff = value_string.get_slice(".gd.", 1)
			replace_arr = [script_path, script_suff]
		
		var formatted = new_string % replace_arr
		line = line.replace(tok, formatted)
		replace = true
	
	return line

static func get_global_scripts_in_line(current_script:GDScript, line:String, tokens=null):
	return _get_scripts_in_line(current_script, line, tokens, true)

static func get_scripts_in_line(current_script:GDScript, line:String, tokens=null):
	return _get_scripts_in_line(current_script, line, tokens, false)

static func _get_scripts_in_line(current_script:GDScript, line:String, tokens=null, only_global:=true):
	var data = {}
	if tokens == null:
		tokens = UStringToken.tokenize_string(line, false)
	
	var preloads = UClassDetail.script_get_preloads(current_script)
	for tok in tokens.tokens:
		var front = UString.get_member_access_front(tok)
		var global_path = UClassDetail.get_global_class_path(front)
		if only_global:
			if global_path == "":
				continue
		else:
			if global_path == "" and not front in preloads:
				continue
		
		var value_string = _get_resolved_access_path(tok, current_script)
		if value_string == "":
			continue
		
		var script_path = value_string
		var script_suff = ""
		var full_path = script_path
		if value_string.find(".gd.") > -1:
			script_path = value_string.get_slice(".gd.", 0) + ".gd"
			script_suff = value_string.get_slice(".gd.", 1)
			full_path = script_path + "." + script_suff
		
		var preload_path = 'preload("%s")' % script_path
		var string_path = '"%s"' % script_path
		if script_suff != "":
			preload_path += "." + script_suff
			string_path += "." + script_suff
		
		
		
		data[tok] = {
			"path": script_path,
			"suffix": script_suff,
			"full_path": full_path,
			"preload_path": preload_path,
			"string_path": string_path
		}
	
	
	return data


static func _get_resolved_access_path(member_access_path:String, script=null):
	if script == null:
		script = EditorInterface.get_script_editor().get_current_script()
	var value = UClassDetail.resolve_script_access_path(script, member_access_path)
	if value == null:
		return ""
	return value

static func get_access_path_scripts(script:GDScript, member_access_path:String):
	var scripts = {}
	#if member_access_path.count(".") == 0:
		#var script_path = UClassDetail.resolve_script_access_path(script, member_access_path)
		#if script_path != "":
			#scripts[script_path] = {"self": member_access_path, "suffix": ""}
		#return scripts
	

	var parts
	if member_access_path.count(".") == 0:
		parts = [member_access_path]
	else:
		parts = member_access_path.split(".", false)
	
	var current_script = script
	for i in range(parts.size()):
		var part = parts[i]
		var next_script = UClassDetail.get_member_info_by_path(current_script, part, ["const"])
		if next_script is GDScript and next_script.resource_path != "":
			var suffix = ""
			var start_i = i + 1
			if start_i < parts.size():
				for n_i in range(start_i, parts.size()):
					if suffix != "":
						suffix += "."
					suffix += parts[n_i]
			
			scripts[next_script.resource_path] = {
				"self": part,
				"suffix":suffix
			}
			current_script = next_script
		else:
			break
	return scripts


static func get_context(line, position):
	
	pass
