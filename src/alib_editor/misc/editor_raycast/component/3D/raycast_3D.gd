
enum RaycastMode{
	FREE,
	PLANE,
	TERRAIN_3D,
}

const _VALID_VISUAL_INSTANCES = ["MeshInstance3D","MultiMeshInstance3D", "Decal", "CSGShape3D", "Label3D", "SpriteBase3D"]

const POSITION = &"position"
const NORMAL = &"normal"
const TRANSFORM = &"transform"

var terrain_3D
var plane:=Plane(Vector3.UP, 0.0)
var raycast_distance:float = 2000
var settings:Dictionary

func on_settings_changed():
	raycast_distance = get_setting(Settings.RAYCAST_DISTANCE, 2000)
	var plane_orientation = get_setting(Settings.PLANE_DIRECTION, Vector3.UP) as Vector3
	plane_orientation = plane_orientation.normalized()
	plane.x = plane_orientation.x
	plane.y = plane_orientation.y
	plane.z = plane_orientation.z
	var plane_offset = get_setting(Settings.PLANE_OFFSET, 0)
	plane.d = plane_offset


func get_raycast_collision(viewport: Viewport) -> Variant:
	var raycast_mode = settings.get(Settings.RAYCAST_MODE, 0)
	var terrain_3D_allow_all_col = settings.get(Settings.TERRAIN_USE_ALL_COL, false)
	
	if raycast_mode == RaycastMode.FREE or (raycast_mode == RaycastMode.TERRAIN_3D and terrain_3D_allow_all_col):
		var collision_data := ALibRuntime.NodeUtils.NUViewport.Raycast.raycast(viewport, raycast_distance)
		if not collision_data.is_empty():
			return collision_data
	elif raycast_mode == RaycastMode.PLANE:
		var raycast_position:Variant = ALibRuntime.NodeUtils.NUViewport.Raycast.raycast_plane(viewport, plane, raycast_distance)
		if raycast_position != null:
			raycast_position = raycast_position as Vector3
			var normal = plane.normal
			if viewport.get_camera_3d().position.direction_to(raycast_position).dot(plane.normal) > 0:
				normal = -plane.normal
			return {
				POSITION: raycast_position,
				NORMAL: normal,
			}
	if raycast_mode == RaycastMode.TERRAIN_3D: #^ must be "if" so if allow all col fails it can come here
		if not is_instance_valid(terrain_3D):
			return 
		if not terrain_3D.owner == EditorInterface.get_edited_scene_root():
			return
		var terrain_raycast_position := ALibRuntime.NodeUtils.NUViewport.Raycast.raycast_terrain_3d(viewport, terrain_3D)
		if terrain_raycast_position.z > 3.4e38 or is_nan(terrain_raycast_position.y):
			return
		var normal = terrain_3D.data.get_normal(terrain_raycast_position)
		if is_nan(normal.y):
			return 
		return {
				POSITION: terrain_raycast_position,
				NORMAL: normal,
			}
	return null





func get_visual_instances(viewport:Viewport, cursor_node:Node, ignore_nodes:=[]) -> Node:
	var camera = viewport.get_camera_3d()
	var visual_instances = ALibRuntime.NodeUtils.NUViewport.Raycast.raycast_visual_instances(viewport, raycast_distance)
	if visual_instances.is_empty():
		return null
	
	var closest_node: Node = null
	var closest_distance_sq: float = raycast_distance * raycast_distance
	var camera_pos: Vector3 = camera.global_position
	
	for id: int in visual_instances:
		var instance: Node3D = instance_from_id(id)
		
		var is_valid_type := false
		var ins_class := instance.get_class()
		for type in _VALID_VISUAL_INSTANCES:
			if ClassDB.is_parent_class(ins_class, type):
				is_valid_type = true
				break
		if not is_valid_type:
			continue

		# 2. Determine the "Target Node" (Is it the owner? Or the instance itself?)
		var target: Node = instance.owner
		if not is_instance_valid(target) or target == cursor_node:
			if not instance.scene_file_path.is_empty():
				target = instance
			else:
				continue # Neither owner nor instance are valid targets

		if target == cursor_node or target in ignore_nodes:
			continue
		var dist_sq: float = instance.global_position.distance_squared_to(camera_pos)
		if dist_sq < closest_distance_sq:
			closest_distance_sq = dist_sq
			closest_node = target
	
	return closest_node



func get_final_transform(raycast_result:Dictionary, apply_randomize:=false):
	var position = raycast_result.get(POSITION) as Vector3
	var normal = raycast_result.get(NORMAL) as Vector3
	
	var raycast_mode = settings.get(Settings.RAYCAST_MODE)
	var align_to_normal = settings.get(Settings.ALIGN_TO_NORMAL, false)
	var snapping_enabled = settings.get(Settings.GRID_SNAP, false)
	var snapping_value = float(settings.get(Settings.GRID_SIZE, 1))
	
	var rotation = settings.get(Settings.TRANSFORM_ROTATION, Vector3.ZERO)
	var scale = settings.get(Settings.TRANSFORM_SCALE, Vector3(1,1,1))
	var terrain_3D_snap_height = settings.get(Settings.TERRAIN_SNAP_TO, true)
	
	rotation = _deg_to_rad(rotation)
	
	
	if raycast_mode == RaycastMode.TERRAIN_3D:
		#terrain_3D = terrain_3D as Terrain3D
		#terrain_3D.data.get_height()
		var height = terrain_3D.data.get_height(position)
		if terrain_3D_snap_height and position.y < height:
			position.y = height
	
	if snapping_enabled:
		position = position.snappedf(snapping_value)
	
	var transform = Transform3D()
	transform.basis = Basis()
	if align_to_normal:
		if normal.is_equal_approx(Vector3.UP): pass
		elif normal.is_equal_approx(Vector3.DOWN):
			transform.basis = Basis.from_euler(Vector3(PI, 0, 0))
		else: # Create a quaternion that represents the rotation from UP to the Normal
			var q = Quaternion(Vector3.UP, normal.normalized())
			transform.basis = Basis(q)
	
	
	#transform.basis = transform.basis.rotated(transform.basis.y, rotation.y)
	transform = _apply_rotation(transform, rotation) #^r not sure about this
	
	
	transform.basis = transform.basis.orthonormalized()
	
	if scale != Vector3(1,1,1):
		transform = transform.scaled(scale)
	
	transform.origin = position
	
	if apply_randomize:
		transform = randomize_transform(transform)
	
	return transform


