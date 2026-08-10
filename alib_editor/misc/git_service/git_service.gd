class_name GitService
extends "res://addons/addon_lib/brohd/singleton/singleton_ref_count.gd" #! ext Singletons.RefCount

## Headless git data provider, shared across consumers (the git panel, the diff gutter, and — later —
## the file tree and a standalone line-diff plugin).
##
## Owns the repo list, the current selection, a per-repo status dict and the commit log. Every git
## call runs off the main thread and is published through `status_updated` / `commits_updated` /
## `refresh_finished`. This node holds no UI: it wraps the static GitUtil library and is the piece
## destined to migrate into addon_lib once the API settles.
##
## Status is held for *every* repo, because this project nests ~25 of them and the file tree renders
## them all at once; the log and the diffs stay current-repo only, since they cost three more spawns
## and only the panel reads them. Repos are refreshed one at a time through `_queue`, which is both
## the work list and the dirty set — that single-worker invariant is what lets `_repo_status` be
## touched from the main thread alone, with no lock.


#region SingletonAPI

const PE_STRIP_CAST_SCRIPT = preload("res://addons/addon_lib/brohd//alib_editor/misc/git_service/git_service.gd")

static func get_singleton_name() -> String:
	return "GitService"

static func get_instance() -> PE_STRIP_CAST_SCRIPT:
	return _get_instance(PE_STRIP_CAST_SCRIPT)

static func instance_valid() -> bool:
	return _instance_valid(PE_STRIP_CAST_SCRIPT)

static func register_node(node:Node):
	return _register_node(PE_STRIP_CAST_SCRIPT, node)

static func unregister_node(node:Node):
	_unregister_node(PE_STRIP_CAST_SCRIPT, node)

static func call_on_ready(callable, print_err:bool=true):
	_call_on_ready(PE_STRIP_CAST_SCRIPT, callable, print_err)

func _init(_node):
	pass

func _all_unregistered_callback():
	_join_thread()

func _get_ready_bool() -> bool:
	return is_node_ready()

#endregion

const SettingHelper = preload("uid://c4l4v4eufkmtx") #! resolve ALibEditor.Settings.SettingHelperEditor

const GitUtil = preload("res://addons/addon_lib/brohd//alib_editor/misc/git_service/git_util.gd")
const GitDiff = preload("res://addons/addon_lib/brohd//alib_editor/misc/git_service/git_diff.gd")
const GlyphIcons = preload("res://addons/addon_lib/brohd//alib_editor/misc/git_service/glyph_icons.gd")
const GitDataDraw = preload("res://addons/addon_lib/brohd/alib_editor/misc/git_service/git_data_draw.gd")

const MAIN_REPO = "res://"
const REFRESH_DEBOUNCE = 1.0


signal status_updated(repo_dir:String)
signal commits_updated(repo_dir:String)
## The queue has drained: the repo set has been re-scanned and every repo that was due has been
## re-read. One emission per drain, where status_updated is one per repo — for consumers that repaint
## against the whole picture rather than a single repo. Covers run_command() and set_repo() too
signal refresh_finished

var colors:GitColors

## Echo the argv of every destructive command. Off by default: it is a diagnostic for "that discard
## did something I did not expect", which is otherwise unanswerable — a wrong-but-successful command
## exits 0 and looks exactly like a right one.
var log_commands:bool = false

var setting_helper:SettingHelper

## res:// paths of every repo found under the project
var repos:Array[String] = []
var current_repo:String = MAIN_REPO
## the last GitUtil.get_status() result for every repo, keyed by repo dir. The panel looks at one repo
## at a time, but the file tree spans all of them at once.
var _repo_status:Dictionary = {}
## the last GitUtil.get_log() result for current_repo, newest first. Stays single repo: the log is the
## expensive spawn and only the panel reads it.
var commits:Array[Dictionary] = []

## Memo of find_repo_for(). A path's owning repo is a pure function of the repo set, so this only
## goes stale when that set changes. Negative answers ("" — under no repo) are memoized too, or every
## non-repo path re-scans all 25 repos forever.
var _repo_for_path:Dictionary = {}

## current_repo's status, for the consumers written before this held more than one.
##
## Assignment is not supported — the map is the truth. The setter reports rather than parses because a
## read only property would fail at load time in the plugin repos that consume this, which are
## separate clones on their own release cadence.
var status:Dictionary:
	get:
		return _repo_status.get(current_repo, {})
	set(_value):
		push_error("GitService.status is read-only — the per-repo map is the truth")

var _thread:Thread
var _debounce_timer:Timer
## repos known stale, in service order. Doubles as the dirty set: membership is the dirty flag.
var _queue:Array[String] = []

# commands waiting for the worker thread, as [command, paths] — see run_command()
var _pending_commands:Array = []


