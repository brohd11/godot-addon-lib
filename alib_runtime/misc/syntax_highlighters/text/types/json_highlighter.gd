extends "res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/hl_base.gd"

## json - object keys, strings, numbers, literals and punctuation. No multiline constructs.

const _LITERALS := {"true": true, "false": true, "null": true}


func _tokenize(line:int, _entry_state:int, map:Dictionary) -> int:
	var text := text_edit.get_line(line)
	var length := text.length()
	var i := 0

	while i < length:
		var c := text[i]

		if c == "\"":
			var string_end := scan_quoted(text, i, "\"")
			push(map, i, palette.key if _is_key(text, string_end) else palette.string)
			push(map, string_end, palette.text)
			i = string_end
			continue

		if "{}[]".contains(c):
			push(map, i, palette.bracket)
			push(map, i + 1, palette.text)
			i += 1
			continue

		if c == "," or c == ":":
			push(map, i, palette.symbol)
			push(map, i + 1, palette.text)
			i += 1
			continue

		if is_digit(c) or (c == "-" and i + 1 < length and is_digit(text[i + 1])):
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

		i += 1

	return STATE_NORMAL


## A string is an object key when the next meaningful character is a colon.
func _is_key(text:String, string_end:int) -> bool:
	var length := text.length()
	var i := string_end
	while i < length and (text[i] == " " or text[i] == "\t"):
		i += 1
	return i < length and text[i] == ":"
