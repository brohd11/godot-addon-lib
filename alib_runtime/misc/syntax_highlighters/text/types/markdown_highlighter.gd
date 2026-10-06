extends "res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/hl_base.gd"

## md - headings, emphasis, code, links, lists and tables.
##
## Multiline: fenced code blocks, both [code]```[/code] and [code]~~~[/code], and emphasis
## spans that wrap a line break. Fence bodies are not highlighted as their info language, they
## take the code color as a whole.
##
## Code spans and link text stay line local even though CommonMark lets them wrap too.

## State bits 0-1: which fence, if any, the line begins inside.
const _FENCE_MASK := 0b11
const _STATE_FENCE_BACKTICK := 1
const _STATE_FENCE_TILDE := 2

## State bits 2-4: which emphasis delimiter, if any, is still open at the start of the line.
const _EMPHASIS_SHIFT := 2
const _EMPHASIS_MASK := 0b111
const _MARKER_NONE := 0
const _MARKER_STAR := 1
const _MARKER_STAR2 := 2
const _MARKER_UNDER := 3
const _MARKER_UNDER2 := 4

var _local_colors_set := false

var emphasis:Color

func _init() -> void:
	multiline = true

func _set_local_vars():
	if _local_colors_set:
		return
	_local_colors_set = true
	emphasis = palette.string_name

func _tokenize(line:int, entry_state:int, map:Dictionary) -> int:
	_set_local_vars()
	
	var text := text_edit.get_line(line)
	var length := text.length()
	var start := indent_of(text)
	var rest := text.substr(start)

	# Masked, not a plain != 0 test: an open emphasis span must not read as a fence.
	var fence_state := entry_state & _FENCE_MASK
	if fence_state != STATE_NORMAL:
		var fence := "```" if fence_state == _STATE_FENCE_BACKTICK else "~~~"
		if rest.begins_with(fence):
			push(map, start, palette.symbol)
			return STATE_NORMAL
		if length > 0:
			push(map, 0, palette.code)
		return entry_state

	# A blank line ends the paragraph, so an unclosed emphasis span dies here rather than
	# running away down the file.
	if start >= length:
		return STATE_NORMAL

	# A wrapped paragraph line must not have a leading "*" eaten as a list bullet or a rule,
	# so an open span skips straight to the inline pass.
	var open_marker := (entry_state >> _EMPHASIS_SHIFT) & _EMPHASIS_MASK
	if open_marker != _MARKER_NONE:
		return _tokenize_inline(text, start, map, open_marker) << _EMPHASIS_SHIFT

	if rest.begins_with("```") or rest.begins_with("~~~"):
		var fence_char := text[start]
		var run := start
		while run < length and text[run] == fence_char:
			run += 1
		push(map, start, palette.symbol)
		push(map, run, palette.keyword)
		return _STATE_FENCE_BACKTICK if fence_char == "`" else _STATE_FENCE_TILDE

	var i := start

	# Blockquote markers, which nest: "> > quoted".
	while i < length and text[i] == ">":
		push(map, i, palette.symbol)
		push(map, i + 1, palette.text)
		i += 1
		while i < length and text[i] == " ":
			i += 1
	
	if i >= length:
		return STATE_NORMAL
	
	# ATX heading. The whole line takes the heading color, inline markup inside it is ignored.
	if text[i] == "#":
		var hashes := i
		while hashes < length and text[hashes] == "#":
			hashes += 1
		if hashes - i <= 6 and (hashes >= length or text[hashes] == " "):
			push(map, i, palette.heading)
			return STATE_NORMAL
	
	var trimmed := text.substr(i).strip_edges()
	if _is_repeated(trimmed, "="):
		push(map, i, palette.heading)
		return STATE_NORMAL
	if _is_repeated(trimmed, "-") or _is_repeated(trimmed, "*") or _is_repeated(trimmed, "_"):
		push(map, i, palette.symbol)
		return STATE_NORMAL

	# Unordered and ordered list markers.
	if "-*+".contains(text[i]) and i + 1 < length and text[i + 1] == " ":
		push(map, i, palette.symbol)
		push(map, i + 1, palette.text)
		i += 2
	elif is_digit(text[i]):
		var digits := i
		while digits < length and is_digit(text[digits]):
			digits += 1
		if digits < length and ".)".contains(text[digits]) \
			and digits + 1 < length and text[digits + 1] == " ":
			push(map, i, palette.symbol)
			push(map, digits + 1, palette.text)
			i = digits + 1

	return _tokenize_inline(text, i, map, _MARKER_NONE) << _EMPHASIS_SHIFT


