extends RefCounted

## Color slots shared by every text highlighter.
##
## Defaults are hardcoded so [code]Palette.new()[/code] is usable outside the editor.
## Use [method from_editor_settings] to match the user's script editor theme.

const SELF_PATH = "res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/palette.gd"
const _ES_BASE = "text_editor/theme/highlighting/"
const _ES_GD_BASE = "text_editor/theme/highlighting/gdscript/"

var text := Color("#cdcfd2")
var comment := Color("#7b7f85")
var string := Color("#ffeda1")
var number := Color("#a1ffe0")
var keyword := Color("#ff7085")
var symbol := Color("#abc9ff")
var key := Color("#bce0ff")
var section := Color("#c7ffed")
var tag := Color("#42ffc2")
var attribute := Color("#a2b8d9")
var heading := Color("#ff8ccc")
var link := Color("#57b3ff")
var code := Color("f9d092ff")
var error := Color("#ff5f5f")
var warning := Color("#ffbd5f")

var control_flow := Color("#ff8ccc")
var function := Color("#57b3ff")
var function_def := Color("#66e6ff")
var variable := Color("#bce0ff")
var string_name := Color("#ffc2a6")
var node_path := Color("#b8c47d")


var bracket := Color("#d1cc52")


static func from_editor_settings():
	var palette = load(SELF_PATH).new()
	palette.apply_editor_settings()
	return palette


## overwrite this palette's slots from the editor's script editor theme, no-op at runtime
func apply_editor_settings() -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton(&"EditorInterface"):
		return
	var editor_interface = Engine.get_singleton(&"EditorInterface")
	if editor_interface == null:
		return
	var editor_settings = editor_interface.get_editor_settings()
	if editor_settings == null:
		return

	text = _es_color(editor_settings, "text_color", text)
	comment = _es_color(editor_settings, "comment_color", comment)
	string = _es_color(editor_settings, "string_color", string)
	number = _es_color(editor_settings, "number_color", number)
	keyword = _es_color(editor_settings, "keyword_color", keyword)
	symbol = _es_color(editor_settings, "symbol_color", symbol)
	key = _es_color(editor_settings, "member_variable_color", key)
	section = _es_color(editor_settings, "function_color", section)
	tag = _es_color(editor_settings, "base_type_color", tag)
	attribute = _es_color(editor_settings, "member_variable_color", attribute)
	heading = _es_color(editor_settings, "function_color", heading)
	link = _es_color(editor_settings, "member_variable_color", link)
	code = _es_color(editor_settings, "member_variable_color", code)
	
	control_flow = _es_color(editor_settings, "control_flow_keyword_color", control_flow)
	function = _es_color(editor_settings, "function_color", function)
	function_def = _es_color(editor_settings, "function_definition_color", function_def)
	variable = _es_color(editor_settings, "member_variable_color", variable)
	string_name = _es_color(editor_settings, "string_name_color", string_name)
	node_path = _es_color(editor_settings, "node_path_color", node_path)
	
	error = editor_settings.get_setting("text_editor/theme/highlighting/comment_markers/critical_color")
	warning = editor_settings.get_setting("text_editor/theme/highlighting/comment_markers/warning_color")
	
	# bracket has no editor equiv

static func _es_color(editor_settings, setting:String, fallback:Color) -> Color:
	var full := _ES_BASE + setting
	if not editor_settings.has_setting(full):
		full = _ES_GD_BASE + setting
	if not editor_settings.has_setting(full):
		return fallback
	
	var value = editor_settings.get_setting(full)
	return value if value is Color else fallback
