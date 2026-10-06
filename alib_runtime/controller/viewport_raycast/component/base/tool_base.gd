extends RefCounted

const Intercept = preload("res://addons/_lib/brohd/alib_runtime/controller/viewport_raycast/component/base/intercept_base.gd")
const EventType = Intercept.EventType


func intercept_handled_event(_event_type:EventType, _event:InputEvent, _viewport:Viewport):
	pass


func handle_key_input(event:InputEvent) -> EventType:
	return Intercept.DefaultHandle.handle_key_input(event)

func handle_mouse_wheel_input(event:InputEvent) -> EventType:
	return Intercept.DefaultHandle.handle_mouse_wheel_input(event)

func handle_mouse_button_input(event:InputEvent) -> EventType:
	return Intercept.DefaultHandle.handle_mouse_button_input(event)