func _ready() -> void:
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = REFRESH_DEBOUNCE
	# every repo, not just the selected one: filesystem_changed says nothing about which repo it
	# touched, and the tree is showing all of them
	_debounce_timer.timeout.connect(refresh_all)
	add_child(_debounce_timer)

	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed, 1)
	
	setting_helper = SettingHelper.new()
	colors = GitColors.new()
	colors.connect_settings(setting_helper)
	setting_helper.subscribe_property(self, &"log_commands", EditorSet.LOG_COMMANDS, false)


	setting_helper.initialize()
	
	# Baking the status letters costs one rendered frame, so it starts here
	_get_glyph_icons_node().warm(GitUtil.get_letter_set())

	refresh_repos()
	# fall back to the main repo if current_repo has gone away, then pull a first status
	if not current_repo in repos:
		current_repo = MAIN_REPO
	refresh_all()


func refresh_repos() -> void:
	var found:Array[String] = GitUtil.find_repos()

	# an unchanged set has to cost nothing, since refresh_all() runs this on every focus in.
	# _repo_for_path is only invalidated by the set moving
	if found == repos:
		return
	repos = found

	# a repo that has gone away must stop answering: its paths now belong to whichever repo contains
	# them next, and a stale entry would keep winning find_repo_for() on length alone
	for repo_dir:String in _repo_status.keys():
		if not repo_dir in repos:
			_repo_status.erase(repo_dir)

	_repo_for_path.clear()


func set_repo(repo_dir:String) -> void:
	if current_repo == repo_dir:
		return
	var previous_repo = current_repo
	current_repo = repo_dir

	# _repo_status deliberately survives the switch: for use with tree
	commits = []
	# a command queued against the old repo must not drain against the new one
	if not _pending_commands.is_empty():
		var dropped:Array = []
		for entry in _pending_commands:
			dropped.append(GitUtil.COMMANDS[entry[0]][GitUtil.Keys.CMD_LABEL])
		push_warning("GitService dropped %d queued command(s) on the switch away from %s: %s" % [
			dropped.size(), previous_repo, ", ".join(dropped)])
	_pending_commands.clear()
	refresh_status()


## The last status for a repo, or {} if the queue has not reached it yet. Never blocks — a miss is
## answered later by status_updated.
func get_repo_status(repo_dir:String) -> Dictionary:
	return _repo_status.get(repo_dir, {})

func is_repo(path:String) -> bool:
	return _repo_status.has(path)

## The repo that owns a path, memoized — the answer only changes with the repo set, which
## refresh_repos() clears this for.
func get_repo_for(file_path:String) -> String:
	if not _repo_for_path.has(file_path):
		_repo_for_path[file_path] = GitUtil.find_repo_for(file_path, repos)
	return _repo_for_path[file_path]


## The status entry for a file, asked of the repo that actually owns it. {} covers clean, unscanned
## and outside-any-repo alike; a caller that needs to tell those apart is asking the wrong question.
func get_file_status(file_path:String) -> Dictionary:
	var repo_dir = get_repo_for(file_path)
	if repo_dir.is_empty():
		return {}
	return get_repo_status(repo_dir).get(GitUtil.Keys.FILES, {}).get(file_path, {})


## Whether git is ignoring a path, asked of the repo that owns it — which is the whole reason this
## reads correctly for a nested clone. The project repo ignores res://addons/, but a plugin with its
## own .git under there answers for itself and says no.
func is_path_ignored(file_path:String) -> bool:
	var repo_dir = get_repo_for(file_path)
	if repo_dir.is_empty():
		return false
	return GitUtil.is_path_ignored(get_repo_status(repo_dir).get(GitUtil.Keys.IGNORED, []), file_path)


## The color a row should take, or null when git has no opinion (clean, or unscanned). Null rather
## than a sentinel Color so it drops into a tree's row builder, which already treats an unset color
## as falsy.
func get_file_color(file_path:String):
	if is_repo(file_path):
		return colors.repo
	# the FILES entry wins over the ignored prefix: a `git add -f`'d file inside an ignored directory
	# is reported by git as a real change, so it reads as one rather than dimming with its parent
	var file_data = get_file_status(file_path)
	if not file_data.is_empty():
		return GitUtil.get_status_color(file_data, colors)
	if is_path_ignored(file_path):
		return colors.ignored
	return null


## The status severity of a path, GitUtil.Severity.NONE when git has no opinion (clean, ignored,
## repo row, unscanned) — the tree only bubbles real changes.
func get_file_severity(file_path:String) -> int:
	var file_data = get_file_status(file_path)
	if file_data.is_empty():
		if is_path_ignored(file_path):
			return GitUtil.Severity.IGNORED
		return GitUtil.Severity.NONE
	return GitUtil.get_status_severity(file_data)


