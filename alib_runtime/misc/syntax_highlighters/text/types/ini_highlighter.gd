extends "res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/hl_base.gd"

## cfg, ini - sections, keys and values.
##
## Godot's own .cfg values are covered too: constructor calls such as [code]Color(1, 0, 0, 1)[/code]
## or [code]PackedStringArray("a")[/code] take the tag color, and [code]&"name"[/code] /
## [code]^"path"[/code] are treated as strings.
##
## Multiline: values that span lines, which is how Godot writes input maps. The state is just
## the open container depth, so a line arriving with depth > 0 is a value continuation rather
## than a new [code]key=value[/code] pair.

const _LITERALS := {
	"true": true, "false": true, "null": true, "nan": true, "inf": true, "inf_neg": true,
	"yes": true, "no": true, "on": true, "off": true,
}


func _init() -> void:
	multiline = true


func _tokenize(line:int, entry_state:int, map:Dictionary) -> int:
	var text := text_edit.get_line(line)
	var length := text.length()

	# Still inside a multi-line value, so the whole line is value content. Blank lines included,
	# since a dict body may contain them.
	if entry_state > STATE_NORMAL:
		return _tokenize_value(text, 0, map, entry_state)

	var start := indent_of(text)
	if start >= length:
		return STATE_NORMAL

	var first := text[start]

	if first == ";" or first == "#":
		push(map, start, palette.comment)
		return STATE_NORMAL

	if first == "[":
		push(map, start, palette.section)
		var close := text.rfind("]")
		if close > start:
			push(map, close + 1, palette.text)
			return _tokenize_value(text, close + 1, map, STATE_NORMAL)
		return STATE_NORMAL

	var equals := text.find("=")
	if equals == -1:
		push(map, start, palette.key)
		return STATE_NORMAL

	push(map, start, palette.key)
	push(map, equals, palette.symbol)
	push(map, equals + 1, palette.text)
	return _tokenize_value(text, equals + 1, map, STATE_NORMAL)


## Colors a value from [param from] to end of line. [param depth] is the open container depth
## on entry, and the return value is the depth at end of line.
func _tokenize_value(text:String, from:int, map:Dictionary, depth:int) -> int:
	var length := text.length()
	var i := from

	while i < length:
		var c := text[i]

		# Only ";" opens an inline comment. A bare "#" is far more likely to be a hex color.
		if c == ";":
			push(map, i, palette.comment)
			return depth

		if c == "#":
			var hex_end := i + 1
			while hex_end < length and is_hex_digit(text[hex_end]):
				hex_end += 1
			var digits := hex_end - i - 1
			if digits == 3 or digits == 4 or digits == 6 or digits == 8:
				push(map, i, palette.number)
				push(map, hex_end, palette.text)
				i = hex_end
			else:
				push(map, i, palette.comment)
				return depth
			continue

		if c == "\"" or c == "'":
			var quote_end := scan_quoted(text, i, c)
			push(map, i, palette.string)
			push(map, quote_end, palette.text)
			i = quote_end
			continue

		# StringName / NodePath literals.
		if (c == "&" or c == "^") and i + 1 < length and text[i + 1] == "\"":
			var literal_end := scan_quoted(text, i + 1, "\"")
			if c == "&":
				push(map, i, palette.string_name)
			elif c == "^":
				push(map, i, palette.node_path)
			else:
				push(map, i, palette.string)
			push(map, literal_end, palette.text)
			i = literal_end
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
			var word := text.substr(i, word_end - i)
			if word_end < length and text[word_end] == "(":
				push(map, i, palette.tag)
			elif _LITERALS.has(word.to_lower()):
				push(map, i, palette.keyword)
			else:
				push(map, i, palette.text)
			push(map, word_end, palette.text)
			i = word_end
			continue

		# Strings are consumed above, so braces inside quotes cannot corrupt the count.
		if "([{".contains(c):
			push(map, i, palette.bracket)
			push(map, i + 1, palette.text)
			depth += 1
			i += 1
			continue

		if ")]}".contains(c):
			push(map, i, palette.bracket)
			push(map, i + 1, palette.text)
			depth = maxi(depth - 1, STATE_NORMAL)
			i += 1
			continue

		if c == "," or c == ":":
			push(map, i, palette.symbol)
			push(map, i + 1, palette.text)
			i += 1
			continue

		i += 1

	return depth
