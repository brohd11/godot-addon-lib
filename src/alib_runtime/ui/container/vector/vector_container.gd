#! namespace ALibRuntime.UICustom class VectorContainer
extends PanelContainer

const LineSlider = preload("uid://dgkq7atn21a7j") # line_slider.gd

enum Mode{
	ROTATION,
	POSITION,
	SCALE,
	DIRECTION,
	CUSTOM
}

static func vector3(_mode:Mode=Mode.CUSTOM, vertical:=false) -> Vector3Container:
	var container = Vector3Container.new()
	container.vertical = vertical
	container.mode = _mode
	return container

class Vector3Container extends PanelContainer:
	
	var vertical:=false
	var mode:Mode = Mode.ROTATION
	var axes_container:BoxContainer
	var x = LineSlider.new()
	var y = LineSlider.new()
	var z = LineSlider.new()
	
	

	var panel_sb:StyleBoxFlat

	var link_button:Button
	var linked_icon:Texture2D
	var unlinked_icon:Texture2D
	var _link_toggled:= false

	signal value_changed(new_value)

	func _ready() -> void:
		var colors = Data.get_colors()
		var x_axis_color = colors.x
		var y_axis_color = colors.y
		var z_axis_color = colors.z
		
		var ed_interface = Engine.get_singleton(&"EditorInterface")
		if is_instance_valid(ed_interface):
			var thm = ed_interface.get_editor_theme()
			panel_sb = thm.get_stylebox("panel", "Panel")
			if not is_instance_valid(linked_icon):
				linked_icon = thm.get_icon("Instance", "EditorIcons")
			if not is_instance_valid(unlinked_icon):
				unlinked_icon = thm.get_icon("Unlinked", "EditorIcons")
		else:
			if not is_instance_valid(panel_sb):
				panel_sb = StyleBoxFlat.new()
		
		add_theme_stylebox_override("panel", panel_sb)
		if vertical:
			axes_container = VBoxContainer.new()
		else:
			axes_container = HBoxContainer.new()
		add_child(axes_container)
		#axes_hbox.add_theme_constant_override("separation", 0)
		#axes_hbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		axes_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var axes = ["x","y","z"]
		for i in range(axes.size()):
			var _name = axes[i]
			
			var spin = get(_name) as LineSlider
			
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			spin.value_changed.connect(_on_value_changed)
			var is_editor_spin = spin is not LineSlider
			if is_editor_spin:
				spin.flat = true
			else:
				spin.prefix = _name
				match _name:
					"x": spin.prefix_color =  x_axis_color
					"y": spin.prefix_color =  y_axis_color
					"z": spin.prefix_color =  z_axis_color
			
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.step = 0.1
			match mode:
				Mode.ROTATION:
					spin.step = 0.1
					spin.suffix = "°"
					spin.min_value = -360
					spin.max_value = 360
					spin.allow_greater = false
					spin.allow_lesser = false
				Mode.POSITION:
					spin.show_slider = false
					spin.step = 0.1
					spin.suffix = "m"
					spin.min_value = -100
					spin.max_value = 100
					if is_editor_spin:
						spin.control_state = EditorSpinSlider.CONTROL_STATE_HIDE
				Mode.SCALE:
					spin.show_slider = false
					spin.step = 0.05
					spin.allow_lesser = false
					spin.min_value = 0.05
					spin.max_value = 10
					
					if is_editor_spin:
						spin.control_state = EditorSpinSlider.CONTROL_STATE_HIDE
				Mode.DIRECTION:
					spin.show_slider = false
					spin.step = 0.01
					spin.min_value = -1
					spin.max_value = 1
					spin.allow_greater = false
					spin.allow_lesser = false
					
					if is_editor_spin:
						spin.control_state = EditorSpinSlider.CONTROL_STATE_HIDE
				_:pass
			
			axes_container.add_child(spin)
			if not vertical and i < 2:
				var spacer = Control.new()
				axes_container.add_child(spacer)
				spacer.custom_minimum_size.x = 4
		
		
		match mode:
			Mode.ROTATION:
				set_value_no_signal(Vector3.ZERO)
			Mode.POSITION:
				set_value_no_signal(Vector3.ZERO)
			Mode.SCALE:
				set_value_no_signal(Vector3(1,1,1))
				link_button = Button.new()
				_link_toggled = true
				link_button.flat = true
				_set_link_icon()
				link_button.pressed.connect(_on_link_toggled)
				axes_container.add_child(link_button)
				
		
		
		

	func _on_value_changed(_new_value:float):
		if mode == Mode.SCALE:
			if _link_toggled:
				set_value_no_signal(Vector3(_new_value, _new_value, _new_value))
		
		value_changed.emit(get_value())

	func set_value_no_signal(_vector3:Vector3):
		x.set_value_no_signal(_vector3.x)
		y.set_value_no_signal(_vector3.y)
		z.set_value_no_signal(_vector3.z)
	
	func set_value(_vector3:Vector3):
		set_value_no_signal(_vector3)
		value_changed.emit(get_value())

	func get_value():
		return Vector3(x.value, y.value, z.value)

	func _on_link_toggled():
		_link_toggled = not _link_toggled
		_set_link_icon()
		if _link_toggled:
			_on_value_changed(x.value)

	func _set_link_icon():
		link_button.icon = linked_icon if _link_toggled else unlinked_icon
	
	func get_sliders() -> Array[LineSlider]:
		return [x, y, z]


class Data:
	static func get_colors():
		var colors = {}
		var ed_interface = Engine.get_singleton(&"EditorInterface")
		if is_instance_valid(ed_interface):
			var thm = ed_interface.get_editor_theme()
			colors["x"] = thm.get_color("axis_x_color", "Editor")
			colors["y"] = thm.get_color("axis_y_color", "Editor")
			colors["z"] = thm.get_color("axis_z_color", "Editor")
		else:
			colors["x"] = Color(0.788, 0.18, 0.278)
			colors["y"] = Color(0.478, 0.749, 0.02)
			colors["z"] = Color(0.118, 0.208, 0.302)
		return colors
