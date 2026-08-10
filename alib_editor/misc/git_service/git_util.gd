## Git repo discovery, status and diffs.
##
## Deliberately standalone — static, no node references, no panel coupling.

const UFile = preload("uid://gs632l1nhxaf") #! resolve ALibRuntime.Utils.UFile

const GitColors = GitService.GitColors

const MAX_DEPTH = 5

const LOG_LIMIT = 100

## The fields of one `git log` record. `%D` (ref names, where tags come from) goes last: it is empty
## for most commits, and a trailing empty field still splits to the right size.
const LOG_FIELDS:PackedStringArray = ["%h", "%s", "%an", "%ar", "%H", "%D"]

## How git marks a tag inside `%D`, as opposed to a branch or HEAD.
const TAG_PREFIX = "tag: "

## `# branch.oid` gives the full 40 character sha, unlike `git log`'s %h — this trims it to git's own
## default abbreviation, which is what a detached HEAD displays as.
const SHORT_OID = 7

## ASCII unit separator, the log field delimiter. Safe where NUL was not: it is a valid single byte
## UTF-8 character, so it survives the Godot String OS.execute pipes its output through.
const LOG_SEP = "\u001f"

## Never descended into: `.git` holds thousands of object files, the rest is build noise.
const PRUNE_DIRS:PackedStringArray = [".git", ".godot", ".import", "node_modules"]

## The v2 line type, which tells a conflict from an untracked file from an ordinary edit. v1 forced
## that out of the XY pair; v2 states it outright.
enum Kind {
	ORDINARY,  ## "1"
	RENAMED,   ## "2", a rename or a copy
	UNMERGED,  ## "u"
	UNTRACKED, ## "?"
	IGNORED,   ## "!"
}

## One side of the XY pair. v2 writes an unmodified side as ".", which maps to NONE here.
enum Status {
	NONE,
	MODIFIED,
	ADDED,
	DELETED,
	RENAMED,
	COPIED,
	TYPE_CHANGED,
	UNMERGED,
}

const CHAR_STATUS = {
	".": Status.NONE,
	"M": Status.MODIFIED,
	"A": Status.ADDED,
	"D": Status.DELETED,
	"R": Status.RENAMED,
	"C": Status.COPIED,
	"T": Status.TYPE_CHANGED,
	"U": Status.UNMERGED,
}

const STATUS_LABELS = {
	Status.MODIFIED: "Modified",
	Status.ADDED: "Added",
	Status.DELETED: "Deleted",
	Status.RENAMED: "Renamed",
	Status.COPIED: "Copied",
	Status.TYPE_CHANGED: "Type Change",
	Status.UNMERGED: "Conflict",
}

## git's own short-format letters, for a row too narrow to spell the word out.
const STATUS_LETTERS = {
	Status.MODIFIED: "M",
	Status.ADDED: "A",
	Status.DELETED: "D",
	Status.RENAMED: "R",
	Status.COPIED: "C",
	Status.TYPE_CHANGED: "T",
	Status.UNMERGED: "U",
}


## The action a row should display, from an entry of the FILES dict. The worktree side wins when the
## file is dirty on disk, so a staged-then-edited file reports what is still uncommitted.
static func get_status_label(file_data:Dictionary) -> String:
	return _status_display(file_data, STATUS_LABELS, "Untracked", "Conflict", "Unknown")


## The same, abbreviated to git's own single letter for a narrow sidebar.
static func get_status_letter(file_data:Dictionary) -> String:
	return _status_display(file_data, STATUS_LETTERS, "?", "U", "")


## How much attention a status asks for. Ordered: a higher int wins when a directory has to pick
## one descendant to speak for (the tree's marker bubble). NONE is "git has no opinion".
enum Severity {
	NONE,
	NESTED,
	IGNORED,
	STAGED,
	UNTRACKED,
	MODIFIED,
	DELETED,
	CONFLICTED,
}

## The severity of a FILES entry. Kind wins over the staged / unstaged pair deliberately: a
## conflicted or untracked file must not be shadowed by either.
static func get_status_severity(file_data:Dictionary) -> int:
	match file_data.get(Keys.KIND, Kind.ORDINARY):
		Kind.UNMERGED: return Severity.CONFLICTED
		Kind.UNTRACKED: return Severity.UNTRACKED

	var staged = file_data.get(Keys.STAGED, false)
	var unstaged = file_data.get(Keys.UNSTAGED, false)
	if staged and not unstaged:
		return Severity.STAGED

	# the worktree side wins for the same reason it does in get_status_label()
	if file_data.get(Keys.WORKTREE, Status.NONE) == Status.MODIFIED:
		return Severity.MODIFIED
	if file_data.get(Keys.WORKTREE, Status.NONE) == Status.DELETED:
		return Severity.DELETED
	return Severity.IGNORED


## The color a row should display, from an entry of the FILES dict. Pure lookup over
## get_status_severity() — the classification lives there, this only dresses it.
static func get_status_color(file_data:Dictionary, colors:GitColors) -> Color:
	match get_status_severity(file_data):
		Severity.CONFLICTED: return colors.conflicted
		Severity.DELETED: return colors.conflicted
		Severity.MODIFIED: return colors.modified
		Severity.UNTRACKED: return colors.untracked
		Severity.STAGED: return colors.staged
	return colors.ignored


## Whether one entry of a status IGNORED array covers `path`. A directory entry keeps its trailing
## slash and covers its whole subtree — git forbids re-including a file under an excluded directory,
## so a collapsed entry really does mean everything below it. Anything else matches exactly.
##
## Both paths are res:// absolute, which is what keeps an unanchored pattern honest: a repo ignoring
## `addons/` reports it as res://addons/, so res://tools/addons/x correctly does not match.
static func ignored_covers(entry:String, path:String) -> bool:
	if entry.ends_with("/"):
		return path.begins_with(entry)
	return path == entry


## Whether a status IGNORED array covers `path`. Linear, and meant to be — these arrays run to a
## handful of entries because git collapses whole ignored directories into one.
static func is_path_ignored(ignored:Array, path:String) -> bool:
	for entry:String in ignored:
		if ignored_covers(entry, path):
			return true
	return false


## Every character get_status_letter() can return — what a glyph cache has to bake up front.
static func get_letter_set() -> String:
	# "?" is the untracked row's letter and is not in the table, which is keyed by Status
	return "".join(STATUS_LETTERS.values()) + "?"


