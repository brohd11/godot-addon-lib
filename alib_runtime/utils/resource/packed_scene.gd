const UFile = preload("uid://bl33psa06nv1e") #! resolve ALibRuntime.Utils.UFile.Methods
const UNode = preload("uid://dsywt12xnn7oh") # u_node.gd

const ReadFile = preload("res://addons/addon_lib/brohd/alib_runtime/utils/resource/packed_scene/read_file.gd")
const ScnCompiler = preload("res://addons/addon_lib/brohd/alib_runtime/utils/resource/packed_scene/scn_compiler.gd")

static func get_scene_aabb(scene_root:Node) -> AABB:
	var nodes = UNode.recursive_get_nodes(scene_root)
	var mesh_nodes = []
	for n in nodes:
		if n is MeshInstance3D:
			mesh_nodes.append(n)
	var first_aabb:AABB
	for mesh_instance:MeshInstance3D in mesh_nodes:
		var mesh:Mesh = mesh_instance.mesh
		var aabb:AABB = mesh.get_aabb()
		if not first_aabb:
			first_aabb = aabb
		else:
			first_aabb.merge(aabb)
	
	return first_aabb
