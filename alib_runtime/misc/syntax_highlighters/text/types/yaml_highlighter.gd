extends "res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/hl_base.gd"

## yml, yaml - keys, values, anchors and block scalars.
##
## Multiline: literal ([code]|[/code]) and folded ([code]>[/code]) block scalars. The opening
## line's indent is packed into the high bits of the state so the block can be closed by the
## first line that dedents back to it.
##
## Not handled: flow scalars quoted across a line break. They cannot be resolved line by line
## without a real parser, and are vanishingly rare in config files.

const _STATE_BLOCK := 1
const _STATE_MASK := 0xFF
const _INDENT_SHIFT := 8

const _LITERALS := {
	"true": true, "false": true, "yes": true, "no": true, "on": true, "off": true,
	"null": true, "Null": true, "NULL": true, "True": true, "False": true,
}

## A block scalar indicator closing the line, ignoring a trailing comment.
const _BLOCK_PATTERN := "[|>][0-9]*[+-]?[ \\t]*(?:#.*)?$"

static var _block_regex:RegEx


func _init() -> void:
	multiline = true

## Compiled lazily rather than in a static initializer, which does not survive a script reload.
func _initialize_regex() -> void:
	if not is_instance_valid(_block_regex):
		_block_regex = RegEx.new()
		_block_regex.compile(_BLOCK_PATTERN)

func _tokenize(line:int, entry_state:int, map:Dictionary) -> int:
	_initialize_regex()
	
	var text := text_edit.get_line(line)
	var length := text.length()

	if (entry_state & _STATE_MASK) == _STATE_BLOCK:
		var base_indent := entry_state >> _INDENT_SHIFT
		# Blank lines and anything indented past the opener stay inside the block.
		if length == 0 or text.strip_edges().is_empty() or indent_of(text) > base_indent:
			push(map, 0, palette.string)
			return entry_state

	if length == 0:
		return STATE_NORMAL

	var i := indent_of(text)
	if i >= length:
		return STATE_NORMAL

	if text[i] == "#":
		push(map, i, palette.comment)
		return STATE_NORMAL

	var rest := text.substr(i)
	if rest.begins_with("---") or rest.begins_with("..."):
		push(map, i, palette.symbol)
		push(map, i + 3, palette.text)
		i += 3
		while i < length and text[i] == " ":
			i += 1

	# Sequence markers, which can nest on one line: "- - item".
	while i < length and text[i] == "-" and (i + 1 >= length or text[i + 1] == " "):
		push(map, i, palette.symbol)
		push(map, i + 1, palette.text)
		i += 1
		while i < length and text[i] == " ":
			i += 1

	var colon := _find_key_colon(text, i)
	if colon != -1:
		push(map, i, palette.key)
		push(map, colon, palette.symbol)
		push(map, colon + 1, palette.text)
		_tokenize_value(text, colon + 1, map)
	else:
		_tokenize_value(text, i, map)

	if _block_regex.search(text) != null:
		return (indent_of(text) << _INDENT_SHIFT) | _STATE_BLOCK
	return STATE_NORMAL


## Index of the colon separating a key from its value, or -1 when the line has no key.
## Quoted keys are skipped over, so a colon inside them does not count.
func _find_key_colon(text:String, from:int) -> int:
	var length := text.length()
	var i := from
	while i < length:
		var c := text[i]
		if c == "\"" or c == "'":
			i = scan_quoted(text, i, c, c == "\"")
			continue
		if c == "#":
			return -1
		if c == ":" and (i + 1 >= length or text[i + 1] == " " or text[i + 1] == "\t"):
			return i
		i += 1
	return -1


func _tokenize_value(text:String, from:int, map:Dictionary) -> void:
	var length := text.length()
	var i := from

	while i < length:
		var c := text[i]

		# YAML requires whitespace before an inline comment.
		if c == "#" and (i == 0 or text[i - 1] == " " or text[i - 1] == "\t"):
			push(map, i, palette.comment)
			return

		if c == "\"" or c == "'":
			var quote_end := scan_quoted(text, i, c, c == "\"")
			push(map, i, palette.string)
			push(map, quote_end, palette.text)
			i = quote_end
			continue

		# Anchors, aliases, tags and the null shorthand.
		if c == "&" or c == "*" or c == "!":
			var token_end := scan_identifier(text, i + 1, "!-")
			push(map, i, palette.keyword)
			push(map, maxi(token_end, i + 1), palette.text)
			i = maxi(token_end, i + 1)
			continue

		if c == "~":
			push(map, i, palette.keyword)
			push(map, i + 1, palette.text)
			i += 1
			continue

		if is_digit(c) or ((c == "-" or c == "+") and i + 1 < length and is_digit(text[i + 1])):
			var number_end := scan_number(text, i, true)
			if number_end > i:
				push(map, i, palette.number)
				push(map, number_end, palette.text)
				i = number_end
				continue

		var word_end := scan_identifier(text, i)
		if word_end > i:
			if _LITERALS.has(text.substr(i, word_end - i)):
				push(map, i, palette.keyword)
				push(map, word_end, palette.text)
			i = word_end
			continue

		if "[]{}".contains(c):
			push(map, i, palette.bracket)
			push(map, i + 1, palette.text)
			i += 1
			continue

		if c == ",":
			push(map, i, palette.symbol)
			push(map, i + 1, palette.text)
			i += 1
			continue

		i += 1