## How many files are in each state, from a get_status() result. STAGED and UNSTAGED are not
## exclusive — a file staged and then edited again is both — so they do not partition TOTAL, which is
## the file count rather than their sum.
static func count_changes(status:Dictionary) -> Dictionary:
	var counts = {
		Keys.COUNT_STAGED: 0,
		Keys.COUNT_UNSTAGED: 0,
		Keys.COUNT_UNTRACKED: 0,
		Keys.COUNT_CONFLICTED: 0,
		Keys.COUNT_TOTAL: 0,
	}

	var files:Dictionary = status.get(Keys.FILES, {})
	counts[Keys.COUNT_TOTAL] = files.size()

	for file_data:Dictionary in files.values():
		match file_data.get(Keys.KIND, Kind.ORDINARY):
			Kind.UNTRACKED:
				counts[Keys.COUNT_UNTRACKED] += 1
				continue
			Kind.UNMERGED:
				counts[Keys.COUNT_CONFLICTED] += 1
				continue

		if file_data.get(Keys.STAGED, false):
			counts[Keys.COUNT_STAGED] += 1
		if file_data.get(Keys.UNSTAGED, false):
			counts[Keys.COUNT_UNSTAGED] += 1

	return counts


## What the branch reads as, from a get_status() result's BRANCH dict. A detached HEAD has no name,
## so it is named by its oid — the reason BRANCH_OID is kept.
static func get_branch_label(branch:Dictionary) -> String:
	if branch.get(Keys.BRANCH_DETACHED, false):
		var oid:String = branch.get(Keys.BRANCH_OID, "")
		return "%s (detached)" % oid.substr(0, SHORT_OID) if not oid.is_empty() else "(detached)"

	var name:String = branch.get(Keys.BRANCH_NAME, "")
	if name.is_empty():
		return "" # not a repo, or git is not on PATH — say nothing rather than guess

	if branch.get(Keys.BRANCH_INITIAL, false):
		return "%s (no commits)" % name

	var upstream:String = branch.get(Keys.BRANCH_UPSTREAM, "")
	if upstream.is_empty():
		return name

	return "%s → %s" % [name, upstream]


## How far the branch has drifted from its upstream: "↑2 ↓1", or "" when in sync or untracked. Kept
## apart from get_branch_label because an ellipsis eats the end of a string, so a combined label
## would lose the ahead/behind first — the half worth acting on.
static func get_divergence_label(branch:Dictionary) -> String:
	var parts:Array[String] = []
	var ahead:int = branch.get(Keys.BRANCH_AHEAD, 0)
	var behind:int = branch.get(Keys.BRANCH_BEHIND, 0)

	if ahead > 0:
		parts.append("↑%d" % ahead)
	if behind > 0:
		parts.append("↓%d" % behind)

	return " ".join(parts)


## Everything the panel's repo row shows, out of what the last refresh already fetched. Spawns nothing.
static func get_repo_info(status:Dictionary, commits:Array) -> Dictionary:
	return {
		Keys.REPO: status.get(Keys.REPO, ""),
		Keys.BRANCH: status.get(Keys.BRANCH, _new_branch()),
		Keys.COUNTS: count_changes(status),
		Keys.LAST_COMMIT: commits[0] if not commits.is_empty() else {},
	}


## The repo row's tooltip. Sections with nothing to say are left out rather than printed empty.
static func format_repo_tooltip(info:Dictionary) -> String:
	var blocks:Array[String] = []

	var repo:String = info.get(Keys.REPO, "")
	if not repo.is_empty():
		blocks.append(repo)

	var branch:Dictionary = info.get(Keys.BRANCH, {})
	var branch_lines:Array[String] = []
	var label = get_branch_label(branch)
	if not label.is_empty():
		branch_lines.append(label)

	var ahead:int = branch.get(Keys.BRANCH_AHEAD, 0)
	var behind:int = branch.get(Keys.BRANCH_BEHIND, 0)
	if ahead > 0 or behind > 0:
		var drift:Array[String] = []
		if ahead > 0:
			drift.append("↑%d ahead" % ahead)
		if behind > 0:
			drift.append("↓%d behind" % behind)
		branch_lines.append(" · ".join(drift))

	if not branch_lines.is_empty():
		blocks.append("\n".join(branch_lines))

	blocks.append(_format_counts(info.get(Keys.COUNTS, {})))

	var commit:Dictionary = info.get(Keys.LAST_COMMIT, {})
	if not commit.is_empty():
		blocks.append("%s  %s\n%s · %s" % [
			commit.get(Keys.HASH, ""),
			commit.get(Keys.SUBJECT, ""),
			commit.get(Keys.AUTHOR, ""),
			commit.get(Keys.DATE, ""),
		])

	return "\n\n".join(blocks)


static func _format_counts(counts:Dictionary) -> String:
	var total:int = counts.get(Keys.COUNT_TOTAL, 0)
	if total == 0:
		return "Clean"

	var parts:Array[String] = []
	for key in [Keys.COUNT_STAGED, Keys.COUNT_UNSTAGED, Keys.COUNT_UNTRACKED, Keys.COUNT_CONFLICTED]:
		var n:int = counts.get(key, 0)
		if n > 0:
			parts.append("%d %s" % [n, key])

	return "%d changed — %s" % [total, ", ".join(parts)]


static func _status_display(file_data:Dictionary, table:Dictionary, untracked:String, conflict:String, unknown:String) -> String:
	match file_data.get(Keys.KIND, Kind.ORDINARY):
		Kind.UNTRACKED:
			return untracked
		Kind.UNMERGED:
			return conflict

	var worktree:Status = file_data.get(Keys.WORKTREE, Status.NONE)
	var index:Status = file_data.get(Keys.INDEX, Status.NONE)
	return table.get(worktree if worktree != Status.NONE else index, unknown)

## `read_stderr` stays off for reads: OS.execute merges stderr into the same output array, where a
## stray git warning would reach the parser. Writes turn it on — git says why it refused there.
#! keys exit:int output:Array
static func run_git(repo_dir:String, args:Array, read_stderr:=false) -> Dictionary:
	# globalized, not project relative: `git -C` resolves against the editor process's working
	# directory, which is not the project root
	var final_args:Array = ["-C", ProjectSettings.globalize_path(repo_dir)]
	final_args.append_array(args)

	var output = []
	var exit_code = OS.execute("git", final_args, output, read_stderr)
	return {
		Keys.EXIT: exit_code,
		Keys.OUTPUT: output,
	}


static func is_repo(dir_path:String) -> bool:
	var git_path = dir_path.path_join(".git")
	# `.git` is a file, not a directory, when the repo is a worktree or a submodule gitlink
	return DirAccess.dir_exists_absolute(git_path) or FileAccess.file_exists(git_path)


