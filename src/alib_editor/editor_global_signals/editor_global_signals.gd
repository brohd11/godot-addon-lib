class_name EditorGlobalSignals

const LineEditList = preload("uid://bipuqam2kunfj") #! resolve ALibRuntime.UICustom.LineEditList

const GeneralDialog = preload("uid://be87r73w16wa5") #! resolve Dialogs.Base.General
const EditorIcons = preload("uid://viocyrti6wce") #! resolve UIPlugin.EditorIcons
const PopupPlacer = preload("uid://cs6pl78crcr0g") #! resolve UtilR.Nodes.PopupMenus.Placer
const SignalBus = preload("uid://dlqk1ia5qfcgg") #! resolve SignalBusSingleton.SignalBus

const BUS_NAME = &"EditorGlobalSignals"

static func get_signal_bus() -> SignalBus:
	return SignalBusSingleton.get_bus(BUS_NAME)

static func subscribe(signal_name:StringName, callable:Callable):
	SignalBusSingleton.subscribe(BUS_NAME, signal_name, callable)

static func unsubscribe(signal_name:StringName, callable:Callable):
	SignalBusSingleton.unsubscribe(BUS_NAME, signal_name, callable)

static func signal_emit(signal_name:StringName, data:Dictionary={}):
	SignalBusSingleton.signal_emit(BUS_NAME, signal_name, data)

static func signal_emitv(signal_name:StringName, arg_array:Array=[]):
	SignalBusSingleton.signal_emitv(BUS_NAME, signal_name, arg_array)


static func pick_signals_dialog(signals_to_display:PackedStringArray=[], valid_signals:PackedStringArray=[]):
	var dialog = GeneralDialog.new()
	dialog.set_title("Editor Signals")
	dialog.default_size = Vector2(500, 300)
	
	var right_click_handler = PopupPlacer.new()
	dialog.add_content(right_click_handler, GeneralDialog.TargetSection.ROOT)
	
	var file_list = LineEditList.new()
	file_list.set_background(EditorInterface.get_editor_theme().get_stylebox("panel", "ItemList"))
	file_list.set_title("Editor Signals")
	
	var signals_button = Button.new()
	signals_button.icon = EditorIcons.get_icon_white("Signal")
	var signal_callable = func():
		var options = PopupPlacer.Options.new()
		for signal_name in EditorGlobalSignals.get_signal_bus().get_signal_names():
			if valid_signals.is_empty() or signal_name in valid_signals:
				options.add_option(signal_name, file_list.new_entry.bind(signal_name))
		right_click_handler.display_on_control(options, signals_button)
	
	signals_button.pressed.connect(signal_callable)
	file_list.title_hbox.add_child(signals_button)
	
	file_list.set_button_flat()
	file_list.show_add_entry_button()
	file_list.set_entries(signals_to_display)
	
	dialog.add_content(file_list)
	
	var resp = await dialog.get_response()
	if resp.cancelled:
		return
	
	var entries = file_list.get_entries()
	return entries
