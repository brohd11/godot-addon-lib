## Two versions of a file, as the hunks git would have printed for them. Spawns nothing and parses
## nothing git produced — it borrows GitUtil's Keys only so a hunk from here and one from `git diff`
## are the same shape.
##
## Callers read hunks without caring which of the two made them, so anything here that drifts from
## parse_patch() is a bug; tests/git/git_diff_tests.gd asserts it does not. One deliberate difference:
## to_lines() counts a trailing newline as an empty last line, because that is what CodeEdit shows.

const GitUtil = preload("res://addons/addon_lib/brohd//alib_editor/misc/git_service/git_util.gd")

## Lines of context around a change, and how far apart two changes must be to become two hunks.
## git's own default, and what the fixtures in tests/git/ were captured with.
const CONTEXT = 3

## Past this many edits, stop looking for the minimal diff. Myers is O(ND) time and O(D²) memory with
## the trace kept — nothing for a keystroke, ruinous for a file rewritten wholesale. Blowing the
## budget yields a coarser true diff (all old removed, all new added), not a wrong one.
const MAX_EDIT_DISTANCE = 1024

enum _Op {
	EQUAL,
	DELETE,
	INSERT,
}


## A blob or a buffer, as the array of lines to diff. Both sides must come through here. Two traps,
## both showing up as "every line changed": `git show` returns the raw blob, so a CRLF-committed file
## arrives with a \r per line where CodeEdit's buffer has none; and the trailing "" from "a\nb\n" is
## the empty last line CodeEdit shows, not a wart — keep it on both sides and it cancels.
static func to_lines(text:String) -> PackedStringArray:
	return text.replace("\r\n", "\n").replace("\r", "\n").split("\n")


## The hunks turning `old_lines` into `new_lines`, in parse_patch()'s shape. NO_NEWLINE is always
## false: git tracks a missing final newline because it diffs bytes, but to_lines() has already
## spelled its absence as one fewer empty line, which a hunk reports as an ordinary added/removed line.
static func diff_lines(old_lines:PackedStringArray, new_lines:PackedStringArray,
		context:=CONTEXT) -> Array[Dictionary]:
	if old_lines == new_lines:
		return []
	return _build_hunks(_diff_ops(old_lines, new_lines), old_lines, new_lines, context)


# The ops that turn old into new, one per line of output. The prefix/suffix trim is not an
# optimisation but the case this runs in: a keystroke in a 2000 line script leaves one line differing.
# The trimmed context returns as EQUAL ops — the list is O(N) either way and hunks need lines to quote.
static func _diff_ops(old_lines:PackedStringArray, new_lines:PackedStringArray) -> PackedByteArray:
	var n = old_lines.size()
	var m = new_lines.size()

	var prefix = 0
	var min_len = mini(n, m)
	while prefix < min_len and old_lines[prefix] == new_lines[prefix]:
		prefix += 1

	var suffix = 0
	while suffix < min_len - prefix and old_lines[n - 1 - suffix] == new_lines[m - 1 - suffix]:
		suffix += 1

	var mid_old = old_lines.slice(prefix, n - suffix)
	var mid_new = new_lines.slice(prefix, m - suffix)

	var mid:PackedByteArray = PackedByteArray()
	if mid_old.is_empty():
		mid = _fill_ops(_Op.INSERT, mid_new.size())
	elif mid_new.is_empty():
		mid = _fill_ops(_Op.DELETE, mid_old.size())
	else:
		# both sides are non empty and differ, so a real edit script is never empty — an empty return
		# can only be the budget giving up
		mid = _myers(mid_old, mid_new)
		if mid.is_empty():
			mid = _fill_ops(_Op.DELETE, mid_old.size())
			mid.append_array(_fill_ops(_Op.INSERT, mid_new.size()))

	var ops = _fill_ops(_Op.EQUAL, prefix)
	ops.append_array(mid)
	ops.append_array(_fill_ops(_Op.EQUAL, suffix))
	return ops


static func _fill_ops(op:_Op, count:int) -> PackedByteArray:
	var ops = PackedByteArray()
	ops.resize(count)
	ops.fill(op)
	return ops


