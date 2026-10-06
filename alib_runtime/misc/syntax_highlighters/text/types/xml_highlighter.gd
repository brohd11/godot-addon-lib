extends "res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/hl_base.gd"

## xml - tags, attributes, entities, comments and CDATA.
##
## Multiline: [code]<!-- -->[/code] comments, [code]<![CDATA[ ]]>[/code] sections, and tags
## whose attribute list wraps across lines.

const _STATE_TAG := 1
const _STATE_COMMENT := 2
const _STATE_CDATA := 3

const _CDATA_OPEN := "<![CDATA["


func _init() -> void:
	multiline = true


func _tokenize(line:int, entry_state:int, map:Dictionary) -> int:
	var text := text_edit.get_line(line)
	var length := text.length()
	var state := entry_state
	var i := 0

	while i < length:
		match state:
			_STATE_COMMENT:
				push(map, i, palette.comment)
				var comment_close := text.find("-->", i)
				if comment_close == -1:
					return _STATE_COMMENT
				i = comment_close + 3
				push(map, i, palette.text)
				state = STATE_NORMAL

			_STATE_CDATA:
				push(map, i, palette.string)
				var cdata_close := text.find("]]>", i)
				if cdata_close == -1:
					return _STATE_CDATA
				i = cdata_close + 3
				push(map, i, palette.text)
				state = STATE_NORMAL

			_STATE_TAG:
				i = _tokenize_tag(text, i, map)
				if i < 0:
					# Negative marks "tag closed here", the real index is the complement.
					i = ~i
					state = STATE_NORMAL

			_:
				var open := text.find("<", i)
				if open == -1:
					_tokenize_entities(text, i, length, map)
					return STATE_NORMAL
				_tokenize_entities(text, i, open, map)

				if text.substr(open, 4) == "<!--":
					push(map, open, palette.comment)
					state = _STATE_COMMENT
					i = open + 4
					continue
				if text.substr(open, _CDATA_OPEN.length()) == _CDATA_OPEN:
					push(map, open, palette.string)
					state = _STATE_CDATA
					i = open + _CDATA_OPEN.length()
					continue

				# "<name", "</name", "<?target", "<!DOCTYPE".
				var name_end := open + 1
				if name_end < length and "/?!".contains(text[name_end]):
					name_end += 1
				name_end = scan_identifier(text, name_end, ":-.")
				push(map, open, palette.tag)
				push(map, maxi(name_end, open + 1), palette.text)
				state = _STATE_TAG
				i = maxi(name_end, open + 1)

	return state


## Colors the inside of a tag from [param from]. Returns the next index, or the bitwise
## complement of it once the tag has been closed.
func _tokenize_tag(text:String, from:int, map:Dictionary) -> int:
	var length := text.length()
	var i := from

	while i < length:
		var c := text[i]

		if c == ">":
			push(map, i, palette.tag)
			push(map, i + 1, palette.text)
			return ~(i + 1)

		if (c == "/" or c == "?") and i + 1 < length and text[i + 1] == ">":
			push(map, i, palette.tag)
			push(map, i + 2, palette.text)
			return ~(i + 2)

		if c == "\"" or c == "'":
			var quote_end := scan_quoted(text, i, c, false)
			push(map, i, palette.string)
			push(map, quote_end, palette.text)
			i = quote_end
			continue

		if c == "=":
			push(map, i, palette.symbol)
			push(map, i + 1, palette.text)
			i += 1
			continue

		var name_end := scan_identifier(text, i, ":-.")
		if name_end > i:
			push(map, i, palette.attribute)
			push(map, name_end, palette.text)
			i = name_end
			continue

		i += 1

	return i


## Character references such as [code]&amp;[/code] inside element text.
func _tokenize_entities(text:String, from:int, to:int, map:Dictionary) -> void:
	var i := from
	while i < to:
		if text[i] != "&":
			i += 1
			continue
		var close := text.find(";", i)
		if close == -1 or close >= to or close - i > 12:
			i += 1
			continue
		push(map, i, palette.keyword)
		push(map, close + 1, palette.text)
		i = close + 1
