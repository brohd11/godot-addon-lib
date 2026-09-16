#! namespace ALibRuntime class DebugPrint

const PRINT_DEBUG = false

#! arg_location section:S
static func print_deb(section:Variant, ...msg:Array):
	if not PRINT_DEBUG:
		return
	var _print = false
	if section in _PRINT:
		_print = true
		msg.push_front(section)
	elif section is Object:
		var script = section.get_script()
		if script:
			if script.resource_path in _PATHS:
				_print = true
				var file_name = script.resource_path.get_file()
				if file_name.is_empty():
					file_name = "Inner Class Debug"
				msg.push_front(file_name)
	
	if _print:
		print("::".join(msg))

class S:
	const DEBUG = &"debug"
	
	
	class Path:
		const GDScriptParser = ""

const _PRINT = [
	S.DEBUG
]

const _PATHS = [
	"res://addons/addon_lib/gdscript_parser/gdscript_parser.gd"
]


static func print_enum(_enum:Dictionary, selected:int):
	print(_enum.keys()[selected])