# Myers' O(ND) shortest edit script, or empty if it would cost more than MAX_EDIT_DISTANCE allows.
# The lines are interned to ints first: the inner loop is a run of equality tests, and int compares
# rather than String compares buy a large constant factor.
static func _myers(old_lines:PackedStringArray, new_lines:PackedStringArray) -> PackedByteArray:
	var ids = {}
	var a = _intern(old_lines, ids)
	var b = _intern(new_lines, ids)

	var n = a.size()
	var m = b.size()
	var budget = mini(n + m, MAX_EDIT_DISTANCE)

	# k runs [-d, d] and the frontier reads its neighbours at k±1, so the array has to hold one more
	# diagonal on each side than the deepest d can name
	var offset = budget + 1
	var v = PackedInt32Array()
	v.resize(2 * budget + 3)

	var trace:Array[PackedInt32Array] = []

	for d in budget + 1:
		trace.append(v.duplicate())
		for k in range(-d, d + 1, 2):
			# down (an insertion) when there is no diagonal to the left, or when the one to the right
			# has reached further; otherwise right (a deletion)
			var x:int
			if k == -d or (k != d and v[offset + k - 1] < v[offset + k + 1]):
				x = v[offset + k + 1]
			else:
				x = v[offset + k - 1] + 1

			var y = x - k
			while x < n and y < m and a[x] == b[y]: # the snake: free moves along equal lines
				x += 1
				y += 1

			v[offset + k] = x

			if x >= n and y >= m:
				return _backtrack(trace, a, b, d, offset)

	return PackedByteArray()


static func _intern(lines:PackedStringArray, ids:Dictionary) -> PackedInt32Array:
	var out = PackedInt32Array()
	out.resize(lines.size())
	for i in lines.size():
		var line = lines[i]
		var id = ids.get(line, -1)
		if id == -1:
			id = ids.size()
			ids[line] = id
		out[i] = id
	return out


# The op list, walked back out of the frontier each round left behind. End to start, because that is
# the direction the trace reads in — each round says where the one before it got to. The ops come out
# reversed and are flipped at the end.
static func _backtrack(trace:Array[PackedInt32Array], a:PackedInt32Array, b:PackedInt32Array,
		d_final:int, offset:int) -> PackedByteArray:
	var ops = PackedByteArray()
	var x = a.size()
	var y = b.size()

	for d in range(d_final, -1, -1):
		var v = trace[d]
		var k = x - y

		var prev_k:int
		if k == -d or (k != d and v[offset + k - 1] < v[offset + k + 1]):
			prev_k = k + 1
		else:
			prev_k = k - 1

		var prev_x = v[offset + prev_k]
		var prev_y = prev_x - prev_k

		while x > prev_x and y > prev_y: # unwind the snake
			ops.append(_Op.EQUAL)
			x -= 1
			y -= 1

		if d > 0:
			ops.append(_Op.INSERT if prev_k == k + 1 else _Op.DELETE)

		x = prev_x
		y = prev_y

	ops.reverse()
	return ops


static func _build_hunks(ops:PackedByteArray, old_lines:PackedStringArray,
		new_lines:PackedStringArray, context:int) -> Array[Dictionary]:
	var hunks:Array[Dictionary] = []
	var n_ops = ops.size()

	# where each side's cursor stands *before* op i, so a hunk can name its starts and counts by
	# subtraction rather than by counting its own lines back up
	var old_at = PackedInt32Array()
	var new_at = PackedInt32Array()
	old_at.resize(n_ops + 1)
	new_at.resize(n_ops + 1)
	var oi = 0
	var ni = 0
	for i in n_ops:
		old_at[i] = oi
		new_at[i] = ni
		if ops[i] != _Op.INSERT:
			oi += 1
		if ops[i] != _Op.DELETE:
			ni += 1
	old_at[n_ops] = oi
	new_at[n_ops] = ni

	var i = 0
	while i < n_ops:
		if ops[i] == _Op.EQUAL:
			i += 1
			continue

		# one hunk swallows the next change along if their context would touch — what makes two edits
		# a line apart one hunk and two edits a page apart two
		var first = i
		var last = i
		var j = i
		while j < n_ops:
			if ops[j] != _Op.EQUAL:
				last = j
				j += 1
				continue
			var run = j
			while j < n_ops and ops[j] == _Op.EQUAL:
				j += 1
			if j >= n_ops or j - run > 2 * context:
				break

		hunks.append(_make_hunk(ops, old_lines, new_lines,
			maxi(0, first - context), mini(n_ops - 1, last + context), old_at, new_at))
		i = last + 1

	return hunks