## Every repo under `root`, not just the top level one — this project keeps each addon as its own
## standalone clone nested inside the project repo.
static func find_repos(root:="res://", max_depth:=MAX_DEPTH) -> Array[String]:
	var repos:Array[String] = []
	var queue = [[UFile.ensure_dir_slash(root), 0]]

	while not queue.is_empty():
		var entry = queue.pop_front()
		var dir_path:String = entry[0]
		var depth:int = entry[1]

		if is_repo(dir_path):
			repos.append(dir_path)
			# no early out — repos nest, so keep descending past one to find the rest

		if depth >= max_depth:
			continue

		# show_hidden must be on or `.git` is invisible to DirAccess
		var contents = UFile.get_dir_contents(dir_path, true, true)
		for sub_dir:String in contents.get("dirs", []):
			if sub_dir.trim_suffix("/").get_file() in PRUNE_DIRS:
				continue
			queue.append([sub_dir, depth + 1])

	return repos


## The repo a path belongs to, out of a find_repos() result: the deepest one containing it, as git
## itself resolves. An addon kept as its own clone is untracked by the project repo around it, which
## would answer "no such file in HEAD" for every script inside it.
static func find_repo_for(path:String, repos:Array) -> String:
	var best = ""
	for repo:String in repos:
		if path.begins_with(repo) and repo.length() > best.length():
			best = repo
	return best


## Blocking — run it off the main thread.
##
## Not `-z`: NUL delimited output is more robust for pathological paths, but OS.execute pipes through
## a Godot String, where embedded NULs cannot be relied on. core.quotepath=false is the safe trade —
## git C-quotes the awkward paths and _unquote_path puts them back.
static func get_status(repo_dir:String) -> Dictionary:
	var result = run_git(repo_dir, [
		"-c", "core.quotepath=false",
		"status", "--porcelain=v2", "--branch", "--untracked-files=all",
		# `matching` and not `traditional`: with --untracked-files=all above, traditional stops
		# collapsing and lists every file inside an ignored directory instead of the directory —
		# 17k lines rather than 4 on this project. matching reports the pattern match itself, which
		# is exactly the prefix ignored_covers() wants.
		"--ignored=matching",
	])

	var output:Array = result[Keys.OUTPUT]
	if result[Keys.EXIT] != 0 or output.is_empty():
		return parse_status("", repo_dir)

	return parse_status(String(output[0]), repo_dir)


## The parse half of get_status, split out so it can be exercised against captured git output
## without spawning anything. See tests/git/.
static func parse_status(text:String, repo_dir:String) -> Dictionary:
	var status = {
		Keys.REPO: repo_dir,
		Keys.BRANCH: _new_branch(),
		Keys.FILES: {},
		Keys.IGNORED: [] as Array[String],
	}

	for raw_line in text.split("\n", false):
		var line = raw_line.trim_suffix("\r")
		if line.begins_with("# branch."):
			_parse_branch_header(line, status[Keys.BRANCH])
		elif not line.begins_with("#"): # ignore headers we don't recognise, as git asks
			_parse_entry(line, repo_dir, status[Keys.FILES], status[Keys.IGNORED])

	return status


## Blocking — run it off the main thread. Merges hunks into an existing get_status() result.
##
## Two spawns for the whole worktree, not one per file: `git diff` with no pathspec already emits
## every changed file, and splitting it up would only multiply git's ~11ms startup. Untracked files
## get no hunks — git excludes them by design, and their content can just be read off disk.
static func attach_diffs(repo_dir:String, status:Dictionary) -> void:
	var files:Dictionary = status.get(Keys.FILES, {})
	if files.is_empty():
		return

	_merge_patch(repo_dir, files, [], Keys.HUNKS_UNSTAGED)      # worktree vs index
	_merge_patch(repo_dir, files, ["--cached"], Keys.HUNKS_STAGED) # index vs HEAD


static func _merge_patch(repo_dir:String, files:Dictionary, extra_args:Array, hunks_key:StringName) -> void:
	var args = ["-c", "core.quotepath=false", "diff", "--patch"]
	args.append_array(extra_args)

	var result = run_git(repo_dir, args)
	if result[Keys.EXIT] != 0:
		return

	var output:Array = result[Keys.OUTPUT]
	if output.is_empty():
		return

	var patch = parse_patch(String(output[0]), repo_dir)
	for res_path:String in patch:
		if not files.has(res_path):
			continue # a path in the diff but not in the status: nothing to hang it off
		var parsed:Dictionary = patch[res_path]
		files[res_path][hunks_key] = parsed[Keys.HUNKS]
		if parsed[Keys.BINARY]:
			files[res_path][Keys.BINARY] = true


## The rev a committed file is read out of. HEAD and not the index: a gutter marking the index would
## go blank the moment you staged.
const REV_HEAD = "HEAD"

## Whether a committed version of a file could be read, and if not, why not — each wants something
## different drawn. ABSENT means every line is new, so paint them all; ERROR means paint nothing;
## IGNORED means git is not watching the file at all, so a diff against it says nothing. Appended to,
## never reordered: the ordinals travel.
enum Head {
	OK,
	ABSENT,
	ERROR,
	IGNORED,
}

## The argv for reading one file out of a rev, split from the spawn so it can be tested.
##
## `<rev>:<path>` is a tree path, not a pathspec: git does not glob it, so PATHSPEC_LITERAL must not
## be prefixed here or git looks for a file literally named ":(literal)src/a.gd".
static func build_show_args(rev:String, repo_dir:String, res_path:String) -> Array:
	return ["show", "%s:%s" % [rev, to_repo_path(repo_dir, res_path)]]


## The argv for asking whether one file is ignored, split from the spawn so it can be tested.
##
## check-ignore takes pathnames and not pathspecs, so PATHSPEC_LITERAL must not be prefixed here —
## the same trap as build_show_args. `-q` because only the exit code is read, `--` so a path that
## looks like a flag is still read as a path.
static func build_check_ignore_args(repo_dir:String, res_path:String) -> Array:
	return ["check-ignore", "-q", "--", to_repo_path(repo_dir, res_path)]


## Whether .gitignore excludes a file from its repo. Blocking — run it off the main thread.
##
## Exit 0 is ignored, 1 is not, 128 is git refusing to answer — the last two are the same answer here.
## check-ignore does not report a *tracked* path as ignored even when a pattern matches it, so this
## cannot misfire on a file git is already watching.
static func is_ignored(repo_dir:String, res_path:String) -> bool:
	return run_git(repo_dir, build_check_ignore_args(repo_dir, res_path))[Keys.EXIT] == 0


