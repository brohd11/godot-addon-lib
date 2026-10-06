extends SyntaxHighlighter

## Routing highlighter for Godot's default text file types.
##
## Set [member extension] or call [method set_file_path], and the matching per-type
## highlighter is picked up from [code]dispatcher.gd[/code]. Unhandled extensions fall back to
## plain text, so callers never branch on file type:
## [codeblock]
## const TextSyntaxHighlighter = preload("res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/text_syntax_highlighter.gd")
##
## var highlighter = TextSyntaxHighlighter.new()
## highlighter.palette = TextSyntaxHighlighter.Palette.from_editor_settings()
## highlighter.set_file_path(path)
## code_edit.syntax_highlighter = highlighter
## [/codeblock]

const Dispatcher = preload("res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/dispatcher.gd")
const Palette = preload("res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/palette.gd")

## Extension driving which highlighter runs, without the leading dot and lower cased.
var extension:String:
	set = set_extension
var palette:Palette = Palette.new():
	set = set_palette

## The active per-type highlighter, or null for an unhandled extension.
var _highlighter


func set_extension(value:String) -> void:
	var normalized := Dispatcher.normalize(value)
	if normalized == extension:
		return
	extension = normalized
	_highlighter = Dispatcher.get_highlighter(extension)
	_bind()
	clear_highlighting_cache()


func set_palette(value:Palette) -> void:
	palette = value if value != null else Palette.new()
	_bind()
	clear_highlighting_cache()


## Convenience for [member extension], taking the extension from a file path.
func set_file_path(path:String) -> void:
	set_extension(path.get_extension())


func _bind() -> void:
	if _highlighter != null:
		_highlighter.setup(get_text_edit(), palette)


func _get_line_syntax_highlighting(line:int) -> Dictionary:
	if _highlighter == null:
		return {}
	return _highlighter.get_line_highlighting(line)


func _clear_highlighting_cache() -> void:
	if _highlighter != null:
		_highlighter.clear_cache()


## Called when the highlighter is attached to a [TextEdit] and when the theme changes, which
## is the first point [method SyntaxHighlighter.get_text_edit] returns anything.
func _update_cache() -> void:
	_bind()
