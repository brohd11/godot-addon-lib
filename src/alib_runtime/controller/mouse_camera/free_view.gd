extends Node3D

## Camera controller, similar to Godot 3D Viewport
## Use a control overlay over the viewport to forward mouse imput to controller.
## mouse_detector.gui_input.connect(controller.mouse_input)

var main_root_node:Node3D
var camera:Camera3D

var cam_dot:float

var cam_zoom_close_limit:float = 0.2
var cam_zoom_far_limit:float = 100000
var cam_dist:float

var mouse_zoom_sens: float = 5 # 0.1
var mouse_zoom_sens_trim:float = 0.02
var mouse_basis_vec_mul:float = 0.05
var mouse_pan_sens:float = 5 # 0.025
var mouse_pan_sens_trim:float = 0.0075
var mouse_rot_sens:float = 5 # 0.1
var mouse_rot_sens_trim:float = 0.02

var target_pos:= Vector3.ZERO
var last_reset_view_pos:= Vector3.ZERO
var last_reset_cam_distance:float = 10
var reset_view_flag:bool = false

var viewport_size_mul = 1

# behaviour
var allow_pan:bool = true
var allow_orbit:bool = true
var allow_zoom:bool = true


func _ready() -> void:
	main_root_node = get_parent()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()


func load_settings():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#mouse_pan_sens = HelperInst.ABConfig.mouse_pan_sens
	#mouse_rot_sens = HelperInst.ABConfig.mouse_rot_sens
	#mouse_zoom_sens = HelperInst.ABConfig.mouse_zoom_sens
	#camera.fov = HelperInst.ABConfig.camera_fov

func _on_settings_changed():
	load_settings()

func _on_viewport_size_changed():
	var view = get_viewport()
	if view:
		viewport_size_mul = get_window().size.x / view.size.x # on view port size changed??
		viewport_size_mul = clampf(viewport_size_mul, 1, 10)


func _process(delta: float) -> void:
	position = lerp(position, target_pos, 0.75)


func mouse_input(event: InputEvent) -> void:
	cam_dist = abs(camera.position.z)
	
	if allow_zoom and event is InputEventMouseButton:
		if event.button_index == 4:
			camera.position.z -= 1 * mouse_zoom_sens * mouse_zoom_sens_trim * cam_dist
		elif event.button_index == 5:
			camera.position.z += 1 * mouse_zoom_sens * mouse_zoom_sens_trim *  cam_dist
		camera.position.z = clampf(camera.position.z, cam_zoom_close_limit, cam_zoom_far_limit)
	
	
	var cam_basis:Basis = camera.global_transform.basis
	var right_vec = cam_basis.x.normalized()
	var up_vec = cam_basis.y.normalized()
	
	var screen_rel_norm = Vector2(1,1)
	
	if event is InputEventMouseMotion:
		screen_rel_norm = event.screen_relative * mouse_basis_vec_mul
		if event.button_mask == 4:
			if allow_pan and Input.is_key_pressed(KEY_SHIFT):
				target_pos -= right_vec * screen_rel_norm.x * mouse_pan_sens * mouse_pan_sens_trim * cam_dist
				target_pos += up_vec * screen_rel_norm.y * mouse_pan_sens * mouse_pan_sens_trim * cam_dist
			elif allow_zoom and Input.is_key_pressed(KEY_CTRL):
				camera.position.z += screen_rel_norm.y * mouse_zoom_sens * mouse_zoom_sens_trim *  cam_dist
			elif allow_orbit:
				var main_root_basis = main_root_node.global_transform.basis
				cam_dot = main_root_basis.z.dot(cam_basis.z)
				rotation_degrees.x -= event.screen_relative.y * mouse_rot_sens * mouse_rot_sens_trim * viewport_size_mul
				rotation_degrees.y -= event.screen_relative.x * mouse_rot_sens * mouse_rot_sens_trim * viewport_size_mul
				
				rotation_degrees.x = clampf(rotation_degrees.x, -90, 90)


func camera_reset():
	if target_pos != Vector3.ZERO:
		last_reset_view_pos = position
		last_reset_cam_distance = camera.position.z # not really working
		target_pos = Vector3.ZERO
		camera.position.z = 10
	else:
		target_pos = last_reset_view_pos
		camera.position.z = last_reset_cam_distance