## One file's committed content, as text. Blocking — run it off the main thread.
##
## `git show` answers 128 both for a path not in HEAD and for a directory that is not a repo, with
## only git's localized prose to separate them, so the failure path re-asks with rev-parse. A repo
## with no commits falls out as ABSENT, which is the truth: nothing in it is committed yet.
##
## The ignore check rides on that same failure path and so costs nothing for a tracked file: not in
## HEAD is the only way to reach it. It separates "git has not seen this yet" from "git will never
## see this", which `git show` alone answers identically.
#! keys head:Head text:String
static func get_file_at_head(repo_dir:String, res_path:String) -> Dictionary:
	var result = run_git(repo_dir, build_show_args(REV_HEAD, repo_dir, res_path))
	if result[Keys.EXIT] == 0:
		var output:Array = result[Keys.OUTPUT]
		# an empty blob is a success with nothing in the array
		return {Keys.HEAD: Head.OK, Keys.TEXT: String(output[0]) if not output.is_empty() else ""}

	if run_git(repo_dir, ["rev-parse", "--git-dir"])[Keys.EXIT] == 0:
		var head:Head = Head.IGNORED if is_ignored(repo_dir, res_path) else Head.ABSENT
		return {Keys.HEAD: head, Keys.TEXT: ""}

	return {Keys.HEAD: Head.ERROR, Keys.TEXT: ""}


## Blocking — run it off the main thread. Newest first, in git's own order.
##
## `%s` is the subject, the first line only, so a record can never contain a newline and one output
## line is exactly one commit. `%ar` is git's own relative date, so there is no date maths here.
static func get_log(repo_dir:String, limit:=LOG_LIMIT) -> Array[Dictionary]:
	var result = run_git(repo_dir, [
		"log",
		"--max-count=%s" % limit,
		"--pretty=format:" + LOG_SEP.join(LOG_FIELDS),
	])

	var output:Array = result[Keys.OUTPUT]
	# a repo with no commits yet exits non zero — that is not an error, it just has no history
	if result[Keys.EXIT] != 0 or output.is_empty():
		return [] as Array[Dictionary]

	return parse_log(String(output[0]))


## The parse half of get_log, split out so it can be exercised against captured git output without
## spawning anything. See tests/git/.
static func parse_log(text:String) -> Array[Dictionary]:
	var commits:Array[Dictionary] = []

	for raw_line in text.split("\n", false):
		var line = raw_line.trim_suffix("\r")
		var parts = line.split(LOG_SEP)
		if parts.size() < LOG_FIELDS.size():
			continue

		commits.append({
			Keys.HASH: parts[0],
			Keys.SUBJECT: parts[1],
			Keys.AUTHOR: parts[2],
			Keys.DATE: parts[3],
			Keys.FULL_HASH: parts[4],
			Keys.TAGS: _parse_refs(parts[5]),
		})

	return commits


# The tags out of a `%D` ref field: "HEAD -> main, origin/main, tag: v0.7.2, tag: v0.7.3". Branch and
# HEAD refs share the field, so the "tag: " prefix is the only thing telling them apart.
static func _parse_refs(field:String) -> Array[String]:
	var tags:Array[String] = []
	for ref in field.split(",", false):
		var name = ref.strip_edges()
		if name.begins_with(TAG_PREFIX):
			tags.append(name.substr(TAG_PREFIX.length()))
	return tags


## The argv for blaming one file at a rev, split from the spawn so it can be tested.
##
## `--porcelain` and not `--line-porcelain`: the commit header is emitted once per commit rather than
## once per line, which is ~800 output lines for a 700 line file where the latter is ~9000. Same trap
## as build_show_args — blame takes a pathname after `--`, so PATHSPEC_LITERAL must not be prefixed.
static func build_blame_args(rev:String, repo_dir:String, res_path:String) -> Array:
	return ["blame", "--porcelain", rev, "--", to_repo_path(repo_dir, res_path)]


## Which commit last touched each line of a file at a rev. Blocking — run it off the main thread.
##
## HEAD and not the worktree: the file on disk is not what the editor's buffer holds either, and HEAD
## is the baseline the gutter's hunks already map a buffer line back to.
##
## Only OK and ABSENT, unlike get_file_at_head: a missing file, a directory that is not a repo and an
## ignored file all mean the same thing here — no history to show — so none of them is worth a spawn
## to tell apart.
#! keys head:Head commits:Dictionary blame_lines:PackedStringArray
static func get_blame(repo_dir:String, res_path:String, rev:=REV_HEAD) -> Dictionary:
	var result = run_git(repo_dir, build_blame_args(rev, repo_dir, res_path))

	var output:Array = result[Keys.OUTPUT]
	if result[Keys.EXIT] != 0 or output.is_empty():
		return {Keys.HEAD: Head.ABSENT, Keys.COMMITS: {}, Keys.BLAME_LINES: PackedStringArray()}

	var parsed = parse_blame(String(output[0]))
	parsed[Keys.HEAD] = Head.OK
	return parsed


## The parse half of get_blame, split out so it can be exercised against captured git output without
## spawning anything. See tests/brohd/git/.
##
## Porcelain states a commit's header only the first time that commit appears, so COMMITS fills in as
## the output is walked and BLAME_LINES carries nothing but a sha to look up in it.
#! keys commits:Dictionary blame_lines:PackedStringArray
static func parse_blame(text:String) -> Dictionary:
	var commits:Dictionary = {}
	var blame_lines := PackedStringArray()
	# which commit's header is being read, and the flag for "the next line starts a new entry"
	var sha := ""

	for raw_line in text.split("\n", false):
		var line = raw_line.trim_suffix("\r")

		# the content line is the only indented one, and it closes the entry — nothing in it is read
		if line.begins_with("\t"):
			sha = ""
			continue

		if not sha.is_empty():
			_parse_blame_header(line, commits[sha])
			continue

		# "<sha> <line in the commit> <line in the file> [<lines in this group>]", the count being
		# present only on a group's first line
		var header = line.split(" ", false)
		if header.size() < 3:
			continue

		sha = header[0]
		var final_line = int(header[2])
		# 1 based, and assigned by index rather than appended: nothing about the format promises the
		# groups arrive in file order, and appending would silently shift every line after one that did not
		if final_line > blame_lines.size():
			blame_lines.resize(final_line)
		blame_lines[final_line - 1] = sha

		if not commits.has(sha):
			commits[sha] = _new_blame_commit(sha)

	return {Keys.COMMITS: commits, Keys.BLAME_LINES: blame_lines}


