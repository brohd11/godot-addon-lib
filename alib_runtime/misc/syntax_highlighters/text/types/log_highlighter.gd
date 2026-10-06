extends "res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/hl_base.gd"

## log - leading timestamps, severity levels, bracketed fields and quoted strings.
##
## Deliberately format agnostic. There is no single log grammar, so this only recognises the
## conventions that virtually every logger shares.

const _ERROR_LEVELS := {
	"ERROR": true, "ERR": true, "FATAL": true, "CRITICAL": true, "CRIT": true,
	"SEVERE": true, "FAIL": true, "FAILED": true, "PANIC": true,
}
const _WARNING_LEVELS := {"WARN": true, "WARNING": true, "DEPRECATED": true}
const _INFO_LEVELS := {
	"INFO": true, "NOTICE": true, "DEBUG": true, "TRACE": true, "VERBOSE": true, "LOG": true,
}

## ISO-ish date time, or a bare clock time, optionally bracketed.
const _TIMESTAMP_PATTERN := "^[ \\t]*\\[?(?:\\d{4}[-/]\\d{2}[-/]\\d{2}[T ])?\\d{2}:\\d{2}:\\d{2}(?:[.,]\\d+)?(?:Z|[+-]\\d{2}:?\\d{2})?\\]?"

static var _timestamp_regex:RegEx

## Compiled lazily rather than in a static initializer, which does not survive a script reload.
func _initialize_regex() -> void:
	if not is_instance_valid(_timestamp_regex):
		_timestamp_regex = RegEx.new()
		_timestamp_regex.compile(_TIMESTAMP_PATTERN)


func _tokenize(line:int, _entry_state:int, map:Dictionary) -> int:
	_initialize_regex()
	
	var text := text_edit.get_line(line)
	var length := text.length()
	var i := 0

	var timestamp := _timestamp_regex.search(text)
	if timestamp != null and timestamp.get_end() > 0:
		push(map, timestamp.get_start(), palette.number)
		push(map, timestamp.get_end(), palette.text)
		i = timestamp.get_end()

	while i < length:
		var c := text[i]

		if c == "\"" or c == "'":
			var quote_end := scan_quoted(text, i, c)
			push(map, i, palette.string)
			push(map, quote_end, palette.text)
			i = quote_end
			continue

		if c == "[":
			var close := text.find("]", i)
			if close != -1:
				push(map, i, palette.key)
				push(map, close + 1, palette.text)
				i = close + 1
				continue

		if is_digit(c):
			var number_end := scan_number(text, i)
			if number_end > i:
				push(map, i, palette.number)
				push(map, number_end, palette.text)
				i = number_end
				continue

		var word_end := scan_identifier(text, i)
		if word_end > i:
			var color = _level_color(text.substr(i, word_end - i))
			if color != null:
				push(map, i, color)
				push(map, word_end, palette.text)
			i = word_end
			continue

		i += 1

	return STATE_NORMAL


## Returns null when the word is not a severity level.
func _level_color(word:String):
	var level := word.to_upper()
	if _ERROR_LEVELS.has(level):
		return palette.error
	if _WARNING_LEVELS.has(level):
		return palette.warning
	if _INFO_LEVELS.has(level):
		return palette.symbol
	return null
