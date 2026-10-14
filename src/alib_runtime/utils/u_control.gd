#! namespace ALibRuntime.Utils class UControl

static func expand(control:Control, vertical:=true, horizontal:=true):
	if vertical:
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if horizontal:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