# One `key value` line of a commit's header. Only what a row displays is kept — `previous`,
# `filename`, the committer fields and the valueless `boundary` all fall through.
static func _parse_blame_header(line:String, commit:Dictionary) -> void:
	var parts = line.split(" ", true, 1)
	if parts.size() < 2:
		return # `boundary` and friends carry no value

	var value = parts[1]
	match parts[0]:
		"author": commit[Keys.AUTHOR] = value
		"author-mail": commit[Keys.AUTHOR_MAIL] = value.trim_prefix("<").trim_suffix(">")
		"author-time":
			commit[Keys.AUTHOR_TIME] = int(value)
			commit[Keys.DATE] = format_relative_time(int(value))
		"author-tz": commit[Keys.AUTHOR_TZ] = value
		"summary": commit[Keys.SUBJECT] = value


# The shape parse_log() returns plus blame's own fields, so a blame commit can be handed to anything
# that already renders a log row. TAGS is not in porcelain output and stays empty rather than faked.
static func _new_blame_commit(sha:String) -> Dictionary:
	return {
		Keys.HASH: sha.left(SHORT_OID),
		Keys.FULL_HASH: sha,
		Keys.SUBJECT: "",
		Keys.AUTHOR: "",
		Keys.DATE: "",
		Keys.TAGS: [] as Array[String],
		Keys.AUTHOR_MAIL: "",
		Keys.AUTHOR_TIME: 0,
		Keys.AUTHOR_TZ: "",
	}


const MINUTE = 60
const HOUR = 60 * MINUTE
const DAY = 24 * HOUR
const WEEK = 7 * DAY
## An average month and year, as git's own relative dates use — exact ones would need the calendar
## and would still be wrong for the gap either side of them.
const MONTH = 30 * DAY
const YEAR = 365 * DAY

## Each row is [unit, the delta it stops covering, its name]. Walked in order, so the first row wide
## enough wins; the thresholds are git's, which is why they are not simply one unit of the next size.
const RELATIVE_UNITS = [
	[1, 90, "second"],
	[MINUTE, 90 * MINUTE, "minute"],
	[HOUR, 36 * HOUR, "hour"],
	[DAY, 14 * DAY, "day"],
	[WEEK, 10 * WEEK, "week"],
	[MONTH, 12 * MONTH, "month"],
]

## A timestamp as git's own `%ar` words: "3 days ago". The one place a date is computed rather than
## read — blame porcelain gives a raw epoch, where `git log` had %ar do this for us.
##
## `now` is a parameter so the buckets can be tested against a fixed clock.
static func format_relative_time(unix_time:int, now:=-1) -> String:
	if unix_time <= 0:
		return ""
	if now < 0:
		now = int(Time.get_unix_time_from_system())

	var delta = now - unix_time
	# a skewed clock, or a commit whose author date is ahead of its commit date. git says this too
	if delta < 0:
		return "in the future"

	for unit in RELATIVE_UNITS:
		if delta < unit[1]:
			return _plural(int(round(float(delta) / unit[0])), unit[2])

	return _plural(int(round(float(delta) / YEAR)), "year")


# "1 day ago" / "3 days ago". Only the seconds bucket can reach 0, and "0 seconds ago" is what git
# prints there too.
static func _plural(count:int, unit:String) -> String:
	return "%d %s%s ago" % [count, unit, "" if count == 1 else "s"]


static func _new_branch() -> Dictionary:
	return {
		Keys.BRANCH_NAME: "",
		Keys.BRANCH_OID: "",
		Keys.BRANCH_UPSTREAM: "",
		Keys.BRANCH_AHEAD: 0,
		Keys.BRANCH_BEHIND: 0,
		Keys.BRANCH_DETACHED: false,
		Keys.BRANCH_INITIAL: false,
	}


# One of the four `# branch.*` headers --branch emits. Each states its field outright, so there is no
# punctuation to unpick the way v1's single "## main...origin/main [ahead 1]" line needed.
static func _parse_branch_header(line:String, branch:Dictionary) -> void:
	var parts = line.split(" ", true, 2)
	if parts.size() < 3:
		return

	match parts[1]:
		"branch.oid":
			# the only thing a detached HEAD can be named by — branch.head reports "(detached)"
			# and leaves the name empty
			branch[Keys.BRANCH_INITIAL] = parts[2] == "(initial)"
			if not branch[Keys.BRANCH_INITIAL]:
				branch[Keys.BRANCH_OID] = parts[2]
		"branch.head":
			if parts[2] == "(detached)":
				branch[Keys.BRANCH_DETACHED] = true
			else:
				branch[Keys.BRANCH_NAME] = parts[2]
		"branch.upstream":
			branch[Keys.BRANCH_UPSTREAM] = parts[2]
		"branch.ab":
			# "+<ahead> -<behind>"
			for field in parts[2].split(" ", false):
				if field.begins_with("+"):
					branch[Keys.BRANCH_AHEAD] = field.substr(1).to_int()
				elif field.begins_with("-"):
					branch[Keys.BRANCH_BEHIND] = field.substr(1).to_int()


# A single tracked / untracked / ignored entry; the leading token is the line type. Every split is
# bounded by an explicit maxsplit: a path may contain spaces, so it must take the whole remainder.
static func _parse_entry(line:String, repo_dir:String, files:Dictionary, ignored:Array) -> void:
	match line.substr(0, 2):
		"1 ":
			# 1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>
			var parts = line.split(" ", true, 8)
			if parts.size() < 9:
				return
			var entry = _new_entry(Kind.ORDINARY, parts[1])
			entry[Keys.SUB] = parts[2]
			entry[Keys.OID_HEAD] = parts[6]
			entry[Keys.OID_INDEX] = parts[7]
			files[_to_res_path(repo_dir, parts[8])] = entry

		"2 ": 
			# 2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X><score> <path><TAB><origPath>
			var parts = line.split(" ", true, 9)
			if parts.size() < 10:
				return
			var paths = parts[9].split("\t")
			if paths.size() < 2:
				return
			var entry = _new_entry(Kind.RENAMED, parts[1])
			entry[Keys.SUB] = parts[2]
			entry[Keys.OID_HEAD] = parts[6]
			entry[Keys.OID_INDEX] = parts[7]
			entry[Keys.SCORE] = parts[8].substr(1).to_int() # drop the leading R / C
			entry[Keys.RENAMED_FROM] = _to_res_path(repo_dir, paths[1])
			files[_to_res_path(repo_dir, paths[0])] = entry

		"u ":
			# u <XY> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>
			var parts = line.split(" ", true, 10)
			if parts.size() < 11:
				return
			var entry = _new_entry(Kind.UNMERGED, parts[1])
			entry[Keys.SUB] = parts[2]
			files[_to_res_path(repo_dir, parts[10])] = entry

		"? ":
			files[_to_res_path(repo_dir, line.substr(2))] = _new_entry(Kind.UNTRACKED, "..")

		"! ":
			# a path, not an entry: git reports the matching directory rather than its contents under
			# --ignored=matching, so this is a prefix to test against, not a file to list
			ignored.append(_to_res_path(repo_dir, line.substr(2)))


