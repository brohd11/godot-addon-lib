@tool
extends RefCounted

static func compile_scene(root_node: Node, references: Dictionary, save_path_base: String):
	print("Compiling scene: ", save_path_base)
	
	# 1. recursive "set_owner"
	# Godot will only save nodes to a PackedScene if their owner is the scene root.
	#_set_owner_recursive(root_node, root_node)
	
	# 2. Generate the "Accessor Script" source code
	var script_source = "@tool\n"
	script_source += "extends %s\n\n" % root_node.get_class()
	for var_name in references:
		var node = references[var_name]
		if not is_instance_valid(node):
			printerr("Warning: Reference '%s' is invalid." % var_name)
			continue
		
		node.owner = root_node
		var parent = node.get_parent()
		while is_instance_valid(parent) and parent != root_node:
			parent.owner = root_node
			parent = parent.get_parent()
		
		# Calculate the path relative to the root
		# The node MUST be a child of root for this to work
		var node_path = root_node.get_path_to(node)
		var type_name = node.get_class()
		
		# Generate: @onready var my_button: Button = $"Path/To/Button"
		# We use get_node() syntax ($"...") to handle spaces/special chars in names safely
		script_source += "@onready var %s: %s = $\"%s\"\n" % [var_name, type_name, node_path]
	
	# 3. Save the Generated Script
	var script_path = save_path_base + ".gd"
	var script = GDScript.new()
	script.source_code = script_source
	
	root_node.set_script(script)
	
	#var err = ResourceSaver.save(script, script_path)
	#if err != OK:
		#printerr("Failed to save generated script: ", err)
		#return

	# 4. Attach script to Root and Refresh
	# We must load it back from disk so the Editor recognizes the resource path properly
	
	#var loaded_script = ResourceLoader.load(script_path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
	#root_node.set_script(loaded_script)
	
	# 5. Pack and Save Binary Scene (.scn)
	var scene = PackedScene.new()
	var result = scene.pack(root_node)
	if result == OK:
		var scene_path = save_path_base + ".scn"
		ResourceSaver.save(scene, scene_path)
		print("Success! Compiled to: ", scene_path)
		
		# Clean up memory
		#root_node.free() 
		
		# Update Editor FileSystem
		#EditorInterface.get_resource_filesystem().scan()
	else:
		printerr("Failed to pack scene: ", result)

static func _set_owner_recursive(node: Node, root: Node):
	if node != root:
		node.owner = root
	for child in node.get_children():
		_set_owner_recursive(child, root)