## git's single letter for a path, or "" when there is nothing to say.
func get_file_letter(file_path:String) -> String:
	return GitUtil.get_status_letter(get_file_status(file_path))


## The baked square for that letter, or null. Null while the glyph cache is cold — harmless for a
## _draw consumer, which re-asks every frame and self-heals when the bake lands. Only a caller that
## captures the texture at row-build time needs GlyphIcons.generated.
func get_file_icon(file_path:String) -> Texture2D:
	var letter = get_file_letter(file_path)
	if letter.is_empty():
		return null
	return _get_glyph_icons_node().get_letter(letter)


func get_branch() -> Dictionary:
	return status.get(GitUtil.Keys.BRANCH, {})


func get_branch_oid() -> String:
	return get_branch_oid_for(current_repo)


## HEAD's commit for any repo, not only the selected one. A per-repo consumer needs this to tell a
## real commit from a repaint; get_branch_oid() answers for current_repo no matter which repo it was
## asked about, which is a trap once status_updated fires for all of them.
func get_branch_oid_for(repo_dir:String) -> String:
	return get_repo_status(repo_dir).get(GitUtil.Keys.BRANCH, {}).get(GitUtil.Keys.BRANCH_OID, "")


# Shared status-letter icons, baked once and read by the git panel's Changes list. Owned here as a
# child node — a git resource, kept with the git data provider.
static func get_glyph_icons_node():
	return get_instance()._get_glyph_icons_node()

func _get_glyph_icons_node():
	var glyph_node = get_node_or_null(NodePath(GlyphIcons.NODE_NAME))
	if not is_instance_valid(glyph_node):
		glyph_node = GlyphIcons.new()
		glyph_node.name = GlyphIcons.NODE_NAME
		add_child(glyph_node)
	return glyph_node


## Refreshes current_repo. Runs git off the main thread: a cold repo can take long enough to drop
## frames.
func refresh_status() -> void:
	_enqueue(current_repo)
	_pump()


## Refreshes every repo. The queue drains one at a time on the one worker, so this is 25 spawns
## spread over a second of background time, not a stall.
##
## Also the hook for anything that changes git state behind the editor's back — a commit made in a
## terminal never reaches filesystem_changed, so nothing else will notice it.
func refresh_all() -> void:
	# a repo cloned or deleted behind the editor's back is the same class of event as a commit, and
	# nothing else picks it up
	refresh_repos()
	for repo_dir:String in repos:
		_enqueue(repo_dir)
	_pump()


## Queues a write for the worker thread, which then re-reads the repo in the same pass. Not run
## inline: a status that read the repo before an interleaved write would land after it and repaint
## stale rows, with nothing scheduled to correct them.
func run_command(command:GitUtil.Command, paths:Array) -> void:
	if paths.is_empty():
		return

	# resolved against the status in hand, not on the worker: by the time the thread runs, `status`
	# may already be the *next* repo's
	var expanded = GitUtil.expand_paths(command, paths, status.get(GitUtil.Keys.FILES, {}))
	_pending_commands.append([command, expanded])
	_pump()


func _enqueue(repo_dir:String) -> void:
	if repo_dir.is_empty() or repo_dir in _queue:
		return
	_queue.append(repo_dir)


## current_repo goes first whenever it has anything to do: it is the repo a panel is pointed at, and
## the only one that pays for diffs and a log. Pending commands make that mandatory rather than
## merely polite — they resolve against its paths and nothing else can carry them.
func _next_repo() -> String:
	if not _pending_commands.is_empty() or current_repo in _queue:
		return current_repo
	return _queue[0] if not _queue.is_empty() else ""


func _pump() -> void:
	if is_instance_valid(_thread) and _thread.is_alive():
		# one repo at a time, and the tail of _on_status_ready pumps again — so the queue drains
		# without ever holding two threads or needing a lock over _repo_status
		return

	_join_thread()

	var repo_dir = _next_repo()
	if repo_dir.is_empty():
		return
	_queue.erase(repo_dir)

	# a queued command can only travel with the repo its paths were resolved against
	var full = repo_dir == current_repo
	var queued:Array = []
	if full:
		queued = _pending_commands
		_pending_commands = []

	_thread = Thread.new()
	_thread.start(_status_task.bind(repo_dir, queued, _is_initial(), full))