static func _new_entry(kind:Kind, xy:String) -> Dictionary:
	var index:Status = CHAR_STATUS.get(xy.substr(0, 1), Status.NONE)
	var worktree:Status = CHAR_STATUS.get(xy.substr(1, 1), Status.NONE)

	return {
		Keys.KIND: kind,
		Keys.INDEX: index,
		Keys.WORKTREE: worktree,
		Keys.STAGED: index != Status.NONE,
		Keys.UNSTAGED: worktree != Status.NONE,
		Keys.RENAMED_FROM: "",
		Keys.SCORE: 0,
		Keys.SUB: "",
		Keys.OID_HEAD: "",
		Keys.OID_INDEX: "",
		Keys.BINARY: false,
		Keys.HUNKS_STAGED: [],
		Keys.HUNKS_UNSTAGED: [],
	}


## A unified diff, split into per-file hunks and keyed by res:// path so it merges straight into the
## FILES dict from get_status. Pure, like parse_status — see tests/git/.
static func parse_patch(text:String, repo_dir:String) -> Dictionary:
	var out = {}

	var res_path = ""
	var header = "" # the "a/x b/x" tail of the current `diff --git` line, kept for the binary case
	var file_data = {}
	var hunk = {}

	# `allow_empty` stays on: an empty context line is " " but a removed empty line is a bare "-", and
	# dropping empties would silently shift the line counts. Only the final newline is punctuation —
	# git terminates its output with it, and the trailing "" would read as an uncounted context line
	# on the last hunk. Every line in a hunk carries an origin, so trimming exactly one is safe.
	for raw_line in text.trim_suffix("\n").split("\n"):
		var line = raw_line.trim_suffix("\r")

		if line.begins_with("diff --git "):
			res_path = ""
			header = line.substr(11)
			file_data = {Keys.HUNKS: [], Keys.BINARY: false}
			hunk = {}
			continue

		if file_data.is_empty():
			continue

		# The two path headers. `+++` names the file, except for a deletion, where it is /dev/null
		# and `---` is the only place the path survives.
		if line.begins_with("+++ ") and line != "+++ /dev/null":
			res_path = _patch_path(repo_dir, line.substr(4), "b/")
			out[res_path] = file_data
			continue
		if line.begins_with("--- ") and line != "--- /dev/null" and res_path.is_empty():
			res_path = _patch_path(repo_dir, line.substr(4), "a/")
			out[res_path] = file_data
			continue

		if line.begins_with("Binary files ") or line.begins_with("GIT binary patch"):
			file_data[Keys.BINARY] = true
			# a binary file has no +++/--- headers, so the `diff --git` line is the only path source
			if res_path.is_empty():
				res_path = _header_path(repo_dir, header)
				if not res_path.is_empty():
					out[res_path] = file_data
			continue

		if line.begins_with("@@"):
			hunk = _parse_hunk_header(line)
			file_data[Keys.HUNKS].append(hunk)
			continue

		if hunk.is_empty():
			continue # still in the file header (index / mode / rename lines)

		# Inside a hunk the first character is the origin. "\" is git's "\ No newline at end of
		# file" marker, which annotates the previous line rather than being one of its own.
		var origin = line.substr(0, 1)
		match origin:
			" ", "+", "-":
				hunk[Keys.LINES].append({
					Keys.ORIGIN: origin,
					Keys.TEXT: line.substr(1),
				})
			"":
				# a context line that is empty; git writes " " but be forgiving
				hunk[Keys.LINES].append({Keys.ORIGIN: " ", Keys.TEXT: ""})
			"\\":
				hunk[Keys.NO_NEWLINE] = true

	return out


# "@@ -<old_start>,<old_count> +<new_start>,<new_count> @@ <heading>"
#
# A count is omitted when it is 1. The trailing heading is git's guess at the enclosing function —
# not diff content, and must not be read as a line.
static func _parse_hunk_header(line:String) -> Dictionary:
	var hunk = {
		Keys.OLD_START: 0,
		Keys.OLD_COUNT: 0,
		Keys.NEW_START: 0,
		Keys.NEW_COUNT: 0,
		Keys.HEADING: "",
		Keys.NO_NEWLINE: false,
		Keys.LINES: [],
	}

	var close = line.find("@@", 2)
	if close < 0:
		return hunk

	hunk[Keys.HEADING] = line.substr(close + 2).strip_edges()

	for field in line.substr(2, close - 2).strip_edges().split(" ", false):
		var side = field.substr(0, 1)
		if side != "-" and side != "+":
			continue

		var nums = field.substr(1).split(",")
		var start = nums[0].to_int()
		var count = nums[1].to_int() if nums.size() > 1 else 1

		if side == "-":
			hunk[Keys.OLD_START] = start
			hunk[Keys.OLD_COUNT] = count
		else:
			hunk[Keys.NEW_START] = start
			hunk[Keys.NEW_COUNT] = count

	return hunk


# The path out of a `--- a/x` / `+++ b/x` header, quoted differently to a porcelain path and so not
# routable through _to_res_path. Two silent traps — a mis-read path just fails to match a status key
# and the hunks vanish: git TAB-terminates the field when the path has a space, and C-quotes the
# whole field including the `a/` prefix, so tab and quoting must come off before the prefix.
static func _patch_path(repo_dir:String, field:String, prefix:String) -> String:
	return repo_dir.path_join(_unquote_path(field.trim_suffix("\t")).trim_prefix(prefix))


