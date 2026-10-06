extends "res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/hl_base.gd"

## toml - tables, keys, values and multiline strings.
##
## Multiline: [code]"""[/code] basic strings and [code]'''[/code] literal strings.

const _STATE_ML_BASIC := 1
const _STATE_ML_LITERAL := 2

const _LITERALS := {"true": true, "false": true, "inf": true, "nan": true}


func _init() -> void:
	multiline = true


func _tokenize(line:int, entry_state:int, map:Dictionary) -> int:
	var text := text_edit.get_line(line)
	var length := text.length()
	var state := entry_state
	var i := 0

	# A table header only counts when the line does not continue a multiline string.
	if state == STATE_NORMAL:
		var start := indent_of(text)
		if start < length and text[start] == "[":
			push(map, start, palette.section)
			var close := text.rfind("]")
			if close > start:
				push(map, close + 1, palette.text)
				i = close + 1
			else:
				return STATE_NORMAL

	while i < length:
		if state == _STATE_ML_BASIC or state == _STATE_ML_LITERAL:
			var terminator := "\"\"\"" if state == _STATE_ML_BASIC else "'''"
			push(map, i, palette.string)
			var close := text.find(terminator, i)
			if close == -1:
				return state
			i = close + 3
			push(map, i, palette.text)
			state = STATE_NORMAL
			continue

		var c := text[i]

		if c == "#":
			push(map, i, palette.comment)
			return STATE_NORMAL

		if text.substr(i, 3) == "\"\"\"" or text.substr(i, 3) == "'''":
			state = _STATE_ML_BASIC if c == "\"" else _STATE_ML_LITERAL
			push(map, i, palette.string)
			i += 3
			continue

		if c == "\"" or c == "'":
			# Literal strings ('...') have no escape sequences.
			var quote_end := scan_quoted(text, i, c, c == "\"")
			push(map, i, palette.string)
			push(map, quote_end, palette.text)
			i = quote_end
			continue

		if c == "=":
			push(map, i, palette.symbol)
			push(map, i + 1, palette.text)
			i += 1
			continue

		if is_digit(c) or ((c == "-" or c == "+") and i + 1 < length and is_digit(text[i + 1])):
			var value_end := _scan_date_or_number(text, i)
			if value_end > i:
				push(map, i, palette.number)
				push(map, value_end, palette.text)
				i = value_end
				continue

		var word_end := scan_identifier(text, i, "-")
		if word_end > i:
			if _LITERALS.has(text.substr(i, word_end - i)):
				push(map, i, palette.keyword)
			elif _is_key(text, word_end):
				push(map, i, palette.key)
			else:
				push(map, i, palette.text)
			push(map, word_end, palette.text)
			i = word_end
			continue

		if "[]{}".contains(c):
			push(map, i, palette.bracket)
			push(map, i + 1, palette.text)
			i += 1
			continue

		if c == "," or c == ".":
			push(map, i, palette.symbol)
			push(map, i + 1, palette.text)
			i += 1
			continue

		i += 1

	return state


## A bare word is a key when the next meaningful character assigns to it, or when it is a
## dotted key segment.
func _is_key(text:String, word_end:int) -> bool:
	var length := text.length()
	var i := word_end
	while i < length and (text[i] == " " or text[i] == "\t"):
		i += 1
	return i < length and (text[i] == "=" or text[i] == ".")


## Offset dates such as 1979-05-27T07:32:00Z are scanned whole so the separators do not break
## the token into pieces.
func _scan_date_or_number(text:String, from:int) -> int:
	var length := text.length()

	# 0x / 0o / 0b integers belong to the plain scanner: the date character set has no notion
	# of a radix prefix and would stop dead on the "x".
	if text[from] == "0" and from + 1 < length and "xXoObB".contains(text[from + 1]):
		return scan_number(text, from, true)

	var i := from
	while i < length and (is_digit(text[i]) or "-+.:TZtz_eE".contains(text[i])):
		i += 1
	# Guard against swallowing a trailing separator.
	while i > from and "-+.:".contains(text[i - 1]):
		i -= 1
	if i > from:
		# Glued to a letter the date set does not cover, so the whole token is malformed.
		return from if _glued_to_identifier(text, i) else i
	return scan_number(text, from, true)
