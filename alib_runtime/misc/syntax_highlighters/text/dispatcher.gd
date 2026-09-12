
const PlainHighlighter = preload("res://addons/addon_lib/brohd/alib_runtime/misc/syntax_highlighters/text/types/plain_highlighter.gd")
const LogHighlighter = preload("res://addons/addon_lib/brohd/alib_runtime/misc/syntax_highlighters/text/types/log_highlighter.gd")
const MarkdownHighlighter = preload("res://addons/addon_lib/brohd/alib_runtime/misc/syntax_highlighters/text/types/markdown_highlighter.gd")
const IniHighlighter = preload("res://addons/addon_lib/brohd/alib_runtime/misc/syntax_highlighters/text/types/ini_highlighter.gd")
const JsonHighlighter = preload("res://addons/addon_lib/brohd/alib_runtime/misc/syntax_highlighters/text/types/json_highlighter.gd")
const YamlHighlighter = preload("res://addons/addon_lib/brohd/alib_runtime/misc/syntax_highlighters/text/types/yaml_highlighter.gd")
const TomlHighlighter = preload("res://addons/addon_lib/brohd/alib_runtime/misc/syntax_highlighters/text/types/toml_highlighter.gd")
const XmlHighlighter = preload("res://addons/addon_lib/brohd/alib_runtime/misc/syntax_highlighters/text/types/xml_highlighter.gd")

## Optional provider owned by GDSh. Keep this a path so ALib works without GDSh installed.
const GDSH_PROVIDER_PATH = "res://addons/addon_lib/gdsh/internal/script_highlighter_logic.gd"

## Formats bundled with ALib. GDSh is discovered separately when installed.
const EXTENSION_MAP := {
	"txt": PlainHighlighter,
	"md": MarkdownHighlighter,
	"cfg": IniHighlighter,
	"ini": IniHighlighter,
	"log": LogHighlighter,
	"json": JsonHighlighter,
	"yml": YamlHighlighter,
	"yaml": YamlHighlighter,
	"toml": TomlHighlighter,
	"xml": XmlHighlighter,
}

const NON_STATIC_MAP = {
	"gdsh": GDSH_PROVIDER_PATH,
}

## A fresh highlighter instance for [param extension], or null when it is not handled.
## Accepts "json", ".json" or "res://path/to/file.json".
static func get_highlighter(extension:String):
	var normalized = normalize(extension)
	if NON_STATIC_MAP.has(normalized):
		return get_non_static_provider(normalized)
	
	var script = EXTENSION_MAP.get(normalized)
	if script == null:
		return null
	return script.new()

static func get_supported_extensions() -> PackedStringArray:
	var extensions := PackedStringArray()
	for extension in EXTENSION_MAP:
		extensions.append(extension)
	for ext in NON_STATIC_MAP.keys():
		if has_non_static_provider(ext):
			extensions.append(ext)
	return extensions


static func normalize(extension:String) -> String:
	if extension.contains("."):
		extension = extension.get_extension()
	return extension.to_lower()


static func has_non_static_provider(ext:String):
	var normalized = normalize(ext)
	if NON_STATIC_MAP.has(normalized):
		return ResourceLoader.exists(NON_STATIC_MAP[normalized], "GDScript")
	return false

static func get_non_static_provider(ext:String):
	var normalized = normalize(ext)
	if not NON_STATIC_MAP.has(normalized):
		return null
	var provider = ResourceLoader.load(NON_STATIC_MAP[normalized], "GDScript") as GDScript
	if provider == null or not provider.can_instantiate():
		return null
	return provider.new()
