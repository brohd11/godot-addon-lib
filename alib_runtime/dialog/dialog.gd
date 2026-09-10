#! namespace ALibRuntime class Dialog



static func confirm(message_text:String, dialog_parent=null) -> bool:
	return await Handlers.Confirmation.confirm(message_text, dialog_parent)

static func acknowledge(message_text:String, dialog_parent=null):
	return await Handlers.Confirmation.acknowledge(message_text, dialog_parent)


class Handlers:
	const Confirmation = preload("uid://b4rwv7tgks0b5") # confirmation.gd
	const File = preload("uid://d1hn4ujniin7r") # file.gd
	const General = preload("uid://bnbqhxa04g4r5") # general_dialog.gd
	const LineSubmit = preload("uid://dmilkaqawd510") # line_submit.gd