func _status_task(repo_dir:String, queued:Array, initial:bool, full:bool) -> void:
	# the writes go first and the read that follows is therefore never stale with respect to them
	var errors:Array = []
	var wrote_worktree = false

	for entry in queued:
		var command:GitUtil.Command = entry[0]
		if log_commands and GitUtil.COMMANDS[command][GitUtil.Keys.CMD_DESTRUCTIVE]:
			# the argv git actually receives, not the paths that were asked for — the gap between the
			# two is the only place a "that discarded the wrong thing" report can be settled
			print("[GitService] %s: git %s" % [repo_dir,
				" ".join(GitUtil.build_command_args(command, repo_dir, entry[1], initial))])
 
		var result = GitUtil.run_command(repo_dir, command, entry[1], initial)

		if result[GitUtil.Keys.EXIT] != 0:
			errors.append("git %s failed (%s): %s" % [
				GitUtil.COMMANDS[command][GitUtil.Keys.CMD_LABEL],
				result[GitUtil.Keys.EXIT],
				"\n".join(result[GitUtil.Keys.OUTPUT]).strip_edges(),
			])
		elif GitUtil.COMMANDS[command][GitUtil.Keys.CMD_WORKTREE]:
			wrote_worktree = true

	# every git call shares the one thread, so the coalescing and stale-repo guard cover them for free
	var status_result = GitUtil.get_status(repo_dir)
	var log_result:Array = []

	# a light pass is that one spawn; the diffs and the log are three more, and only the repo a panel
	# is pointed at needs them. Across 25 nested repos that is 28 spawns instead of 100.
	if full:
		# merged in on the worker thread, so the handoff keeps its shape and a row click costs no git
		GitUtil.attach_diffs(repo_dir, status_result)
		log_result = GitUtil.get_log(repo_dir)
	
	_on_status_ready.call_deferred(repo_dir, status_result, log_result, errors, wrote_worktree, full)


func _on_status_ready(repo_dir:String, status_result:Dictionary, log_result:Array, errors:Array,
		wrote_worktree:bool, full:bool) -> void:
	_join_thread()

	# a failed command otherwise looks exactly like one that worked, because the list simply repaints
	# the rows it already had
	for error:String in errors:
		push_error(error)

	# a repo dropped by refresh_repos() is the only genuinely dead result. A repo switch no longer
	# makes one stale: this repo's status is no less true for the panel having looked away, and the
	# tree is still showing it.
	if repo_dir in repos:
		_repo_status[repo_dir] = status_result
		status_updated.emit(repo_dir)
	
		# the log is the one half a mid flight switch really does strip, since only the panel reads it
		# and it only ever means current_repo
		if full and repo_dir == current_repo:
			commits.assign(log_result)
			commits_updated.emit(repo_dir)
	 
	# discard and delete rewrite files behind the editor's back and nothing else will tell it: a script
	# still open on the old contents would write them straight back on the next save
	if wrote_worktree:
		# like grabbing focus from none, one of the most thorough scans.
		EditorInterface.get_script_editor().notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	_pump()

	# _pump() leaves _thread null only when it found nothing left to start, so that is the drain test
	if not is_instance_valid(_thread):
		refresh_finished.emit()


func _join_thread() -> void:
	if not is_instance_valid(_thread):
		return
	_thread.wait_to_finish()
	_thread = null

# Whether the repo has no commits yet, which changes how a file is unstaged — see GitUtil.
func _is_initial() -> bool:
	return get_branch().get(GitUtil.Keys.BRANCH_INITIAL, false)

func _on_filesystem_changed() -> void:
	_debounce_timer.start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_debounce_timer.start()

class GitColors:
	var conflicted:Color = GitUtil.Colors.RED
	var staged:Color = GitUtil.Colors.GREEN
	var modified:Color = GitUtil.Colors.L_YELLOW
	var untracked:Color = GitUtil.Colors.L_GREEN
	var ignored:Color = GitUtil.Colors.DIM
	var repo:Color = GitUtil.Colors.REPO
	
	
	func connect_settings(setting_helper:SettingHelper):
		setting_helper.subscribe_property(self, &"conflicted", EditorSet.CONFLICTED, GitUtil.Colors.RED)
		setting_helper.subscribe_property(self, &"staged", EditorSet.STAGED, GitUtil.Colors.GREEN)
		setting_helper.subscribe_property(self, &"modified", EditorSet.MODIFIED, GitUtil.Colors.L_YELLOW)
		setting_helper.subscribe_property(self, &"untracked", EditorSet.UNTRACKED, GitUtil.Colors.L_GREEN)
		setting_helper.subscribe_property(self, &"ignored", EditorSet.IGNORED, GitUtil.Colors.DIM)
		setting_helper.subscribe_property(self, &"repo", EditorSet.REPO, GitUtil.Colors.REPO)
	

class EditorSet:
	const CONFLICTED = &"plugin/git_view/color/conflicted"
	const STAGED = &"plugin/git_view/color/staged"
	const MODIFIED = &"plugin/git_view/color/modified"
	const UNTRACKED = &"plugin/git_view/color/untracked"
	const IGNORED = &"plugin/git_view/color/ignored"
	const REPO = &"plugin/git_view/color/repo"

	const LOG_COMMANDS = &"plugin/git_view/log_destructive_commands"
