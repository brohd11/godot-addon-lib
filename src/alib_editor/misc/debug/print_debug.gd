#! namespace ALibEditor class PrintDebug

static func print(msg:Array):
	print("::".join(msg))

static func print_err(msg:Array):
	printerr("::".join(msg))