# The path out of a `diff --git a/x b/x` line. A last resort for binary files, which get no +++/---.
#
# Ambiguous by construction: the paths are space-joined and unquoted, so `a/one two.txt b/one two.txt`
# cannot be split on the space. Recoverable only because the halves are identical for anything but a
# rename, so the split is found by length and then checked. Returns "" when that check fails — no
# hunks beats a file's hunks silently attached to the wrong path.
static func _header_path(repo_dir:String, header:String) -> String:
	if header.begins_with("\""):
		var close = _find_closing_quote(header)
		if close < 0:
			return ""
		return repo_dir.path_join(_unquote_path(header.substr(0, close + 1)).trim_prefix("a/"))

	# "a/" + path + " " + "b/" + path, so the length is 2 * path + 5
	if header.length() < 7 or (header.length() - 5) % 2 != 0:
		return ""

	# exact, not truncating: the odd-length case already returned above
	@warning_ignore("integer_division")
	var path = header.substr(2, (header.length() - 5) / 2)
	if header != "a/%s b/%s" % [path, path]:
		return "" # a rename, or something else we cannot read back confidently
	return repo_dir.path_join(path)


# The closing quote of a C-quoted field, honouring backslash escapes so an escaped quote inside the
# name does not end it early.
static func _find_closing_quote(text:String) -> int:
	var i = 1
	while i < text.length():
		match text[i]:
			"\\": i += 2
			"\"": return i
			_: i += 1
	return -1


static func _to_res_path(repo_dir:String, rel_path:String) -> String:
	# porcelain paths are relative to the repo root; this is what makes the keys mergeable into the
	# per-file cache in utils_local.gd
	return repo_dir.path_join(_unquote_path(rel_path))


# git C-quotes any path with a quote, a backslash or a control character in it.
static func _unquote_path(path:String) -> String:
	if not path.begins_with("\""):
		return path

	path = path.substr(1, path.length() - 2)

	var out = ""
	var i = 0
	while i < path.length():
		if path[i] != "\\":
			out += path[i]
			i += 1
			continue

		i += 1
		if i >= path.length():
			break

		var escaped = path[i]
		i += 1
		match escaped:
			"n": out += "\n"
			"t": out += "\t"
			"r": out += "\r"
			"\"": out += "\""
			"\\": out += "\\"
			_:
				if escaped >= "0" and escaped <= "7": # \nnn, an octal byte
					var code = 0
					for digit in escaped + path.substr(i, 2):
						code = code * 8 + (digit.unicode_at(0) - 48)
					i += 2
					out += char(code)
				else:
					out += escaped

	return out


#region Commands

## Turns a pathspec into a plain path, killing the glob. git globs a pathspec, so a name containing
## [ * or ? acts on files that were never named — and DISCARD or DELETE would take the bystander
## with them, with no reflog for work that never reached the index.
const PATHSPEC_LITERAL = ":(literal)"

## What a file is, as a mask, so a command can state the states it accepts as data — a const
## Dictionary cannot hold a function reference.
enum State {
	STAGED     = 1 << 0,
	UNSTAGED   = 1 << 1,
	UNTRACKED  = 1 << 2,
	CONFLICTED = 1 << 3,
}

enum Command {
	STAGE,
	UNSTAGE,
	DISCARD,
	DELETE,
}
const COMMAND_DESTRUCTIVE = [Command.DISCARD, Command.DELETE]

## STAGE accepts CONFLICTED because staging is how git marks a conflict resolved. DISCARD takes
## UNSTAGED and not UNTRACKED: `git restore` does not touch a file git has never seen, and removing
## one of those is DELETE, with a different blast radius.
const COMMANDS = {
	Command.STAGE: {
		Keys.CMD_LABEL: "Stage",
		Keys.CMD_ARGS: ["add"],
		Keys.CMD_ACCEPTS: State.UNSTAGED | State.UNTRACKED | State.CONFLICTED,
		Keys.CMD_DESTRUCTIVE: false,
		Keys.CMD_WORKTREE: false,
	},
	Command.UNSTAGE: {
		Keys.CMD_LABEL: "Unstage",
		Keys.CMD_ARGS: ["restore", "--staged"],
		Keys.CMD_ACCEPTS: State.STAGED,
		Keys.CMD_DESTRUCTIVE: false,
		Keys.CMD_WORKTREE: false,
	},
	Command.DISCARD: {
		Keys.CMD_LABEL: "Discard Changes",
		Keys.CMD_ARGS: ["restore"],
		Keys.CMD_ACCEPTS: State.UNSTAGED,
		Keys.CMD_DESTRUCTIVE: true,
		Keys.CMD_WORKTREE: true,
	},
	Command.DELETE: {
		Keys.CMD_LABEL: "Delete File",
		Keys.CMD_ARGS: ["clean", "-f"],
		Keys.CMD_ACCEPTS: State.UNTRACKED,
		Keys.CMD_DESTRUCTIVE: true,
		Keys.CMD_WORKTREE: true,
	},
}

## The unstage that works on a repo with no commits. `git restore --staged` restores the index from
## HEAD, which an initial repo has none of — it dies with "could not resolve HEAD".
const ARGS_UNSTAGE_INITIAL:Array = ["rm", "--cached"]


## Which of State's bits a file has raised, from an entry of the FILES dict. The kind settles
## untracked and conflicted before the staged/unstaged pair is read — not an optimisation: an
## untracked entry has a ".." XY pair, so neither flag is set and only the kind classifies it.
static func get_file_state(file_data:Dictionary) -> int:
	match file_data.get(Keys.KIND, Kind.ORDINARY):
		Kind.UNTRACKED:
			return State.UNTRACKED
		Kind.UNMERGED:
			return State.CONFLICTED

	var state = 0
	if file_data.get(Keys.STAGED, false):
		state |= State.STAGED
	if file_data.get(Keys.UNSTAGED, false):
		state |= State.UNSTAGED
	return state


## Whether a command has anything to do to this file — what decides if it is offered on the menu.
static func command_accepts(command:Command, file_data:Dictionary) -> bool:
	return get_file_state(file_data) & int(COMMANDS[command][Keys.CMD_ACCEPTS]) != 0


## The paths a command must be handed, which is not always the ones selected. A rename is a delete of
## the old path plus an add of the new, keyed on the new one — unstage only that and git leaves the
## old path's deletion staged, a half-unstaged rename worse than either end of it.
static func expand_paths(command:Command, paths:Array, files:Dictionary) -> Array:
	if command != Command.UNSTAGE:
		return paths.duplicate()

	var out:Array = []
	for path in paths:
		out.append(path)
		var file_data:Dictionary = files.get(path, {})
		if file_data.get(Keys.KIND, Kind.ORDINARY) != Kind.RENAMED:
			continue
		var from:String = file_data.get(Keys.RENAMED_FROM, "")
		if not from.is_empty() and not out.has(from):
			out.append(from)
	return out