static func _make_hunk(ops:PackedByteArray, old_lines:PackedStringArray,
		new_lines:PackedStringArray, start:int, end:int, old_at:PackedInt32Array,
		new_at:PackedInt32Array) -> Dictionary:
	var lines = []
	var i = start
	while i <= end:
		if ops[i] == _Op.EQUAL:
			lines.append({GitUtil.Keys.ORIGIN: " ", GitUtil.Keys.TEXT: old_lines[old_at[i]]})
			i += 1
			continue

		# a unified diff writes a change block as every removal then every addition, whatever order
		# the edit script found them in. Interleaving them would be a patch git never writes.
		var dels = []
		var adds = []
		while i <= end and ops[i] != _Op.EQUAL:
			if ops[i] == _Op.DELETE:
				dels.append({GitUtil.Keys.ORIGIN: "-", GitUtil.Keys.TEXT: old_lines[old_at[i]]})
			else:
				adds.append({GitUtil.Keys.ORIGIN: "+", GitUtil.Keys.TEXT: new_lines[new_at[i]]})
			i += 1
		lines.append_array(dels)
		lines.append_array(adds)

	var old_count = old_at[end + 1] - old_at[start]
	var new_count = new_at[end + 1] - new_at[start]

	# git's zero count rule: "@@ -0,0 +1,3 @@" for an insertion into an empty file. When a count is 0
	# the start names the line before the change, there being no line at it — and a 0 based cursor is
	# already that number.
	return {
		GitUtil.Keys.OLD_START: old_at[start] if old_count == 0 else old_at[start] + 1,
		GitUtil.Keys.OLD_COUNT: old_count,
		GitUtil.Keys.NEW_START: new_at[start] if new_count == 0 else new_at[start] + 1,
		GitUtil.Keys.NEW_COUNT: new_count,
		GitUtil.Keys.HEADING: "", # git guesses the enclosing function; we do not, and it is optional
		GitUtil.Keys.NO_NEWLINE: false, # see diff_lines()
		GitUtil.Keys.LINES: lines,
	}


## What a line is, as a mask: the two things a line can say are independent — a bar for its own
## content, a wedge for what went missing next to it — and hunks_to_markers() resolves hunks from
## anywhere against any buffer, where nothing guarantees they do not overlap.
enum Marker {
	ADDED         = 1 << 0,
	MODIFIED      = 1 << 1,
	DELETED_ABOVE = 1 << 2, ## lines were removed immediately before this one
	DELETED_BELOW = 1 << 3, ## ...and this is what that looks like at the end of the file, where there
							## is no line after the deletion to hang the mark on
	NO_BASELINE   = 1 << 4, ## nothing to diff against — a whole file state rather than anything a
							## hunk describes, so hunks_to_markers() never emits it. Set by
							## fill_markers() for a file git is not watching
}


## Every line of a buffer marked the same, for the whole file states a hunk cannot express. Same
## shape and same empty-file guard as hunks_to_markers(), so the draw side cannot tell them apart.
static func fill_markers(line_count:int, mask:int) -> PackedByteArray:
	var markers = PackedByteArray()
	if line_count <= 0:
		return markers
	markers.resize(line_count)
	markers.fill(mask)
	return markers


