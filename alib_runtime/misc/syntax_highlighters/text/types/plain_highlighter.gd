extends "res://addons/_lib/brohd/alib_runtime/misc/syntax_highlighters/text/hl_base.gd"

## txt - no grammar. Everything renders in the editor's default text color.
##
## Exists so the dispatcher can hand back a real object for plain text, keeping the entry
## point free of file type branching.

func _tokenize(_line:int, _entry_state:int, _map:Dictionary) -> int:
	return STATE_NORMAL