func randomize_transform(base_transform: Transform3D) -> Transform3D:
	
	
	var rotation_enabled = settings.get(Settings.RANDOMIZE_ROTATION_ENABLE, false)
	var scale_enabled = settings.get(Settings.RANDOMIZE_SCALE_ENABLE, false)
	
	if not (rotation_enabled or scale_enabled):
		return base_transform
	
	var final_t = base_transform
	
	var rot_variance = settings.get(Settings.RANDOMIZE_ROTATION, Vector3.ZERO) as Vector3
	rot_variance = _deg_to_rad(rot_variance)
	var scale_variance = settings.get(Settings.RANDOMIZE_SCALE, Vector3.ZERO) as Vector3
	print(rot_variance)
	# 1. RANDOM ROTATION
	if rotation_enabled:
		for i in range(3):
			var val: float = rot_variance[i]
			if is_zero_approx(val):
				continue
			
			var rand_angle = randf_range(-val, val)
			
			var axis = Vector3.UP
			match i:
				0: axis = Vector3.RIGHT # X
				1: axis = Vector3.UP    # Y
				2: axis = Vector3.BACK  # Z
			
			# rotated_local automatically handles the basis multiplication for you
			final_t = final_t.rotated_local(axis, rand_angle)

	# 2. RANDOM SCALE (Multiplicative)
	if scale_enabled:
		# Extract current scale (which includes your manual placement scale)
		var current_scale = final_t.basis.get_scale()
		var new_scale = current_scale
		
		for i in range(3):
			var val: float = scale_variance[i]
			if is_zero_approx(val):
				continue
			
			# Multiplicative Logic:
			# If val is 0.1, we get a factor between 0.9 and 1.1
			var rand_percent = randf_range(-val, val)
			var multiplier = 1.0 + rand_percent
			
			# Apply to the specific axis
			new_scale[i] *= multiplier
			
			# Safety check: prevent scale from hitting 0 or becoming negative
			new_scale[i] = max(0.01, new_scale[i])
			
		# Re-apply scale
		# We must orthonormalize to reset the basis axes to length 1.0 
		# before applying the new scale vector.
		final_t.basis = final_t.basis.orthonormalized().scaled(new_scale)

	return final_t


func _apply_rotation(transform:Transform3D, rotation:Vector3):
	var final_t = transform
	for i in range(3):
		var val: float = rotation[i]
		if is_zero_approx(val):
			continue
		
		var axis = Vector3.UP
		match i:
			0: axis = Vector3.RIGHT # X
			1: axis = Vector3.UP    # Y
			2: axis = Vector3.BACK  # Z
		
		final_t = final_t.rotated_local(axis, val)
	return final_t

func _apply_scale(transform:Transform3D, scale:Vector3):
	var final_t = transform
	var current_scale = final_t.basis.get_scale()
	var new_scale = current_scale
	
	for i in range(3):
		var val: float = scale[i]
		if is_zero_approx(val) or is_equal_approx(val, 1):
			continue
		new_scale[i] = max(0.01, val)
	
	final_t.basis = final_t.basis.orthonormalized().scaled(new_scale)
	return final_t


static func _deg_to_rad(rot:Vector3):
	return Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))


func get_setting(setting_name:StringName, default=null):
	return settings.get(setting_name, default)

class Settings:
	const RAYCAST_MODE = &"raycast_3d.settings.raycast_mode"
	const RAYCAST_DISTANCE = &"raycast_3d.settings.raycast_distance"
	const ALIGN_TO_NORMAL = &"raycast_3d.settings.align_to_normal"
	
	const GRID_SIZE = &"raycast_3d.settings.grid_size"
	const GRID_SNAP = &"raycast_3d.settings.grid_snap"
	
	const PLANE_DIRECTION = &"raycast_3d.settings.plane_direction"
	const PLANE_OFFSET = &"raycast_3d.settings.plane_offset"
	const PLANE_OFFSET_STEP = &"raycast_3d.settings.plane_offset_step"
	
	const TERRAIN_SNAP_TO = &"raycast_3d.settings.terrain_snap_to"
	const TERRAIN_USE_ALL_COL = &"raycast_3d.settings.terrain_use_all_col"
	
	
	const TRANSFORM_ROTATION = &"raycast_3d.settings.transform_rotation"
	const TRANSFORM_SCALE = &"raycast_3d.settings.transform_scale"
	
	const RANDOMIZE_ROTATION_ENABLE = &"raycast_3d.settings.randomize_rotation_enable"
	const RANDOMIZE_ROTATION = &"raycast_3d.settings.randomize_rotation"
	const RANDOMIZE_SCALE_ENABLE = &"raycast_3d.settings.randomize_scale_enable"
	const RANDOMIZE_SCALE = &"raycast_3d.settings.randomize_scale"
	const RANDOMIZE_POSITION = &"raycast_3d.settings.randomize_position"