## Colors from [param from] to end of line. [param open_marker] is the emphasis delimiter still
## open from the previous line, and the return value is the one still open at end of this one.
func _tokenize_inline(text:String, from:int, map:Dictionary, open_marker:int) -> int:
	var length := text.length()
	var i := from

	# Continuing a span opened on an earlier line: everything up to its closer is emphasis.
	if open_marker != _MARKER_NONE:
		push(map, from, emphasis)
		var resume := _find_closer(text, from, open_marker)
		if resume == -1:
			return open_marker
		push(map, resume, palette.text)
		i = resume

	while i < length:
		var c := text[i]

		if c == "\\":
			i += 2
			continue

		if c == "`":
			var ticks := 0
			while i + ticks < length and text[i + ticks] == "`":
				ticks += 1
			push(map, i, palette.code)
			var code_close := text.find("`".repeat(ticks), i + ticks)
			if code_close == -1:
				return _MARKER_NONE
			i = code_close + ticks
			push(map, i, palette.text)
			continue

		if c == "*" or c == "_":
			var marks := 0
			while i + marks < length and text[i + marks] == c:
				marks += 1
			# A run that cannot open is ordinary punctuation, such as a lone "*" between spaces.
			if not _can_open(text, i + marks):
				i += marks
				continue
			var marker := _marker_id(c, marks)
			var emphasis_close := _find_closer(text, i + marks, marker)
			if emphasis_close == -1:
				# Unclosed on this line, so it carries to the next one.
				push(map, i, emphasis)
				return marker
			push(map, i, emphasis)
			i = emphasis_close
			push(map, i, palette.text)
			continue

		# Links and images: [text](url) / ![alt](url).
		if c == "[" or (c == "!" and i + 1 < length and text[i + 1] == "["):
			var bracket := i if c == "[" else i + 1
			var bracket_close := text.find("]", bracket)
			if bracket_close != -1 and bracket_close + 1 < length and text[bracket_close + 1] == "(":
				var paren_close := text.find(")", bracket_close)
				if paren_close != -1:
					push(map, i, palette.keyword)              # "![alt](" / "[text]("
					push(map, bracket_close + 2, palette.link) # the url
					push(map, paren_close, palette.keyword)    # ")"
					push(map, paren_close + 1, palette.text)
					i = paren_close + 1
					continue
			i += 1
			continue

		# Autolinks and raw html.
		if c == "<":
			var angle_close := text.find(">", i)
			if angle_close != -1:
				push(map, i, palette.link)
				push(map, angle_close + 1, palette.text)
				i = angle_close + 1
				continue

		if c == "|":
			push(map, i, palette.symbol)
			push(map, i + 1, palette.text)
			i += 1
			continue

		i += 1

	return _MARKER_NONE


## Index just past the delimiter run that closes [param marker], searching from [param from],
## or -1 when the line does not close it.
func _find_closer(text:String, from:int, marker:int) -> int:
	var length := text.length()
	var c := "*" if marker <= _MARKER_STAR2 else "_"
	var marks := 1 if marker == _MARKER_STAR or marker == _MARKER_UNDER else 2
	var i := from

	while i < length:
		if text[i] == "\\":
			i += 2
			continue
		if text[i] != c:
			i += 1
			continue
		var run := 0
		while i + run < length and text[i + run] == c:
			run += 1
		if run >= marks and _can_close(text, i):
			return i + marks
		i += run

	return -1


## Delimiter runs of three or more clamp to two, so "***" tracks as "**".
static func _marker_id(c:String, marks:int) -> int:
	var base := _MARKER_STAR if c == "*" else _MARKER_UNDER
	return base + (0 if marks < 2 else 1)


## The subset of CommonMark's left-flanking rule that matters here: a run can only open when
## something other than whitespace follows it. Without this a lone "*" in prose would open a
## span that then leaked onto every following line.
static func _can_open(text:String, run_end:int) -> bool:
	if run_end >= text.length():
		return false
	var c := text[run_end]
	return c != " " and c != "\t"


## Right-flanking counterpart: a run can only close when something other than whitespace
## precedes it.
static func _can_close(text:String, run_start:int) -> bool:
	if run_start <= 0:
		return false
	var c := text[run_start - 1]
	return c != " " and c != "\t"


## True when [param text] is three or more of [param c] and nothing else.
static func _is_repeated(text:String, c:String) -> bool:
	if text.length() < 3:
		return false
	for i in text.length():
		if text[i] != c:
			return false
	return true