## Hunks, resolved to one byte per line of the new text — a lookup a draw callback can do without
## touching a hunk, since the paint runs per visible row per frame. Takes hunks and not a diff, so it
## works on parse_patch()'s too.
static func hunks_to_markers(hunks:Array, line_count:int) -> PackedByteArray:
	var markers = PackedByteArray()
	if line_count <= 0:
		return markers
	markers.resize(line_count)
	markers.fill(0)

	for hunk:Dictionary in hunks:
		# 0 based, as a CodeEdit line is. A zero count hunk's start already names the line before the
		# change and needs no adjusting; every other names the first line it describes.
		var new_i:int = hunk[GitUtil.Keys.NEW_START]
		if hunk[GitUtil.Keys.NEW_COUNT] != 0:
			new_i -= 1

		var lines:Array = hunk[GitUtil.Keys.LINES]
		var i = 0
		while i < lines.size():
			if lines[i][GitUtil.Keys.ORIGIN] == " ":
				new_i += 1
				i += 1
				continue

			var adds = 0
			var dels = 0
			var block = new_i # the first added line, or the line the removal sits in front of
			while i < lines.size() and lines[i][GitUtil.Keys.ORIGIN] != " ":
				if lines[i][GitUtil.Keys.ORIGIN] == "+":
					adds += 1
				else:
					dels += 1
				i += 1
			new_i += adds

			if adds > 0:
				# a replacement is one fact, not a removal next to an addition — marking it as a
				# deletion too would say the line before it lost something, which it did not
				var mask = Marker.MODIFIED if dels > 0 else Marker.ADDED
				for line in range(block, block + adds):
					_mark(markers, line, mask)
			elif dels > 0:
				if block < line_count:
					_mark(markers, block, Marker.DELETED_ABOVE)
				else:
					_mark(markers, line_count - 1, Marker.DELETED_BELOW)

	return markers


# Bounds checked: the hunks and the line count need not have come from the same place, and a real
# one can arrive a keystroke stale.
static func _mark(markers:PackedByteArray, line:int, mask:int) -> void:
	if line < 0 or line >= markers.size():
		return
	markers[line] |= mask


## A 0 based new-text line as the line it was in the old text, or -1 for one the old text does not
## have. Takes hunks and not a diff, as hunks_to_markers() does, so parse_patch()'s work too.
##
## What a line's history needs: git blame numbers lines as the commit has them, and the buffer has
## moved since. A line inside an addition answers -1 — there is nothing committed to attribute it to.
static func map_new_to_old(hunks:Array, line:int) -> int:
	if line < 0:
		return -1

	# what every hunk ending before this line does to its number. Summed rather than searched for, so
	# the hunks need not be in order
	var offset = 0

	for hunk:Dictionary in hunks:
		# 0 based, as in hunks_to_markers: a zero count start already names the line before the change
		var new_start:int = hunk[GitUtil.Keys.NEW_START]
		if hunk[GitUtil.Keys.NEW_COUNT] != 0:
			new_start -= 1

		if line < new_start:
			continue

		if line < new_start + hunk[GitUtil.Keys.NEW_COUNT]:
			return _map_within(hunk, line, new_start)

		offset += hunk[GitUtil.Keys.OLD_COUNT] - hunk[GitUtil.Keys.NEW_COUNT]

	return line + offset


# Where in a hunk a new-text line lands. Walked rather than offset: a hunk's span is wider than its
# changes — diff_lines() carries CONTEXT lines either side — so a line inside one is usually still a
# committed line, and only the origins say which.
static func _map_within(hunk:Dictionary, line:int, new_start:int) -> int:
	var old_i:int = hunk[GitUtil.Keys.OLD_START]
	if hunk[GitUtil.Keys.OLD_COUNT] != 0:
		old_i -= 1
	var new_i = new_start

	for entry:Dictionary in hunk[GitUtil.Keys.LINES]:
		match entry[GitUtil.Keys.ORIGIN]:
			"-":
				old_i += 1 # occupies no new line, so `line` cannot be it
			"+":
				if new_i == line:
					return -1
				new_i += 1
			_:
				if new_i == line:
					return old_i
				old_i += 1
				new_i += 1

	return -1 # unreachable while the caller only enters for a line the hunk covers