## A res:// path as git sees it: relative to the repo root, which run_git's `-C` resolves against.
## The inverse of _to_res_path(). Assumes `path` is under `repo_dir` — find_repo_for() is what makes
## that true; otherwise trim_prefix returns a res:// path and git is asked about a file that cannot exist.
static func to_repo_path(repo_dir:String, path:String) -> String:
	return path.trim_prefix(repo_dir)


## A res:// path as a pathspec git will match literally, relative to the repo root.
static func to_pathspec(repo_dir:String, path:String) -> String:
	return PATHSPEC_LITERAL + to_repo_path(repo_dir, path)


## Whether a path names something git can be pointed at, rather than the repo root itself. The root
## trims to "", and a bare `:(literal)` matches every file in the repo — a DISCARD built from one
## takes the whole worktree with it.
static func is_commandable_path(repo_dir:String, path:String) -> bool:
	var rel = to_repo_path(repo_dir, path)
	return not (rel.is_empty() or rel == "." or rel == "/")


## The full argv for a command. `--` keeps a path that looks like a rev from being read as one.
##
## Returns [] when no path survives is_commandable_path(): an argv ending at `--` is a command over
## the entire repo, so there is nothing safe to hand back.
static func build_command_args(command:Command, repo_dir:String, paths:Array, initial:=false) -> Array:
	var pathspecs:Array = []
	for path:String in paths:
		if is_commandable_path(repo_dir, path):
			pathspecs.append(to_pathspec(repo_dir, path))
	if pathspecs.is_empty():
		return []

	var args:Array = []
	if command == Command.UNSTAGE and initial:
		args.append_array(ARGS_UNSTAGE_INITIAL)
	else:
		args.append_array(COMMANDS[command][Keys.CMD_ARGS])

	args.append("--")
	args.append_array(pathspecs)
	return args


## Blocking — the panel runs it on the same worker thread as get_status, which keeps a mutation from
## interleaving with the status read that follows it.
##
## `initial` is the repo-has-no-commits flag from BRANCH_INITIAL. Returns run_git's {exit, output};
## a non-zero exit is the caller's to surface.
static func run_command(repo_dir:String, command:Command, paths:Array, initial:=false) -> Dictionary:
	if paths.is_empty():
		return {Keys.EXIT: 0, Keys.OUTPUT: []}

	# a repo-wide command is never what a row click meant — no-op rather than run it
	var args = build_command_args(command, repo_dir, paths, initial)
	if args.is_empty():
		return {Keys.EXIT: 0, Keys.OUTPUT: []}

	return run_git(repo_dir, args, true)

#endregion



class Keys:
	const EXIT = &"exit"
	const OUTPUT = &"output"

	## one entry of the COMMANDS table
	const CMD_LABEL = &"label"
	const CMD_ARGS = &"args"
	## the State mask a command has something to do to
	const CMD_ACCEPTS = &"accepts"
	## unrecoverable — no reflog for work that never reached the index
	const CMD_DESTRUCTIVE = &"destructive"
	## writes files on disk, so the editor has to be told to look again
	const CMD_WORKTREE = &"worktree_write"

	const REPO = &"repo"
	const BRANCH = &"branch"
	const FILES = &"files"
	## repo-relative ignore matches, as res:// paths. Deliberately not folded into FILES: these are
	## mostly whole directories, and every FILES consumer treats its keys as changed files.
	const IGNORED = &"ignored"
	## a Head enum value — why get_file_at_head() answered the way it did
	const HEAD = &"head"
	const COUNTS = &"counts"
	const LAST_COMMIT = &"last_commit"

	const BRANCH_NAME = &"name"
	## HEAD's commit, and the only handle on a detached HEAD, which has no name
	const BRANCH_OID = &"oid"
	const BRANCH_UPSTREAM = &"upstream"
	const BRANCH_AHEAD = &"ahead"
	const BRANCH_BEHIND = &"behind"
	const BRANCH_DETACHED = &"detached"
	const BRANCH_INITIAL = &"initial"

	## a file can be both staged and unstaged, so these do not partition TOTAL — only TOTAL is the
	## number of files
	const COUNT_STAGED = &"staged"
	const COUNT_UNSTAGED = &"unstaged"
	const COUNT_UNTRACKED = &"untracked"
	const COUNT_CONFLICTED = &"conflicted"
	const COUNT_TOTAL = &"total"

	const KIND = &"kind"
	const INDEX = &"index"
	const WORKTREE = &"worktree"
	const STAGED = &"staged"
	const UNSTAGED = &"unstaged"
	const RENAMED_FROM = &"renamed_from"
	const SCORE = &"score"
	const SUB = &"sub"
	const OID_HEAD = &"oid_head"
	const OID_INDEX = &"oid_index"

	const BINARY = &"binary"
	const HUNKS = &"hunks"
	const HUNKS_STAGED = &"hunks_staged"
	const HUNKS_UNSTAGED = &"hunks_unstaged"

	const OLD_START = &"old_start"
	const OLD_COUNT = &"old_count"
	const NEW_START = &"new_start"
	const NEW_COUNT = &"new_count"
	const HEADING = &"heading"
	const NO_NEWLINE = &"no_newline"
	const LINES = &"lines"
	const ORIGIN = &"origin"
	const TEXT = &"text"

	const HASH = &"hash"
	const FULL_HASH = &"full_hash"
	const SUBJECT = &"subject"
	const AUTHOR = &"author"
	const DATE = &"date"
	const TAGS = &"tags"

	## a parse_blame() result. COMMITS is keyed by full sha; BLAME_LINES holds one of those shas per
	## line of the blamed file, 0 based, so a line costs a lookup rather than a copy of the commit
	const COMMITS = &"commits"
	const BLAME_LINES = &"blame_lines"
	## blame's own commit fields, on top of the ones a parse_log() record already carries
	const AUTHOR_MAIL = &"author_mail"
	const AUTHOR_TIME = &"author_time"
	const AUTHOR_TZ = &"author_tz"


class Colors:
	const REPO = Color(0.384, 0.719, 0.705, 1.0)
	
	const L_GREEN = Color(0.57, 0.92, 0.57, 1.0)
	const GREEN = Color(0.0, 0.454, 0.0, 1.0)
	const L_YELLOW = Color(0.74, 0.69, 0.466, 1.0)
	const YELLOW = Color(0.741, 0.608, 0.0, 1.0)
	const RED = Color(0.573, 0.0, 0.0, 1.0)
	## For what git is not watching — present enough to read as deliberate, faint enough not to
	## compete with the colors that mean an actual change
	const DIM = Color(0.5, 0.5, 0.5, 0.5)
