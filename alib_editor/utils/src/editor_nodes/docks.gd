#! namespace ALibEditor.Nodes class Docks

const UVersion = preload("uid://dn156lc18d1vt") #! resolve UtilR.UVersion

static func get_current_dock(control):
	var version = UVersion.get_minor_version()
	if version < 6:
		return _get_current_dock_44(control)
	else: #elif version <= 7:
		return _get_current_dock_46(control)

static func _get_current_dock_44(control):
	var parent = control.get_parent()
	if not parent:
		#print("Parent is null. Get dock.")
		return
	var docks = get_all_docks()
	if parent in docks:
		var dock_slot = parent.name.get_slice("DockSlot", 1)
		match dock_slot:
			"LeftUL": return EditorPlugin.DockSlot.DOCK_SLOT_LEFT_UL
			"LeftBL": return EditorPlugin.DockSlot.DOCK_SLOT_LEFT_BL
			"LeftUR": return EditorPlugin.DockSlot.DOCK_SLOT_LEFT_UR
			"LeftBR": return EditorPlugin.DockSlot.DOCK_SLOT_LEFT_BR
			"RightUL": return EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_UL
			"RightBL": return EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_BL
			"RightUR": return EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_UR
			"RightBR": return EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_BR
	
	elif parent == EditorInterface.get_editor_main_screen():
		return -1
	elif parent == EditorNodeRef.get_registered(EditorNodeRef.Nodes.BOTTOM_PANEL):
		return -2
	else:
		return -3

static func _get_current_dock_46(control):
	var parent = control.get_parent()
	if not parent:
		#print("Parent is null. Get dock.")
		return
	if parent == EditorInterface.get_editor_main_screen():
		return -1
	var dock_container = parent.get_parent()
	var docks = get_all_docks()
	if dock_container in docks:
		var dock_slot = dock_container.name.get_slice("DockSlot", 1)
		match dock_slot:
			"LeftUL": return EditorPlugin.DockSlot.DOCK_SLOT_LEFT_UL
			"LeftBL": return EditorPlugin.DockSlot.DOCK_SLOT_LEFT_BL
			"LeftUR": return EditorPlugin.DockSlot.DOCK_SLOT_LEFT_UR
			"LeftBR": return EditorPlugin.DockSlot.DOCK_SLOT_LEFT_BR
			"RightUL": return EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_UL
			"RightBL": return EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_BL
			"RightUR": return EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_UR
			"RightBR": return EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_BR
	elif dock_container == EditorNodeRef.get_registered(EditorNodeRef.Nodes.BOTTOM_PANEL):
		return -2
	else:
		return -3


static func get_current_dock_control(control):
	var version = UVersion.get_minor_version()
	if version < 6:
		return _get_current_dock_control_44(control)
	else: #elif version <= 7:
		return _get_current_dock_control_46(control)

static func _get_current_dock_control_44(control):
	var parent = control.get_parent()
	if not parent:
		#print("Parent is null. Get control.")
		return
	if parent is TabContainer:
		return parent
	elif parent == EditorNodeRef.get_registered(EditorNodeRef.Nodes.BOTTOM_PANEL):
		return parent
	elif parent == EditorInterface.get_editor_main_screen():
		return parent

static func _get_current_dock_control_46(control):
	var parent = control.get_parent()
	if not parent:
		#print("Parent is null. Get control.")
		return
	if parent.get_class() == "EditorDock":
		return parent.get_parent()
	elif parent == EditorInterface.get_editor_main_screen():
		return parent




static func get_dock_control_by_id(id:int):
	if id == -3:
		return
	elif id == -2:
		return EditorNodeRef.get_registered(EditorNodeRef.Nodes.BOTTOM_PANEL)
	elif id == -1:
		return EditorInterface.get_editor_main_screen()
	else:
		var docks = EditorNodeRef.get_registered(EditorNodeRef.Nodes.DOCKS)
		var target_dock
		match id:
			0: target_dock = "LeftUL"
			1: target_dock = "LeftBL"
			2: target_dock = "LeftUR"
			3: target_dock = "LeftBR"
			4: target_dock = "RightUL"
			5: target_dock = "RightBL"
			6: target_dock = "RightUR"
			7: target_dock = "RightBR"
		for dock in docks:
			if dock.name.ends_with(target_dock):
				return dock


static func get_all_docks() -> Array:
	return EditorNodeRef.get_registered(EditorNodeRef.Nodes.DOCKS)
