
const RightClickHandler = preload("uid://mmtkf4h8er3m") #! resolve ClickHandlers.RightClickHandler
const Options = RightClickHandler.Options

const EditorIcons = preload("uid://viocyrti6wce") #! resolve ALibEditor.Singleton.EditorIcons

const Dialog = preload("uid://bccd38qwc47vu") #! resolve ALibRuntime.Dialog
const LineSubmit = Dialog.Handlers.LineSubmit

const UEditorTheme = preload("uid://q4pcebn4vhsr") #! resolve ALibEditor.Utils.UEditorTheme
const ThemeColor = UEditorTheme.ThemeColor
const FileSystem = preload("uid://dagr353kjvdrc") #! resolve ALibEditor.Nodes.FileSystem
const PopupID = preload("uid://co1fsmkihc4cg") #! resolve ALibEditor.Nodes.FileSystem.PopupID

const UVersion = preload("uid://b4f7kxqukmbj2") #! resolve ALibRuntime.Utils.UVersion
const UFile = preload("uid://bl33psa06nv1e") #! resolve ALibRuntime.Utils.UFile.Methods
const GetFilesAsync = preload("uid://ctsugodrtg3rc") #! resolve ALibRuntime.Utils.UFile.GetFilesAsync
const UResourceMethods = preload("uid://brjrqxh2smivn") #! resolve ALibRuntime.Utils.UResource.Methods
const UGDScript = preload("uid://bqwb564jwff43") #! resolve ALibRuntime.Utils.UGDScript
const UOs = preload("uid://cnuejrhrodgbx") #! resolve ALibRuntime.Utils.UOs
const UTree = preload("uid://byxrrav3r3afw") #! resolve ALibRuntime.Utils.UTree
const UString = preload("uid://bbk1yedqm7a6a") #! resolve ALibRuntime.Utils.UString.Methods
const UStringFilter = preload("uid://b1j5snv8mpgob") #! resolve ALibRuntime.Utils.UString.Filter
const UWindow = preload("uid://q2lbynew21er") #! resolve ALibRuntime.Utils.UWindow
const UControl = preload("uid://brio73mirr5e6") #! resolve ALibRuntime.Utils.UControl

const NUItemList = preload("uid://cjls86v1v4242") #! resolve ALibRuntime.NodeUtils.NUItemList
const NUTree = preload("uid://coqq638olix8k") #! resolve ALibRuntime.NodeUtils.NUTree

const SettingHelperEditor = preload("uid://c4l4v4eufkmtx") #! resolve ALibEditor.Settings.SettingHelperEditor
const SettingHelperSingleton = preload("uid://b6jyhs240r0hm") #! resolve ALibRuntime.Settings.SettingHelperSingleton
const SettingHelperJson = SettingHelperSingleton.SettingHelperJson

const ColumnDragger = preload("res://addons/addon_lib/brohd/alib_runtime/ui/column/dragger.gd")

const CacheHelper = preload("res://addons/addon_lib/brohd/alib_runtime/cache_helper/cache_helper.gd")


#^ THESE ARE MOVED TO SINGLETON
static func is_path_valid_res(path:String) -> bool:
	if not path.begins_with("res://"):
		return false
	return FileSystemSingleton.is_path_valid(path)

static func is_root_folder(path:String):
	if path.ends_with("://") or path == "/":
		return true
	return false

static func paths_have_same_root(path:String, path_2:String):
	if path.begins_with("res://"):
		if path_2.begins_with("res://"):
			return true
		return false
	elif path.begins_with("user://"):
		if path_2.begins_with("user://"):
			return true
		return false
	elif path.begins_with("/"):
		if path_2.begins_with("/"):
			return true
		return false

#^ THESE ARE MOVED TO SINGLETON
