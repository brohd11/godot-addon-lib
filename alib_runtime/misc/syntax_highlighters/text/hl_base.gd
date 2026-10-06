extends RefCounted

## Base for the per-file-type highlighters routed by [code]dispatcher.gd[/code].
##
## Subclasses implement [method _tokenize] only. Grammars whose constructs span lines set
## [member multiline] in [method _init]; the base then keeps a per-line entry-state cache so
## scrolling into the middle of a fenced block still resolves correctly.

const Palette = preload("res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/palette.gd")

const STATE_NORMAL := 0

var text_edit:TextEdit
var palette:Palette

## Set true by subclasses whose grammar spans lines. Enables the entry-state cache.
var multiline := false

## State each line *begins* in. Index 0 is always STATE_NORMAL.
var _line_states:PackedInt32Array = PackedInt32Array()
## Highest line index whose entry state is trusted. -1 when the cache is empty.
var _valid_to:int = -1


func setup(p_text_edit:TextEdit, p_palette:Palette) -> void:
	text_edit = p_text_edit
	palette = p_palette
	clear_cache()


func clear_cache() -> void:
	_line_states.clear()
	_valid_to = -1


## Returns [code]{column: {"color": Color}}[/code] with keys in ascending column order.
func get_line_highlighting(line:int) -> Dictionary:
	if text_edit == null or palette == null:
		return {}
	var map := {}
	_tokenize(line, _get_entry_state(line), map)
	return finalize(map)


## Override. Colors [param line] into [param map] and returns the state the next line begins
## in. Single-line grammars ignore [param entry_state] and return [constant STATE_NORMAL].
## [param map] may be a throwaway when only the state is wanted, so keep it side-effect free.
func _tokenize(_line:int, _entry_state:int, _map:Dictionary) -> int:
	return STATE_NORMAL


## State [param line] begins in, walking forward from the last trusted line.
func _get_entry_state(line:int) -> int:
	if not multiline or line <= 0 or text_edit == null:
		return STATE_NORMAL
	if line <= _valid_to:
		return _line_states[line]

	if _line_states.size() < line + 1:
		_line_states.resize(line + 1)
	if _valid_to < 0:
		_line_states[0] = STATE_NORMAL
		_valid_to = 0

	var scratch := {}
	var current := _valid_to
	while current < line:
		_line_states[current + 1] = _tokenize(current, _line_states[current], scratch)
		scratch.clear()
		current += 1
	_valid_to = line
	return _line_states[line]


#region helpers

static func push(map:Dictionary, column:int, color:Color) -> void:
	map[column] = {"color": color}


## Collapse a per-character color buffer into [param map]. Suits grammars with nested
## contexts, where emitting spans in order is awkward.
static func collapse(colors:Array, map:Dictionary) -> void:
	var last:Variant = null
	for i in colors.size():
		var color:Color = colors[i]
		if last == null or color != last:
			map[i] = {"color": color}
			last = color


## Dictionary keys are insertion ordered, so this only rebuilds when a tokenizer emitted
## columns out of order.
static func finalize(map:Dictionary) -> Dictionary:
	var columns := map.keys()
	var ordered := true
	for i in range(1, columns.size()):
		if columns[i] < columns[i - 1]:
			ordered = false
			break
	if ordered:
		return map
	columns.sort()
	var sorted := {}
	for column in columns:
		sorted[column] = map[column]
	return sorted


## Index of the first non whitespace character, or the line length for a blank line.
static func indent_of(text:String) -> int:
	var length := text.length()
	var i := 0
	while i < length and (text[i] == " " or text[i] == "\t"):
		i += 1
	return i


## [param from] is the index of the opening quote. Returns the index just past the closing
## quote, or the line length when the string is unterminated.
static func scan_quoted(text:String, from:int, quote:String, escapes:=true) -> int:
	var length := text.length()
	var i := from + 1
	while i < length:
		var c := text[i]
		if escapes and c == "\\":
			i += 2
			continue
		if c == quote:
			return i + 1
		i += 1
	return length


## Returns the index just past the number, or [param from] when no number starts there.
##
## With [param strict], a digit run glued directly to identifier characters is not a number at
## all: "5d" in a config value is one malformed token, whereas "222ms" in a log line is a
## number followed by a unit and should keep the digits lit.
static func scan_number(text:String, from:int, strict:=false) -> int:
	var length := text.length()
	var i := from
	if i < length and (text[i] == "-" or text[i] == "+"):
		i += 1
	if i >= length or not is_digit(text[i]):
		return from

	if text[i] == "0" and i + 1 < length and "xXbBoO".contains(text[i + 1]):
		i += 2
		while i < length and (is_hex_digit(text[i]) or text[i] == "_"):
			i += 1
		return from if strict and _glued_to_identifier(text, i) else i

	while i < length:
		var c := text[i]
		if is_digit(c) or c == "_" or c == ".":
			i += 1
		elif c == "e" or c == "E":
			i += 1
			if i < length and (text[i] == "+" or text[i] == "-"):
				i += 1
		else:
			break
	return from if strict and _glued_to_identifier(text, i) else i


static func _glued_to_identifier(text:String, at:int) -> bool:
	return at < text.length() and is_identifier_start(text[at])


## Returns the index just past the identifier, or [param from] when none starts there.
static func scan_identifier(text:String, from:int, extra:="") -> int:
	var length := text.length()
	if from >= length or not (is_identifier_start(text[from]) or extra.contains(text[from])):
		return from
	var i := from
	while i < length and (is_identifier_char(text[i]) or extra.contains(text[i])):
		i += 1
	return i


static func is_digit(c:String) -> bool:
	return c >= "0" and c <= "9"


static func is_hex_digit(c:String) -> bool:
	return is_digit(c) or (c >= "a" and c <= "f") or (c >= "A" and c <= "F")


static func is_identifier_start(c:String) -> bool:
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


static func is_identifier_char(c:String) -> bool:
	return is_identifier_start(c) or is_digit(c)

#endregion
