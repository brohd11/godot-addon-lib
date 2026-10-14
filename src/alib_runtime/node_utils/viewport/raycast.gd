

static func raycast(viewport: Viewport, distance:float=5000) -> Dictionary:
	var camera:Camera3D = viewport.get_camera_3d()
	var space_state:PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var mousepos:Vector2 = viewport.get_mouse_position()

	var origin:Vector3 = camera.project_ray_origin(mousepos)
	var end:Vector3 = origin + camera.project_ray_normal(mousepos) * distance
	var query:= PhysicsRayQueryParameters3D.create(origin, end)

	return space_state.intersect_ray(query)

static func raycast_plane(viewport: Viewport, plane: Plane, distance:float=1000) -> Variant:
	var camera:Camera3D = viewport.get_camera_3d()
	var mousepos:Vector2 = viewport.get_mouse_position()
	return plane.intersects_ray(camera.project_ray_origin(mousepos), camera.project_ray_normal(mousepos) * distance)

static func raycast_visual_instances(viewport:Viewport, distance:float=5000) -> PackedInt64Array:
	var camera:Camera3D = viewport.get_camera_3d()
	var mousepos:Vector2 = viewport.get_mouse_position()
	var origin := camera.project_ray_origin(mousepos)
	var end := origin + camera.project_ray_normal(mousepos) * distance
	return RenderingServer.instances_cull_ray(origin, end, camera.get_world_3d().scenario)


static func raycast_terrain_3d(viewport: Viewport, terrain3D_node) -> Vector3:
	var camera:Camera3D = viewport.get_camera_3d()
	var mousepos:Vector2= viewport.get_mouse_position()
	var origin:Vector3 = camera.project_ray_origin(mousepos)
	var direction:Vector3 = camera.project_ray_normal(mousepos)
	return terrain3D_node.get_intersection(origin, direction, true)
