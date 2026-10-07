extends Control

const ClickState = preload("uid://c8l2o7cw3fklh") #! resolve UtilR.Inputs.ClickState

enum EventType{
	NONE,
	LMB_PRESSED,
	LMB_RELEASED,
	LMB_PRESSED_CTRL,
	LMB_RELEASED_CTRL,
	RMB_PRESSED,
	RMB_RELEASED,
	RMB_PRESSED_CTRL,
	RMB_RELEASED_CTRL,
	WHEEL_UP_CTRL,
	WHEEL_DOWN_CTRL,
	CUSTOM,
	DISABLE_TOOL,
	DISCARD,
}

const CALLABLE_KEY_INPUT = &"handle_key_input"
const CALLABLE_MOUSE_BUTTON = &"handle_mouse_button_input"
const CALLABLE_MOUSE_WHEEL = &"handle_mouse_wheel_input"

var enabled:=false
var _mouse_in_control:=false

signal handled_event(event_type, input_event)

func _ready() -> void:
	#gui_input.connect(_on_gui_input)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_force_pass_scroll_events = false
	mouse_entered.connect(func():_mouse_in_control=true)
	mouse_exited.connect(func():_mouse_in_control=false)

func _get_viewport_manager():
	return

func _get_current_tool():
	return

func set_enabled(state:bool):
	enabled = state
	if enabled:
		mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func _gui_input(event:InputEvent): # this was _on_gui_input connected above, should be able to just overide it
	if not (enabled and _mouse_in_control):
		return
	var filtered_event = _check_event(CALLABLE_MOUSE_BUTTON, event)
	if filtered_event == EventType.NONE:
		return
	
	handled_event.emit(filtered_event, event)
	accept_event()

func _input(event: InputEvent) -> void:
	if not (enabled and _mouse_in_control):
		return
	var filtered_event = _check_event(CALLABLE_KEY_INPUT, event)
	if filtered_event == EventType.NONE:
		filtered_event = _check_event(CALLABLE_MOUSE_WHEEL, event)
		if filtered_event == EventType.NONE:
			return
	
	handled_event.emit(filtered_event, event)
	get_viewport().set_input_as_handled()

func _check_event(callable:StringName, event):
	var current_tool = _get_current_tool()
	if is_instance_valid(current_tool):
		if current_tool.has_method(callable):
			return current_tool.call(callable, event)
	
	if callable == CALLABLE_KEY_INPUT:
		return DefaultHandle.handle_key_input(event)
	elif callable == CALLABLE_MOUSE_BUTTON:
		return DefaultHandle.handle_mouse_button_input(event)
	elif callable == CALLABLE_MOUSE_WHEEL:
		return DefaultHandle.handle_mouse_wheel_input(event)
	return EventType.NONE


class DefaultHandle:
	static func handle_mouse_button_input(event:InputEvent):
		if not event is InputEventMouseButton:
			return EventType.NONE
		
		var click_state = ClickState.get_click_state(event) as ClickState.State
		var modifier = ClickState.get_click_modifier(event) as ClickState.Modifier
		if click_state == ClickState.State.LMB_PRESSED:
			if modifier == ClickState.Modifier.CTRL:
				return EventType.LMB_PRESSED_CTRL
			return EventType.LMB_PRESSED
		elif click_state == ClickState.State.LMB_RELEASED:
			if modifier == ClickState.Modifier.CTRL:
				return EventType.LMB_RELEASED_CTRL
			return EventType.LMB_RELEASED
		elif click_state == ClickState.State.LMB_DOUBLE_CLICK:
			return EventType.DISCARD
		
		
		return EventType.NONE
	
	static func handle_key_input(event:InputEvent):
		if not event is InputEventKey or not event.is_pressed():
			return EventType.NONE
		
		if event.keycode == KEY_ESCAPE:
			return EventType.DISABLE_TOOL
		return EventType.NONE

	static func handle_mouse_wheel_input(event:InputEvent) -> EventType:
		if not event is InputEventMouseButton:
			return EventType.NONE
		
		var click_state = ClickState.get_click_state(event) as ClickState.State
		var modifier = ClickState.get_click_modifier(event) as ClickState.Modifier
		if click_state == ClickState.State.WHEEL_UP:
			if modifier == ClickState.Modifier.CTRL:
				return EventType.WHEEL_UP_CTRL
			
		elif click_state == ClickState.State.WHEEL_DOWN:
			if modifier == ClickState.Modifier.CTRL:
				return EventType.WHEEL_DOWN_CTRL
		
		return EventType.NONE
